import Foundation

/// 原 Plan/Run 独占输入；这里只持有不可编辑的准备、接受与核验投影。
extension UnifiedSearchController {
    var showsTaskField: Bool {
        let drafts = (operations?.allDrafts ?? []) + (plan?.items.map(\.draft) ?? [])
            + (settingExecution?.snapshot.items.map(\.draft) ?? [])
        return drafts.contains { routesTaskField($0.commandID) }
    }

    func routesTaskField(_ command: CommandID) -> Bool {
        TaskFieldEdit.basicCommands.contains(command.rawValue) || taskField?.supports(command) == true
    }

    var hasTaskField: Bool {
        let drafts = (operations?.allDrafts ?? []) + (plan?.items.map(\.draft) ?? [])
        return !drafts.isEmpty && drafts.allSatisfy { taskField?.supports($0.commandID) == true }
    }

    var currentTaskFieldPreview: CommandTaskFieldPreview? {
        guard operationVisible, let preview = taskFieldPreview, let taskField,
              (try? taskField.validatePreview(preview, expecting: buffer.lease, displaySession: session)) != nil else { return nil }
        return preview
    }

    var currentTaskFieldAcceptance: CommandTaskFieldAcceptance? {
        guard let accepted = taskFieldAcceptance, accepted.preview == currentTaskFieldPreview else { return nil }
        return accepted
    }

    var taskFieldUnit: CommandExecutionUnit? {
        guard operationVisible, let run = settingExecution, run.snapshot.items.count == 1,
              run.snapshot.items.first.map({ TaskFieldEdit.commands.contains($0.draft.commandID.rawValue) }) == true else { return nil }
        return run.units.first
    }

    func revokeTaskField() {
        taskFieldPreview = nil
        taskFieldAcceptance = nil
        taskFieldVerification = nil
    }

    private func checkField(_ source: UnifiedSearchBuffer) throws {
        guard validates(source), operationVisible else { throw TaskFieldCommandIssue.stale }
        guard hasTaskField else { throw TaskFieldCommandIssue.unassembled }
        guard editingParameter == nil, tagSelection == nil, objectSelectionLocation == nil, !objectSelectionLoading,
              settingExecution == nil, let operations, operations.pending == nil, operations.retained.isEmpty,
              let plan, plan.editing == nil, plan.stamp == source.plan else {
            throw TaskFieldCommandIssue.unsupportedPlan
        }
        if let draft = operations.active {
            guard plan.items.isEmpty, draft.stamp == source.operation, TaskFieldEdit.commands.contains(draft.commandID.rawValue) else {
                throw TaskFieldCommandIssue.unsupportedPlan
            }
            // 无效 shortText 的原文仍在原生拼写缓冲；不能入列后让“未填”掩盖换行等输入。
            guard draft.check().staticallyValid else { throw TaskFieldCommandIssue.invalidArguments }
        }
        try session.validateDisplayHost(expecting: source.lease)
    }

    func prepareTaskField(_ source: UnifiedSearchBuffer) {
        guard !settingSubmitting, taskNativeInputReady, validates(source), operationVisible else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try checkField(source)
            revokeTaskField()
            if let draft = operations?.active, let plan {
                try coordinator.send(.enqueue(draft.stamp, itemID: UUID(), plan: plan.stamp), expecting: source.lease)
                _ = publishOperation(text: buffer.text)
            }
            guard let plan, let taskField else { throw TaskFieldCommandIssue.stale }
            taskFieldPreview = try taskField.prepare(plan: plan.stamp, expecting: buffer.lease, displaySession: session)
            taskFieldFailure = nil
        } catch {
            revokeTaskField()
            taskFieldFailure = UnifiedSearchTaskFieldCopy.error(error)
        }
    }

    func acceptTaskField(_ preview: CommandTaskFieldPreview, source: UnifiedSearchBuffer) {
        guard !settingSubmitting, taskNativeInputReady, validates(source), operationVisible else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try checkField(source)
            guard taskFieldPreview == preview, let taskField else { throw TaskFieldCommandIssue.stale }
            taskFieldAcceptance = try taskField.accept(preview, expecting: source.lease, displaySession: session)
            taskFieldFailure = nil
        } catch {
            taskFieldAcceptance = nil
            taskFieldFailure = UnifiedSearchTaskFieldCopy.error(error)
        }
    }

    func submitTaskField(_ source: UnifiedSearchBuffer) {
        guard !settingSubmitting, taskNativeInputReady, validates(source), operationVisible, settingExecution == nil else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try checkField(source)
            // 交原接受给适配器，保留最后检查的具体拒绝原因；不重准备或更换原 lease。
            guard let accepted = taskFieldAcceptance, let taskField else { throw TaskFieldCommandIssue.stale }
            _ = try taskField.submit(accepted: accepted, expecting: source.lease, displaySession: session)
            _ = publishOperation(text: buffer.text)
            planMessage = "unified.plan.notExecutable"
        } catch {
            taskFieldAcceptance = nil
            if settingExecution != nil {
                _ = publishOperation(text: buffer.text)
                planMessage = "unified.plan.notExecutable"
            }
            taskFieldFailure = UnifiedSearchTaskFieldCopy.error(error)
        }
    }

    func verifyTaskField(_ source: UnifiedSearchBuffer) {
        guard !settingSubmitting, validates(source), operationVisible, taskFieldUnit?.taskField?.state == .unknown,
              let run = settingExecution, let item = run.snapshot.items.first,
              let operation = run.operation(item.id), let taskField else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            let verification = try taskField.verifyUnknown(operation, expecting: source.lease, displaySession: session)
            guard validates(source), operationVisible else { return }
            taskFieldVerification = verification
        } catch { taskFieldFailure = UnifiedSearchTaskFieldCopy.error(error) }
    }
}
