import AppKit
import SwiftUI

class DaybookAppKitTextView: NSTextView {
    var onCommandReturn: (() -> Void)?
    var commandChord: ShortcutChord?
    var onFocusChange: ((Bool) -> Void)?
    var onMarkedTextChange: ((Bool) -> Void)?
    private var lastMarkedState = false

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
            if lastMarkedState {
                lastMarkedState = false
                onMarkedTextChange?(false)
            }
            onFocusChange?(false)
        }
        return resigned
    }

    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
        syncMarkedState()
    }

    override func unmarkText() {
        super.unmarkText()
        syncMarkedState()
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        super.insertText(string, replacementRange: replacementRange)
        syncMarkedState()
    }

    private func syncMarkedState() {
        let marked = hasMarkedText()
        guard marked != lastMarkedState else { return }
        lastMarkedState = marked
        onMarkedTextChange?(marked)
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

    override func hitTest(_ point: NSPoint) -> NSView? {
        if let superview, let root = window?.contentView,
           Self.isPointInSyntaxOverlay(superview.convert(point, to: nil), in: root) {
            return nil
        }
        return super.hitTest(point)
    }

    private static func isPointInSyntaxOverlay(_ windowPoint: NSPoint, in view: NSView) -> Bool {
        if let id = view.identifier?.rawValue,
           id == "syntax.overlay.candidates" || id == "syntax.overlay.preview" || id == "syntax.overlay.attributes",
           !view.isHidden, view.alphaValue > 0.01,
           view.convert(view.bounds, to: nil).contains(windowPoint) {
            return true
        }
        return view.subviews.contains { isPointInSyntaxOverlay(windowPoint, in: $0) }
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
    var onMarkedTextChange: ((Bool) -> Void)? = nil

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
        editor.minSize = NSSize(width: 0, height: 28)
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
        editor.textContainerInset = NSSize(width: 4, height: 4)
        editor.font = .systemFont(ofSize: fontSize)
        editor.textColor = NSColor(DaybookPalette.text.primary)
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        if #available(macOS 15.1, *) { editor.writingToolsBehavior = .none }
        editor.delegate = context.coordinator
        editor.onMarkedTextChange = onMarkedTextChange
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
        editor.onMarkedTextChange = onMarkedTextChange
        editor.onCommandReturn = { [weak editor] in
            guard let editor, !editor.hasMarkedText() else { return }
            context.coordinator.parent.text = editor.string
            context.coordinator.parent.autocomplete.dismiss()
            context.coordinator.parent.onSubmit?()
        }
        Self.synchronizeText(text, in: editor, highlightsSyntax: highlightsSyntax, font: nativeFont)
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
        }
        editor.setSelectedRange(NSRange(location: cursor, length: 0))
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: DaybookTextEditor
        private var lastSelection = NSRange(location: 0, length: 0)
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
            guard !DaybookTextEditing.isProtected(editor), parent.highlightsSyntax, let storage = editor.textStorage else { return }
            SyntaxHighlighter.applyHighlighting(to: storage, font: NSFont.systemFont(ofSize: parent.fontSize))
        }

        private func updateCompletion(_ editor: NSTextView) {
            guard !DaybookTextEditing.isProtected(editor), editor.window?.firstResponder === editor else {
                parent.autocomplete.dismissSuggestionsOnly()
                return
            }
            parent.autocomplete.editor = editor
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
                        lastSelection = textView.selectedRange()
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
