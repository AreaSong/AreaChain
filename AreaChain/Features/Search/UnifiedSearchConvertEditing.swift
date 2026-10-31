import Foundation

/// 互转的预览、接受、独立确认与核对只是原 Plan/Run 之外的不可编辑投影；草稿与计划仍归 Coordinator。
extension UnifiedSearchController {
    var showsConvert: Bool {
        let drafts = (operations?.allDrafts ?? []) + (plan?.items.map(\.draft) ?? [])
            + (settingExecution?.snapshot.items.map(\.draft) ?? [])
        return drafts.contains { routesConvert($0.commandID) }
    }

    func routesConvert(_ command: CommandID) -> Bool { convert?.supports(command) == true }

    var hasConvert: Bool {
        let drafts = (operations?.allDrafts ?? []) + (plan?.items.map(\.draft) ?? [])
        return drafts.count == 1 && drafts.allSatisfy { convert?.supports($0.commandID) == true }
    }

    var currentConvertPreview: CommandConvertPreview? {
        guard operationVisible, let preview = convertPreview, let convert,
              (try? convert.validatePreview(preview, expecting: buffer.lease, displaySession: session)) != nil else { return nil }
        return preview
    }

    var currentConvertAcceptance: CommandConvertAcceptance? {
        guard let accepted = convertAcceptance, accepted.preview == currentConvertPreview else { return nil }
        return accepted
    }

    var convertUnit: CommandExecutionUnit? {
        guard operationVisible, let run = settingExecution, run.snapshot.items.count == 1,
              run.snapshot.items.first.map({ CommandConvertEdit.commands.contains($0.draft.commandID.rawValue) }) == true else {
            return nil
        }
        return run.units.first
    }

    func revokeConvert() {
        if let confirmation = convertConfirmation { convert?.cancel(confirmation) }
        convertPreview = nil
        convertAcceptance = nil
        convertConfirmation = nil
    }

    private func checkConvert(_ source: UnifiedSearchBuffer) throws {
        guard validates(source), operationVisible else { throw CommandConvertIssue.stale }
        guard hasConvert else { throw CommandConvertIssue.unsupportedPlan }
        guard editingParameter == nil, tagSelection == nil, objectSelectionLocation == nil, !objectSelectionLoading,
              settingExecution == nil, let operations, operations.pending == nil, operations.retained.isEmpty,
              let plan, plan.editing == nil, plan.stamp == source.plan else {
            throw CommandConvertIssue.unsupportedPlan
        }
        if let draft = operations.active {
            guard plan.items.isEmpty, draft.stamp == source.operation,
                  CommandConvertEdit.commands.contains(draft.commandID.rawValue) else { throw CommandConvertIssue.unsupportedPlan }
            guard draft.check().staticallyValid else { throw CommandConvertIssue.invalidArguments }
        }
        try session.validateDisplayHost(expecting: source.lease)
    }

    private func convertAction(_ source: UnifiedSearchBuffer, _ work: () throws -> Void) {
        guard !settingSubmitting, taskNativeInputReady, validates(source), operationVisible else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            try checkConvert(source)
            try work()
            convertFailure = nil
        } catch { convertFailure = UnifiedSearchConvertCopy.error(error) }
    }

    func prepareConvert(_ source: UnifiedSearchBuffer) {
        convertAction(source) {
            revokeConvert()
            if let draft = operations?.active, let plan {
                try coordinator.send(.enqueue(draft.stamp, itemID: UUID(), plan: plan.stamp), expecting: source.lease)
                _ = publishOperation(text: buffer.text)
            }
            guard let plan, let convert else { throw CommandConvertIssue.stale }
            convertPreview = try convert.prepare(plan: plan.stamp, expecting: buffer.lease, displaySession: session)
        }
    }

    func acceptConvert(_ preview: CommandConvertPreview, source: UnifiedSearchBuffer) {
        convertAction(source) {
            guard convertPreview == preview, convertConfirmation == nil, let convert else { throw CommandConvertIssue.stale }
            convertAcceptance = nil
            convertAcceptance = try convert.accept(preview, expecting: source.lease, displaySession: session)
        }
    }

    /// 普通提交（按钮与 ⌘Return）只打开独立确认，从不直接写入。
    func requestConvertConfirmation(_ source: UnifiedSearchBuffer) {
        guard convertConfirmation == nil, settingExecution == nil else { return }
        convertAction(source) {
            guard let accepted = currentConvertAcceptance, let convert else { throw CommandConvertIssue.confirmationRequired }
            convertConfirmation = try convert.confirm(accepted, expecting: source.lease, displaySession: session)
            inputFocused = false
        }
    }

    /// Esc 与取消只撤销确认；草稿、计划、预览和接受均保持原样。
    func cancelConvertConfirmation() {
        guard let confirmation = convertConfirmation else { return }
        convert?.cancel(confirmation)
        convertConfirmation = nil
        inputFocused = true
        refreshOperationPresentation()
    }

    func confirmConvert(_ confirmation: CommandConvertConfirmation, source: UnifiedSearchBuffer) {
        guard convertConfirmation == confirmation, settingExecution == nil else { return }
        convertAction(source) {
            defer { convertConfirmation = nil; inputFocused = true }
            guard let accepted = convertAcceptance, let convert else { throw CommandConvertIssue.stale }
            do {
                _ = try convert.submit(accepted: accepted, confirmation: confirmation, expecting: source.lease,
                                       displaySession: session)
            } catch {
                // 失败前的原因要求重新预览；已进入 Run 的结果仍由原 Run 展示。
                convertAcceptance = nil
                if settingExecution == nil { convertPreview = nil }
                if settingExecution != nil { _ = publishOperation(text: buffer.text) }
                throw error
            }
            _ = publishOperation(text: buffer.text)
            planMessage = "unified.plan.notExecutable"
        }
    }

    /// 只读核对未知结果；不自动重试、不恢复同一计划的执行资格。
    func verifyConvertUnknown(_ source: UnifiedSearchBuffer) {
        guard validates(source), let convert, let run = settingExecution, let unit = convertUnit,
              unit.conversion?.state == .unknown, let operation = run.snapshot.items.first.flatMap({ run.operation($0.id) }) else { return }
        do {
            convertVerification = try convert.verifyUnknown(operation, expecting: source.lease, displaySession: session)
            convertFailure = nil
        } catch { convertFailure = UnifiedSearchConvertCopy.error(error) }
    }
}

enum UnifiedSearchConvertCopy {
    static func error(_ error: Error) -> String {
        guard let issue = error as? CommandConvertIssue else {
            if error as? CommandExecutionError == .busy { return "unified.convert.busy" }
            return "unified.convert.stale"
        }
        switch issue {
        case .unassembled, .invalidRepository: return "unified.convert.unassembled"
        case .unsupportedPlan: return "unified.convert.single"
        case .invalidArguments: return "unified.convert.input"
        case .invalidTarget(let problem): return "unified.convert.problem." + String(describing: problem)
        case .confirmationRequired: return "unified.convert.acceptFirst"
        case .confirmationStale, .stale, .alreadyInvoked: return "unified.convert.stale"
        case .verificationRequired: return "unified.convert.verificationRequired"
        }
    }

    static func result(_ facts: CommandConvertFacts) -> String {
        "unified.convert." + (facts.state == .pending ? "pendingResult" : String(describing: facts.state))
    }

    static func outcome(_ verification: CommandConvertVerification) -> String {
        "unified.convert.verification." + String(describing: verification.outcome)
    }
}
