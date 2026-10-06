import Foundation

extension CommandHandoffCoordinator {
    func taskCreatePlan(_ stamp: CommandPlanStamp, expecting lease: CommandHostLease) throws -> CommandPlanItem {
        try validate(lease)
        let session = try host(lease.ownership.hostID).session
        guard session.plan.stamp == stamp, session.execution == nil, session.plan.editing == nil,
              session.operations.allDrafts.isEmpty, session.operations.pending == nil,
              session.plan.items.count == 1, let item = session.plan.items.first else {
            throw TaskCreateCommandIssue.unsupportedPlan
        }
        try Self.validateTaskCreateItem(item)
        return item
    }

    nonisolated static func validateTaskCreateItem(_ item: CommandPlanItem) throws {
        guard item.atomicGroup == nil, item.links.predecessors.isEmpty, item.links.results.isEmpty,
              item.mergedOrigins.isEmpty, item.returnedAttempts.isEmpty else {
            throw TaskCreateCommandIssue.unsupportedPlan
        }
        _ = try CommandTaskCreateInput(item.draft)
    }

    func withTaskCreatePreparation<T>(expecting lease: CommandHostLease, _ work: () throws -> T) throws -> T {
        try validate(lease)
        guard taskCreations.preparing[lease.ownership.hostID] == nil else { throw CommandExecutionError.busy }
        taskCreations.preparing[lease.ownership.hostID] = lease.ownership
        defer { taskCreations.preparing[lease.ownership.hostID] = nil }
        return try work()
    }

    func taskCreatePreparation(_ request: TaskCreateCommandRequest) throws -> CommandTaskCreatePreparation {
        try validate(request.lease)
        let session = try host(request.lease.ownership.hostID).session
        guard let run = session.execution, run.operation(request.operation.operationID) == request.operation,
              run.attempt(request.attempt.unitID) == request.attempt,
              request.attempt.phase == .local, run.units.count == 1, run.snapshot.items.count == 1,
              let item = run.snapshot.items.first, run.units[0].state == .running,
              run.units[0].local == .notSubmitted, run.outputs.isEmpty, session.plan.items.isEmpty,
              session.operations.allDrafts.isEmpty, session.operations.pending == nil,
              let prepared = taskCreations.preparations[item.draft.id],
              prepared.plan == run.snapshot.stamp, prepared.item == item.stamp, prepared.draft == item.draft.stamp,
              prepared.lease.ownership == request.lease.ownership,
              request.lease.revision == prepared.lease.revision + 2,
              run.resolvedInput(item.id)?.arguments == prepared.input.arguments,
              run.resolvedInput(item.id)?.targets == CommandDraftTargets.none else { throw TaskCreateCommandIssue.stale }
        try Self.validateTaskCreateItem(item)
        return prepared
    }

    func claimTaskCreate(_ request: TaskCreateCommandRequest) throws -> CommandRuntimeInvocation {
        let prepared = try taskCreatePreparation(request)
        guard !taskCreations.wasInvoked(prepared.id) else { throw TaskCreateCommandIssue.alreadyInvoked }
        let invocation = try claimRuntimeInvocation(request.operation, attempt: request.attempt, expecting: request.lease)
        taskCreations.markInvoked(prepared.id)
        return invocation
    }
}
