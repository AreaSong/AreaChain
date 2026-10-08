import AppKit

/// 每个普通字段固定持有同一个原生 editor；撤销仍使用 AppKit 的原 UndoManager。
final class DaybookTextFieldCell: NSTextFieldCell {
    private let inputEditor = DaybookFieldEditor()
    var preservesNewlines = false

    override func fieldEditor(for controlView: NSView) -> NSTextView? {
        inputEditor.isFieldEditor = true
        inputEditor.usesSingleLineInput = usesSingleLineMode
        inputEditor.preservesNewlines = preservesNewlines
        return inputEditor
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        guard preservesNewlines, !stringValue.isEmpty else {
            super.drawInterior(withFrame: cellFrame, in: controlView)
            return
        }
        // 活跃字段由原生 editor 绘制；再画 cell 原文会与横向滚动后的编辑文本叠印。
        guard (controlView as? NSTextField)?.currentEditor() == nil else { return }
        DaybookSingleLineLayout.draw(attributedStringValue, in: drawingRect(forBounds: cellFrame))
    }

    override func cellSize(forBounds rect: NSRect) -> NSSize {
        guard preservesNewlines else { return super.cellSize(forBounds: rect) }
        return NSSize(width: rect.width, height: (font ?? .systemFont(ofSize: DaybookType.bodySize)).boundingRectForFont.height)
    }
}

final class DaybookFieldEditor: NSTextView {
    var usesSingleLineInput = false
    private let singleLineLayout = DaybookSingleLineLayout()
    var preservesNewlines = false {
        didSet { layoutManager?.delegate = preservesNewlines ? singleLineLayout : nil }
    }

    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        guard usesSingleLineInput, !DaybookTextEditing.isProtected(self) else {
            super.insertText(insertString, replacementRange: replacementRange)
            return
        }
        let input: Any
        if let text = insertString as? String {
            input = singleLine(text)
        } else if let text = insertString as? NSAttributedString {
            input = singleLine(text)
        } else { input = insertString }
        // 只转换尚未提交的 payload；原生一次替换登记的长度就是最终长度。
        super.insertText(input, replacementRange: replacementRange)
    }

    override func readSelection(from pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        guard type == .string, usesSingleLineInput || preservesNewlines, !DaybookTextEditing.isProtected(self),
              isEditable, let text = pboard.string(forType: type) else {
            return super.readSelection(from: pboard, type: type)
        }
        // AppKit 的单行导入会另登记整段归一化，重做因而把光标放到全文末尾。
        // 普通单行用途提前转换，保真用途直送原文；都只登记一次原生插入事务。
        insertText(text, replacementRange: selectedRange())
        return true
    }

    private func singleLine(_ text: String) -> String {
        DaybookNewlinePolicy.searchWhitespace.submittedText(text, allowsShiftNewline: false)
    }

    private func singleLine(_ text: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: text)
        var location = 0
        for scalar in text.string.unicodeScalars {
            if CharacterSet.newlines.contains(scalar) {
                result.replaceCharacters(in: NSRange(location: location, length: 1), with: " ")
            }
            location += scalar.utf16.count
        }
        return result
    }
}
