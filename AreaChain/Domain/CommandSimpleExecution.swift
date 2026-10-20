import Foundation

/// 简单修改的执行事实。noChange 零保存；saved 只在保存成功后出现；unknown 不自动重试。
struct CommandSimpleFacts: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    enum State: String, Equatable { case pending, notSubmitted, noChange, saved, unknown }
    let acceptanceID: UUID
    let command: CommandID
    let input: CommandResolvedInput
    let before: CommandSimpleState
    let after: CommandSimpleState
    /// 新建型指令的新对象身份；回执用它打开新对象，未知核对用它只读查找。
    let creation: CommandObjectReference?
    var state: State = .pending
    var save = CommandTaskTitleFacts.Call.notCalled
    var rollback = CommandTaskTitleFacts.Call.notCalled
    var publication = CommandTaskTitleFacts.Call.notCalled
    var registrationFailed = false
    var publicationFailed = false
    var conflict = false
    /// 保存成功后是否发出了系统后续请求（如提醒授权）；只表示已请求，不代表系统已处理。
    var followUpRequested = false
    var description: String { "CommandSimpleFacts(\(state))" }
    var debugDescription: String { description }

    init(_ accepted: CommandSimpleAcceptance) {
        acceptanceID = accepted.id
        command = accepted.preview.command
        input = accepted.preview.input
        before = accepted.preview.before
        after = accepted.preview.after
        creation = accepted.preview.creation
    }
    var frozenCall: CommandSimpleCall { .init(input: input, creation: creation, frozen: before.keys.union(after.keys)) }

    func receipt(in run: CommandExecutionRun, attempt: CommandAttemptStamp) throws -> (Int, CommandExecutionResult?) {
        guard attempt.execution == run.stamp, attempt.phase == .local, run.multiPlan == nil, run.permitsMember(attempt.unitID),
              let item = run.snapshot.items.first(where: { $0.id == attempt.unitID }), item.id == attempt.unitID,
              let index = run.units.firstIndex(where: { $0.id == attempt.unitID }),
              run.units[index].attempt == attempt.number, run.units[index].currentPhase == .local else {
            throw CommandExecutionError.stale
        }
        guard run.canRecordLocalFacts(attempt, unit: run.units[index], hasPrevious: run.units[index].simple != nil) else {
            throw CommandExecutionError.stale
        }
        guard item.draft.commandID == command, run.resolvedInput(item.id) == input, run.outputs[item.id] == nil else {
            throw CommandExecutionError.invalidResult
        }
        if let previous = run.units[index].simple {
            guard previous.acceptanceID == acceptanceID, previous.input == input, previous.before == before,
                  previous.after == after, previous.state == .pending || previous.state == state else {
                throw CommandExecutionError.invalidResult
            }
        }
        switch state {
        case .pending: return (index, nil)
        case .noChange:
            guard save == .notCalled, rollback == .notCalled, publication == .notCalled, before == after else {
                throw CommandExecutionError.invalidResult
            }
            return (index, .noChange)
        case .saved:
            guard save == .returned else { throw CommandExecutionError.invalidResult }
            return (index, .committed(outputs: [:], external: [.taskPublication]))
        case .unknown: return (index, .commitUnknown)
        case .notSubmitted:
            guard save == .notCalled else { throw CommandExecutionError.invalidResult }
            return (index, .failedWithoutCommit)
        }
    }
}

extension CommandHandoffCoordinator {
    func withSimplePreparation<T>(expecting lease: CommandHostLease, _ work: () throws -> T) throws -> T {
        try validate(lease)
        guard !hasInvocation(lease.ownership) else { throw CommandExecutionError.busy }
        simples.preparing[lease.ownership.hostID] = lease.ownership
        defer { simples.preparing[lease.ownership.hostID] = nil }
        return try work()
    }

    /// 简单指令只走单项 Run 的第一次尝试；多项计划授权、输出依赖与重放许可都不能取得此入口。
    func simpleAcceptance(_ request: TaskTitleCommandRequest) throws -> CommandSimpleAcceptance {
        try validate(request.lease)
        let session = try host(request.lease.ownership.hostID).session
        guard let run = session.execution, run.multiPlan == nil, run.snapshot.items.count == 1,
              run.operation(request.operation.operationID) == request.operation,
              run.attempt(request.attempt.unitID) == request.attempt, request.attempt.phase == .local,
              request.attempt.number == 1, run.permitsMember(request.operation.operationID),
              let unit = run.units.first(where: { $0.id == request.attempt.unitID }),
              unit.state == .running, unit.local == .notSubmitted,
              session.plan.items.isEmpty, session.operations.allDrafts.isEmpty, session.operations.pending == nil,
              let item = run.snapshot.items.first(where: { $0.id == request.operation.operationID }),
              let accepted = simples.acceptances[item.draft.id] else { throw CommandSimpleIssue.stale }
        return accepted
    }

    func claimSimple(_ request: TaskTitleCommandRequest) throws -> CommandRuntimeInvocation {
        let accepted = try simpleAcceptance(request)
        guard !simples.wasInvoked(accepted.id) else { throw CommandSimpleIssue.alreadyInvoked }
        let invocation = try claimRuntimeInvocation(request.operation, attempt: request.attempt, expecting: request.lease)
        simples.markInvoked(accepted.id)
        // 确认只用一次：执行开始即撤销（合并批 M-2）。
        simples.confirmations.revoke(acceptanceID: accepted.id)
        return invocation
    }

    func recordSimple(_ invocation: CommandRuntimeInvocation, facts: CommandSimpleFacts) throws {
        let current = try taskMutationHost(invocation)
        guard let item = current.session.execution?.snapshot.items.first(where: { $0.id == invocation.operation.operationID }),
              let accepted = simples.acceptances[item.draft.id], accepted.id == facts.acceptanceID,
              accepted.preview.item == item.stamp, accepted.preview.input == facts.input,
              accepted.preview.before == facts.before, accepted.preview.after == facts.after,
              simples.wasInvoked(accepted.id) else {
            throw CommandExecutionError.invalidResult
        }
        var next = current.session
        try next.recordSimple(facts, attempt: invocation.attempt)
        publishPreferenceSession(next, from: current.lease)
    }
}
