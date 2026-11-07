import AppKit
import SwiftUI

/// 搜索字段专用 editor 保留 AppKit 输入法、选区、横向滚动与撤销，隔离其他控件历史。
final class UnifiedSearchFieldCell: NSTextFieldCell {
    let searchEditor = UnifiedSearchFieldEditor()

    override func fieldEditor(for controlView: NSView) -> NSTextView? {
        searchEditor.isFieldEditor = true
        return searchEditor
    }
}

final class UnifiedSearchFieldEditor: NSTextView {
    var onBegin: ((NSTextView) -> Void)?
    var onObjectSpace: (() -> Bool)?
    private let searchUndo = UndoManager()

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.window?.firstResponder === self else { return }
                self.onBegin?(self)
            }
        }
        return accepted
    }
    override var undoManager: UndoManager? { searchUndo }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49, !hasMarkedText(),
           event.modifierFlags.isDisjoint(with: [.command, .control, .option, .shift]),
           onObjectSpace?() == true { return }
        super.keyDown(with: event)
    }
}

/// 仅统一搜索启用；复用捕获语法颜色并对 `/` 命令前缀着色。
@MainActor
final class UnifiedSearchHighlight {
    private var lastText: String?
    private var lastAppearance: NSAppearance.Name?

    func clear() {
        lastText = nil
        lastAppearance = nil
    }

    func apply(to editor: NSTextView, text: String) {
        guard !editor.hasMarkedText(), let storage = editor.textStorage else { return }
        let appearance = editor.effectiveAppearance.name
        guard text != lastText || appearance != lastAppearance else { return }
        let font = NSFont.systemFont(ofSize: DaybookType.bodySize)
        let attributed = NSMutableAttributedString(attributedString: SyntaxHighlighter.attributedString(for: editor.string, font: font))
        let full = NSRange(location: 0, length: attributed.length)
        if text.hasPrefix("/") {
            let isScope = UnifiedSearchInputState.isContentScopePrefix(text)
            let headColor = isScope ? DaybookPalette.Syntax.tagNS : DaybookPalette.Syntax.timeNS
            let nsText = editor.string as NSString
            let firstSpace = nsText.rangeOfCharacter(from: .whitespacesAndNewlines)
            let headRange = firstSpace.location == NSNotFound
                ? full
                : NSRange(location: 0, length: firstSpace.location)
            attributed.addAttribute(.foregroundColor, value: headColor, range: headRange)
            if !isScope, firstSpace.location != NSNotFound, NSMaxRange(firstSpace) < full.length {
                let tailRange = NSRange(location: NSMaxRange(firstSpace), length: full.length - NSMaxRange(firstSpace))
                attributed.addAttribute(.foregroundColor, value: DaybookPalette.Syntax.tagNS, range: tailRange)
            }
        }
        let selection = editor.selectedRanges
        storage.beginEditing()
        attributed.enumerateAttributes(in: full) { attributes, range, _ in
            storage.setAttributes(attributes, range: range)
        }
        storage.endEditing()
        editor.selectedRanges = selection
        lastText = text
        lastAppearance = appearance
    }
}
