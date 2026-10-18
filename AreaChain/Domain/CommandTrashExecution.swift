import Foundation

extension CommandHandoffCoordinator {
    func withTrashPreparation<T>(expecting lease: CommandHostLease, _ work: () throws -> T) throws -> T {
        try validate(lease)
        guard !hasInvocation(lease.ownership) else { throw CommandExecutionError.busy }
        trashes.preparing[lease.ownership.hostID] = lease.ownership
        defer { trashes.preparing[lease.ownership.hostID] = nil }
        return try work()
    }

    /// 回收只走单项 Run；多项计划授权、输出依赖与重放许可都不能取得此入口。
    func trashAcceptance(_ request: TaskTitleCommandRequest) throws -> (CommandTrashAcceptance, CommandTrashConfirmation) {
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
              let accepted = trashes.acceptances[item.draft.id] else { throw CommandTrashIssue.stale }
        let confirmation = try trashes.confirmation(for: accepted)
        _ = try accepted.preview.frozenItem(in: run, lease: request.lease)
        return (accepted, confirmation)
    }

    func claimTrash(_ request: TaskTitleCommandRequest) throws -> CommandRuntimeInvocation {
        let (accepted, _) = try trashAcceptance(request)
        guard !trashes.wasInvoked(accepted.id) else { throw CommandTrashIssue.alreadyInvoked }
        let invocation = try claimRuntimeInvocation(request.operation, attempt: request.attempt, expecting: request.lease)
        trashes.markInvoked(accepted.id)
        return invocation
    }

    func recordTrash(_ invocation: CommandRuntimeInvocation, facts: CommandTrashFacts) throws {
        let current = try taskMutationHost(invocation)
        guard let item = current.session.execution?.snapshot.items.first(where: { $0.id == invocation.operation.operationID }),
              let accepted = trashes.acceptances[item.draft.id], accepted.id == facts.acceptanceID,
              accepted.preview.item == item.stamp, accepted.preview.targets == facts.targets,
              accepted.preview.impacts == facts.impacts, trashes.confirmations[accepted.id]?.id == facts.confirmationID,
              trashes.wasInvoked(accepted.id) else {
            throw CommandExecutionError.invalidResult
        }
        var next = current.session
        try next.recordTrash(facts, attempt: invocation.attempt)
        publishPreferenceSession(next, from: current.lease)
    }
}
