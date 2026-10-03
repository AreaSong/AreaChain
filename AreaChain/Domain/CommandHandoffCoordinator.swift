import Foundation
import Observation

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
        var next = try host(lease.ownership.hostID).session
        let effect = try next.applyOwnedEvent(event)
        // 连相同文字的再次输入和无状态输出的操作意图也使准备票据失效。
        hosts[lease.ownership.hostID] = .init(
            lease: .init(ownership: lease.ownership, revision: lease.revision + 1), session: next)
        return effect
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
