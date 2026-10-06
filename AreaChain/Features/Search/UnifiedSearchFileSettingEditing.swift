import Foundation

/// 枚举保证每个宿主只能装配一个执行后端；兼容初始化仍选择旧单项适配。
enum UnifiedSearchSettingBackend {
    case unassembled
    case legacy(LocalSettingCommandAdapter)
    case file(FileLocalSettingCommandAdapter)
}

struct UnifiedSearchFileSettingFailure {
    let source: UnifiedSearchBuffer
    let message: String
}

struct UnifiedSearchFileSettingConfirmation {
    let source: UnifiedSearchBuffer
    let evidence: FileLocalSettingConflictConfirmation
}

extension UnifiedSearchController {
    var fileSettingReport: FileLocalSettingCommandReport? {
        guard operationVisible, let run = settingExecution else { return nil }
        return try? fileSettings?.report(for: run.stamp, expecting: buffer.lease)
    }

    var fileSettingIssue: String? {
        if let failure = fileSettingFailure, failure.source == buffer { return failure.message }
        do { try checkFileSettingSubmission(buffer); return nil }
        catch { return UnifiedSearchFileSettingCopy.issue(error) }
    }

    func checkFileSettingSubmission(_ source: UnifiedSearchBuffer) throws {
        try validateFileSettingEvent(source)
        guard let fileSettings else { throw FileLocalSettingCommandIssue.unsupportedBackend }
        if let draft = operations?.active {
            try fileSettings.readiness(draft: draft.stamp, expecting: source.lease)
        } else {
            guard let plan, source.plan == plan.stamp else { throw FileLocalSettingCommandIssue.stale }
            try fileSettings.readiness(plan: plan.stamp, expecting: source.lease)
        }
    }

    /// 明确动作内顺序发送原建组事件和准备；失败后发布实际现状，不删除或筛选成员。
    func requestFileSettingPreparation(_ source: UnifiedSearchBuffer) {
        guard !settingSubmitting, validates(source), operationVisible else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try validateFileSettingEvent(source)
            guard let fileSettings else { throw FileLocalSettingCommandIssue.unsupportedBackend }
            if let draft = operations?.active {
                guard plan?.items.isEmpty == true else { throw FileLocalSettingCommandIssue.busy }
                _ = try fileSettings.prepare(draft.stamp, expecting: source.lease)
            } else {
                guard let plan else { throw FileLocalSettingCommandIssue.stale }
                // 已准备且仍合法的重复点击不刷新基线或推进版本。
                if (try? fileSettings.readiness(plan: plan.stamp, expecting: source.lease)) != nil { return }
                try establishFileSettingGroup(fileSettings, source: source)
                guard let updated = self.plan else { throw FileLocalSettingCommandIssue.stale }
                _ = try fileSettings.prepareGroup(plan: updated.stamp, expecting: buffer.lease)
            }
            _ = publishOperation(text: buffer.text)
            planMessage = "unified.group.ready"
        } catch { publishFileSettingFailure(error) }
    }

    func requestFileSettingSubmit(_ source: UnifiedSearchBuffer) {
        guard !settingSubmitting, validates(source), operationVisible, settingExecution == nil else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try checkFileSettingSubmission(source)
            guard let fileSettings else { throw FileLocalSettingCommandIssue.unsupportedBackend }
            if let draft = operations?.active, let plan {
                try coordinator.send(.enqueue(draft.stamp, itemID: UUID(), plan: plan.stamp), expecting: source.lease)
                _ = publishOperation(text: "")
            }
            guard let plan else { throw FileLocalSettingCommandIssue.stale }
            _ = try fileSettings.submit(plan: plan.stamp, expecting: buffer.lease, displaySession: session)
            _ = publishOperation(text: buffer.text)
            planMessage = "unified.plan.notExecutable"
        } catch { publishFileSettingFailure(error) }
    }

    func requestFileSettingConflict(_ source: UnifiedSearchBuffer) {
        guard !settingSubmitting, validates(source), operationVisible else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try validateFileSettingEvent(source)
            guard let fileSettings, let plan else { throw FileLocalSettingCommandIssue.stale }
            if let draft = operations?.active {
                guard plan.items.isEmpty else { throw FileLocalSettingCommandIssue.busy }
                try coordinator.send(.enqueue(draft.stamp, itemID: UUID(), plan: plan.stamp), expecting: source.lease)
                _ = publishOperation(text: "")
            }
            guard let current = self.plan else { throw FileLocalSettingCommandIssue.stale }
            let evidence = try fileSettings.rereadConflict(plan: current.stamp, expecting: buffer.lease)
            fileSettingConfirmation = .init(source: buffer, evidence: evidence)
            fileSettingFailure = nil
        } catch { publishFileSettingFailure(error) }
    }

    func resolveFileSettingConflict(_ confirmation: UnifiedSearchFileSettingConfirmation, choice: LocalSettingConflictChoice) {
        guard !settingSubmitting, validates(confirmation.source), operationVisible, fileSettingConfirmation?.evidence == confirmation.evidence else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try validateFileSettingEvent(confirmation.source)
            guard let fileSettings else { throw FileLocalSettingCommandIssue.stale }
            fileSettingConfirmation = nil
            try fileSettings.resolveConflict(confirmation.evidence, choice: choice)
            _ = publishOperation(text: buffer.text)
            if choice == .continueEditing, let item = plan?.items.first {
                settingSubmitting = false
                beginPlanEditing(item.stamp, source: buffer)
            }
        } catch { publishFileSettingFailure(error) }
    }

    func fileSettingResultAction(_ action: UnifiedSearchFileSettingAction, report: FileLocalSettingCommandReport,
                                 source: UnifiedSearchBuffer) {
        guard !settingSubmitting, validates(source), operationVisible, fileSettingReport == report,
              let fileSettings else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try session.validateDisplayHost(expecting: source.lease)
            switch action {
            case .verify: _ = try fileSettings.verifyCommit(report.localReceipt.attempt, expecting: source.lease)
            case .presentation:
                _ = try fileSettings.retryPresentation(report.latestAttempt, expecting: source.lease, displaySession: session)
            case .returnToPlan:
                try fileSettings.returnUnsubmittedToPlan(report.localReceipt.attempt, expecting: source.lease)
            case .done:
                guard settingExecution?.units.first?.state == .succeeded else { throw FileLocalSettingCommandIssue.notRetryable }
                try coordinator.send(.releaseExecution(report.identity.execution), expecting: source.lease)
            }
            _ = publishOperation(text: "")
            planMessage = "unified.plan.notExecutable"
        } catch { publishFileSettingFailure(error) }
    }

    private func validateFileSettingEvent(_ source: UnifiedSearchBuffer) throws {
        guard validates(source), operationVisible, fileSettings?.isAssembled(for: coordinator) == true else {
            throw FileLocalSettingCommandIssue.stale
        }
        guard settingExecution == nil, editingParameter == nil, plan?.editing == nil,
              objectSelectionLocation == nil, !objectSelectionLoading else { throw FileLocalSettingCommandIssue.busy }
        try session.validateDisplayHost(expecting: source.lease)
    }

    private func publishFileSettingFailure(_ error: Error) {
        // 读取已推进的同一所有权现状只为展示；不会再次执行旧事件。
        _ = publishOperation(text: buffer.text)
        let message = UnifiedSearchFileSettingCopy.issue(error)
        fileSettingFailure = .init(source: buffer, message: message)
        planMessage = message
    }
}

enum UnifiedSearchFileSettingAction { case verify, presentation, returnToPlan, done }
