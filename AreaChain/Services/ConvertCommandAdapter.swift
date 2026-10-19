import Foundation

/// T-M5 互转沿回收的显式隔离装配；能力默认关闭，只有显式 convert 才开放 todo.toRoutine／routine.toTodo。
/// 流程固定为 prepare → accept → 独立 confirm → submit；写入只经共享的 ItemConversionService。
@MainActor final class ConvertCommandAdapter {
    enum Capability { case closed, convert }
    let coordinator: CommandHandoffCoordinator
    let environment: BatchCommandEnvironment?
    let capability: Capability
    let conversion: ConvertCommandTransaction.Conversion
    private let reader: ConvertCommandReader?

    /// 时钟与日历刷新必须由装配方注入；QA 中刷新是 fake，不写真实日历。
    init(coordinator: CommandHandoffCoordinator, environment: BatchCommandEnvironment? = nil,
         capability: Capability = .closed, clock: ItemConversionService.Clock, refreshCalendar: @escaping () -> Void) {
        self.coordinator = coordinator
        self.environment = environment
        self.capability = capability
        conversion = .init(clock: clock, refreshCalendar: refreshCalendar)
        reader = environment.map { ConvertCommandReader(environment: $0, clock: clock) }
    }

    func supports(_ command: CommandID) -> Bool {
        environment != nil && capability == .convert && CommandConvertEdit.commands.contains(command.rawValue)
    }

    func assembled() throws -> (BatchCommandEnvironment, ConvertCommandReader) {
        guard capability == .convert, let environment, let reader else { throw CommandConvertIssue.unassembled }
        try environment.validateClean()
        return (environment, reader)
    }

    func prepare(plan: CommandPlanStamp, expecting lease: CommandHostLease,
                 displaySession: ContentQueryReadSession? = nil) throws -> CommandConvertPreview {
        try displaySession?.validateDisplayHost(expecting: lease)
        let (environment, reader) = try assembled()
        return try coordinator.withConvertPreparation(expecting: lease) {
            let host = try coordinator.host(lease.ownership.hostID)
            guard host.session.plan.stamp == plan else { throw CommandConvertIssue.stale }
            let item = try CommandConvertPreview.input(in: host)
            try coordinator.conversions.requireResolved(item.draft.targets.objects)
            let preview = try reader.prepare(in: host)
            try coordinator.validate(lease)
            try environment.validateClean()
            try displaySession?.validateDisplayHost(expecting: lease)
            return preview
        }
    }

    func validatePreview(_ preview: CommandConvertPreview, expecting lease: CommandHostLease,
                         displaySession: ContentQueryReadSession? = nil) throws {
        try displaySession?.validateDisplayHost(expecting: lease)
        let (environment, reader) = try assembled()
        try coordinator.withConvertPreparation(expecting: lease) {
            let host = try coordinator.host(lease.ownership.hostID)
            guard preview.lease == lease, host.session.plan.stamp == preview.plan else { throw CommandConvertIssue.stale }
            try coordinator.conversions.requireResolved(preview.targets.objects)
            try reader.validate(preview, item: CommandConvertPreview.input(in: host))
            try coordinator.validate(lease)
            try environment.validateClean()
            try displaySession?.validateDisplayHost(expecting: lease)
        }
    }

    func accept(_ preview: CommandConvertPreview, expecting lease: CommandHostLease,
                displaySession: ContentQueryReadSession? = nil) throws -> CommandConvertAcceptance {
        try validatePreview(preview, expecting: lease, displaySession: displaySession)
        return try coordinator.conversions.accept(preview)
    }

    /// 打开独立确认前再读一次真实对象；面板的损失说明与之后的提交使用同一份冻结预览。
    func confirm(_ accepted: CommandConvertAcceptance, expecting lease: CommandHostLease,
                 displaySession: ContentQueryReadSession? = nil) throws -> CommandConvertConfirmation {
        try validatePreview(accepted.preview, expecting: lease, displaySession: displaySession)
        return try coordinator.conversions.confirm(accepted)
    }

    func cancel(_ confirmation: CommandConvertConfirmation) {
        coordinator.conversions.cancel(confirmation)
    }

    func submit(accepted: CommandConvertAcceptance, confirmation: CommandConvertConfirmation, expecting lease: CommandHostLease,
                displaySession: ContentQueryReadSession? = nil) throws -> CommandConvertFacts {
        do {
            guard try coordinator.conversions.confirmation(for: accepted) == confirmation else {
                throw CommandConvertIssue.confirmationStale
            }
            try validatePreview(accepted.preview, expecting: lease, displaySession: displaySession)
            guard coordinator.conversions.acceptances[accepted.preview.draft.draftID] == accepted,
                  !coordinator.conversions.wasInvoked(accepted.id) else { throw CommandConvertIssue.stale }
        } catch {
            // 确认后对象或资格变化：撤销本次确认，必须重新预览与确认。
            cancel(confirmation)
            throw error
        }
        try coordinator.send(.sealPlan(accepted.preview.plan, runID: UUID()), expecting: lease)
        var host = try coordinator.host(lease.ownership.hostID)
        guard let run = host.session.execution else { throw CommandConvertIssue.stale }
        let effect = try coordinator.send(.beginStep(run.stamp), expecting: host.lease)
        guard case .attempt(let attempt) = effect, let operation = run.operation(accepted.preview.item.id) else {
            throw CommandConvertIssue.stale
        }
        host = try coordinator.host(lease.ownership.hostID)
        return try execute(.init(lease: host.lease, operation: operation, attempt: attempt), displaySession: displaySession)
    }

    func execute(_ request: TaskTitleCommandRequest,
                 displaySession: ContentQueryReadSession? = nil) throws -> CommandConvertFacts {
        let (environment, reader) = try assembled()
        let (accepted, confirmation) = try coordinator.convertAcceptance(request)
        let invocation = try coordinator.claimConvert(request)
        do {
            try environment.dependencies.validateBeforeTransaction()
            try coordinator.validateRuntimeInvocation(invocation)
            guard let run = try coordinator.host(request.lease.ownership.hostID).session.execution else {
                throw CommandConvertIssue.stale
            }
            let item = try accepted.preview.frozenItem(in: run, lease: request.lease)
            try reader.validate(accepted.preview, item: item)
            try coordinator.validateRuntimeInvocation(invocation)
            try environment.validateClean()
            try displaySession?.validateDisplayHost(expecting: invocation.lease)
        } catch {
            var facts = CommandConvertFacts(accepted, confirmation: confirmation)
            facts.state = .notSubmitted
            facts.conflict = true
            try coordinator.recordConvert(invocation, facts: facts)
            try coordinator.finishTaskMutation(invocation, external: [:])
            throw error
        }
        let facts = ConvertCommandTransaction.apply(accepted, confirmation: confirmation, environment: environment,
                                                    conversion: conversion) { [coordinator] facts in
            try coordinator.recordConvert(invocation, facts: facts)
        }
        // 结果未知：在核对出确定结果前，同一对象不能再准备转换，避免重复创建。
        if facts.state == .unknown { coordinator.conversions.markUnknown(facts.impact.target, acceptanceID: accepted.id) }
        try coordinator.recordConvert(invocation, facts: facts)
        try coordinator.finishTaskMutation(invocation, external: [
            .taskPublication: facts.publication == .returned && !facts.publicationFailed ? .succeeded : .unknown
        ])
        return facts
    }
}
