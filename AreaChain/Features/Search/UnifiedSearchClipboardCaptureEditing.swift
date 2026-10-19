import Foundation

/// capture.clipboard 的界面状态：只读当前操作草稿，不入列、不建 Run。
struct UnifiedSearchClipboardCaptureState {
    var preview: CommandClipboardCapturePreview?
    var facts: CommandClipboardCaptureFacts?
    var failure: String?
    var verification: CommandClipboardCaptureVerification?

    mutating func revoke() {
        preview = nil
        facts = nil
        failure = nil
        verification = nil
    }
}

/// 准备只说明“将读取当前剪贴板”，提交时才读一次；按钮与 ⌘Return 同一入口。
extension UnifiedSearchController {
    var showsClipboardCapture: Bool { operations?.active.map { routesClipboardCapture($0.commandID) } == true }

    func routesClipboardCapture(_ command: CommandID) -> Bool { clipboard?.supports(command) == true }

    var currentClipboardCapturePreview: CommandClipboardCapturePreview? {
        guard operationVisible, let preview = clipboardCapture.preview, let clipboard,
              (try? clipboard.validatePreview(preview, expecting: buffer.lease, displaySession: session)) != nil else { return nil }
        return preview
    }

    /// 结果未知、待核对的待办身份；由适配器持有，不因面板刷新丢失。
    var unresolvedClipboardCapture: UUID? { clipboard?.unresolved.keys.first }

    private func clipboardAction(_ source: UnifiedSearchBuffer, _ work: (ClipboardCaptureCommandAdapter, CommandDraft) throws -> Void) {
        guard !settingSubmitting, taskNativeInputReady, validates(source), operationVisible else { return }
        settingSubmitting = true
        defer { settingSubmitting = false; refreshOperationPresentation() }
        do {
            guard let clipboard else { throw ClipboardCaptureCommandIssue.unassembled }
            guard editingParameter == nil, tagSelection == nil, objectSelectionLocation == nil, !objectSelectionLoading,
                  settingExecution == nil, plan?.items.isEmpty == true, let draft = operations?.active,
                  draft.stamp == source.operation else { throw ClipboardCaptureCommandIssue.unsupportedPlan }
            try session.validateDisplayHost(expecting: source.lease)
            try work(clipboard, draft)
            clipboardCapture.failure = nil
        } catch { clipboardCapture.failure = UnifiedSearchClipboardCaptureCopy.error(error) }
    }

    func prepareClipboardCapture(_ source: UnifiedSearchBuffer) {
        clipboardAction(source) { clipboard, draft in
            clipboardCapture.revoke()
            clipboardCapture.preview = try clipboard.prepare(draft: draft.stamp, expecting: source.lease, displaySession: session)
        }
    }

    func submitClipboardCapture(_ source: UnifiedSearchBuffer) {
        clipboardAction(source) { clipboard, _ in
            guard let preview = currentClipboardCapturePreview else { throw ClipboardCaptureCommandIssue.stale }
            clipboardCapture.facts = nil
            let facts = try clipboard.submit(preview, expecting: source.lease, displaySession: session)
            // 同一份预览只能提交一次；之后要再加今天须重新准备。
            clipboardCapture.preview = nil
            clipboardCapture.facts = facts
        }
    }

    func verifyClipboardCapture(_ source: UnifiedSearchBuffer) {
        guard validates(source), let clipboard, let todoID = unresolvedClipboardCapture else { return }
        do {
            clipboardCapture.verification = try clipboard.verifyUnknown(todoID, expecting: source.lease, displaySession: session)
            clipboardCapture.failure = nil
        } catch { clipboardCapture.failure = UnifiedSearchClipboardCaptureCopy.error(error) }
    }
}

enum UnifiedSearchClipboardCaptureCopy {
    static func error(_ error: Error) -> String {
        guard let issue = error as? ClipboardCaptureCommandIssue else {
            if error as? CommandExecutionError == .busy { return "unified.simple.busy" }
            return "unified.clipboardCapture.stale"
        }
        switch issue {
        case .unassembled: return "unified.simple.unassembled"
        case .unsupportedPlan: return "unified.clipboardCapture.single"
        case .stale, .alreadySubmitted: return "unified.clipboardCapture.stale"
        case .verificationRequired: return "unified.simple.verificationRequired"
        case .empty: return "unified.clipboardCapture.state.empty"
        }
    }
}
