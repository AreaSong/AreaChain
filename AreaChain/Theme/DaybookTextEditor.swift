import AppKit
import SwiftUI

final class DaybookAppKitTextView: NSTextView {
    var onCommandReturn: (() -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // 大写锁定等状态不改变快捷键含义，单行和多行输入保持一致。
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        if flags == .command, event.keyCode == 36, window?.firstResponder === self {
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
    var onSubmit: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.scrollerStyle = .overlay
        scroll.hasVerticalScroller = true
        scroll.verticalScroller = DaybookScroller()
        scroll.autohidesScrollers = true
        let editor = DaybookAppKitTextView(frame: NSRect(x: 0, y: 0, width: 240, height: 64))
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
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        if #available(macOS 15.1, *) { editor.writingToolsBehavior = .none }
        editor.delegate = context.coordinator
        editor.setAccessibilityIdentifier("syntax.text.editor")
        scroll.documentView = editor
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let editor = scroll.documentView as? DaybookAppKitTextView else { return }
        editor.font = .systemFont(ofSize: fontSize)
        editor.textColor = NSColor(DaybookPalette.text.primary)
        editor.insertionPointColor = NSColor(DaybookPalette.text.primary)
        editor.setAccessibilityLabel(placeholder)
        editor.onCommandReturn = { [weak editor] in
            guard let editor, !editor.hasMarkedText() else { return }
            context.coordinator.parent.text = editor.string
            context.coordinator.parent.autocomplete.dismiss()
            context.coordinator.parent.onSubmit?()
        }
        Self.synchronizeText(text, in: editor)
        if focused, let window = editor.window, window.firstResponder !== editor {
            DispatchQueue.main.async {
                guard focused else { return }
                window.makeFirstResponder(editor)
            }
        }
    }

    static func synchronizeText(_ text: String, in editor: NSTextView) {
        guard !editor.hasMarkedText(), editor.string != text else { return }
        let length = (text as NSString).length
        let delta = length - (editor.string as NSString).length
        let cursor = min(length, max(0, editor.selectedRange().location + delta))
        editor.string = text
        editor.setSelectedRange(NSRange(location: cursor, length: 0))
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: DaybookTextEditor
        init(_ parent: DaybookTextEditor) { self.parent = parent }

        func textDidBeginEditing(_ notification: Notification) {
            parent.autocomplete.editor = notification.object as? NSTextView
            parent.focused = true
        }

        func textDidEndEditing(_ notification: Notification) {
            parent.autocomplete.dismiss()
            parent.autocomplete.editor = nil
            parent.focused = false
        }

        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            parent.text = editor.string
            updateCompletion(editor)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            updateCompletion(editor)
        }

        private func updateCompletion(_ editor: NSTextView) {
            guard !editor.hasMarkedText(), editor.window?.firstResponder === editor else {
                parent.autocomplete.dismiss()
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
