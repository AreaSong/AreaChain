import Foundation

/// T-M4 回收沿批量的显式隔离装配；能力默认关闭，只有显式 softTrash 才开放四个回收命令。
/// 流程固定为 prepare → accept → 独立 confirm → submit，确认只绑定接受时的计划与目标。
@MainActor final class TrashCommandAdapter {
    enum Capability { case closed, softTrash }
    let coordinator: CommandHandoffCoordinator
    let environment: BatchCommandEnvironment?
    let capability: Capability
    private let reader: TrashCommandReader?

    init(coordinator: CommandHandoffCoordinator, environment: BatchCommandEnvironment? = nil,
         capability: Capability = .closed) {
        self.coordinator = coordinator
        self.environment = environment
        self.capability = capability
        reader = environment.map(TrashCommandReader.init)
    }

    func supports(_ command: CommandID) -> Bool {
        environment != nil && capability == .softTrash && CommandTrashEdit.commands.contains(command.rawValue)
    }

    func assembled() throws -> (BatchCommandEnvironment, TrashCommandReader) {
        guard capability == .softTrash, let environment, let reader else { throw CommandTrashIssue.unassembled }
        try environment.validateClean()
        return (environment, reader)
    }

    func prepare(plan: CommandPlanStamp, expecting lease: CommandHostLease,
                 displaySession: ContentQueryReadSession? = nil) throws -> CommandTrashPreview {
        try displaySession?.validateDisplayHost(expecting: lease)
        let (environment, reader) = try assembled()
        return try coordinator.withTrashPreparation(expecting: lease) {
            let host = try coordinator.host(lease.ownership.hostID)
            guard host.session.plan.stamp == plan else { throw CommandTrashIssue.stale }
            let preview = try reader.prepare(in: host)
            try coordinator.validate(lease)
            try environment.validateClean()
            try displaySession?.validateDisplayHost(expecting: lease)
            return preview
        }
    }

    func validatePreview(_ preview: CommandTrashPreview, expecting lease: CommandHostLease,
                         displaySession: ContentQueryReadSession? = nil) throws {
        try displaySession?.validateDisplayHost(expecting: lease)
        let (environment, reader) = try assembled()
        try coordinator.withTrashPreparation(expecting: lease) {
            let host = try coordinator.host(lease.ownership.hostID)
            guard preview.lease == lease, host.session.plan.stamp == preview.plan else { throw CommandTrashIssue.stale }
            try reader.validate(preview, item: CommandTrashPreview.input(in: host))
            try coordinator.validate(lease)
            try environment.validateClean()
            try displaySession?.validateDisplayHost(expecting: lease)
        }
    }

    func accept(_ preview: CommandTrashPreview, expecting lease: CommandHostLease,
                displaySession: ContentQueryReadSession? = nil) throws -> CommandTrashAcceptance {
        try validatePreview(preview, expecting: lease, displaySession: displaySession)
        return try coordinator.trashes.accept(preview)
    }

    /// 打开独立确认前再读一次真实对象；摘要与之后的提交使用同一份冻结预览。
    func confirm(_ accepted: CommandTrashAcceptance, expecting lease: CommandHostLease,
                 displaySession: ContentQueryReadSession? = nil) throws -> CommandTrashConfirmation {
        try validatePreview(accepted.preview, expecting: lease, displaySession: displaySession)
        return try coordinator.trashes.confirm(accepted)
    }

    func cancel(_ confirmation: CommandTrashConfirmation) {
        coordinator.trashes.cancel(confirmation)
    }

    func submit(accepted: CommandTrashAcceptance, confirmation: CommandTrashConfirmation, expecting lease: CommandHostLease,
                displaySession: ContentQueryReadSession? = nil) throws -> CommandTrashFacts {
        do {
            guard try coordinator.trashes.confirmation(for: accepted) == confirmation else { throw CommandTrashIssue.confirmationStale }
            try validatePreview(accepted.preview, expecting: lease, displaySession: displaySession)
            guard coordinator.trashes.acceptances[accepted.preview.draft.draftID] == accepted,
                  !coordinator.trashes.wasInvoked(accepted.id) else { throw CommandTrashIssue.stale }
        } catch {
            // 确认后对象或资格变化：撤销本次确认，必须重新预览与确认。
            cancel(confirmation)
            throw error
        }
        try coordinator.send(.sealPlan(accepted.preview.plan, runID: UUID()), expecting: lease)
        var host = try coordinator.host(lease.ownership.hostID)
        guard let run = host.session.execution else { throw CommandTrashIssue.stale }
        let effect = try coordinator.send(.beginStep(run.stamp), expecting: host.lease)
        guard case .attempt(let attempt) = effect, let operation = run.operation(accepted.preview.item.id) else {
            throw CommandTrashIssue.stale
        }
        host = try coordinator.host(lease.ownership.hostID)
        return try execute(.init(lease: host.lease, operation: operation, attempt: attempt), displaySession: displaySession)
    }

    func execute(_ request: TaskTitleCommandRequest,
                 displaySession: ContentQueryReadSession? = nil) throws -> CommandTrashFacts {
        let (environment, reader) = try assembled()
        let (accepted, confirmation) = try coordinator.trashAcceptance(request)
        let invocation = try coordinator.claimTrash(request)
        do {
            try environment.dependencies.validateBeforeTransaction()
            try coordinator.validateRuntimeInvocation(invocation)
            guard let run = try coordinator.host(request.lease.ownership.hostID).session.execution else {
                throw CommandTrashIssue.stale
            }
            let item = try accepted.preview.frozenItem(in: run, lease: request.lease)
            try reader.validate(accepted.preview, item: item)
            try coordinator.validateRuntimeInvocation(invocation)
            try environment.validateClean()
            try displaySession?.validateDisplayHost(expecting: invocation.lease)
        } catch {
            var facts = CommandTrashFacts(accepted, confirmation: confirmation)
            facts.state = .notSubmitted
            facts.conflict = true
            try coordinator.recordTrash(invocation, facts: facts)
            try coordinator.finishTaskMutation(invocation, external: [:])
            throw error
        }
        let facts = TrashCommandTransaction.apply(accepted, confirmation: confirmation, environment: environment) { [coordinator] facts in
            try coordinator.recordTrash(invocation, facts: facts)
        }
        try coordinator.recordTrash(invocation, facts: facts)
        try coordinator.finishTaskMutation(invocation, external: [
            .taskPublication: facts.publication == .returned && !facts.publicationFailed ? .succeeded : .unknown
        ])
        return facts
    }
}
