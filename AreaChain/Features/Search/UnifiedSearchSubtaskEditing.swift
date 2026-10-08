import Foundation

/// 原 Plan/Run 独占输入；这里只持有不可编辑的准备、接受与核验投影。
extension UnifiedSearchController {
    var showsSubtask: Bool {
        let drafts = (operations?.allDrafts ?? []) + (plan?.items.map(\.draft) ?? [])
            + (settingExecution?.snapshot.items.map(\.draft) ?? [])
        return drafts.contains { routesSubtask($0.commandID) }
    }

    func routesSubtask(_ command: CommandID) -> Bool {
        subtask?.supports(command) == true
    }

    var hasSubtask: Bool {
        let drafts = (operations?.allDrafts ?? []) + (plan?.items.map(\.draft) ?? [])
        return !drafts.isEmpty && drafts.allSatisfy { subtask?.supports($0.commandID) == true }
    }

    var currentSubtaskPreview: CommandSubtaskPreview? {
        guard operationVisible, let preview = subtaskPreview, let subtask,
              (try? subtask.validatePreview(preview, expecting: buffer.lease, displaySession: session)) != nil else { return nil }
        return preview
    }

    var currentSubtaskAcceptance: CommandSubtaskAcceptance? {
        guard let accepted = subtaskAcceptance, accepted.preview == currentSubtaskPreview else { return nil }
        return accepted
    }

    var subtaskUnit: CommandExecutionUnit? {
        guard operationVisible, let run = settingExecution, run.snapshot.items.count == 1,
              run.snapshot.items.first.map({ CommandSubtaskEdit.commands.contains($0.draft.commandID.rawValue) }) == true else { return nil }
        return run.units.first
    }

    func revokeSubtask() {
        subtaskPreview = nil
        subtaskAcceptance = nil
        subtaskVerification = nil
    }

    private func checkSubtask(_ source: UnifiedSearchBuffer) throws {
        guard validates(source), operationVisible else { throw SubtaskCommandIssue.stale }
        guard hasSubtask else { throw SubtaskCommandIssue.unassembled }
        guard editingParameter == nil, tagSelection == nil, objectSelectionLocation == nil, !objectSelectionLoading,
              settingExecution == nil, let operations, operations.pending == nil, operations.retained.isEmpty,
              let plan, plan.editing == nil, plan.stamp == source.plan else {
            throw SubtaskCommandIssue.unsupportedPlan
        }
        if let draft = operations.active {
            guard plan.items.isEmpty, draft.stamp == source.operation, CommandSubtaskEdit.commands.contains(draft.commandID.rawValue) else {
                throw SubtaskCommandIssue.unsupportedPlan
            }
            // 无效 shortText 的原文仍在原生拼写缓冲；不能入列后让“未填”掩盖换行等输入。
            guard draft.check().staticallyValid else { throw SubtaskCommandIssue.invalidArguments }
        }
        try session.validateDisplayHost(expecting: source.lease)
    }

    func prepareSubtask(_ source: UnifiedSearchBuffer) {
        guard !settingSubmitting, taskNativeInputReady, validates(source), operationVisible else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try checkSubtask(source)
            revokeSubtask()
            if let draft = operations?.active, let plan {
                try coordinator.send(.enqueue(draft.stamp, itemID: UUID(), plan: plan.stamp), expecting: source.lease)
                _ = publishOperation(text: buffer.text)
            }
            guard let plan, let subtask else { throw SubtaskCommandIssue.stale }
            subtaskPreview = try subtask.prepare(plan: plan.stamp, expecting: buffer.lease, displaySession: session)
            subtaskFailure = nil
        } catch {
            revokeSubtask()
            subtaskFailure = UnifiedSearchSubtaskCopy.error(error)
        }
    }

    func acceptSubtask(_ preview: CommandSubtaskPreview, source: UnifiedSearchBuffer) {
        guard !settingSubmitting, taskNativeInputReady, validates(source), operationVisible else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try checkSubtask(source)
            guard subtaskPreview == preview, let subtask else { throw SubtaskCommandIssue.stale }
            subtaskAcceptance = try subtask.accept(preview, expecting: source.lease, displaySession: session)
            subtaskFailure = nil
        } catch {
            subtaskAcceptance = nil
            subtaskFailure = UnifiedSearchSubtaskCopy.error(error)
        }
    }

    func submitSubtask(_ source: UnifiedSearchBuffer) {
        guard !settingSubmitting, taskNativeInputReady, validates(source), operationVisible, settingExecution == nil else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try checkSubtask(source)
            // 交原接受给适配器，保留最后检查的具体拒绝原因；不重准备或更换原 lease。
            guard let accepted = subtaskAcceptance, let subtask else { throw SubtaskCommandIssue.stale }
            _ = try subtask.submit(accepted: accepted, expecting: source.lease, displaySession: session)
            _ = publishOperation(text: buffer.text)
            planMessage = "unified.plan.notExecutable"
        } catch {
            subtaskAcceptance = nil
            if settingExecution != nil {
                _ = publishOperation(text: buffer.text)
                planMessage = "unified.plan.notExecutable"
            }
            subtaskFailure = UnifiedSearchSubtaskCopy.error(error)
        }
    }

    func verifySubtask(_ source: UnifiedSearchBuffer) {
        guard !settingSubmitting, validates(source), operationVisible, subtaskUnit?.subtask?.state == .unknown,
              let run = settingExecution, let item = run.snapshot.items.first,
              let operation = run.operation(item.id), let subtask else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            let verification = try subtask.verifyUnknown(operation, expecting: source.lease, displaySession: session)
            guard validates(source), operationVisible else { return }
            subtaskVerification = verification
        } catch { subtaskFailure = UnifiedSearchSubtaskCopy.error(error) }
    }
}
