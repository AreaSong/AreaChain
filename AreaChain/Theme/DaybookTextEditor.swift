import AppKit
import SwiftUI

class DaybookAppKitTextView: NSTextView {
    var onCommandReturn: (() -> Void)?
    var commandChord: ShortcutChord?
    var onFocusChange: ((Bool) -> Void)?

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted {
            onFocusChange?(true)
        }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            onFocusChange?(false)
        }
        return resigned
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // 没有单独指定组合时，备注编辑仍只认 ⌘Return，不跟着「记入手记」改。
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let matches = commandChord?.matches(event) ?? (flags == .command && event.keyCode == UInt16(ShortcutKey.returnKey))
        if matches, window?.firstResponder === self {
            if !hasMarkedText() { onCommandReturn?() }
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

/// 多行原生编辑器与单行输入共用语法引擎，保留输入法组合文本和系统撤销。
struct DaybookTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var focused: Bool
    var placeholder: String
    var fontSize: CGFloat = DaybookType.bodySize
    var autocomplete: SyntaxAutocompleteState
    var availableTags: [String]
    var highlightsSyntax: Bool = true
    var onSubmit: (() -> Void)? = nil
    var commandChord: ShortcutChord? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.automaticallyAdjustsContentInsets = false
        scroll.contentInsets = NSEdgeInsetsZero
        scroll.scrollerStyle = .overlay
        scroll.hasVerticalScroller = true
        scroll.verticalScroller = DaybookScroller()
        scroll.autohidesScrollers = true
        let editor = DaybookAppKitTextView(frame: NSRect(x: 0, y: 0, width: 240, height: 28))
        editor.minSize = NSSize(width: 0, height: 0)
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.isRichText = false
        editor.importsGraphics = false
        editor.allowsUndo = true
        editor.drawsBackground = false
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.containerSize.height = .greatestFiniteMagnitude
        editor.textContainerInset = NSSize(width: 4, height: 5)
        editor.font = .systemFont(ofSize: fontSize)
        editor.textColor = NSColor(DaybookPalette.text.primary)
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        if #available(macOS 15.1, *) { editor.writingToolsBehavior = .none }
        editor.delegate = context.coordinator
        editor.onFocusChange = { [weak coordinator = context.coordinator, weak editor] isFocused in
            guard let coordinator, let editor else { return }
            coordinator.handleFocusChange(isFocused, editor: editor)
        }
        editor.setAccessibilityIdentifier("syntax.text.editor")
        if highlightsSyntax, !text.isEmpty, let storage = editor.textStorage {
            SyntaxHighlighter.applyHighlighting(to: storage, font: .systemFont(ofSize: fontSize))
        }
        scroll.documentView = editor
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        scroll.automaticallyAdjustsContentInsets = false
        scroll.contentInsets = NSEdgeInsetsZero
        guard let editor = scroll.documentView as? DaybookAppKitTextView else { return }
        let nativeFont = NSFont.systemFont(ofSize: fontSize)
        if !DaybookTextEditing.isProtected(editor), editor.font != nativeFont {
            editor.font = nativeFont
        }
        editor.insertionPointColor = NSColor(DaybookPalette.text.primary)
        editor.setAccessibilityLabel(placeholder)
        editor.commandChord = commandChord
        editor.onCommandReturn = { [weak editor] in
            guard let editor, !editor.hasMarkedText() else { return }
            context.coordinator.parent.text = editor.string
            context.coordinator.parent.autocomplete.dismiss()
            context.coordinator.parent.onSubmit?()
        }
        Self.synchronizeText(text, in: editor, highlightsSyntax: highlightsSyntax, font: nativeFont)
        if !DaybookTextEditing.isProtected(editor) {
            if highlightsSyntax, let storage = editor.textStorage {
                SyntaxHighlighter.applyHighlighting(to: storage, font: nativeFont)
                editor.typingAttributes = [
                    .font: nativeFont,
                    .foregroundColor: NSColor(DaybookPalette.text.primary)
                ]
            }
            if autocomplete.inputText != text || autocomplete.availableTags != availableTags {
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    autocomplete.reset()
                } else if editor.window?.firstResponder === editor {
                    let cursor = min(editor.selectedRange().location, (text as NSString).length)
                    autocomplete.update(text: text, cursorLocation: cursor, availableTags: availableTags)
                } else {
                    autocomplete.inputText = text
                    autocomplete.availableTags = availableTags
                }
            }
        }
        if focused, let window = editor.window, window.firstResponder !== editor {
            DispatchQueue.main.async {
                guard focused else { return }
                window.makeFirstResponder(editor)
            }
        }
    }

    static func synchronizeText(_ text: String, in editor: NSTextView, highlightsSyntax: Bool = false, font: NSFont? = nil) {
        guard !editor.hasMarkedText(), editor.string != text else { return }
        let length = (text as NSString).length
        let delta = length - (editor.string as NSString).length
        let cursor = min(length, max(0, editor.selectedRange().location + delta))
        editor.string = text
        if highlightsSyntax, let font, let storage = editor.textStorage {
            SyntaxHighlighter.applyHighlighting(to: storage, font: font)
            editor.typingAttributes = [
                .font: font,
                .foregroundColor: NSColor(DaybookPalette.text.primary)
            ]
        }
        editor.setSelectedRange(NSRange(location: cursor, length: 0))
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: DaybookTextEditor
        init(_ parent: DaybookTextEditor) { self.parent = parent }

        func handleFocusChange(_ isFocused: Bool, editor: NSTextView) {
            if isFocused {
                parent.autocomplete.editor = editor
                if !parent.focused { parent.focused = true }
            } else {
                parent.autocomplete.dismiss()
                parent.autocomplete.editor = nil
                if parent.focused { parent.focused = false }
            }
        }

        func textDidBeginEditing(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            handleFocusChange(true, editor: editor)
        }

        func textDidEndEditing(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            handleFocusChange(false, editor: editor)
        }

        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            parent.text = editor.string
            applyHighlightIfReady(editor)
            updateCompletion(editor)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            applyHighlightIfReady(editor)
            updateCompletion(editor)
        }

        private func applyHighlightIfReady(_ editor: NSTextView) {
            guard !DaybookTextEditing.isProtected(editor), parent.highlightsSyntax, let storage = editor.textStorage else { return }
            let font = NSFont.systemFont(ofSize: parent.fontSize)
            SyntaxHighlighter.applyHighlighting(to: storage, font: font)
            editor.typingAttributes = [
                .font: font,
                .foregroundColor: NSColor(DaybookPalette.text.primary)
            ]
        }

        private func updateCompletion(_ editor: NSTextView) {
            guard editor.window?.firstResponder === editor else {
                parent.autocomplete.dismissSuggestionsOnly()
                return
            }
            if editor.hasMarkedText() {
                parent.autocomplete.inputText = editor.string
                parent.autocomplete.availableTags = parent.availableTags
                if parent.autocomplete.showsPreview && parent.autocomplete.presentedAt == 0 {
                    parent.autocomplete.presentedAt = ProcessInfo.processInfo.systemUptime
                }
                parent.autocomplete.dismissSuggestionsOnly()
                return
            }
            parent.autocomplete.update(
                text: editor.string, cursorLocation: editor.selectedRange().location, availableTags: parent.availableTags
            )
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard !textView.hasMarkedText() else { return false }
            let completion = parent.autocomplete
            if commandSelector == #selector(NSResponder.cancelOperation(_:)), completion.hasPresentation {
                if completion.showsAttributes {
                    completion.dismiss()
                    return true
                }
                if completion.isActive && !completion.candidates.isEmpty {
                    completion.dismissSuggestionsOnly()
                    return true
                }
                if completion.showsPreview {
                    completion.dismissPreview()
                    return true
                }
                completion.dismiss()
                return true
            }
            if completion.isActive {
                switch commandSelector {
                case #selector(NSResponder.moveUp(_:)): completion.selectPrevious(); return true
                case #selector(NSResponder.moveDown(_:)): completion.selectNext(); return true
                case #selector(NSResponder.insertTab(_:)), #selector(NSResponder.insertNewline(_:)):
                    if NSApp.currentEvent?.modifierFlags.contains(.shift) != true,
                       let candidate = completion.selectedCandidate(), completion.commit(candidate, in: textView) {
                        parent.text = textView.string
                        applyHighlightIfReady(textView)
                        completion.update(
                            text: textView.string,
                            cursorLocation: textView.selectedRange().location,
                            availableTags: parent.availableTags
                        )
                        return true
                    }
                case #selector(NSResponder.cancelOperation(_:)): completion.dismiss(); return true
                default: break
                }
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                textView.window?.makeFirstResponder(nil)
                parent.focused = false
                return true
            }
            return false
        }
    }
}
