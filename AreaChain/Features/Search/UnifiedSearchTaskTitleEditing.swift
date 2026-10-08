import Foundation

/// 原 Plan/Run 独占输入；这里只持有不可编辑的准备、接受与核验投影。
extension UnifiedSearchController {
    var showsTaskTitle: Bool {
        let drafts = (operations?.allDrafts ?? []) + (plan?.items.map(\.draft) ?? [])
            + (settingExecution?.snapshot.items.map(\.draft) ?? [])
        return drafts.contains { $0.commandID.rawValue == "todo.title" }
    }

    var hasTaskTitle: Bool { taskTitle?.supports(.init(rawValue: "todo.title")) == true }

    var currentTaskTitlePreview: CommandTaskTitlePreview? {
        guard operationVisible, let preview = taskTitlePreview, let taskTitle,
              (try? taskTitle.validatePreview(preview, expecting: buffer.lease, displaySession: session)) != nil else { return nil }
        return preview
    }

    var currentTaskTitleAcceptance: CommandTaskTitleAcceptance? {
        guard let accepted = taskTitleAcceptance, accepted.preview == currentTaskTitlePreview else { return nil }
        return accepted
    }

    var taskTitleUnit: CommandExecutionUnit? {
        guard operationVisible, let run = settingExecution,
              run.snapshot.items.count == 1 || (try? CommandTaskChainIdentity(plan: run.snapshot.stamp, items: run.snapshot.items)) != nil,
              let item = run.snapshot.items.first(where: { $0.draft.commandID.rawValue == "todo.title" }) else { return nil }
        return run.units.first { $0.id == item.id }
    }

    func revokeTaskTitle() {
        taskTitlePreview = nil
        taskTitleAcceptance = nil
        taskTitleVerification = nil
    }

    private func checkTitle(_ source: UnifiedSearchBuffer) throws {
        guard validates(source), operationVisible else { throw TaskTitleCommandIssue.stale }
        guard hasTaskTitle else { throw TaskTitleCommandIssue.unassembled }
        guard editingParameter == nil, tagSelection == nil, objectSelectionLocation == nil, !objectSelectionLoading,
              settingExecution == nil, let operations, operations.pending == nil, operations.retained.isEmpty,
              let plan, plan.editing == nil, plan.stamp == source.plan else {
            throw CommandTaskTitlePreviewIssue.unsupportedPlan
        }
        if let draft = operations.active {
            guard plan.items.isEmpty, draft.stamp == source.operation, draft.commandID.rawValue == "todo.title" else {
                throw CommandTaskTitlePreviewIssue.unsupportedPlan
            }
            // 无效 shortText 的原文仍在原生拼写缓冲；不能入列后让“未填”掩盖换行等输入。
            guard draft.check().staticallyValid else { throw CommandTaskTitlePreviewIssue.invalidArguments }
        }
        try session.validateDisplayHost(expecting: source.lease)
    }

    func prepareTaskTitle(_ source: UnifiedSearchBuffer) {
        guard !settingSubmitting, taskNativeInputReady, validates(source), operationVisible else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try checkTitle(source)
            revokeTaskTitle()
            if let draft = operations?.active, let plan {
                try coordinator.send(.enqueue(draft.stamp, itemID: UUID(), plan: plan.stamp), expecting: source.lease)
                _ = publishOperation(text: buffer.text)
            }
            guard let plan, let taskTitle else { throw TaskTitleCommandIssue.stale }
            taskTitlePreview = try taskTitle.prepare(plan: plan.stamp, expecting: buffer.lease, displaySession: session)
            taskTitleFailure = nil
        } catch {
            revokeTaskTitle()
            taskTitleFailure = UnifiedSearchTaskTitleCopy.error(error)
        }
    }

    func acceptTaskTitle(_ preview: CommandTaskTitlePreview, source: UnifiedSearchBuffer) {
        guard !settingSubmitting, taskNativeInputReady, validates(source), operationVisible else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try checkTitle(source)
            guard taskTitlePreview == preview, let taskTitle else { throw TaskTitleCommandIssue.stale }
            taskTitleAcceptance = try taskTitle.accept(preview, expecting: source.lease, displaySession: session)
            taskTitleFailure = nil
        } catch {
            taskTitleAcceptance = nil
            taskTitleFailure = UnifiedSearchTaskTitleCopy.error(error)
        }
    }

    func submitTaskTitle(_ source: UnifiedSearchBuffer) {
        guard !settingSubmitting, taskNativeInputReady, validates(source), operationVisible, settingExecution == nil else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try checkTitle(source)
            // 交原接受给适配器，保留最后检查的具体拒绝原因；不重准备或更换原 lease。
            guard let accepted = taskTitleAcceptance, let taskTitle else { throw TaskTitleCommandIssue.stale }
            _ = try taskTitle.submit(accepted: accepted, expecting: source.lease, displaySession: session)
            _ = publishOperation(text: buffer.text)
            planMessage = "unified.plan.notExecutable"
        } catch {
            taskTitleAcceptance = nil
            if settingExecution != nil {
                _ = publishOperation(text: buffer.text)
                planMessage = "unified.plan.notExecutable"
            }
            taskTitleFailure = UnifiedSearchTaskTitleCopy.error(error)
        }
    }

    func verifyTaskTitle(_ source: UnifiedSearchBuffer) {
        guard !settingSubmitting, validates(source), operationVisible, taskTitleUnit?.taskTitle?.state == .unknown,
              let run = settingExecution, let item = run.snapshot.items.first(where: { $0.draft.commandID.rawValue == "todo.title" }),
              let operation = run.operation(item.id), let taskTitle else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            let verification = try taskTitle.verifyUnknown(operation, expecting: source.lease, displaySession: session)
            guard validates(source), operationVisible else { return }
            taskTitleVerification = verification
        } catch { taskTitleFailure = UnifiedSearchTaskTitleCopy.error(error) }
    }
}
