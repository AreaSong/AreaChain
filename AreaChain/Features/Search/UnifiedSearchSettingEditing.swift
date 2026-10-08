import Foundation

struct UnifiedSearchSettingFailure {
    let source: UnifiedSearchBuffer
    let issue: LocalSettingCommandIssue
}

struct UnifiedSearchSettingConfirmation {
    let source: UnifiedSearchBuffer
    let evidence: LocalSettingConflictConfirmation
}

/// 只衔接原草稿/计划与具体适配器；结果由原运行及适配器回执派生，不建立执行状态机。
extension UnifiedSearchController {
    var settingExecution: CommandExecutionRun? {
        _ = revision
        guard let host = try? coordinator.host(buffer.lease.ownership.hostID),
              host.lease.ownership == buffer.lease.ownership else { return nil }
        return host.session.execution
    }

    var settingDraft: CommandDraft? {
        operations?.active ?? (plan?.items.count == 1 ? plan?.items.first?.draft : nil)
    }

    var settingReport: LocalSettingCommandReport? {
        guard operationVisible, let run = settingExecution, let unit = run.units.first,
              let attempt = run.attempt(unit.id) else { return nil }
        return try? localSettings?.report(for: attempt, expecting: buffer.lease)
    }

    var settingIssue: LocalSettingCommandIssue? {
        if let failure = settingFailure, failure.source == buffer { return failure.issue }
        do { try checkSettingSubmission(buffer); return nil }
        catch { return error as? LocalSettingCommandIssue ?? .stale }
    }

    var hasSettingAdapter: Bool {
        localSettings?.isAssembled(for: coordinator) == true || fileSettings?.isAssembled(for: coordinator) == true
    }

    func supportsSetting(_ command: CommandID) -> Bool {
        hasSettingAdapter && LocalSettingCommandMapping.field(for: command) != nil
    }

    /// 只在接受/恢复/编辑事件后采集一次；重绘及参数预览不会替换已有原值。
    func prepareSettingDraft() {
        // 文件基线只能由明确的准备操作取得，计划编辑和重绘不隐式刷新。
        guard fileSettings == nil else { return }
        guard operationVisible, hasSettingAdapter, operations?.pending == nil,
              let draft = editingDraft, localSettings?.supports(draft.commandID) == true,
              draft.baseline.preference == nil else { return }
        do {
            try localSettings?.prepare(draft.stamp, expecting: buffer.lease)
            _ = publishOperation(text: buffer.text)
        } catch { recordSettingFailure(error) }
    }

    func requestSettingBaseline(source: UnifiedSearchBuffer) {
        guard !settingSubmitting, validates(source), operationVisible else { return }
        prepareSettingDraft()
    }

    private func checkSettingSubmission(_ source: UnifiedSearchBuffer) throws {
        guard validates(source), operationVisible else { throw LocalSettingCommandIssue.stale }
        guard hasSettingAdapter, let localSettings else { throw LocalSettingCommandIssue.unwired }
        guard editingParameter == nil, objectSelectionLocation == nil, !objectSelectionLoading else {
            throw LocalSettingCommandIssue.busy
        }
        if let draft = operations?.active {
            guard source.operation == draft.stamp else { throw LocalSettingCommandIssue.stale }
            try localSettings.readiness(draft: draft.stamp, expecting: source.lease)
        } else {
            guard let plan, source.plan == plan.stamp else { throw LocalSettingCommandIssue.stale }
            try localSettings.readiness(plan: plan.stamp, expecting: source.lease)
        }
        try session.validateDisplayHost(expecting: source.lease)
    }

    /// 点击和原生 ⌘Return 共用；最后写入门禁继续由适配器复核。
    func requestOperationSubmit(_ source: UnifiedSearchBuffer) {
        if showsTaskChain { submitTaskChain(source); return }
        if showsSubtask { submitSubtask(source); return }
        if showsTaskField { submitTaskField(source); return }
        if showsTaskTitle { submitTaskTitle(source); return }
        if showsTaskCreate { requestTaskCreate(source); return }
        if fileSettings != nil { requestFileSettingSubmit(source); return }
        guard !settingSubmitting, validates(source), operationVisible, settingExecution == nil else { return }
        guard hasSettingAdapter, let localSettings else {
            operationMessage = "unified.operation.submitBlocked"
            planMessage = "unified.plan.notExecutable"
            refreshOperationPresentation()
            return
        }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try checkSettingSubmission(source)
            if let draft = operations?.active, let plan {
                // 与原入列按钮同一个原子转移；不能先删草稿再尝试执行。
                try coordinator.send(.enqueue(draft.stamp, itemID: UUID(), plan: plan.stamp), expecting: source.lease)
                _ = publishOperation(text: "")
            }
            guard let plan else { throw LocalSettingCommandIssue.stale }
            _ = try localSettings.submit(plan: plan.stamp, expecting: buffer.lease, displaySession: session)
            _ = publishOperation(text: buffer.text)
        } catch {
            // seal/begin 或可信完成可能已推进修订；只发布同一所有权的现状，不重放请求。
            _ = publishOperation(text: buffer.text)
            recordSettingFailure(error)
        }
    }

    func requestSettingConflict(source: UnifiedSearchBuffer) {
        guard !settingSubmitting, validates(source), operationVisible, hasSettingAdapter,
              settingExecution == nil, let draft = settingDraft, let localSettings else { return }
        settingSubmitting = true
        defer { settingSubmitting = false }
        do {
            let evidence = try localSettings.rereadConflict(draft.stamp, expecting: source.lease)
            settingConfirmation = .init(source: source, evidence: evidence)
            settingFailure = nil
            refreshOperationPresentation()
        } catch { recordSettingFailure(error) }
    }

    func resolveSettingConflict(_ confirmation: UnifiedSearchSettingConfirmation, choice: LocalSettingConflictChoice) {
        guard !settingSubmitting, validates(confirmation.source), operationVisible,
              settingConfirmation?.evidence == confirmation.evidence, let localSettings else { return }
        settingSubmitting = true
        defer { settingSubmitting = false }
        settingConfirmation = nil
        do {
            try localSettings.resolveConflict(confirmation.evidence, choice: choice)
            _ = publishOperation(text: buffer.text)
            settingSubmitting = false
            if choice == .continueEditing, let item = plan?.items.first {
                beginPlanEditing(item.stamp, source: buffer)
            }
            settingMessage = choice == .confirmOverwrite ? "unified.setting.overwriteReady" : "unified.setting.pending"
            operationExpanded = true
        } catch { recordSettingFailure(error) }
    }

    func returnSettingToPlan(_ report: LocalSettingCommandReport, source: UnifiedSearchBuffer) {
        guard !settingSubmitting, validates(source), operationVisible, settingReport == report, let localSettings else { return }
        do {
            try localSettings.returnUnsubmittedToPlan(report.receipt.attempt, expecting: source.lease)
            _ = publishOperation(text: "")
            if case .conflict = report.outcome { requestSettingConflict(source: buffer) }
            else if let item = plan?.items.first { beginPlanEditing(item.stamp, source: buffer) }
        } catch { recordSettingFailure(error) }
    }

    func retrySettingPresentation(_ report: LocalSettingCommandReport, source: UnifiedSearchBuffer) {
        guard !settingSubmitting, validates(source), operationVisible, settingReport == report, let localSettings else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            _ = try localSettings.retryPresentation(report.receipt.attempt, expecting: source.lease, displaySession: session)
            _ = publishOperation(text: buffer.text)
        } catch {
            _ = publishOperation(text: buffer.text)
            recordSettingFailure(error)
        }
    }

    func acknowledgeSettingResult(_ report: LocalSettingCommandReport, source: UnifiedSearchBuffer) {
        guard !settingSubmitting, validates(source), operationVisible, settingReport == report else { return }
        do {
            try coordinator.send(.releaseExecution(report.operation.execution), expecting: source.lease)
            _ = publishOperation(text: "")
            inputFocused = true
        } catch { recordSettingFailure(error) }
    }

    private func recordSettingFailure(_ error: Error) {
        settingFailure = .init(source: buffer, issue: error as? LocalSettingCommandIssue ?? .stale)
        refreshOperationPresentation()
    }
}
