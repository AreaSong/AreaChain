import Foundation

/// 仅 B-M1 显式宿主装配；一个批量操作始终占用一个原计划项与一次调用身份。
@MainActor final class BatchCommandAdapter {
    let coordinator: CommandHandoffCoordinator
    let environment: BatchCommandEnvironment?
    init(coordinator: CommandHandoffCoordinator, environment: BatchCommandEnvironment? = nil) {
        self.coordinator = coordinator
        self.environment = environment
    }
    func supports(_ command: CommandID) -> Bool { environment != nil && CommandBatchEdit.commands.contains(command.rawValue) }
    func assembled() throws -> BatchCommandEnvironment {
        guard let environment else { throw CommandBatchIssue.unassembled }
        try environment.validateClean()
        return environment
    }

    func prepare(plan: CommandPlanStamp, expecting lease: CommandHostLease,
                 displaySession: ContentQueryReadSession? = nil) throws -> CommandBatchPreview {
        try displaySession?.validateDisplayHost(expecting: lease)
        let environment = try assembled()
        return try coordinator.withBatchPreparation(expecting: lease) {
            let host = try coordinator.host(lease.ownership.hostID)
            guard host.session.plan.stamp == plan else { throw CommandBatchIssue.stale }
            let preview = try environment.reader.prepare(in: host)
            try coordinator.validate(lease)
            try environment.validateClean()
            try displaySession?.validateDisplayHost(expecting: lease)
            return preview
        }
    }

    func validatePreview(_ preview: CommandBatchPreview, expecting lease: CommandHostLease,
                         displaySession: ContentQueryReadSession? = nil) throws {
        try displaySession?.validateDisplayHost(expecting: lease)
        let environment = try assembled()
        try coordinator.withBatchPreparation(expecting: lease) {
            let host = try coordinator.host(lease.ownership.hostID)
            guard preview.lease == lease, host.session.plan.stamp == preview.plan else { throw CommandBatchIssue.stale }
            try environment.reader.validate(preview, item: CommandBatchPreview.input(in: host))
            try coordinator.validate(lease)
            try environment.validateClean()
            try displaySession?.validateDisplayHost(expecting: lease)
        }
    }

    func accept(_ preview: CommandBatchPreview, expecting lease: CommandHostLease,
                displaySession: ContentQueryReadSession? = nil) throws -> CommandBatchAcceptance {
        try validatePreview(preview, expecting: lease, displaySession: displaySession)
        return try coordinator.batches.accept(preview)
    }

    func submit(accepted: CommandBatchAcceptance, expecting lease: CommandHostLease,
                displaySession: ContentQueryReadSession? = nil) throws -> CommandBatchFacts {
        try validatePreview(accepted.preview, expecting: lease, displaySession: displaySession)
        guard coordinator.batches.acceptances[accepted.preview.draft.draftID] == accepted,
              !coordinator.batches.wasInvoked(accepted.id) else { throw CommandBatchIssue.stale }
        try coordinator.send(.sealPlan(accepted.preview.plan, runID: UUID()), expecting: lease)
        var host = try coordinator.host(lease.ownership.hostID)
        guard let run = host.session.execution else { throw CommandBatchIssue.stale }
        let effect = try coordinator.send(.beginStep(run.stamp), expecting: host.lease)
        guard case .attempt(let attempt) = effect, let operation = run.operation(accepted.preview.item.id) else {
            throw CommandBatchIssue.stale
        }
        host = try coordinator.host(lease.ownership.hostID)
        return try execute(.init(lease: host.lease, operation: operation, attempt: attempt), displaySession: displaySession)
    }

    func execute(_ request: TaskTitleCommandRequest,
                 displaySession: ContentQueryReadSession? = nil) throws -> CommandBatchFacts {
        let environment = try assembled()
        let accepted = try coordinator.batchAcceptance(request)
        let invocation = try coordinator.claimBatch(request)
        do {
            try environment.dependencies.validateBeforeTransaction()
            try coordinator.validateRuntimeInvocation(invocation)
            guard let run = try coordinator.host(request.lease.ownership.hostID).session.execution else {
                throw CommandBatchIssue.stale
            }
            let item = try accepted.preview.frozenItem(in: run, lease: request.lease)
            try environment.reader.validate(accepted.preview, item: item)
            try coordinator.validateRuntimeInvocation(invocation)
            try environment.validateClean()
            try displaySession?.validateDisplayHost(expecting: invocation.lease)
        } catch {
            var facts = CommandBatchFacts(accepted)
            facts.state = .notSubmitted
            facts.conflict = true
            try coordinator.recordBatch(invocation, facts: facts)
            try coordinator.finishTaskMutation(invocation, external: [:])
            throw error
        }
        var facts: CommandBatchFacts
        if accepted.preview.changedCount == 0 {
            facts = .init(accepted)
            facts.state = .noChange
        } else {
            facts = BatchCommandTransaction.apply(accepted, environment: environment) { [coordinator] facts in
                try coordinator.recordBatch(invocation, facts: facts)
            }
        }
        try coordinator.recordBatch(invocation, facts: facts)
        try coordinator.finishTaskMutation(invocation, external: [
            .taskPublication: facts.publication == .returned && !facts.publicationFailed ? .succeeded : .unknown
        ])
        return facts
    }

    func tagCandidates(draft stamp: CommandDraftStamp, expecting lease: CommandHostLease,
                       displaySession: ContentQueryReadSession,
                       evidence: CommandTaskTagCatalog.Evidence? = nil) throws -> CommandTaskTagCandidates {
        try displaySession.validateDisplayHost(expecting: lease)
        let environment = try assembled()
        return try coordinator.withBatchPreparation(expecting: lease) {
            let host = try coordinator.host(lease.ownership.hostID)
            let draft = host.session.plan.items.first(where: { $0.id == host.session.plan.editing })?.draft
                ?? host.session.operations.active
            guard host.session.execution == nil, host.session.operations.pending == nil, let draft,
                  draft.stamp == stamp, draft.commandID.rawValue == "batch.tags",
                  !draft.blocksUnprotectedExport, draft.protectionRequirement == .ordinary else { throw CommandBatchIssue.stale }
            let reader = environment.reader.catalogReader
            let catalog = try evidence.map(reader.validate) ?? reader.current()
            try coordinator.validate(lease)
            try environment.validateClean()
            try displaySession.validateDisplayHost(expecting: lease)
            return try .init(catalog: catalog, liveOnly: true)
        }
    }
}
