import AppKit
import SwiftUI

/// 单行原生输入桥接，复用 DaybookTextFieldCell 与 DaybookFieldEditor 以保证输入法组词与撤销稳定。
struct BaseSingleLineTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var focus: Binding<Bool>
    var syntaxPlugin: BaseInputSyntaxPlugin
    var fontSize: CGFloat = DaybookType.bodySize
    var fontWeight: NSFont.Weight = .regular
    var allowsShiftNewline: Bool = false
    var newlinePolicy: DaybookNewlinePolicy = .capture
    var commandChord: ShortcutChord? = nil
    var autocomplete: SyntaxAutocompleteState? = nil
    var availableTags: [String] = []
    var onSubmit: () -> Void = {}
    var onCommandReturn: (() -> Void)? = nil
    var onTab: (() -> Void)? = nil
    var onEscape: (() -> Void)? = nil
    var onVerticalArrow: ((BaseInputVerticalDirection) -> Void)? = nil

    var nativeFont: NSFont {
        fontWeight == .regular ? .systemFont(ofSize: fontSize) : .systemFont(ofSize: fontSize, weight: fontWeight)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let field = DaybookAppKitTextField(string: "")
        let cell = DaybookTextFieldCell(textCell: "")
        cell.wraps = false; cell.isScrollable = true
        cell.usesSingleLineMode = !allowsShiftNewline && newlinePolicy != .verbatim
        cell.preservesNewlines = newlinePolicy == .verbatim
        field.cell = cell; field.isEditable = true; field.isSelectable = true
        field.placeholderString = placeholder; field.font = nativeFont
        field.textColor = NSColor(DaybookPalette.text.primary)
        field.drawsBackground = false; field.backgroundColor = .clear
        field.isBordered = false; field.isBezeled = false
        field.focusRingType = .none; field.lineBreakMode = .byTruncatingTail
        field.setContentHuggingPriority(.defaultHigh, for: .vertical)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.delegate = context.coordinator
        field.onWindowAttached = { [weak field, weak coordinator = context.coordinator] in
            if let field { coordinator?.requestFocus(in: field) }
        }
        if syntaxPlugin != .none, !text.isEmpty {
            field.attributedStringValue = BaseInputSyntaxHighlighter.attributedString(for: text, plugin: syntaxPlugin, font: nativeFont)
        } else {
            field.stringValue = text
        }
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        context.coordinator.configureRestoration(in: field)
        if let appKitField = field as? DaybookAppKitTextField {
            appKitField.commandChord = commandChord
            appKitField.onCommandReturn = { [weak field, weak coordinator = context.coordinator] in
                if let field { coordinator?.triggerCommandReturn(in: field) }
            }
        }
        Self.synchronizeText(text, in: field, syntaxPlugin: syntaxPlugin, font: nativeFont)
        if let autocomplete, (field.currentEditor() as? NSTextView).map(DaybookTextEditing.isProtected) != true,
           autocomplete.inputText != text || autocomplete.availableTags != availableTags {
            let cursor = (field.currentEditor() as? NSTextView)?.selectedRange().location ?? (text as NSString).length
            autocomplete.update(text: text, cursorLocation: cursor, availableTags: availableTags)
        }
        if let cell = field.cell as? DaybookTextFieldCell {
            cell.usesSingleLineMode = !allowsShiftNewline && newlinePolicy != .verbatim
            cell.preservesNewlines = newlinePolicy == .verbatim
        }
        (field.currentEditor() as? DaybookFieldEditor)?.usesSingleLineInput = !allowsShiftNewline && newlinePolicy != .verbatim
        if field.placeholderString != placeholder { field.placeholderString = placeholder }
        field.font = nativeFont; field.textColor = NSColor(DaybookPalette.text.primary)
        context.coordinator.requestFocus(in: field)
    }

    /// 同步外部文本至 AppKit 控件，在输入法 markedText 组词期间保持静默以避免打断候选。
    static func synchronizeText(_ text: String, in field: NSTextField, syntaxPlugin: BaseInputSyntaxPlugin, font: NSFont) {
        let editor = field.currentEditor() as? NSTextView
        let current = editor?.string ?? field.stringValue
        guard current != text, editor.map(DaybookTextEditing.isProtected) != true else { return }
        let length = (text as NSString).length
        let delta = length - (current as NSString).length
        let cursor = min(length, max(0, (editor?.selectedRange().location ?? 0) + delta))
        if let editor {
            editor.string = text
            if syntaxPlugin != .none, let storage = editor.textStorage {
                BaseInputSyntaxHighlighter.applyHighlighting(to: storage, plugin: syntaxPlugin, font: font)
            }
            editor.setSelectedRange(NSRange(location: cursor, length: 0))
        } else if syntaxPlugin != .none {
            field.attributedStringValue = BaseInputSyntaxHighlighter.attributedString(for: text, plugin: syntaxPlugin, font: font)
        } else {
            field.stringValue = text
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: BaseSingleLineTextField
        private weak var observedEditor: NSTextView?
        private var lastSelection = NSRange(location: 0, length: 0)

        init(_ parent: BaseSingleLineTextField) { self.parent = parent }
        deinit { NotificationCenter.default.removeObserver(self) }

        func requestFocus(in field: NSTextField) {
            guard parent.focus.wrappedValue, field.window != nil, field.currentEditor() == nil else { return }
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

        func controlTextDidBeginEditing(_ obj: Notification) {
            guard let field = obj.object as? NSTextField, let editor = field.currentEditor() as? NSTextView else { return }
            beginEditing(field, editor: editor)
        }

        func beginEditing(_ field: NSTextField, editor: NSTextView) {
            parent.focus.wrappedValue = true
            parent.autocomplete?.editor = editor
            (editor as? DaybookFieldEditor)?.usesSingleLineInput = !parent.allowsShiftNewline && parent.newlinePolicy != .verbatim
            if parent.syntaxPlugin != .none, let storage = editor.textStorage, !DaybookTextEditing.isProtected(editor) {
                BaseInputSyntaxHighlighter.applyHighlighting(to: storage, plugin: parent.syntaxPlugin, font: parent.nativeFont)
            }
            parent.autocomplete?.update(text: editor.string, cursorLocation: editor.selectedRange().location, availableTags: parent.availableTags)
            if observedEditor !== editor {
                if let old = observedEditor { NotificationCenter.default.removeObserver(self, name: nil, object: old) }
                observedEditor = editor
                NotificationCenter.default.addObserver(
                    self, selector: #selector(editorDidChangeSelection(_:)), name: NSTextView.didChangeSelectionNotification, object: editor
                )
                NotificationCenter.default.addObserver(
                    self, selector: #selector(editorDidChangeText(_:)), name: NSText.didChangeNotification, object: editor
                )
            }
            editor.allowsUndo = true
            editor.isAutomaticQuoteSubstitutionEnabled = false; editor.isAutomaticDashSubstitutionEnabled = false
            editor.isAutomaticTextReplacementEnabled = false; editor.isAutomaticSpellingCorrectionEnabled = false
            if #available(macOS 15.1, *) { editor.writingToolsBehavior = .none }
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            parent.focus.wrappedValue = false
            parent.autocomplete?.dismiss(); parent.autocomplete?.editor = nil
            if parent.syntaxPlugin != .none, observedEditor.map(DaybookTextEditing.isProtected) != true {
                (obj.object as? NSTextField)?.attributedStringValue = BaseInputSyntaxHighlighter.attributedString(
                    for: parent.text, plugin: parent.syntaxPlugin, font: parent.nativeFont
                )
            }
            if let editor = observedEditor {
                NotificationCenter.default.removeObserver(self, name: nil, object: editor)
                observedEditor = nil
            }
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            let editor = field.currentEditor() as? NSTextView
            observeText(editor?.string ?? field.stringValue, editor: editor)
        }

        @objc private func editorDidChangeSelection(_ notification: Notification) {
            guard let autocomplete = parent.autocomplete, let textView = notification.object as? NSTextView else { return }
            if textView.window?.firstResponder === textView { lastSelection = textView.selectedRange() }
            guard !DaybookTextEditing.isProtected(textView) else { autocomplete.dismissSuggestionsOnly(); return }
            autocomplete.update(text: textView.string, cursorLocation: textView.selectedRange().location, availableTags: parent.availableTags)
        }

        @objc private func editorDidChangeText(_ notification: Notification) {
            if let editor = notification.object as? NSTextView { observeText(editor.string, editor: editor) }
        }

        func observeText(_ value: String, editor: NSTextView?) {
            parent.text = value
            guard editor.map(DaybookTextEditing.isProtected) != true else { parent.autocomplete?.dismissSuggestionsOnly(); return }
            if parent.syntaxPlugin != .none, let storage = editor?.textStorage {
                BaseInputSyntaxHighlighter.applyHighlighting(to: storage, plugin: parent.syntaxPlugin, font: parent.nativeFont)
            }
            let cursor = editor?.selectedRange().location ?? (value as NSString).length
            parent.autocomplete?.update(text: value, cursorLocation: cursor, availableTags: parent.availableTags)
        }

        func triggerCommandReturn(in field: NSTextField) {
            if let editor = (field.currentEditor() as? NSTextView) ?? observedEditor {
                guard !DaybookTextEditing.isProtected(editor) else { return }
                let submitted = parent.newlinePolicy.submittedText(editor.string, allowsShiftNewline: parent.allowsShiftNewline)
                guard DaybookTextEditing.replaceForSubmission(submitted, in: editor) else { return }
                parent.text = editor.string
            }
            parent.autocomplete?.dismiss()
            if let onCommandReturn = parent.onCommandReturn { onCommandReturn() } else { parent.onSubmit() }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // 输入法组词期间绝不拦截回车、Tab、Esc 或上下方向键，交还系统完成选词。
            guard !DaybookTextEditing.isProtected(textView) else { return false }
            if let autocomplete = parent.autocomplete, autocomplete.hasPresentation,
               handleAutocomplete(commandSelector, textView: textView, autocomplete: autocomplete) {
                return true
            }
            if commandSelector == #selector(NSResponder.insertTab(_:)), let onTab = parent.onTab { onTab(); return true }
            if commandSelector == #selector(NSResponder.moveUp(_:)), let onVerticalArrow = parent.onVerticalArrow {
                onVerticalArrow(.up); return true
            }
            if commandSelector == #selector(NSResponder.moveDown(_:)), let onVerticalArrow = parent.onVerticalArrow {
                onVerticalArrow(.down); return true
            }
            let isShiftNewline = commandSelector == #selector(NSResponder.insertNewline(_:))
                && NSApp.currentEvent?.modifierFlags.contains(.shift) == true
            if commandSelector == #selector(NSResponder.insertLineBreak(_:)) || isShiftNewline {
                if parent.allowsShiftNewline { textView.insertNewlineIgnoringFieldEditor(nil) }
                return true
            }
            if commandSelector == #selector(NSResponder.insertNewline(_:)), !textView.hasMarkedText() {
                let submitted = parent.newlinePolicy.submittedText(textView.string, allowsShiftNewline: parent.allowsShiftNewline)
                guard DaybookTextEditing.replaceForSubmission(submitted, in: textView) else { return true }
                parent.text = textView.string
                if let event = NSApp.currentEvent, ShortcutChordMatching.accepts(event, chord: parent.commandChord),
                   let onCommandReturn = parent.onCommandReturn {
                    onCommandReturn()
                } else {
                    parent.onSubmit()
                }
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                if let onEscape = parent.onEscape { onEscape() }
                else { textView.window?.makeFirstResponder(nil); parent.focus.wrappedValue = false }
                return true
            }
            return false
        }

        private func handleAutocomplete(
            _ selector: Selector, textView: NSTextView, autocomplete: SyntaxAutocompleteState
        ) -> Bool {
            if selector == #selector(NSResponder.cancelOperation(_:)) {
                if autocomplete.showsAttributes { autocomplete.dismiss(); return true }
                if autocomplete.isActive && !autocomplete.candidates.isEmpty { autocomplete.dismissSuggestionsOnly(); return true }
                if autocomplete.showsPreview { autocomplete.dismissPreview(); return true }
                autocomplete.dismiss(); return true
            }
            guard autocomplete.isActive else { return false }
            switch selector {
            case #selector(NSResponder.moveUp(_:)): autocomplete.selectPrevious(); return true
            case #selector(NSResponder.moveDown(_:)):
                guard !autocomplete.candidates.isEmpty else { return false }
                autocomplete.selectNext(); return true
            case #selector(NSResponder.insertTab(_:)), #selector(NSResponder.insertNewline(_:)):
                guard let candidate = autocomplete.selectedCandidate(),
                      autocomplete.commit(candidate, in: textView) else { return false }
                parent.text = textView.string; return true
            default: return false
            }
        }
    }
}

/// 多行原生编辑器桥接，支持直接换行或 Shift+Return 换行，并在 markedText 期间保护按键不误交。
struct BaseMultiLineTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var focused: Bool
    var placeholder: String
    var syntaxPlugin: BaseInputSyntaxPlugin
    var fontSize: CGFloat
    var commandChord: ShortcutChord?
    var autocomplete: SyntaxAutocompleteState
    var tracksAutocomplete: Bool
    var availableTags: [String]
    var onSubmit: (() -> Void)?
    var onCommandReturn: (() -> Void)?
    var onTab: (() -> Void)?
    var onEscape: (() -> Void)?
    var onVerticalArrow: ((BaseInputVerticalDirection) -> Void)?
    var onMarkedTextChange: ((Bool) -> Void)?
    var onPasteImage: ((NSPasteboard) -> Bool)?

    var focus: Binding<Bool> { _focused }

    init(
        text: Binding<String>, focus: Binding<Bool>, placeholder: String,
        syntaxPlugin: BaseInputSyntaxPlugin = .taskSyntax, fontSize: CGFloat = DaybookType.bodySize,
        commandChord: ShortcutChord? = nil, autocomplete: SyntaxAutocompleteState? = nil,
        availableTags: [String] = [], onSubmit: (() -> Void)? = nil,
        onCommandReturn: (() -> Void)? = nil, onTab: (() -> Void)? = nil,
        onEscape: (() -> Void)? = nil, onVerticalArrow: ((BaseInputVerticalDirection) -> Void)? = nil,
        onMarkedTextChange: ((Bool) -> Void)? = nil, onPasteImage: ((NSPasteboard) -> Bool)? = nil
    ) {
        _text = text; _focused = focus; self.placeholder = placeholder
        self.syntaxPlugin = syntaxPlugin; self.fontSize = fontSize; self.commandChord = commandChord
        self.autocomplete = autocomplete ?? SyntaxAutocompleteState(context: .tags)
        self.tracksAutocomplete = autocomplete != nil; self.availableTags = availableTags
        self.onSubmit = onSubmit; self.onCommandReturn = onCommandReturn; self.onTab = onTab
        self.onEscape = onEscape; self.onVerticalArrow = onVerticalArrow
        self.onMarkedTextChange = onMarkedTextChange; self.onPasteImage = onPasteImage
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false; scroll.borderType = .noBorder
        scroll.automaticallyAdjustsContentInsets = false; scroll.contentInsets = NSEdgeInsetsZero
        scroll.scrollerStyle = .overlay; scroll.hasVerticalScroller = true
        scroll.verticalScroller = DaybookScroller(); scroll.autohidesScrollers = true
        let editor = DaybookAppKitTextView(frame: NSRect(x: 0, y: 0, width: 240, height: 28))
        editor.minSize = NSSize(width: 0, height: 28)
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.isRichText = false; editor.importsGraphics = false; editor.allowsUndo = true
        editor.drawsBackground = false; editor.isVerticallyResizable = true; editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.containerSize.height = .greatestFiniteMagnitude
        editor.textContainerInset = NSSize(width: 4, height: 4)
        editor.font = .systemFont(ofSize: fontSize); editor.textColor = NSColor(DaybookPalette.text.primary)
        editor.isAutomaticQuoteSubstitutionEnabled = false; editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false; editor.isAutomaticSpellingCorrectionEnabled = false
        if #available(macOS 15.1, *) { editor.writingToolsBehavior = .none }
        editor.delegate = context.coordinator
        editor.onMarkedTextChange = onMarkedTextChange; editor.onPasteImage = onPasteImage
        editor.onFocusChange = { [weak coordinator = context.coordinator, weak editor] isFocused in
            if let coordinator, let editor { coordinator.handleFocusChange(isFocused, editor: editor) }
        }
        editor.setAccessibilityIdentifier("syntax.text.editor")
        scroll.documentView = editor
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        scroll.automaticallyAdjustsContentInsets = false; scroll.contentInsets = NSEdgeInsetsZero
        guard let editor = scroll.documentView as? DaybookAppKitTextView else { return }
        let nativeFont = NSFont.systemFont(ofSize: fontSize)
        if !DaybookTextEditing.isProtected(editor), editor.font != nativeFont { editor.font = nativeFont }
        editor.insertionPointColor = NSColor(DaybookPalette.text.primary)
        editor.setAccessibilityLabel(placeholder)
        editor.commandChord = commandChord
        editor.onMarkedTextChange = onMarkedTextChange; editor.onPasteImage = onPasteImage
        editor.onCommandReturn = { [weak editor, weak coordinator = context.coordinator] in
            if let editor, !DaybookTextEditing.isProtected(editor) { coordinator?.triggerCommandReturn(in: editor) }
        }
        Self.synchronizeText(text, in: editor, syntaxPlugin: syntaxPlugin, font: nativeFont)
        if tracksAutocomplete, !DaybookTextEditing.isProtected(editor), editor.window?.firstResponder === editor,
           autocomplete.inputText != text || autocomplete.availableTags != availableTags {
            let cursor = min((text as NSString).length, editor.selectedRange().location)
            autocomplete.editor = editor
            autocomplete.update(text: text, cursorLocation: cursor, availableTags: availableTags)
        }
        if focused, let window = editor.window, window.firstResponder !== editor {
            DispatchQueue.main.async { if focused { window.makeFirstResponder(editor) } }
        }
    }

    static func synchronizeText(
        _ text: String, in editor: NSTextView, syntaxPlugin: BaseInputSyntaxPlugin = .none, font: NSFont? = nil
    ) {
        guard !DaybookTextEditing.isProtected(editor), editor.string != text else { return }
        let length = (text as NSString).length
        let delta = length - (editor.string as NSString).length
        let cursor = min(length, max(0, editor.selectedRange().location + delta))
        editor.string = text
        if syntaxPlugin != .none, let font, let storage = editor.textStorage {
            BaseInputSyntaxHighlighter.applyHighlighting(to: storage, plugin: syntaxPlugin, font: font)
        }
        editor.setSelectedRange(NSRange(location: cursor, length: 0))
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: BaseMultiLineTextEditor
        private var lastSelection = NSRange(location: 0, length: 0)
        init(_ parent: BaseMultiLineTextEditor) { self.parent = parent }

        func handleFocusChange(_ isFocused: Bool, editor: NSTextView) {
            if isFocused {
                if parent.tracksAutocomplete { parent.autocomplete.editor = editor }
                if !parent.focused { parent.focused = true }
            } else {
                if parent.tracksAutocomplete { parent.autocomplete.dismiss(); parent.autocomplete.editor = nil }
                if parent.focused { parent.focused = false }
            }
        }

        func textDidBeginEditing(_ notification: Notification) {
            if let editor = notification.object as? NSTextView { handleFocusChange(true, editor: editor) }
        }

        func textDidEndEditing(_ notification: Notification) {
            if let editor = notification.object as? NSTextView { handleFocusChange(false, editor: editor) }
        }

        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            parent.text = editor.string
            lastSelection = editor.selectedRange()
            applyHighlightIfReady(editor)
            updateCompletion(editor)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            let selection = editor.selectedRange()
            guard selection != lastSelection else { return }
            lastSelection = selection
            updateCompletion(editor)
        }

        private func applyHighlightIfReady(_ editor: NSTextView) {
            guard !DaybookTextEditing.isProtected(editor), parent.syntaxPlugin != .none,
                  let storage = editor.textStorage else { return }
            BaseInputSyntaxHighlighter.applyHighlighting(to: storage, plugin: parent.syntaxPlugin, font: .systemFont(ofSize: parent.fontSize))
        }

        private func updateCompletion(_ editor: NSTextView) {
            guard parent.tracksAutocomplete else { return }
            guard !DaybookTextEditing.isProtected(editor), editor.window?.firstResponder === editor else {
                parent.autocomplete.dismissSuggestionsOnly(); return
            }
            parent.autocomplete.editor = editor
            parent.autocomplete.update(text: editor.string, cursorLocation: editor.selectedRange().location, availableTags: parent.availableTags)
        }

        func triggerCommandReturn(in editor: NSTextView) {
            guard !DaybookTextEditing.isProtected(editor) else { return }
            parent.text = editor.string
            if parent.tracksAutocomplete { parent.autocomplete.dismiss() }
            if let onCommandReturn = parent.onCommandReturn { onCommandReturn() } else { parent.onSubmit?() }
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard !DaybookTextEditing.isProtected(textView) else { return false }
            if parent.tracksAutocomplete, handleAutocomplete(commandSelector, textView: textView, completion: parent.autocomplete) {
                return true
            }
            if commandSelector == #selector(NSResponder.insertTab(_:)), let onTab = parent.onTab { onTab(); return true }
            if commandSelector == #selector(NSResponder.moveUp(_:)), let onVerticalArrow = parent.onVerticalArrow {
                onVerticalArrow(.up); return true
            }
            if commandSelector == #selector(NSResponder.moveDown(_:)), let onVerticalArrow = parent.onVerticalArrow {
                onVerticalArrow(.down); return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                if let onEscape = parent.onEscape { onEscape() }
                else { textView.window?.makeFirstResponder(nil); parent.focused = false }
                return true
            }
            return false
        }

        private func handleAutocomplete(_ commandSelector: Selector, textView: NSTextView, completion: SyntaxAutocompleteState) -> Bool {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)), completion.hasPresentation {
                if completion.showsAttributes { completion.dismiss(); return true }
                if completion.isActive && !completion.candidates.isEmpty { completion.dismissSuggestionsOnly(); return true }
                if completion.showsPreview { completion.dismissPreview(); return true }
                completion.dismiss(); return true
            }
            guard completion.isActive else { return false }
            switch commandSelector {
            case #selector(NSResponder.moveUp(_:)): completion.selectPrevious(); return true
            case #selector(NSResponder.moveDown(_:)): completion.selectNext(); return true
            case #selector(NSResponder.insertTab(_:)), #selector(NSResponder.insertNewline(_:)):
                guard NSApp.currentEvent?.modifierFlags.contains(.shift) != true,
                      let candidate = completion.selectedCandidate(), completion.commit(candidate, in: textView) else { return false }
                parent.text = textView.string
                lastSelection = textView.selectedRange()
                applyHighlightIfReady(textView)
                completion.update(text: textView.string, cursorLocation: textView.selectedRange().location, availableTags: parent.availableTags)
                return true
            case #selector(NSResponder.cancelOperation(_:)): completion.dismiss(); return true
            default: return false
            }
        }
    }
}
