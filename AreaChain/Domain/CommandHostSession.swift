import Foundation

/// 最小组合边界；查询返回/同步意图不产生任何操作草稿事件。
struct CommandHostSession: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    private(set) var query: ContentQuerySession
    private(set) var operations: CommandDraftSession
    private(set) var plan: CommandPlan
    private(set) var execution: CommandExecutionRun?
    private var usedRunIDs: Set<UUID> = []

    init(page: ContentQueryPageContext) {
        query = .init(page: page)
        operations = .init(hostID: page.location.hostID)
        plan = .init(hostID: page.location.hostID)
    }

    @discardableResult mutating func queryEvent(_ event: ContentQueryEvent) -> [ContentQueryIntent] {
        let transition = ContentQueryReducer.reduce(query, event)
        query = transition.state
        return transition.intents
    }

    @discardableResult mutating func operationEvent(_ event: CommandDraftEvent) -> [CommandDraftIntent] {
        let transition = CommandDraftReducer.reduce(operations, event)
        operations = transition.state
        return transition.intents
    }

    /// 只建模“不影响草稿”的宿主信号，不保存焦点或面板可见性的第二份状态。
    mutating func presentationEvent(_ event: CommandHostPresentationEvent) {}

    var requiresUnsavedContentHandling: Bool {
        operations.requiresUnsavedContentHandling || plan.requiresUnsavedContentHandling
            || execution?.requiresUnsavedContentHandling == true
    }

    var isBusy: Bool { execution?.isBusy == true }
    var hostID: String { operations.hostID }
    var description: String { "CommandHostSession(planItems: \(plan.items.count), hasExecution: \(execution != nil))" }
    var debugDescription: String { description }

    /// 跨草稿/计划的值事务：任一校验失败，两个所有者都保持原样。
    mutating func enqueue(_ draft: CommandDraftStamp, itemID: UUID, expecting stamp: CommandPlanStamp) throws {
        var next = self
        guard let transferred = next.operations.takeForPlan(draft) else { throw CommandPlanError.stale }
        try next.plan.add(transferred, id: itemID, expecting: stamp)
        self = next
    }

    mutating func planEvent(_ event: CommandPlanEvent, expecting stamp: CommandPlanStamp) throws {
        if plan.items.contains(where: { $0.executionOrigin?.returnID != nil }) {
            try plan.applyRevision(event, expecting: stamp)
        } else { try plan.apply(event, expecting: stamp) }
    }

    mutating func restorePlanRevision(_ items: [CommandPlanItem], from run: CommandExecutionRun) throws {
        guard execution == run else { throw CommandMultiPlanIssue.stale }
        try plan.restoreRevision(items, from: run)
        execution = nil
    }

    mutating func mergePlanRevision(_ earlier: CommandPlanItemStamp, _ later: CommandPlanItemStamp,
                                   baseline: CommandDraftBaseline, origin: CommandPlanExecutionOrigin) throws {
        try plan.mergeVerified(earlier, later, baseline: baseline, origin: origin)
    }

    /// 移除只退回 retained，不默认丢弃内容；丢弃仍用草稿原有显式版本化入口。
    mutating func removeFromPlan(_ item: CommandPlanItemStamp, expecting stamp: CommandPlanStamp) throws {
        var next = self
        let draft = try next.plan.remove(item, expecting: stamp)
        guard next.operations.retainFromPlan(draft) else { throw CommandPlanError.busy }
        self = next
    }

    mutating func removeGroupFromPlan(_ group: UUID, expecting stamp: CommandPlanStamp) throws {
        guard execution == nil else { throw CommandPlanError.busy }
        var next = self
        for draft in try next.plan.removeGroup(group, expecting: stamp) {
            guard next.operations.retainFromPlan(draft) else { throw CommandPlanError.busy }
        }
        self = next
    }

    /// 封存只启动纯协议。目录仍 unwired；将来调用业务前还必须经过独立执行资格门禁。
    mutating func sealPlanForProtocol(_ stamp: CommandPlanStamp, runID: UUID) throws {
        guard execution == nil else { throw CommandPlanError.busy }
        guard !usedRunIDs.contains(runID) else { throw CommandPlanError.duplicate }
        let snapshot = try plan.seal(expecting: stamp)
        execution = .init(id: runID, snapshot: snapshot)
        usedRunIDs.insert(runID)
    }

    mutating func sealMultiPlan(_ identity: CommandMultiPlanIdentity, runID: UUID) throws {
        guard execution == nil, !usedRunIDs.contains(runID), plan.stamp == identity.plan,
              operations.allDrafts.isEmpty, operations.pending == nil, plan.editing == nil,
              try CommandMultiPlanIdentity(plan: plan.stamp, items: plan.items, families: identity.families,
                                           outputCapability: identity.outputCapability) == identity else {
            throw CommandMultiPlanIssue.stale
        }
        let snapshot = try plan.seal(expecting: identity.plan)
        execution = .init(id: runID, snapshot: snapshot, multiPlan: identity)
        usedRunIDs.insert(runID)
    }

    mutating func recordMultiPlanReadFailure(_ attempt: CommandAttemptStamp) throws {
        guard var run = execution, run.multiPlan != nil,
              let index = run.units.firstIndex(where: { $0.id == attempt.unitID }) else { throw CommandMultiPlanIssue.stale }
        try run.receive(.init(attempt: attempt, result: .failedWithoutCommit))
        run.units[index].validationFailedBeforeInvocation = true
        execution = run
    }

    mutating func beginNextProtocolStep(expecting stamp: CommandExecutionStamp) throws -> CommandAttemptStamp {
        guard execution != nil else { throw CommandExecutionError.stale }
        return try execution!.beginNext(expecting: stamp)
    }

    @discardableResult mutating func receiveProtocolResult(_ receipt: CommandExecutionReceipt) throws -> Bool {
        guard execution != nil else { throw CommandExecutionError.stale }
        return try execution!.receive(receipt)
    }

    mutating func retryProtocolStep(_ attempt: CommandAttemptStamp, assurance: CommandRetryAssurance) throws {
        guard execution != nil else { throw CommandExecutionError.stale }
        try execution!.retry(attempt, assurance: assurance)
    }

    mutating func cancelUnstartedProtocolStep(_ unitID: UUID, expecting stamp: CommandExecutionStamp) throws {
        guard execution != nil else { throw CommandExecutionError.stale }
        try execution!.cancelNotStarted(unitID, expecting: stamp)
    }

    mutating func resolveProtocolValidation(_ attempt: CommandAttemptStamp, resolution: CommandValidationResolution) throws {
        guard execution != nil else { throw CommandExecutionError.stale }
        try execution!.resolveValidation(attempt, resolution: resolution)
    }

    /// 只有全部确认成功才可释放运行内正文；失败/未知结果继续保留，不退回成可重放创建。
    mutating func releaseSuccessfulExecution(expecting stamp: CommandExecutionStamp) throws {
        guard let execution, execution.stamp == stamp else { throw CommandExecutionError.stale }
        guard execution.units.allSatisfy({ $0.state == .succeeded }) else { throw CommandExecutionError.busy }
        self.execution = nil
    }

    mutating func replacePreferenceBaseline(_ baseline: CommandDraftBaseline, arguments: [CommandArgument],
                                           expecting stamp: CommandDraftStamp) throws {
        guard execution == nil, operations.pending == nil,
              let draft = allDrafts.first(where: { $0.stamp == stamp }),
              CommandPlanSemantics.isAtomicSetting(draft.commandID), !draft.blocksUnprotectedExport else {
            throw CommandPlanError.stale
        }
        if operations.active?.stamp == stamp {
            let intents = operationEvent(.reloadDiscardingChanges(stamp, baseline, arguments))
            guard !intents.contains(.rejectedEvent) else { throw CommandPlanError.stale }
        } else {
            try plan.replacePreferenceBaseline(baseline, arguments: arguments, expecting: stamp)
        }
    }

    mutating func returnUnsubmittedPreference(_ attempt: CommandAttemptStamp, expecting stamp: CommandPlanStamp) throws {
        guard let execution, execution.stamp == attempt.execution, plan.stamp == stamp,
              operations.active == nil, operations.pending == nil else { throw CommandExecutionError.stale }
        try plan.restoreUnsubmittedPreference(execution, attempt: attempt)
        self.execution = nil
    }

    mutating func replacePreferenceGroupBaselines(_ updates: [CommandPreferenceBaselineUpdate],
                                                 expecting stamp: CommandPlanStamp) throws {
        guard execution == nil, operations.active == nil, operations.pending == nil else { throw CommandPlanError.busy }
        try plan.replacePreferenceGroupBaselines(updates, expecting: stamp)
    }

    mutating func verifyPreferenceGroup(_ receipt: CommandExecutionReceipt) throws {
        guard execution != nil else { throw CommandExecutionError.stale }
        try execution!.verifyPreferenceGroup(receipt)
    }

    mutating func recordTaskField(_ facts: CommandTaskFieldFacts, attempt: CommandAttemptStamp) throws {
        guard execution != nil else { throw CommandExecutionError.stale }
        try execution!.recordTaskField(facts, attempt: attempt)
    }
    mutating func recordBatch(_ facts: CommandBatchFacts, attempt: CommandAttemptStamp) throws {
        guard execution != nil else { throw CommandExecutionError.stale }
        try execution!.recordBatch(facts, attempt: attempt)
    }

    mutating func recordSubtask(_ facts: CommandSubtaskFacts, attempt: CommandAttemptStamp) throws {
        guard execution != nil else { throw CommandExecutionError.stale }
        try execution!.recordSubtask(facts, attempt: attempt)
    }

    mutating func recordRoutine(_ facts: CommandRoutineFacts, attempt: CommandAttemptStamp) throws {
        guard execution != nil else { throw CommandExecutionError.stale }
        try execution!.recordRoutine(facts, attempt: attempt)
    }

    mutating func recordRoutineCreation(_ facts: CommandRoutineCreateFacts, attempt: CommandAttemptStamp) throws {
        guard execution != nil else { throw CommandExecutionError.stale }
        try execution!.recordRoutineCreation(facts, attempt: attempt)
    }

    mutating func recordTaskTitle(_ facts: CommandTaskTitleFacts, attempt: CommandAttemptStamp) throws {
        guard execution != nil else { throw CommandExecutionError.stale }
        try execution!.recordTaskTitle(facts, attempt: attempt)
    }

    mutating func recordTaskCreation(_ facts: CommandTaskCreateFacts, attempt: CommandAttemptStamp) throws {
        guard execution != nil else { throw CommandExecutionError.stale }
        try execution!.recordTaskCreation(facts, attempt: attempt)
    }

    /// 只生成候选状态，协调者在全部校验后同时发布双方；此入口本身不授予所有权。
    func handoffStates(to target: Self) throws -> (source: Self, target: Self) {
        guard !allDrafts.contains(where: \.blocksUnprotectedTransfer) else { throw CommandHandoffError.protectedContent }
        guard execution == nil, target.execution == nil, operations.pending == nil,
              target.operations.pending == nil else { throw CommandHandoffError.ineligible }
        guard target.operations.active == nil, target.operations.retained.isEmpty,
              target.plan.items.isEmpty, target.plan.editing == nil else { throw CommandHandoffError.targetOccupied }
        var receiver = target
        receiver.query = query.handedOff(to: target.query)
        receiver.operations = operations.handedOff(to: target.operations)
        receiver.plan = try plan.handedOff(to: target.plan)
        receiver.usedRunIDs.formUnion(usedRunIDs)
        var source = self
        source.query = query.binding == .independent(.privacyInvalidated)
            ? ContentQueryReducer.reduce(query, .privacyInvalidated).state : .init(page: query.page)
        source.operations = operations.emptiedAfterHandoff()
        source.plan = plan.emptiedAfterHandoff()
        return (source, receiver)
    }

    var allDrafts: [CommandDraft] { operations.allDrafts + plan.items.map(\.draft) }

    mutating func acceptProtection(_ reference: CommandProtectedReference, expecting stamp: CommandDraftStamp) throws {
        guard execution == nil, operations.pending == nil else { throw CommandPlanError.busy }
        if plan.items.contains(where: { $0.draft.stamp == stamp }) {
            try plan.acceptProtection(reference, expecting: stamp)
        } else {
            try operations.acceptProtection(reference, expecting: stamp)
        }
    }

    var handoffNativeSelections: Set<UUID> {
        let drafts = (operations.active.map { [$0] } ?? []) + operations.retained + plan.items.map(\.draft)
        return Set(drafts.flatMap { draft in
            let originals = draft.baseline.values.values.compactMap { original -> CommandValue? in
                if case .uniform(let value) = original { return value }
                return nil
            }
            return (draft.arguments.compactMap(\.value) + originals).compactMap { value -> UUID? in
                if case .nativeSelection(let id) = value { return id }
                return nil
            }
        })
    }
}

enum CommandHostPresentationEvent: CaseIterable {
    case collapseCompletion, collapsePreview, clickOutside, refocus
}
