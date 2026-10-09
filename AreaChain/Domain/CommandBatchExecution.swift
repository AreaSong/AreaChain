import Foundation

extension CommandHandoffCoordinator {
    func withBatchPreparation<T>(expecting lease: CommandHostLease, _ work: () throws -> T) throws -> T {
        try validate(lease)
        guard !hasInvocation(lease.ownership) else { throw CommandExecutionError.busy }
        batches.preparing[lease.ownership.hostID] = lease.ownership
        defer { batches.preparing[lease.ownership.hostID] = nil }
        return try work()
    }

    func batchAcceptance(_ request: TaskTitleCommandRequest) throws -> CommandBatchAcceptance {
        try validate(request.lease)
        let session = try host(request.lease.ownership.hostID).session
        guard let run = session.execution, run.operation(request.operation.operationID) == request.operation,
              run.attempt(request.attempt.unitID) == request.attempt, request.attempt.phase == .local,
              run.permitsMember(request.operation.operationID),
              let unit = run.units.first(where: { $0.id == request.attempt.unitID }),
              unit.state == .running, unit.local == .notSubmitted,
              session.plan.items.isEmpty, session.operations.allDrafts.isEmpty, session.operations.pending == nil,
              let item = run.snapshot.items.first(where: { $0.id == request.operation.operationID }),
              let accepted = batches.acceptances[item.draft.id] else { throw CommandBatchIssue.stale }
        _ = try accepted.preview.frozenItem(in: run, lease: request.lease)
        return accepted
    }

    func claimBatch(_ request: TaskTitleCommandRequest) throws -> CommandRuntimeInvocation {
        let accepted = try batchAcceptance(request)
        guard !batches.wasInvoked(accepted.id) else { throw CommandBatchIssue.alreadyInvoked }
        let invocation = try claimMemberInvocation(request.operation, attempt: request.attempt, expecting: request.lease,
                                                   acceptanceID: accepted.id, previewLease: accepted.preview.lease)
        batches.markInvoked(accepted.id)
        return invocation
    }

    func recordBatch(_ invocation: CommandRuntimeInvocation, facts: CommandBatchFacts) throws {
        let current = try taskMutationHost(invocation)
        guard let item = current.session.execution?.snapshot.items.first(where: { $0.id == invocation.operation.operationID }),
              let accepted = batches.acceptances[item.draft.id], accepted.id == facts.acceptanceID,
              accepted.preview.item == item.stamp, accepted.preview.targets == facts.targets,
              accepted.preview.impacts == facts.impacts, accepted.preview.writeSet == facts.writeSet,
              accepted.checkCreationIDs == facts.checkCreationIDs, batches.wasInvoked(accepted.id) else {
            throw CommandExecutionError.invalidResult
        }
        var next = current.session
        try next.recordBatch(facts, attempt: invocation.attempt)
        publishPreferenceSession(next, from: current.lease)
    }
}
