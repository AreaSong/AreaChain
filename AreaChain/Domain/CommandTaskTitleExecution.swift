import Foundation

extension CommandHandoffCoordinator {
    func withTaskTitlePreparation<T>(expecting lease: CommandHostLease, _ work: () throws -> T) throws -> T {
        try validate(lease)
        guard !hasInvocation(lease.ownership) else { throw CommandExecutionError.busy }
        taskTitles.preparing[lease.ownership.hostID] = lease.ownership
        defer { taskTitles.preparing[lease.ownership.hostID] = nil }
        return try work()
    }

    func taskTitleAcceptance(_ request: TaskTitleCommandRequest) throws -> CommandTaskTitleAcceptance {
        try validate(request.lease)
        let session = try host(request.lease.ownership.hostID).session
        guard let run = session.execution, run.operation(request.operation.operationID) == request.operation,
              run.attempt(request.attempt.unitID) == request.attempt, request.attempt.phase == .local,
              let unit = run.units.first(where: { $0.id == request.attempt.unitID }), unit.state == .running, unit.local == .notSubmitted,
              session.plan.items.isEmpty, session.operations.allDrafts.isEmpty, session.operations.pending == nil,
              let item = run.snapshot.items.first(where: { $0.id == request.operation.operationID }),
              let accepted = taskTitles.acceptances[item.draft.id] else { throw TaskTitleCommandIssue.stale }
        if let chain = accepted.preview.binding.chain {
            guard try taskChainBinding(expecting: request.lease) == chain else { throw TaskTitleCommandIssue.stale }
        } else {
            guard run.units.count == 1, run.snapshot.items.count == 1 else { throw TaskTitleCommandIssue.stale }
        }
        _ = try accepted.preview.frozenInput(in: run, lease: request.lease)
        return accepted
    }

    func claimTaskTitle(_ request: TaskTitleCommandRequest) throws -> CommandRuntimeInvocation {
        let accepted = try taskTitleAcceptance(request)
        guard !taskTitles.wasInvoked(accepted.id) else { throw TaskTitleCommandIssue.alreadyInvoked }
        let invocation: CommandRuntimeInvocation
        if let chain = accepted.preview.binding.chain {
            invocation = try claimTaskChainInvocation(request.operation, attempt: request.attempt, expecting: request.lease, identity: chain.identity)
        } else { invocation = try claimRuntimeInvocation(request.operation, attempt: request.attempt, expecting: request.lease) }
        taskTitles.markInvoked(accepted.id)
        return invocation
    }
}
