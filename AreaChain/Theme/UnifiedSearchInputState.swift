import AppKit
import SwiftUI

/// 宿主发布的显示缓冲；lease 原样随意图返回，不能由控件续租。
struct UnifiedSearchBuffer: Equatable {
    let lease: CommandHostLease
    let version: UInt64
    let text: String
    var privacyRevision: UInt64 = 0
    var selectingObjects = false
}

struct UnifiedSearchEdit {
    let source: UnifiedSearchBuffer
    let text: String
    let selection: NSRange
}

enum UnifiedSearchIntent: Equatable {
    case submit, results(Int), open, escape, selectActive
}

struct UnifiedSearchActions {
    var edit: (UnifiedSearchEdit) -> UnifiedSearchBuffer?
    var accept: (UnifiedSearchEdit) -> UnifiedSearchBuffer?
    var focus: (Bool) -> Void
    var intent: (UnifiedSearchIntent, UnifiedSearchBuffer) -> Void

    init(
        edit: @escaping (UnifiedSearchEdit) -> UnifiedSearchBuffer?,
        accept: ((UnifiedSearchEdit) -> UnifiedSearchBuffer?)? = nil,
        focus: @escaping (Bool) -> Void,
        intent: @escaping (UnifiedSearchIntent, UnifiedSearchBuffer) -> Void
    ) {
        self.edit = edit
        self.accept = accept ?? edit
        self.focus = focus
        self.intent = intent
    }
}

struct UnifiedSearchInputConfiguration {
    let actions: UnifiedSearchActions
    let locale: Locale
    var availableTags: [String] = []
}

/// 只保存原生展示与语法候选，不持有旧式目录副本。
@Observable @MainActor
final class UnifiedSearchInputState {
    let suggestions = SyntaxAutocompleteState(context: .search)
    private(set) var buffer: UnifiedSearchBuffer
    @ObservationIgnored var locale = Locale(identifier: "en")
    @ObservationIgnored var actions: UnifiedSearchActions
    @ObservationIgnored var availableTags: [String] = []
    /// 当前候选来自 `#`／`!`／`@` 语法（非 `/` 指令）；接受走 SyntaxAutocompleteState 原生提交。
    private(set) var showsSyntax = false
    var focused = false
    @ObservationIgnored weak var field: NSTextField?
    @ObservationIgnored weak var editor: NSTextView?
    @ObservationIgnored private var applying = false
    @ObservationIgnored private var deferredBuffer: UnifiedSearchBuffer?
    @ObservationIgnored private var lastSelection = NSRange(location: 0, length: 0)
    @ObservationIgnored private var highlight = UnifiedSearchHighlight()

    init(buffer: UnifiedSearchBuffer, actions: UnifiedSearchActions) {
        self.buffer = buffer
        self.actions = actions
    }

    static func isContentScopePrefix(_ rawText: String) -> Bool {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return false }
        let firstEnd = trimmed.firstIndex(where: \.isWhitespace) ?? trimmed.endIndex
        let token = String(trimmed[..<firstEnd].dropFirst()).lowercased()
        return CommandContentScope(rawValue: token) != nil
    }

    static func isCLICommandInput(_ rawText: String) -> Bool {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("/") {
            return !isContentScopePrefix(trimmed)
        }
        return rawText.contains(" > ")
    }

    func configure(_ configuration: UnifiedSearchInputConfiguration?) {
        guard let configuration else { return }
        let changed = locale != configuration.locale || availableTags != configuration.availableTags
        actions = configuration.actions
        availableTags = configuration.availableTags
        locale = configuration.locale
        if changed { refresh() }
    }

    func synchronize(_ incoming: UnifiedSearchBuffer, field: NSTextField) {
        self.field = field
        if incoming.lease.ownership == buffer.lease.ownership, incoming.version < buffer.version { return }
        guard incoming != buffer || field.stringValue != incoming.text else { return }
        let privacyChanged = incoming.privacyRevision != buffer.privacyRevision
        let ownerChanged = incoming.lease.ownership != buffer.lease.ownership
        if privacyChanged || ownerChanged {
            clearNative()
        } else if editor?.hasMarkedText() == true {
            deferredBuffer = incoming
            return
        }
        deferredBuffer = nil
        buffer = incoming
        applying = true
        DaybookTextField.synchronizeText(incoming.text, in: field)
        applying = false
        refresh()
    }

    func begin(_ field: NSTextField, editor: NSTextView) {
        self.field = field
        self.editor = editor
        (editor as? UnifiedSearchFieldEditor)?.onObjectSpace = { [weak self] in
            guard let self, self.buffer.selectingObjects else { return false }
            self.actions.intent(.selectActive, self.buffer)
            return true
        }
        focused = true
        actions.focus(true)
        refresh()
    }

    func end() {
        (editor as? UnifiedSearchFieldEditor)?.onObjectSpace = nil
        focused = false
        suggestions.dismiss()
        showsSyntax = false
        actions.focus(false)
        editor = nil
    }

    func changed(_ editor: NSTextView) {
        guard !applying else { return }
        if !editor.hasMarkedText(), let deferredBuffer, let field {
            synchronize(deferredBuffer, field: field)
            return
        }
        let request = UnifiedSearchEdit(source: buffer, text: editor.string, selection: editor.selectedRange())
        if editor.string != buffer.text {
            guard let accepted = actions.edit(request), accepted.text == editor.string,
                  accepted.lease.ownership == buffer.lease.ownership, accepted.version > buffer.version else {
                if !editor.hasMarkedText() { restore() }
                return
            }
            buffer = accepted
        }
        refresh()
    }

    func refresh() {
        guard let editor, !applying else { return }
        lastSelection = editor.selectedRange()
        if buffer.selectingObjects { dismissSuggestions(); return }
        guard !editor.hasMarkedText(), editor.string == buffer.text else {
            dismissSuggestions()
            return
        }
        if !Self.isCLICommandInput(buffer.text), focused {
            showSyntaxCandidates()
        } else {
            dismissSuggestions()
        }
        applying = true
        highlight.apply(to: editor, text: buffer.text)
        applying = false
    }

    /// Tab 触发 Linux CLI 命令或参数名补全。
    func completeCLICommand(in editor: NSTextView) -> Bool {
        guard !editor.hasMarkedText() else { return false }
        StandardActionCatalog.bootstrapIfNeeded()
        let candidates = ActionRegistry.shared.completions(for: buffer.text)
        guard let first = candidates.first else { return false }
        let insertion = first.completedInput
        guard insertion != editor.string else { return true }
        field?.window?.makeFirstResponder(field)
        editor.breakUndoCoalescing()
        editor.insertText(insertion, replacementRange: NSRange(location: 0, length: (editor.string as NSString).length))
        editor.setSelectedRange(NSRange(location: (insertion as NSString).length, length: 0))
        changed(editor)
        editor.breakUndoCoalescing()
        return true
    }

    func command(_ selector: Selector, editor: NSTextView) -> Bool {
        guard !editor.hasMarkedText() else { return false }
        if buffer.selectingObjects, selector == #selector(NSResponder.insertTab(_:)) {
            actions.intent(.open, buffer)
            return true
        }
        if selector == #selector(NSResponder.cancelOperation(_:)) {
            if suggestions.isActive {
                dismissSuggestions()
            } else {
                actions.intent(.escape, buffer)
            }
            return true
        }
        if selector == #selector(NSResponder.moveUp(_:)) || selector == #selector(NSResponder.moveDown(_:)) {
            let down = selector == #selector(NSResponder.moveDown(_:))
            if suggestions.isActive {
                if down { suggestions.selectNext() } else { suggestions.selectPrevious() }
            } else {
                actions.intent(.results(down ? 1 : -1), buffer)
            }
            return true
        }
        if selector == #selector(NSResponder.insertTab(_:)) {
            if showsSyntax, suggestions.isActive, let selected = suggestions.selectedCandidate() {
                _ = accept(syntax: selected)
                return true
            }
            if Self.isCLICommandInput(buffer.text) {
                _ = completeCLICommand(in: editor)
                return true
            }
            return false
        }
        if selector == #selector(NSResponder.insertNewline(_:)) {
            if showsSyntax, suggestions.isActive, let selected = suggestions.selectedCandidate() {
                _ = accept(syntax: selected)
            } else {
                actions.intent(.open, buffer)
            }
            return true
        }
        return false
    }

    /// 明确导航先收候选并释放本字段焦点；组合输入由调用方继续等待，不清文字或撤销。
    func dismissForNavigation() -> Bool {
        guard editor?.hasMarkedText() != true else { return false }
        dismissSuggestions()
        if let editor, let window = field?.window, window.firstResponder === editor {
            return window.makeFirstResponder(nil)
        }
        return true
    }

    func submit() {
        guard editor?.hasMarkedText() != true, editor?.string == buffer.text else { return }
        actions.intent(.submit, buffer)
    }

    /// 只清独立 field editor 的撤销；绝不调用窗口共享 undoManager.removeAllActions。
    func clearNative() {
        applying = true
        suggestions.reset()
        showsSyntax = false
        deferredBuffer = nil
        let native = (field?.cell as? UnifiedSearchFieldCell)?.searchEditor ?? editor
        native?.unmarkText()
        native?.string = ""
        native?.setSelectedRange(NSRange(location: 0, length: 0))
        native?.undoManager?.removeAllActions()
        field?.stringValue = ""
        lastSelection = NSRange(location: 0, length: 0)
        highlight.clear()
        applying = false
    }

    @discardableResult
    func accept(syntax candidate: SyntaxCandidate) -> Bool {
        guard showsSyntax, suggestions.isActive, suggestions.candidates.contains(candidate),
              let trigger = suggestions.trigger, let current = editor, !current.hasMarkedText(),
              current.string == buffer.text, NSMaxRange(trigger.range) <= (buffer.text as NSString).length else { return false }
        let before = buffer.text
        if field?.window?.firstResponder !== current { field?.window?.makeFirstResponder(field) }
        guard let editor, !editor.hasMarkedText(), editor.string == before else { return false }
        editor.breakUndoCoalescing()
        editor.insertText(candidate.insertText, replacementRange: trigger.range)
        editor.setSelectedRange(NSRange(location: trigger.range.location + (candidate.insertText as NSString).length, length: 0))
        editor.breakUndoCoalescing()
        changed(editor)
        return buffer.text != before && buffer.text == editor.string
    }

    private func showSyntaxCandidates() {
        suggestions.update(text: buffer.text, cursorLocation: lastSelection.location, availableTags: availableTags)
        let existing = Set(availableTags.map(TagSyntax.normalizedName))
        let items = suggestions.candidates.filter { candidate in
            guard candidate.kind == .tag else { return true }
            return !candidate.isCreation && existing.contains(TagSyntax.normalizedName(String(candidate.title.dropFirst())))
        }
        if items.isEmpty {
            suggestions.dismissSuggestionsOnly()
        } else if items != suggestions.candidates {
            suggestions.candidates = items
            suggestions.selectedIndex = min(suggestions.selectedIndex, items.count - 1)
        }
        showsSyntax = suggestions.isActive
    }

    private func dismissSuggestions() {
        suggestions.dismiss()
        showsSyntax = false
    }

    private func restore() {
        applying = true
        if let field { DaybookTextField.synchronizeText(buffer.text, in: field) }
        applying = false
        refresh()
    }
}
