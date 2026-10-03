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

/// 仅统一搜索启用；复用捕获语法颜色，但不让普通任务路径变成指令。
@MainActor
final class UnifiedSearchHighlight {
    private var lastResult: CommandPathResult?
    private var lastAppearance: NSAppearance.Name?

    func clear() {
        lastResult = nil
        lastAppearance = nil
    }

    func apply(to editor: NSTextView, result: CommandPathResult) {
        guard !editor.hasMarkedText(), let storage = editor.textStorage else { return }
        let appearance = editor.effectiveAppearance.name
        guard result != lastResult || appearance != lastAppearance else { return }
        let font = NSFont.systemFont(ofSize: DaybookType.bodySize)
        let attributed = NSMutableAttributedString(attributedString: SyntaxHighlighter.attributedString(for: editor.string, font: font))
        let full = NSRange(location: 0, length: attributed.length)
        if result.state != .ordinaryText {
            let color = result.state == .scope ? DaybookPalette.Syntax.tagNS : DaybookPalette.Syntax.timeNS
            attributed.addAttribute(.foregroundColor, value: color, range: full)
            if !result.arguments.isEmpty {
                let slash = (editor.string as NSString).range(of: "/", options: .backwards)
                if slash.location != NSNotFound {
                    attributed.addAttribute(.foregroundColor, value: DaybookPalette.Syntax.tagNS,
                                            range: NSRange(location: NSMaxRange(slash), length: full.length - NSMaxRange(slash)))
                }
            }
            for diagnostic in result.diagnostics where CommandPathText.valid(diagnostic.range, in: editor.string) {
                let color = result.state == .invalid
                    ? DaybookPalette.Syntax.priorityColorNS(isImportant: true, isUrgent: true)
                    : NSColor(DaybookPalette.text.secondary)
                attributed.addAttribute(.foregroundColor, value: color, range: diagnostic.range)
                attributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: diagnostic.range)
            }
        }
        let selection = editor.selectedRanges
        storage.beginEditing()
        attributed.enumerateAttributes(in: full) { attributes, range, _ in
            storage.setAttributes(attributes, range: range)
        }
        storage.endEditing()
        editor.selectedRanges = selection
        lastResult = result
        lastAppearance = appearance
    }
}
