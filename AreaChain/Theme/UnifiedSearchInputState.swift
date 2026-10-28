import AppKit
import SwiftUI

/// 宿主发布的显示缓冲；lease 原样随意图返回，不能由控件续租。
struct UnifiedSearchBuffer: Equatable {
    let lease: CommandHostLease
    let version: UInt64
    let text: String
    var privacyRevision: UInt64 = 0
    var operation: CommandDraftStamp?
    var selectingObjects = false
    var plan: CommandPlanStamp?
    var planItem: CommandPlanItemStamp?
}

struct UnifiedSearchEdit {
    let source: UnifiedSearchBuffer
    let text: String
    let selection: NSRange
    var acceptance: CommandPathEdit?
}

enum UnifiedSearchIntent: Equatable {
    case submit, results(Int), open, escape, selectActive
}

struct UnifiedSearchActions {
    var edit: (UnifiedSearchEdit) -> UnifiedSearchBuffer?
    var accept: (UnifiedSearchEdit) -> UnifiedSearchBuffer?
    var focus: (Bool) -> Void
    var intent: (UnifiedSearchIntent, UnifiedSearchBuffer) -> Void
}

struct UnifiedSearchInputConfiguration {
    let actions: UnifiedSearchActions
    let parser: CommandPathParser
    let discovery: CommandDiscoveryConfiguration
    let locale: Locale
    var parameter: UnifiedSearchParameterContext?
    /// `#` 候选只列这些已有标签（宿主按旧搜索取存活标签）；搜索不能创建标签。
    var availableTags: [String] = []
}

struct UnifiedSearchCompletion {
    let source: UnifiedSearchBuffer
    let selection: NSRange
    let result: CommandPathResult
}

/// 只保存原生展示与候选，不持有可修改的业务参数、查询或指令目录副本。
@Observable @MainActor
final class UnifiedSearchInputState {
    let suggestions = SyntaxAutocompleteState(context: .search)
    private(set) var buffer: UnifiedSearchBuffer
    private(set) var completion: UnifiedSearchCompletion?
    private var acceptedNavigation: UnifiedSearchBuffer?
    @ObservationIgnored var parser: CommandPathParser
    @ObservationIgnored var configuration = CommandDiscoveryConfiguration.standard
    @ObservationIgnored var locale = Locale(identifier: "en")
    @ObservationIgnored var parameter: UnifiedSearchParameterContext?
    @ObservationIgnored var actions: UnifiedSearchActions
    @ObservationIgnored var availableTags: [String] = []
    /// 当前候选来自 `#`／`!`／`@` 语法（非 `/` 指令，修复批 M-7F 恢复旧搜索候选）；接受走 SyntaxAutocompleteState 原生提交。
    private(set) var showsSyntax = false
    var focused = false
    @ObservationIgnored weak var field: NSTextField?
    @ObservationIgnored weak var editor: NSTextView?
    @ObservationIgnored private var applying = false
    @ObservationIgnored private var deferredBuffer: UnifiedSearchBuffer?
    @ObservationIgnored private var pendingAcceptance: CommandPathEdit?
    @ObservationIgnored private var lastSelection = NSRange(location: 0, length: 0)
    @ObservationIgnored private var highlight = UnifiedSearchHighlight()

    init(buffer: UnifiedSearchBuffer, parser: CommandPathParser = .init(), actions: UnifiedSearchActions) {
        self.buffer = buffer
        self.parser = parser
        self.actions = actions
    }

    func configure(_ configuration: UnifiedSearchInputConfiguration?) {
        guard let configuration else { return }
        let changed = parser.catalog.entries != configuration.parser.catalog.entries
            || self.configuration != configuration.discovery || locale != configuration.locale
            || parameter != configuration.parameter || availableTags != configuration.availableTags
        actions = configuration.actions
        availableTags = configuration.availableTags
        parser = configuration.parser
        self.configuration = configuration.discovery
        locale = configuration.locale
        parameter = configuration.parameter
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
        completion = nil
        actions.focus(false)
        editor = nil
    }

    func changed(_ editor: NSTextView) {
        guard !applying else { return }
        // 普通参数组合文本先留在原生 editor；结束组词后才校验并进入草稿。
        if parameter != nil, editor.hasMarkedText() { suggestions.dismiss(); completion = nil; return }
        if !editor.hasMarkedText(), let deferredBuffer, let field {
            synchronize(deferredBuffer, field: field)
            return
        }
        // 组合文本也属于显示缓冲，但不能发布候选或改写 marked range。
        let acceptance = pendingAcceptance
        pendingAcceptance = nil
        let request = UnifiedSearchEdit(source: buffer, text: editor.string,
                                        selection: editor.selectedRange(), acceptance: acceptance)
        if editor.string != buffer.text || acceptance != nil {
            let response = acceptance == nil ? actions.edit(request) : actions.accept(request)
            guard let accepted = response, accepted.text == editor.string,
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
        let result = parameter?.completion(buffer.text, locale: locale)
            ?? parser.parse(.init(text: buffer.text, cursorLocation: lastSelection.location,
                                 locale: locale, configuration: configuration))
        if acceptedNavigation == buffer { dismissSuggestions() }
        else if parameter == nil, result.state == .ordinaryText, focused {
            // 解析器只把 `/` 开头的文字当指令；其余文字沿旧搜索的语法候选。completion 仍记本次解析供状态行使用。
            completion = .init(source: buffer, selection: lastSelection, result: result)
            showSyntaxCandidates()
        } else { _ = publish(.init(source: buffer, selection: lastSelection, result: result)) }
        applying = true
        if parameter == nil { highlight.apply(to: editor, result: result) }
        applying = false
    }

    /// 异步提供者必须携带原缓冲、宿主 lease 和选区；相同文字不是相同事件。
    @discardableResult
    func publish(_ value: UnifiedSearchCompletion) -> Bool {
        guard value.source == buffer, value.result.input == buffer.text,
              value.selection == lastSelection, editor?.hasMarkedText() != true,
              editor?.string == buffer.text, focused else { return false }
        completion = value
        showsSyntax = false
        suggestions.candidates = value.result.candidates.map {
            SyntaxCandidate(id: $0.id, title: $0.title, insertText: $0.insertText, kind: .tag)
        }
        suggestions.selectedIndex = min(suggestions.selectedIndex, max(0, suggestions.candidates.count - 1))
        suggestions.isActive = !suggestions.candidates.isEmpty
        return true
    }

    @discardableResult
    func accept(_ candidate: CommandPathCandidate, source: UnifiedSearchCompletion) -> Bool {
        guard source.source == buffer, source.selection == lastSelection,
              completion?.source == source.source, completion?.result == source.result,
              let editor, !editor.hasMarkedText(),
              let edit = source.result.accepting(candidate, in: editor.string, hasMarkedText: false) else { return false }
        field?.window?.makeFirstResponder(field)
        pendingAcceptance = edit
        editor.breakUndoCoalescing()
        editor.insertText(candidate.insertText, replacementRange: candidate.replacementRange)
        editor.setSelectedRange(NSRange(location: edit.cursorLocation, length: 0))
        changed(editor)
        pendingAcceptance = nil
        editor.breakUndoCoalescing()
        if candidate.category == .navigation, buffer.text == edit.text {
            acceptedNavigation = buffer
            suggestions.dismiss()
            completion = nil
        }
        return buffer.text == edit.text
    }

    func command(_ selector: Selector, editor: NSTextView) -> Bool {
        guard !editor.hasMarkedText() else { return false }
        if buffer.selectingObjects, selector == #selector(NSResponder.insertTab(_:)) {
            actions.intent(.open, buffer)
            return true
        }
        if selector == #selector(NSResponder.cancelOperation(_:)) {
            if suggestions.isActive {
                if completion?.result.command?.category == .navigation { acceptedNavigation = buffer }
                dismissSuggestions()
            } else { actions.intent(.escape, buffer) }
            return true
        }
        if selector == #selector(NSResponder.moveUp(_:)) || selector == #selector(NSResponder.moveDown(_:)) {
            let down = selector == #selector(NSResponder.moveDown(_:))
            if suggestions.isActive {
                if down { suggestions.selectNext() } else { suggestions.selectPrevious() }
            } else { actions.intent(.results(down ? 1 : -1), buffer) }
            return true
        }
        if selector == #selector(NSResponder.insertTab(_:)) || selector == #selector(NSResponder.insertNewline(_:)) {
            if showsSyntax, suggestions.isActive, let selected = suggestions.selectedCandidate() {
                _ = accept(syntax: selected)
            } else if let source = completion, suggestions.isActive,
               let selected = suggestions.selectedCandidate(),
               let candidate = source.result.candidates.first(where: { $0.id == selected.id }) {
                _ = accept(candidate, source: source)
            } else if selector == #selector(NSResponder.insertNewline(_:)) {
                actions.intent(.open, buffer)
            } else { return false }
            return true
        }
        return false
    }

    /// 明确导航先收候选并释放本字段焦点；组合输入由调用方继续等待，不清文字或撤销。
    func dismissForNavigation() -> Bool {
        guard editor?.hasMarkedText() != true else { return false }
        acceptedNavigation = buffer
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
        completion = nil
        pendingAcceptance = nil
        acceptedNavigation = nil
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

    /// 点选或 Return／Tab 接受语法候选：替换 SyntaxAutocompleteState 识别出的触发区间，经原生编辑插入（保留撤销与光标），
    /// 再走同一文字变更路径进入缓冲。触发区间先取出：重新聚焦会让 AppKit 重开编辑并按新选区重算候选。
    @discardableResult
    func accept(syntax candidate: SyntaxCandidate) -> Bool {
        guard showsSyntax, suggestions.isActive, suggestions.candidates.contains(candidate),
              let trigger = suggestions.trigger, let current = editor, !current.hasMarkedText(),
              current.string == buffer.text, NSMaxRange(trigger.range) <= (buffer.text as NSString).length else { return false }
        let before = buffer.text
        // 已在编辑时不再设第一响应者：对正在编辑的字段再设一次会结束并重开编辑（全选），候选随之失效。
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
        // 搜索不能创建标签：`#` 只留已有标签；引擎对未命中查询给出的原样回显也不展示（§1 产品约定）。
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
        completion = nil
    }

    private func restore() {
        applying = true
        if let field { DaybookTextField.synchronizeText(buffer.text, in: field) }
        applying = false
        refresh()
    }
}
