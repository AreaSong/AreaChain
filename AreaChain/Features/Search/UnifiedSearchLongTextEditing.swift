import AppKit
import Observation

/// UI 只持一次性访问和字段身份；正文不进入 buffer、parameterText 或返回搜索票据。
@Observable @MainActor final class UnifiedSearchLongTextEditing {
    let id = UUID()
    let draftID: UUID
    let parameter: CommandParameterID
    let content: CommandDraftContentSession
    private var initialAccess: CommandDraftContentAccess?
    weak var editor: CommandProtectedTextView?
    var isProtected: Bool
    var operation: CommandFieldOperation
    var pending = false
    var composing = false
    var available = true
    var message = "unified.longText.draftOnly"

    init(draft: CommandDraft, parameter: CommandParameterID, content: CommandDraftContentSession,
         access: CommandDraftContentAccess) throws {
        draftID = draft.id
        self.parameter = parameter
        self.content = content
        initialAccess = access
        isProtected = access.isProtected
        operation = try content.nativeOperation(access, parameter: parameter)
    }

    func attach(_ editor: CommandProtectedTextView) throws {
        guard self.editor == nil, let access = initialAccess, available else { throw CommandDraftProtectionError.stale }
        initialAccess = nil
        self.editor = editor
        try editor.begin(using: access)
        pending = editor.pendingConfirmation
    }

    func end() {
        available = false
        initialAccess = nil
        editor?.end()
        editor = nil
    }
}

extension UnifiedSearchController {
    /// 只有显式装配才出现入口；不扩大全局单行参数补全或执行能力。
    func assembleLongText(vault: PrivacyVault) {
        guard longTextContent == nil else { return }
        longTextContent = CommandDraftContentSession(coordinator: coordinator, vault: vault) { [weak self] lease in
            guard let self, !self.isNavigationPresented else { throw CommandDraftProtectionError.stale }
            try self.session.validateDisplayHost(expecting: lease)
        }
    }

    func supportsLongText(_ parameter: CommandParameter) -> Bool {
        longTextContent != nil && parameter.type == .longText && [.notes, .body].contains(parameter.id)
    }

    func beginLongText(_ parameter: CommandParameterID, source: UnifiedSearchBuffer) {
        guard validatesParameterSource(source, parameter: parameter), let draft = editingDraft,
              let content = longTextContent else { return }
        endLongText()
        do {
            let access = try draft.protectedReference == nil
                ? content.explicitlyEditOrdinary(draft.stamp, expecting: source.lease)
                : content.explicitlyRestore(draft.stamp, expecting: source.lease)
            longTextEditing = try .init(draft: draft, parameter: parameter, content: content, access: access)
            longTextMessage = nil
            inputFocused = false
        } catch { longTextMessage = "unified.longText.unavailable" }
    }

    func endLongText() {
        let previous = longTextEditing
        longTextEditing = nil
        previous?.end()
        longTextContent?.revokeAccess()
    }

    func longTextAdvanced(_ editing: UnifiedSearchLongTextEditing) {
        guard longTextEditing === editing else { return }
        _ = publishOperation(text: buffer.text)
        editing.pending = editing.editor?.pendingConfirmation == true
        editing.composing = editing.editor?.hasMarkedText() == true
        if editing.editor?.issue == .acceptedNotDisplayed { editing.message = "unified.longText.acceptedHidden" }
        else if editing.editor?.issue != nil { editing.message = "unified.longText.rejected" }
        else { editing.message = "unified.longText.draftOnly" }
    }

    func protectLongText(source: UnifiedSearchBuffer) {
        guard validates(source), let draft = editingDraft, draft.protectedReference == nil,
              let content = longTextContent else { return }
        do {
            _ = try content.protect(draft.stamp, expecting: source.lease)
            endLongText()
            _ = publishOperation(text: buffer.text)
            longTextMessage = "unified.longText.protectedHidden"
        } catch { longTextMessage = "unified.longText.notProtected" }
    }

    func changeLongTextOperation(_ operation: CommandFieldOperation, editing: UnifiedSearchLongTextEditing) {
        guard longTextEditing === editing, editing.available else { return }
        do {
            try editing.editor?.changeOperation(operation)
            editing.operation = operation
            // 操作变化撤销旧输入资格；新编辑必须显式重新打开，不跨外部操作续租。
            endLongText()
        } catch { editing.message = "unified.longText.rejected" }
    }
}
