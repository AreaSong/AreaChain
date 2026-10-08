import Foundation

extension CommandHandoffCoordinator {
    func routineCreationAcceptance(_ request: RoutineCommandRequest) throws -> CommandRoutineCreateAcceptance {
        try validate(request.lease)
        let session = try host(request.lease.ownership.hostID).session
        guard let run = session.execution, run.operation(request.operation.operationID) == request.operation,
              run.attempt(request.attempt.unitID) == request.attempt, request.attempt.phase == .local,
              run.units.count == 1, run.units[0].state == .running, run.units[0].local == .notSubmitted,
              session.plan.items.isEmpty, session.operations.allDrafts.isEmpty, session.operations.pending == nil,
              let item = run.snapshot.items.first,
              let accepted = taskCreations.routinePreparations[item.draft.id] else { throw RoutineCreateIssue.stale }
        _ = try accepted.preview.frozenItem(in: run, lease: request.lease)
        return accepted
    }

    func claimRoutineCreation(_ request: RoutineCommandRequest) throws -> CommandRuntimeInvocation {
        let accepted = try routineCreationAcceptance(request)
        guard !taskCreations.wasInvoked(accepted.id) else { throw RoutineCreateIssue.stale }
        let invocation = try claimRuntimeInvocation(request.operation, attempt: request.attempt, expecting: request.lease)
        taskCreations.markInvoked(accepted.id)
        return invocation
    }

    func recordRoutineCreation(_ invocation: CommandRuntimeInvocation, facts: CommandRoutineCreateFacts) throws {
        let current = try taskMutationHost(invocation)
        guard let item = current.session.execution?.snapshot.items.first,
              let accepted = taskCreations.routinePreparations[item.draft.id], accepted.preview.item == item.stamp,
              accepted.creationID == facts.creationID, taskCreations.wasInvoked(accepted.id) else {
            throw CommandExecutionError.invalidResult
        }
        var next = current.session
        try next.recordRoutineCreation(facts, attempt: invocation.attempt)
        publishPreferenceSession(next, from: current.lease)
    }
}
