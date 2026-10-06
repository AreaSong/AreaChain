import Foundation
import Observation

struct CommandRuntimeInvocation: Equatable {
    let id: UUID
    let lease: CommandHostLease
    let operation: CommandOperationIdentity
    let attempt: CommandAttemptStamp
    fileprivate init(id: UUID, lease: CommandHostLease, operation: CommandOperationIdentity, attempt: CommandAttemptStamp) {
        self.id = id
        self.lease = lease
        self.operation = operation
        self.attempt = attempt
    }
}

struct CommandPreferenceGroupInvocation: Equatable {
    let id: UUID
    let lease: CommandHostLease
    let identity: CommandPreferenceGroupIdentity
    let attempt: CommandAttemptStamp
    let verification: Bool
    fileprivate init(lease: CommandHostLease, identity: CommandPreferenceGroupIdentity,
                     attempt: CommandAttemptStamp, verification: Bool) {
        id = UUID()
        self.lease = lease
        self.identity = identity
        self.attempt = attempt
        self.verification = verification
    }
}

/// 注入的单一运行内权威；引用不能按值复制。MainActor 串行、同步且无回调的提交不存在半次发布。
/// 只登记指令宿主，不持有窗口、文件能力、业务对象或全局单例；不提供从旧快照重新登记的入口。
@Observable @MainActor final class CommandHandoffCoordinator: CustomStringConvertible, CustomDebugStringConvertible {
    private struct Pending {
        let ticket: CommandHandoffTicket
        var readiness: CommandHandoffReadiness?
    }

    private let id = UUID()
    @ObservationIgnored private var hosts: [String: CommandOwnedHost] = [:]
    @ObservationIgnored private var pending: [UUID: Pending] = [:]
    @ObservationIgnored private var statuses: [UUID: CommandHandoffStatus] = [:]
    @ObservationIgnored private var invocations: [UUID: CommandRuntimeInvocation] = [:]
    @ObservationIgnored private var invokedAttempts: Set<CommandAttemptStamp> = []
    @ObservationIgnored private var groupInvocations: [UUID: CommandPreferenceGroupInvocation] = [:]
    @ObservationIgnored let taskCreations = CommandTaskCreateRegistry()
    private(set) var ownershipRevision: UInt64 = 0

    init(pages: [ContentQueryPageContext]) throws {
        guard Set(pages.map { $0.location.hostID }).count == pages.count else { throw CommandHandoffError.duplicate }
        for page in pages {
            let ownership = CommandHostOwnership(coordinatorID: id, hostID: page.location.hostID, generation: 0)
            hosts[page.location.hostID] = .init(lease: .init(ownership: ownership, revision: 0), session: .init(page: page))
        }
    }

    nonisolated var description: String { "CommandHandoffCoordinator(redacted)" }
    nonisolated var debugDescription: String { description }

    func host(_ hostID: String) throws -> CommandOwnedHost {
        guard let host = hosts[hostID] else { throw CommandHandoffError.stale }
        return host
    }

    func status(_ ticketID: UUID) -> CommandHandoffStatus? { statuses[ticketID] }

    /// 适配在派发未来执行/回调前必须验证当前 lease，并保留原事件身份，禁止给旧事件补发新 lease。
    func validate(_ lease: CommandHostLease) throws {
        guard hosts[lease.ownership.hostID]?.lease == lease else { throw CommandHandoffError.stale }
    }

    @discardableResult func send(_ event: CommandHostEvent, expecting lease: CommandHostLease) throws -> CommandHostEffect {
        try validate(lease)
        if hasInvocation(lease.ownership) {
            switch event {
            case .query: break
            default: throw CommandExecutionError.busy
            }
        }
        var next = try host(lease.ownership.hostID).session
        let effect = try next.applyOwnedEvent(event)
        // 连相同文字的再次输入和无状态输出的操作意图也使准备票据失效。
        hosts[lease.ownership.hostID] = .init(
            lease: .init(ownership: lease.ownership, revision: lease.revision + 1), session: next)
        return effect
    }

    /// 在任何可重入 IO 前登记；所有适配实例共用此登记，纯回执去重不能替代它。
    func claimPreferenceInvocation(_ operation: CommandOperationIdentity, attempt: CommandAttemptStamp,
                                   expecting lease: CommandHostLease) throws -> CommandRuntimeInvocation {
        try claimRuntimeInvocation(operation, attempt: attempt, expecting: lease)
    }

    func claimRuntimeInvocation(_ operation: CommandOperationIdentity, attempt: CommandAttemptStamp,
                                expecting lease: CommandHostLease) throws -> CommandRuntimeInvocation {
        try validate(lease)
        let session = try host(lease.ownership.hostID).session
        guard let run = session.execution, run.stamp == operation.execution,
              run.operation(operation.operationID) == operation, run.attempt(attempt.unitID) == attempt,
              run.snapshot.items.count == 1, run.units.count == 1,
              run.units[0].state == .running, run.units[0].receipt?.attempt != attempt,
              session.plan.items.isEmpty, session.operations.active == nil, session.operations.pending == nil,
              !invokedAttempts.contains(attempt),
              !hasInvocation(lease.ownership) else {
            throw CommandExecutionError.stale
        }
        let invocation = CommandRuntimeInvocation(id: UUID(), lease: lease, operation: operation, attempt: attempt)
        invokedAttempts.insert(attempt)
        invocations[invocation.id] = invocation
        return invocation
    }

    func validatePreferenceInvocation(_ invocation: CommandRuntimeInvocation) throws {
        try validateRuntimeInvocation(invocation)
    }

    func validateRuntimeInvocation(_ invocation: CommandRuntimeInvocation) throws {
        guard invocations[invocation.id] == invocation else { throw CommandExecutionError.stale }
        try validate(invocation.lease)
        let run = try host(invocation.lease.ownership.hostID).session.execution
        guard run?.operation(invocation.operation.operationID) == invocation.operation,
              run?.attempt(invocation.attempt.unitID) == invocation.attempt else { throw CommandExecutionError.stale }
    }

    /// 可信完成只跨同一 ownership 的展示修订；不会给产生请求的旧 lease 续租。
    func completePreferenceInvocation(_ invocation: CommandRuntimeInvocation, result: CommandExecutionResult) throws {
        guard invocations[invocation.id] == invocation else { throw CommandExecutionError.stale }
        let current = try host(invocation.lease.ownership.hostID)
        guard current.lease.ownership == invocation.lease.ownership,
              current.session.execution?.operation(invocation.operation.operationID) == invocation.operation else {
            throw CommandExecutionError.stale
        }
        var next = current.session
        try next.receiveProtocolResult(.init(attempt: invocation.attempt, result: result))
        hosts[next.hostID] = .init(lease: .init(ownership: current.lease.ownership,
                                             revision: current.lease.revision + 1), session: next)
        invocations[invocation.id] = nil
    }

    func replacePreferenceBaseline(_ baseline: CommandDraftBaseline, arguments: [CommandArgument],
                                   draft: CommandDraftStamp, expecting lease: CommandHostLease) throws {
        try validate(lease)
        guard !hasInvocation(lease.ownership) else { throw CommandExecutionError.busy }
        var next = try host(lease.ownership.hostID).session
        try next.replacePreferenceBaseline(baseline, arguments: arguments, expecting: draft)
        hosts[next.hostID] = .init(lease: .init(ownership: lease.ownership, revision: lease.revision + 1), session: next)
    }

    func returnUnsubmittedPreference(_ attempt: CommandAttemptStamp, plan: CommandPlanStamp,
                                    expecting lease: CommandHostLease) throws {
        try validate(lease)
        guard !hasInvocation(lease.ownership) else {
            throw CommandExecutionError.busy
        }
        var next = try host(lease.ownership.hostID).session
        try next.returnUnsubmittedPreference(attempt, expecting: plan)
        hosts[next.hostID] = .init(lease: .init(ownership: lease.ownership, revision: lease.revision + 1), session: next)
    }

    private func hasInvocation(_ ownership: CommandHostOwnership) -> Bool {
        invocations.values.contains { $0.lease.ownership == ownership }
            || groupInvocations.values.contains { $0.lease.ownership == ownership }
            || taskCreations.preparing[ownership.hostID] == ownership
    }

    /// 任务事实先进入原 Run，随后事件撤销显示许可也不会丢掉已提交输出。
    func recordTaskCreation(_ invocation: CommandRuntimeInvocation, facts: CommandTaskCreateFacts) throws {
        let current = try taskCreationHost(invocation)
        guard let item = current.session.execution?.snapshot.items.first,
              let prepared = taskCreations.preparations[item.draft.id], prepared.item == item.stamp,
              prepared.creationID == facts.creationID, taskCreations.wasInvoked(prepared.id) else {
            throw CommandExecutionError.invalidResult
        }
        var next = current.session
        try next.recordTaskCreation(facts, attempt: invocation.attempt)
        publishPreferenceSession(next, from: current.lease)
    }

    func finishTaskCreation(_ invocation: CommandRuntimeInvocation,
                            external: [CommandExternalEffect: CommandExternalResult]) throws {
        let current = try taskCreationHost(invocation)
        var next = current.session
        if next.execution?.units.first?.local == .committed {
            let attempt = try next.beginNextProtocolStep(expecting: invocation.operation.execution)
            try next.receiveProtocolResult(.init(attempt: attempt, result: .external(external)))
        }
        publishPreferenceSession(next, from: current.lease)
        invocations[invocation.id] = nil
    }

    private func taskCreationHost(_ invocation: CommandRuntimeInvocation) throws -> CommandOwnedHost {
        guard invocations[invocation.id] == invocation else { throw CommandExecutionError.stale }
        let current = try host(invocation.lease.ownership.hostID)
        guard current.lease.ownership == invocation.lease.ownership,
              current.session.execution?.operation(invocation.operation.operationID) == invocation.operation else {
            throw CommandExecutionError.stale
        }
        return current
    }

    func replacePreferenceGroupBaselines(_ updates: [CommandPreferenceBaselineUpdate], plan: CommandPlanStamp,
                                         expecting lease: CommandHostLease) throws {
        try validate(lease)
        guard !hasInvocation(lease.ownership) else { throw CommandExecutionError.busy }
        var next = try host(lease.ownership.hostID).session
        try next.replacePreferenceGroupBaselines(updates, expecting: plan)
        publishPreferenceSession(next, from: lease)
    }

    /// 多适配实例共享的调用占用，在 AppPreferences 与任何文件 IO 之前取得。
    func claimPreferenceGroup(_ identity: CommandPreferenceGroupIdentity, attempt: CommandAttemptStamp,
                              expecting lease: CommandHostLease, verification: Bool = false) throws -> CommandPreferenceGroupInvocation {
        try validate(lease)
        let session = try host(lease.ownership.hostID).session
        guard !hasInvocation(lease.ownership), let run = session.execution,
              run.preferenceGroupIdentity() == identity, identity.unitID == attempt.unitID,
              run.attempt(attempt.unitID) == attempt, let unit = run.units.first,
              session.plan.items.isEmpty, session.operations.active == nil, session.operations.pending == nil else {
            throw CommandExecutionError.stale
        }
        if verification {
            guard unit.local == .unknown, unit.state == .verificationRequired else { throw CommandExecutionError.stale }
        } else {
            guard unit.state == .running, !invokedAttempts.contains(attempt) else { throw CommandExecutionError.stale }
            invokedAttempts.insert(attempt)
        }
        let invocation = CommandPreferenceGroupInvocation(lease: lease, identity: identity,
                                                         attempt: attempt, verification: verification)
        groupInvocations[invocation.id] = invocation
        return invocation
    }

    func validatePreferenceGroup(_ invocation: CommandPreferenceGroupInvocation) throws {
        try validate(invocation.lease)
        _ = try groupHost(invocation)
        guard try host(invocation.lease.ownership.hostID).session.execution?.attempt(invocation.attempt.unitID)
                == invocation.attempt else { throw CommandExecutionError.stale }
    }

    /// 可信本地事实跨展示修订归原运行；占用保持到展示事实入账，不能中途转交或释放。
    func recordPreferenceGroup(_ invocation: CommandPreferenceGroupInvocation, result: CommandPreferenceGroupCommit) throws {
        let current = try groupHost(invocation)
        var next = current.session
        let receipt = CommandExecutionReceipt(attempt: invocation.attempt, result: .preferenceGroupCommit(result))
        if invocation.verification { try next.verifyPreferenceGroup(receipt) }
        else { try next.receiveProtocolResult(receipt) }
        publishPreferenceSession(next, from: current.lease)
    }

    @discardableResult
    func finishPreferenceGroup(_ invocation: CommandPreferenceGroupInvocation,
                               presentation: CommandPreferenceGroupPresentation? = nil) throws -> CommandExecutionReceipt? {
        let current = try groupHost(invocation)
        var next = current.session
        var receipt: CommandExecutionReceipt?
        if let presentation {
            let attempt: CommandAttemptStamp
            if invocation.attempt.phase == .external { attempt = invocation.attempt }
            else { attempt = try next.beginNextProtocolStep(expecting: invocation.identity.execution) }
            receipt = .init(attempt: attempt, result: .preferenceGroupPresentation(presentation))
            try next.receiveProtocolResult(receipt!)
        }
        publishPreferenceSession(next, from: current.lease)
        groupInvocations[invocation.id] = nil
        return receipt
    }

    private func groupHost(_ invocation: CommandPreferenceGroupInvocation) throws -> CommandOwnedHost {
        guard groupInvocations[invocation.id] == invocation else { throw CommandExecutionError.stale }
        let current = try host(invocation.lease.ownership.hostID)
        guard current.lease.ownership == invocation.lease.ownership,
              current.session.execution?.preferenceGroupIdentity() == invocation.identity else { throw CommandExecutionError.stale }
        return current
    }

    private func publishPreferenceSession(_ session: CommandHostSession, from lease: CommandHostLease) {
        hosts[session.hostID] = .init(lease: .init(ownership: lease.ownership, revision: lease.revision + 1), session: session)
    }

    /// 凭据只能由成功封存的内容服务生成，仍由此处核验唯一当前宿主。
    func acceptProtection(_ checkpoint: CommandDraftCheckpoint) throws {
        try validate(checkpoint.lease)
        var next = try host(checkpoint.lease.ownership.hostID).session
        guard next.allDrafts.contains(where: { $0.stamp == checkpoint.draft }) else { throw CommandHandoffError.stale }
        try checkpoint.consume()
        try next.acceptProtection(checkpoint.reference, expecting: checkpoint.draft)
        hosts[next.hostID] = .init(lease: .init(ownership: checkpoint.lease.ownership,
                                              revision: checkpoint.lease.revision + 1), session: next)
    }

    /// 系统失效只跨越同一所有权内的用户修订；不能跨转交代次，也不能重盖旧用户事件。
    /// 仍经 send 委托唯一 HostSession，仅清查询，草稿/计划/执行不变。
    @discardableResult
    func invalidateSearch(ownedBy ownership: CommandHostOwnership) throws -> CommandHostLease {
        let current = try host(ownership.hostID)
        guard current.lease.ownership == ownership else { throw CommandHandoffError.stale }
        try send(.query(.privacyInvalidated), expecting: current.lease)
        return try host(ownership.hostID).lease
    }

    func prepare(id: UUID, source: CommandHostLease, target: CommandHostLease) throws -> CommandHandoffTicket {
        guard source.ownership.hostID != target.ownership.hostID else { throw CommandHandoffError.sameHost }
        guard statuses[id] == nil else { throw CommandHandoffError.duplicate }
        try validate(source)
        try validate(target)
        let involved = [source.ownership.hostID, target.ownership.hostID]
        guard !pending.values.contains(where: {
            involved.contains($0.ticket.source.ownership.hostID) || involved.contains($0.ticket.target.ownership.hostID)
        }) else { throw CommandHandoffError.transferInProgress }
        let sourceState = try host(source.ownership.hostID).session
        let targetState = try host(target.ownership.hostID).session
        try checkEligibility(source: sourceState, target: targetState)
        let ticket = CommandHandoffTicket(id: id, source: source, target: target, requirements: .init(
            replacesQuery: targetState.query.requiresHandoffReplacement, nativeSelections: sourceState.handoffNativeSelections))
        pending[id] = .init(ticket: ticket)
        statuses[id] = .preparing
        return ticket
    }

    func confirm(_ ticket: CommandHandoffTicket, readiness: CommandHandoffReadiness) throws {
        let current = try currentPending(ticket)
        try validate(ticket.source)
        try validate(ticket.target)
        guard !ticket.requirements.replacesQuery || readiness.acceptsQueryReplacement else {
            throw CommandHandoffError.queryReplacementRequired
        }
        guard readiness.confirmedNativeSelections == ticket.requirements.nativeSelections else {
            throw CommandHandoffError.resourcesUnconfirmed
        }
        if let previous = current.readiness {
            guard previous == readiness else { throw CommandHandoffError.stale }
            return
        }
        pending[ticket.id]?.readiness = readiness
        statuses[ticket.id] = .confirmed
    }

    func commit(_ ticket: CommandHandoffTicket) throws {
        guard try currentPending(ticket).readiness != nil else { throw CommandHandoffError.receiverUnconfirmed }
        try validate(ticket.source)
        try validate(ticket.target)
        let source = try host(ticket.source.ownership.hostID)
        let target = try host(ticket.target.ownership.hostID)
        try checkEligibility(source: source.session, target: target.session)
        let moved = try source.session.handoffStates(to: target.session)
        var next = hosts
        next[source.session.hostID] = renewed(source, session: moved.source)
        next[target.session.hostID] = renewed(target, session: moved.target)
        // 所有可能失败的计算已结束；唯一发布点同时撤去两端旧代次。
        hosts = next
        pending[ticket.id] = nil
        statuses[ticket.id] = .completed
        // 两端已原子发布后才通知展示层撤权；观察者不能介入半次转交。
        ownershipRevision &+= 1
    }

    func cancel(_ ticket: CommandHandoffTicket) throws {
        _ = try currentPending(ticket)
        pending[ticket.id] = nil
        statuses[ticket.id] = .cancelled
    }

    /// 未来窗口/资源适配的失败只终结票据，不改变会话或伪造接收成功。
    func fail(_ ticket: CommandHandoffTicket, reason: CommandHandoffFailure) throws {
        _ = try currentPending(ticket)
        pending[ticket.id] = nil
        statuses[ticket.id] = .failed(reason)
    }

    private func currentPending(_ ticket: CommandHandoffTicket) throws -> Pending {
        guard let current = pending[ticket.id], current.ticket == ticket else { throw CommandHandoffError.stale }
        return current
    }

    private func checkEligibility(source: CommandHostSession, target: CommandHostSession) throws {
        guard !source.allDrafts.contains(where: \.blocksUnprotectedTransfer) else { throw CommandHandoffError.protectedContent }
        // 包括非忙碌的成功、失败、冲突、部分/未知结果；运行绝不随转交迁移或抹除。
        guard source.execution == nil, target.execution == nil,
              source.operations.pending == nil, target.operations.pending == nil else { throw CommandHandoffError.ineligible }
        guard target.operations.active == nil, target.operations.retained.isEmpty,
              target.plan.items.isEmpty, target.plan.editing == nil else { throw CommandHandoffError.targetOccupied }
        guard CommandPlanValidation.structure(source.plan.items).isEmpty else { throw CommandHandoffError.invalidPlan }
    }

    private func renewed(_ old: CommandOwnedHost, session: CommandHostSession) -> CommandOwnedHost {
        let ownership = CommandHostOwnership(coordinatorID: id, hostID: session.hostID,
                                             generation: old.lease.ownership.generation + 1)
        return .init(lease: .init(ownership: ownership, revision: old.lease.revision + 1), session: session)
    }
}
