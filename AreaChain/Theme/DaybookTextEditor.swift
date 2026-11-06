import AppKit
import SwiftUI

class DaybookAppKitTextView: NSTextView {
    var onCommandReturn: (() -> Void)?
    var commandChord: ShortcutChord?
    var onFocusChange: ((Bool) -> Void)?
    var onMarkedTextChange: ((Bool) -> Void)?
    var onPasteImage: ((NSPasteboard) -> Bool)?
    var pasteboard: NSPasteboard = .general
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
        if onPasteImage != nil, flags == .command,
           event.keyCode == 9 || event.charactersIgnoringModifiers?.lowercased() == "v",
           window?.firstResponder === self {
            if !hasMarkedText() { paste(nil) }
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func paste(_ sender: Any?) {
        let board = pasteboard
        if !hasMarkedText(), let onPasteImage,
           ClipboardPayload.make(
               text: board.string(forType: .string),
               hasImage: ImageBytes.pasteboardImage(board) != nil,
               imageTitle: ""
           )?.attachImage == true,
           onPasteImage(board) {
            return
        }
        if board !== NSPasteboard.general {
            _ = readSelection(from: board, type: .string)
            return
        }
        super.paste(sender)
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

/// 多行原生编辑器与单行输入共用语法引擎，直接委托 `BaseMultiLineTextEditor` 承载输入法组词与系统撤销。
struct DaybookTextEditor: View {
    typealias Coordinator = BaseMultiLineTextEditor.Coordinator

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
    var onPasteImage: ((NSPasteboard) -> Bool)? = nil

    private var baseEditor: BaseMultiLineTextEditor {
        BaseMultiLineTextEditor(
            text: $text,
            focus: $focused,
            placeholder: placeholder,
            syntaxPlugin: highlightsSyntax ? .taskSyntax : .none,
            fontSize: fontSize,
            commandChord: commandChord,
            autocomplete: autocomplete,
            availableTags: availableTags,
            onSubmit: onSubmit,
            onMarkedTextChange: onMarkedTextChange,
            onPasteImage: onPasteImage
        )
    }

    var body: some View {
        baseEditor
    }

    func makeCoordinator() -> Coordinator {
        baseEditor.makeCoordinator()
    }

    static func synchronizeText(
        _ text: String,
        in editor: NSTextView,
        highlightsSyntax: Bool = false,
        font: NSFont? = nil
    ) {
        BaseMultiLineTextEditor.synchronizeText(
            text,
            in: editor,
            syntaxPlugin: highlightsSyntax ? .taskSyntax : .none,
            font: font
        )
    }
}
