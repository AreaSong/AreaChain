import Foundation

extension CommandHandoffCoordinator {
    func withSubtaskPreparation<T>(expecting lease: CommandHostLease, _ work: () throws -> T) throws -> T {
        try validate(lease)
        guard !hasInvocation(lease.ownership) else { throw CommandExecutionError.busy }
        subtasks.preparing[lease.ownership.hostID] = lease.ownership
        defer { subtasks.preparing[lease.ownership.hostID] = nil }
        return try work()
    }

    func subtaskAcceptance(_ request: TaskTitleCommandRequest) throws -> CommandSubtaskAcceptance {
        try validate(request.lease)
        let session = try host(request.lease.ownership.hostID).session
        guard let run = session.execution, run.operation(request.operation.operationID) == request.operation,
              run.attempt(request.attempt.unitID) == request.attempt, request.attempt.phase == .local,
              run.permitsMember(request.operation.operationID),
              let unit = run.units.first(where: { $0.id == request.attempt.unitID }),
              unit.state == .running, unit.local == .notSubmitted,
              session.plan.items.isEmpty, session.operations.allDrafts.isEmpty, session.operations.pending == nil,
              let item = run.snapshot.items.first(where: { $0.id == request.operation.operationID }),
              let accepted = subtasks.acceptances[item.draft.id] else { throw SubtaskCommandIssue.stale }
        try validateConsumption(accepted.preview.consumption, item: item, run: run)
        _ = try accepted.preview.frozenItem(in: run, lease: request.lease)
        return accepted
    }

    func claimSubtask(_ request: TaskTitleCommandRequest) throws -> CommandRuntimeInvocation {
        let accepted = try subtaskAcceptance(request)
        guard !subtasks.wasInvoked(accepted.id) else { throw SubtaskCommandIssue.alreadyInvoked }
        let invocation = try claimMemberInvocation(request.operation, attempt: request.attempt, expecting: request.lease,
                                                   acceptanceID: accepted.id, previewLease: accepted.preview.lease)
        subtasks.markInvoked(accepted.id)
        return invocation
    }

    func recordSubtask(_ invocation: CommandRuntimeInvocation, facts: CommandSubtaskFacts) throws {
        let current = try taskMutationHost(invocation)
        guard let item = current.session.execution?.snapshot.items.first(where: { $0.id == invocation.operation.operationID }),
              let accepted = subtasks.acceptances[item.draft.id], accepted.preview.item == item.stamp,
              accepted.object == facts.object, accepted.preview.parent.id == facts.parentID,
              accepted.preview.input.edit.isCreation == facts.isCreation, subtasks.wasInvoked(accepted.id) else {
            throw CommandExecutionError.invalidResult
        }
        var next = current.session
        try next.recordSubtask(facts, attempt: invocation.attempt)
        publishPreferenceSession(next, from: current.lease)
    }
}
