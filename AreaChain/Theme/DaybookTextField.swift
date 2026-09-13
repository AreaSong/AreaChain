import AppKit
import SwiftUI

/// 支持按键等效拦截（如 ⌘↩）的 AppKit 文本框
final class DaybookAppKitTextField: NSTextField {
    var onCommandReturn: (() -> Void)?
    var onWindowAttached: (() -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { onWindowAttached?() }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == .command,
           (event.keyCode == 36 || event.charactersIgnoringModifiers == "\r" || event.charactersIgnoringModifiers == "\n") {
            if let editor = currentEditor() as? NSTextView,
               window?.firstResponder === editor {
                guard !editor.hasMarkedText() else { return true }
                stringValue = editor.string
                onCommandReturn?()
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

/// AppKit 单行输入，避开 SwiftUI TextField 在 NSPopover 里错位的系统附件按钮。
struct DaybookTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var fontSize: CGFloat = 13
    var focus: Binding<Bool>
    var autocomplete: SyntaxAutocompleteState? = nil
    var availableTags: [String] = []
    var onSubmit: () -> Void
    var onCommandReturn: (() -> Void)? = nil
    var onCommitAutocomplete: ((SyntaxCandidate) -> Void)? = nil
    var allowsShiftNewline: Bool = true
    var onEscape: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = DaybookAppKitTextField(string: "")
        field.placeholderString = placeholder
        field.font = .systemFont(ofSize: fontSize)
        field.textColor = NSColor(DaybookTheme.ink)
        field.drawsBackground = false
        field.backgroundColor = .clear
        field.isBordered = false
        field.isBezeled = false
        field.focusRingType = .none
        field.lineBreakMode = .byTruncatingTail
        if let cell = field.cell as? NSTextFieldCell {
            cell.wraps = false
            cell.isScrollable = true
            cell.usesSingleLineMode = false
        }
        field.setContentHuggingPriority(.defaultHigh, for: .vertical)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.delegate = context.coordinator
        field.onWindowAttached = { [weak field, weak coordinator = context.coordinator] in
            guard let field else { return }
            coordinator?.requestFocus(in: field)
        }
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        context.coordinator.configureRestoration(in: field)
        (field as? DaybookAppKitTextField)?.onCommandReturn = onCommandReturn == nil ? nil : { [weak field] in
            guard let field, let extra = context.coordinator.parent.onCommandReturn else { return }
            let editorString = (field.currentEditor() as? NSTextView)?.string ?? field.stringValue
            var value = editorString
            if !context.coordinator.parent.allowsShiftNewline, value.contains("\n") {
                value = value.replacingOccurrences(of: "\n", with: " ")
            }
            context.coordinator.parent.text = value
            context.coordinator.parent.autocomplete?.dismiss()
            extra()
        }
        Self.synchronizeText(text, in: field)
        if field.placeholderString != placeholder {
            field.placeholderString = placeholder
        }
        field.font = .systemFont(ofSize: fontSize)
        field.textColor = NSColor(DaybookTheme.ink)
        context.coordinator.requestFocus(in: field)
    }

    /// 同步外部草稿更新，但不打断中文输入法的组合文本。
    static func synchronizeText(_ text: String, in field: NSTextField) {
        let editor = field.currentEditor() as? NSTextView
        let current = editor?.string ?? field.stringValue
        guard current != text, editor?.hasMarkedText() != true else { return }
        let length = (text as NSString).length
        let delta = length - (current as NSString).length
        let cursor = min(length, max(0, (editor?.selectedRange().location ?? 0) + delta))
        field.stringValue = text
        editor?.string = text
        editor?.setSelectedRange(NSRange(location: cursor, length: 0))
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: DaybookTextField
        private weak var observedEditor: NSTextView?
        private var lastSelection = NSRange(location: 0, length: 0)

        init(_ parent: DaybookTextField) {
            self.parent = parent
        }

        func requestFocus(in field: NSTextField) {
            guard parent.focus.wrappedValue, field.window != nil, field.currentEditor() == nil else { return }
            // 首次更新可能早于挂载；窗口就绪后重试，并尊重最新的焦点请求。
            DispatchQueue.main.async { [weak self, weak field] in
                guard let self, let field, self.parent.focus.wrappedValue,
                      field.currentEditor() == nil, let window = field.window else { return }
                window.makeFirstResponder(field)
            }
        }

        func configureRestoration(in field: NSTextField) {
            parent.autocomplete?.restoreEditing = { [weak self, weak field] in
                guard let self, let field, let window = field.window else { return }
                self.parent.focus.wrappedValue = true
                guard field.currentEditor() == nil else { return }
                let selection = self.lastSelection
                window.makeFirstResponder(field)
                if let editor = field.currentEditor() as? NSTextView {
                    let length = (editor.string as NSString).length
                    let start = min(selection.location, length)
                    editor.setSelectedRange(NSRange(location: start, length: min(selection.length, length - start)))
                }
            }
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @objc func submitted(_ sender: Any? = nil) {
            if NSApp.currentEvent?.modifierFlags.contains(.command) == true, let extra = parent.onCommandReturn {
                extra()
            } else {
                parent.onSubmit()
            }
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else {
                parent.text = ""
                return
            }
            var value = field.stringValue
            if !parent.allowsShiftNewline, value.contains("\n") {
                value = value.replacingOccurrences(of: "\n", with: " ")
                field.stringValue = value
            }
            parent.text = value

            if let autocomplete = parent.autocomplete {
                let editor = field.currentEditor() as? NSTextView
                guard editor?.hasMarkedText() != true else { autocomplete.dismiss(); return }
                let cursor = editor?.selectedRange().location ?? (value as NSString).length
                autocomplete.update(text: value, cursorLocation: cursor, availableTags: parent.availableTags)
            }
        }

        @objc private func editorDidChangeSelection(_ notification: Notification) {
            guard let autocomplete = parent.autocomplete,
                  let textView = notification.object as? NSTextView else { return }
            if textView.window?.firstResponder === textView { lastSelection = textView.selectedRange() }
            guard !textView.hasMarkedText() else { autocomplete.dismiss(); return }
            let cursor = textView.selectedRange().location
            autocomplete.update(text: textView.string, cursorLocation: cursor, availableTags: parent.availableTags)
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            parent.focus.wrappedValue = true
            guard let editor = (obj.object as? NSTextField)?.currentEditor() as? NSTextView else { return }
            parent.autocomplete?.editor = editor

            // 注意：不能将 editor.delegate 设为 self！
            // NSTextField 内部强依赖自身作为 fieldEditor 的 delegate 来同步状态与派发通知。
            // 若覆盖 delegate，NSTextField 将不会向此 Coordinator 转发 controlTextDidChange 与 doCommandBy。
            if observedEditor !== editor {
                if let old = observedEditor {
                    NotificationCenter.default.removeObserver(self, name: NSTextView.didChangeSelectionNotification, object: old)
                }
                observedEditor = editor
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(editorDidChangeSelection(_:)),
                    name: NSTextView.didChangeSelectionNotification,
                    object: editor
                )
            }

            editor.allowsUndo = true
            editor.isAutomaticQuoteSubstitutionEnabled = false
            editor.isAutomaticDashSubstitutionEnabled = false
            editor.isAutomaticTextReplacementEnabled = false
            editor.isAutomaticSpellingCorrectionEnabled = false
            if #available(macOS 15.1, *) {
                editor.writingToolsBehavior = .none
            }
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            parent.focus.wrappedValue = false
            parent.autocomplete?.dismiss()
            parent.autocomplete?.editor = nil
            if let editor = observedEditor {
                NotificationCenter.default.removeObserver(self, name: NSTextView.didChangeSelectionNotification, object: editor)
                observedEditor = nil
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard !textView.hasMarkedText() else { return false }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)),
               let autocomplete = parent.autocomplete, autocomplete.hasPresentation {
                autocomplete.dismiss()
                return true
            }
            if let autocomplete = parent.autocomplete, autocomplete.isActive {
                if commandSelector == #selector(NSResponder.moveUp(_:)) {
                    autocomplete.selectPrevious()
                    return true
                }
                if commandSelector == #selector(NSResponder.moveDown(_:)) {
                    autocomplete.selectNext()
                    return true
                }
                if commandSelector == #selector(NSResponder.insertTab(_:)) ||
                   commandSelector == #selector(NSResponder.insertNewline(_:)) {
                    if let candidate = autocomplete.selectedCandidate(), autocomplete.commit(candidate, in: textView) {
                        parent.text = textView.string
                        parent.onCommitAutocomplete?(candidate)
                        return true
                    }
                }
                if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                    autocomplete.dismiss()
                    return true
                }
            }

            if commandSelector == #selector(NSResponder.insertLineBreak(_:)) ||
               (commandSelector == #selector(NSResponder.insertNewline(_:)) && NSApp.currentEvent?.modifierFlags.contains(.shift) == true) {
                if parent.allowsShiftNewline {
                    textView.insertNewlineIgnoringFieldEditor(nil)
                }
                return true
            }
            if commandSelector == Selector(("noop:")) {
                let flags = (NSApp.currentEvent?.modifierFlags ?? NSEvent.modifierFlags).intersection(.deviceIndependentFlagsMask)
                if flags == .command, let extra = parent.onCommandReturn {
                    var value = textView.string
                    if !parent.allowsShiftNewline, value.contains("\n") {
                        value = value.replacingOccurrences(of: "\n", with: " ")
                    }
                    parent.text = value
                    parent.autocomplete?.dismiss()
                    extra()
                    return true
                }
            }
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if textView.hasMarkedText() {
                    return false
                }
                var value = textView.string
                if !parent.allowsShiftNewline, value.contains("\n") {
                    value = value.replacingOccurrences(of: "\n", with: " ")
                }
                parent.text = value
                submitted()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                if let onEscape = parent.onEscape {
                    onEscape()
                    return true
                }
                textView.window?.makeFirstResponder(nil)
                parent.focus.wrappedValue = false
                return true
            }
            if commandSelector == #selector(NSResponder.moveDown(_:)), textView.string.isEmpty {
                textView.window?.makeFirstResponder(nil)
                parent.focus.wrappedValue = false
                return true
            }
            return false
        }
    }
}

extension DaybookTextField {
    /// 兼容现有 SwiftUI 焦点调用；原生搜索可直接绑定自己的焦点状态，避免结果区切换重置输入。
    init(
        text: Binding<String>, placeholder: String, fontSize: CGFloat = 13,
        focus: FocusState<Bool>.Binding, autocomplete: SyntaxAutocompleteState? = nil,
        availableTags: [String] = [], onSubmit: @escaping () -> Void,
        onCommandReturn: (() -> Void)? = nil, onCommitAutocomplete: ((SyntaxCandidate) -> Void)? = nil,
        allowsShiftNewline: Bool = true, onEscape: (() -> Void)? = nil
    ) {
        self.init(
            text: text, placeholder: placeholder, fontSize: fontSize,
            focus: Binding(get: { focus.wrappedValue }, set: { focus.wrappedValue = $0 }),
            autocomplete: autocomplete, availableTags: availableTags, onSubmit: onSubmit,
            onCommandReturn: onCommandReturn, onCommitAutocomplete: onCommitAutocomplete,
            allowsShiftNewline: allowsShiftNewline, onEscape: onEscape
        )
    }
}
