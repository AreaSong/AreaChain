import Foundation

extension UnifiedSearchController {
    var currentTaskComposition: CommandTaskCreatePreview? {
        guard operationVisible, let preview = taskCompositionPreview, let taskCreate,
              (try? taskCreate.validatePreview(preview, expecting: buffer.lease, displaySession: session)) != nil else { return nil }
        return preview
    }

    var currentTaskAcceptance: CommandTaskCreatePreparation? {
        guard let accepted = taskCompositionAccepted, let preview = currentTaskComposition,
              accepted.preview == preview, accepted.lease == buffer.lease else { return nil }
        return accepted
    }

    func revokeTaskComposition() {
        let wasSelectingTags = tagSelection != nil
        taskCompositionPreview = nil
        taskCompositionAccepted = nil
        tagSelection = nil
        tagReturnDraftID = nil
        if wasSelectingTags { setObjectInputMode(false) }
    }

    private func checkComposition(_ source: UnifiedSearchBuffer) throws {
        guard hasTaskComposition, validates(source), operationVisible else { throw TaskCreateCommandIssue.stale }
        guard editingParameter == nil, tagSelection == nil, objectSelectionLocation == nil, !objectSelectionLoading,
              settingExecution == nil, let operations, operations.pending == nil, operations.retained.isEmpty,
              let plan, plan.editing == nil, plan.stamp == source.plan else { throw TaskCreateCommandIssue.unsupportedPlan }
        if let draft = operations.active {
            guard plan.items.isEmpty, draft.stamp == source.operation else { throw TaskCreateCommandIssue.unsupportedPlan }
            guard draft.commandID.rawValue == "todo.create", draft.targets == .none,
                  draft.baseline == CommandDraftBaseline(), !draft.blocksUnprotectedExport,
                  draft.protectionRequirement == .ordinary else { throw TaskCreateCommandIssue.protectedContent }
            _ = try CommandTaskCreatePreview.inputFields(draft)
        } else { _ = try coordinator.taskCreatePlan(plan.stamp, expecting: source.lease, composed: true) }
        try session.validateDisplayHost(expecting: source.lease)
    }

    func prepareTaskComposition(_ source: UnifiedSearchBuffer) {
        guard !settingSubmitting, taskNativeInputReady, validates(source), operationVisible else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try checkComposition(source)
            // 已接受的原准备没有替换接口；新预览可以查看，但不可静默重新接受并继续。
            revokeTaskComposition()
            if let draft = operations?.active, let plan {
                try coordinator.send(.enqueue(draft.stamp, itemID: UUID(), plan: plan.stamp), expecting: source.lease)
                _ = publishOperation(text: buffer.text)
            }
            guard let plan, let taskCreate else { throw TaskCreateCommandIssue.stale }
            taskCompositionPreview = try taskCreate.preview(plan: plan.stamp, expecting: buffer.lease, displaySession: session)
            compositionFailure = nil
        } catch {
            revokeTaskComposition()
            compositionFailure = UnifiedSearchTaskCompositionCopy.error(error)
        }
    }

    func acceptTaskComposition(_ preview: CommandTaskCreatePreview, source: UnifiedSearchBuffer) {
        guard !settingSubmitting, taskNativeInputReady, validates(source), operationVisible else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try checkComposition(source)
            guard currentTaskComposition == preview, let taskCreate else { throw TaskCreateCommandIssue.stale }
            taskCompositionAccepted = try taskCreate.accept(preview, expecting: source.lease, displaySession: session)
            compositionFailure = nil
        } catch {
            taskCompositionAccepted = nil
            compositionFailure = UnifiedSearchTaskCompositionCopy.error(error)
        }
    }

    func submitTaskComposition(_ source: UnifiedSearchBuffer) {
        guard !settingSubmitting, taskNativeInputReady, validates(source), operationVisible, settingExecution == nil else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try checkComposition(source)
            guard let accepted = currentTaskAcceptance, let taskCreate else { throw TaskCreateCommandIssue.stale }
            _ = try taskCreate.submit(accepted: accepted, expecting: source.lease, displaySession: session)
            _ = publishOperation(text: buffer.text)
            planMessage = "unified.plan.notExecutable"
        } catch {
            // 目录冲突保留原参数/计划；不刷新预览、不重签票据、不重放。
            taskCompositionAccepted = nil
            if settingExecution != nil {
                _ = publishOperation(text: buffer.text)
                planMessage = "unified.plan.notExecutable"
            }
            compositionFailure = UnifiedSearchTaskCompositionCopy.error(error)
        }
    }
}
