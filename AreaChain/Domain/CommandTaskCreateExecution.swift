import Foundation

extension CommandHandoffCoordinator {
    func taskCreatePlan(_ stamp: CommandPlanStamp, expecting lease: CommandHostLease,
                        composed: Bool = false) throws -> CommandPlanItem {
        try validate(lease)
        let session = try host(lease.ownership.hostID).session
        guard session.plan.stamp == stamp, session.execution == nil, session.plan.editing == nil,
              session.operations.allDrafts.isEmpty, session.operations.pending == nil,
              session.plan.items.count == 1, let item = session.plan.items.first else {
            throw TaskCreateCommandIssue.unsupportedPlan
        }
        try Self.validateTaskCreateItem(item, composed: composed)
        return item
    }

    nonisolated static func validateTaskCreateItem(_ item: CommandPlanItem, composed: Bool = false, allowingDependencies: Bool = false) throws {
        guard item.atomicGroup == nil, allowingDependencies || item.links.predecessors.isEmpty, item.links.results.isEmpty,
              item.hasSupportedOrigins, allowingDependencies || item.executionOrigin == nil else {
            throw TaskCreateCommandIssue.unsupportedPlan
        }
        if composed {
            guard item.draft.commandID.rawValue == "todo.create", item.draft.targets == .none,
                  item.draft.baseline == CommandDraftBaseline(), !item.draft.blocksUnprotectedExport,
                  item.draft.protectionRequirement == .ordinary else { throw TaskCreateCommandIssue.protectedContent }
            _ = try CommandTaskCreatePreview.inputFields(item.draft)
        } else { _ = try CommandTaskCreateInput(item.draft) }
    }

    func withTaskCreatePreparation<T>(expecting lease: CommandHostLease, _ work: () throws -> T) throws -> T {
        try validate(lease)
        guard !hasInvocation(lease.ownership) else { throw CommandExecutionError.busy }
        taskCreations.preparing[lease.ownership.hostID] = lease.ownership
        defer { taskCreations.preparing[lease.ownership.hostID] = nil }
        return try work()
    }

    func taskCreatePreparation(_ request: TaskCreateCommandRequest) throws -> CommandTaskCreatePreparation {
        try validate(request.lease)
        let session = try host(request.lease.ownership.hostID).session
        guard let run = session.execution, run.operation(request.operation.operationID) == request.operation,
              run.attempt(request.attempt.unitID) == request.attempt,
              request.attempt.phase == .local,
              let item = run.snapshot.items.first(where: { $0.id == request.operation.operationID }),
              let unit = run.units.first(where: { $0.id == request.attempt.unitID }), unit.state == .running,
              unit.local == .notSubmitted, run.outputs[item.id] == nil, session.plan.items.isEmpty,
              session.operations.allDrafts.isEmpty, session.operations.pending == nil,
              let prepared = taskCreations.preparations[item.draft.id],
              prepared.plan == run.snapshot.stamp, prepared.item == item.stamp, prepared.draft == item.draft.stamp,
              prepared.lease.ownership == request.lease.ownership,
              run.previewLeaseMatches(prepared.lease, current: request.lease, itemID: item.id),
              run.resolvedInput(item.id)?.arguments == prepared.arguments,
              run.resolvedInput(item.id)?.targets == CommandDraftTargets.none else { throw TaskCreateCommandIssue.stale }
        if let chain = prepared.chain {
            try chain.validate(run)
            guard chain.producer == item.stamp, request.attempt.unitID == item.id, request.attempt.number == 1 else {
                throw TaskCreateCommandIssue.stale
            }
        } else {
            guard run.permitsMember(item.id) else { throw TaskCreateCommandIssue.unsupportedPlan }
        }
        try Self.validateTaskCreateItem(item, composed: prepared.preview != nil, allowingDependencies: run.multiPlan != nil)
        return prepared
    }

    func claimTaskCreate(_ request: TaskCreateCommandRequest) throws -> CommandRuntimeInvocation {
        let prepared = try taskCreatePreparation(request)
        guard !taskCreations.wasInvoked(prepared.id) else { throw TaskCreateCommandIssue.alreadyInvoked }
        let invocation: CommandRuntimeInvocation
        if let chain = prepared.chain {
            invocation = try claimTaskChainInvocation(request.operation, attempt: request.attempt, expecting: request.lease, identity: chain)
        } else { invocation = try claimMemberInvocation(request.operation, attempt: request.attempt, expecting: request.lease,
                                                    acceptanceID: prepared.id, previewLease: prepared.lease) }
        taskCreations.markInvoked(prepared.id)
        return invocation
    }
}
