import AppKit

/// 只借用原计划/运行；准备证据不可编辑，失败不复制成新的可提交草稿。
extension UnifiedSearchController {
    var showsTaskCreate: Bool {
        let drafts = (operations?.allDrafts ?? []) + (plan?.items.map(\.draft) ?? [])
            + (settingExecution?.snapshot.items.map(\.draft) ?? [])
        return drafts.contains { $0.commandID.rawValue == "todo.create" }
    }

    var taskCreateDraft: CommandDraft? {
        operations?.active ?? plan?.items.first?.draft ?? settingExecution?.snapshot.items.first?.draft
    }

    var currentTaskPreparation: CommandTaskCreatePreparation? {
        guard let prepared = taskCreatePreparation, operationVisible,
              prepared.lease == buffer.lease, prepared.plan == plan?.stamp,
              prepared.item == plan?.items.first?.stamp else { return nil }
        return prepared
    }

    var taskCreateUnit: CommandExecutionUnit? {
        guard operationVisible, let run = settingExecution, run.snapshot.items.count == 1,
              run.snapshot.items.first?.draft.commandID.rawValue == "todo.create" else { return nil }
        return run.units.first
    }

    var taskCreateIssue: TaskCreateCommandIssue? {
        if let taskCreateFailure { return taskCreateFailure }
        do { try checkTaskCreate(buffer); return nil }
        catch { return error as? TaskCreateCommandIssue ?? .stale }
    }

    private func checkTaskCreate(_ source: UnifiedSearchBuffer) throws {
        guard validates(source), operationVisible else { throw TaskCreateCommandIssue.stale }
        guard taskCreate?.supports(.init(rawValue: "todo.create")) == true else { throw TaskCreateCommandIssue.unassembled }
        guard settingExecution == nil, editingParameter == nil, objectSelectionLocation == nil,
              !objectSelectionLoading, let operations, operations.pending == nil,
              operations.retained.isEmpty, let plan, plan.editing == nil, source.plan == plan.stamp else {
            throw TaskCreateCommandIssue.unsupportedPlan
        }
        if let draft = operations.active {
            guard plan.items.isEmpty, source.operation == draft.stamp else { throw TaskCreateCommandIssue.unsupportedPlan }
            _ = try CommandTaskCreateInput(draft)
        } else {
            _ = try coordinator.taskCreatePlan(plan.stamp, expecting: source.lease)
        }
        try session.validateDisplayHost(expecting: source.lease)
    }

    /// 同步原生入口共同防重入；未完成组合文本不能从按钮或面板快捷键绕过。
    private var taskNativeInputReady: Bool {
        (NSApp.keyWindow?.firstResponder as? NSTextView)?.hasMarkedText() != true
    }

    func requestTaskCreate(_ source: UnifiedSearchBuffer, prepareOnly: Bool = false) {
        guard !settingSubmitting, validates(source), operationVisible, settingExecution == nil,
              taskNativeInputReady else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try checkTaskCreate(source)
            guard let taskCreate else { throw TaskCreateCommandIssue.unassembled }
            if prepareOnly, operations?.active != nil { throw TaskCreateCommandIssue.unsupportedPlan }
            if let draft = operations?.active, let plan {
                // 与计划按钮相同的原子移交；保留查询，不替换原 draft 身份。
                try coordinator.send(.enqueue(draft.stamp, itemID: UUID(), plan: plan.stamp), expecting: source.lease)
                _ = publishOperation(text: buffer.text)
            }
            guard let plan else { throw TaskCreateCommandIssue.stale }
            let lease = buffer.lease
            try session.validateDisplayHost(expecting: lease)
            if prepareOnly {
                taskCreatePreparation = try taskCreate.prepare(plan: plan.stamp, expecting: lease)
            } else {
                _ = try taskCreate.submit(plan: plan.stamp, expecting: lease, displaySession: session)
                _ = publishOperation(text: buffer.text)
            }
            taskCreateFailure = nil
        } catch {
            // 只刷新同一所有权的原运行；不得拿新 lease 再调用提交。
            _ = publishOperation(text: buffer.text)
            taskCreateFailure = error as? TaskCreateCommandIssue ?? .stale
        }
    }

    func verifyTaskCreate(_ source: UnifiedSearchBuffer) {
        guard !settingSubmitting, validates(source), operationVisible,
              taskCreateUnit?.taskCreation?.state == .unknown, let run = settingExecution,
              let item = run.snapshot.items.first, let operation = run.operation(item.id), let taskCreate else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do { taskCreateVerification = try taskCreate.verifyUnknown(operation, expecting: source.lease) }
        catch { taskCreateFailure = error as? TaskCreateCommandIssue ?? .stale }
    }

    func acknowledgeTaskCreate(_ source: UnifiedSearchBuffer) {
        guard !settingSubmitting, validates(source), operationVisible, let run = settingExecution,
              taskCreateUnit?.state == .succeeded, taskCreateUnit?.taskCreation?.state == .saved else { return }
        do {
            try coordinator.send(.releaseExecution(run.stamp), expecting: source.lease)
            taskCreatePreparation = nil
            taskCreateVerification = nil
            _ = publishOperation(text: buffer.text)
        } catch { taskCreateFailure = .stale }
    }
}
