import Foundation

extension CommandHandoffCoordinator {
    func withRoutinePreparation<T>(expecting lease: CommandHostLease, _ work: () throws -> T) throws -> T {
        try validate(lease)
        guard !hasInvocation(lease.ownership) else { throw CommandExecutionError.busy }
        routines.preparing[lease.ownership.hostID] = lease.ownership
        defer { routines.preparing[lease.ownership.hostID] = nil }
        return try work()
    }

    func routineAcceptance(_ request: RoutineCommandRequest) throws -> CommandRoutineAcceptance {
        try validate(request.lease)
        let session = try host(request.lease.ownership.hostID).session
        guard let run = session.execution, run.operation(request.operation.operationID) == request.operation,
              run.attempt(request.attempt.unitID) == request.attempt, request.attempt.phase == .local,
              run.permitsMember(request.operation.operationID),
              let unit = run.units.first(where: { $0.id == request.attempt.unitID }),
              unit.state == .running, unit.local == .notSubmitted,
              session.plan.items.isEmpty, session.operations.allDrafts.isEmpty, session.operations.pending == nil,
              let item = run.snapshot.items.first(where: { $0.id == request.operation.operationID }),
              let accepted = routines.acceptances[item.draft.id] else { throw RoutineCommandIssue.stale }
        try validateConsumption(accepted.preview.consumption, item: item, run: run)
        _ = try accepted.preview.frozenItem(in: run, lease: request.lease)
        return accepted
    }

    func claimRoutine(_ request: RoutineCommandRequest) throws -> CommandRuntimeInvocation {
        let accepted = try routineAcceptance(request)
        guard !routines.wasInvoked(accepted.id) else { throw RoutineCommandIssue.alreadyInvoked }
        let invocation = try claimMemberInvocation(request.operation, attempt: request.attempt, expecting: request.lease,
                                                   acceptanceID: accepted.id, previewLease: accepted.preview.lease)
        routines.markInvoked(accepted.id)
        return invocation
    }

    func recordRoutine(_ invocation: CommandRuntimeInvocation, facts: CommandRoutineFacts) throws {
        let current = try taskMutationHost(invocation)
        guard let item = current.session.execution?.snapshot.items.first(where: { $0.id == invocation.operation.operationID }),
              let accepted = routines.acceptances[item.draft.id], accepted.preview.item == item.stamp,
              accepted.object == facts.object, accepted.preview.stateImpact == facts.stateImpact,
              accepted.checkCreationIDs == facts.checkCreationIDs, routines.wasInvoked(accepted.id) else {
            throw CommandExecutionError.invalidResult
        }
        var next = current.session
        try next.recordRoutine(facts, attempt: invocation.attempt)
        publishPreferenceSession(next, from: current.lease)
    }

    func finishRoutine(_ invocation: CommandRuntimeInvocation,
                         external: [CommandExternalEffect: CommandExternalResult]) throws {
        try finishTaskMutation(invocation, external: external)
    }
}
