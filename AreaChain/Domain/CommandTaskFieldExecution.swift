import Foundation

extension CommandHandoffCoordinator {
    func withTaskFieldPreparation<T>(expecting lease: CommandHostLease, _ work: () throws -> T) throws -> T {
        try validate(lease)
        guard !hasInvocation(lease.ownership) else { throw CommandExecutionError.busy }
        taskFields.preparing[lease.ownership.hostID] = lease.ownership
        defer { taskFields.preparing[lease.ownership.hostID] = nil }
        return try work()
    }

    func taskFieldAcceptance(_ request: TaskTitleCommandRequest) throws -> CommandTaskFieldAcceptance {
        try validate(request.lease)
        let session = try host(request.lease.ownership.hostID).session
        guard let run = session.execution, run.operation(request.operation.operationID) == request.operation,
              run.attempt(request.attempt.unitID) == request.attempt, request.attempt.phase == .local,
              run.units.count == 1, run.units[0].state == .running, run.units[0].local == .notSubmitted,
              session.plan.items.isEmpty, session.operations.allDrafts.isEmpty, session.operations.pending == nil,
              let item = run.snapshot.items.first,
              let accepted = taskFields.acceptances[item.draft.id] else { throw TaskFieldCommandIssue.stale }
        _ = try accepted.preview.frozenItem(in: run, lease: request.lease)
        return accepted
    }

    func claimTaskField(_ request: TaskTitleCommandRequest) throws -> CommandRuntimeInvocation {
        let accepted = try taskFieldAcceptance(request)
        guard !taskFields.wasInvoked(accepted.id) else { throw TaskFieldCommandIssue.alreadyInvoked }
        let invocation = try claimRuntimeInvocation(request.operation, attempt: request.attempt, expecting: request.lease)
        taskFields.markInvoked(accepted.id)
        return invocation
    }

    func recordTaskField(_ invocation: CommandRuntimeInvocation, facts: CommandTaskFieldFacts) throws {
        let current = try taskMutationHost(invocation)
        guard let item = current.session.execution?.snapshot.items.first,
              let accepted = taskFields.acceptances[item.draft.id], accepted.preview.item == item.stamp,
              accepted.preview.target.id == facts.targetID, taskFields.wasInvoked(accepted.id) else {
            throw CommandExecutionError.invalidResult
        }
        var next = current.session
        try next.recordTaskField(facts, attempt: invocation.attempt)
        publishPreferenceSession(next, from: current.lease)
    }

    func finishTaskField(_ invocation: CommandRuntimeInvocation,
                         external: [CommandExternalEffect: CommandExternalResult]) throws {
        try finishTaskMutation(invocation, external: external)
    }
}
