import AppKit

/// 只改变控制字形的排版动作；字符存储、UTF-16 索引和原生撤销保持原样。
@MainActor
final class DaybookSingleLineLayout: NSObject, @preconcurrency NSLayoutManagerDelegate {
    func layoutManager(_ layoutManager: NSLayoutManager, shouldUse action: NSLayoutManager.ControlCharacterAction,
                       forControlCharacterAt charIndex: Int) -> NSLayoutManager.ControlCharacterAction {
        guard let text = layoutManager.textStorage?.string as NSString?,
              let scalar = Unicode.Scalar(text.character(at: charIndex)),
              CharacterSet.newlines.contains(scalar) else { return action }
        return .whitespace
    }

    func layoutManager(_ layoutManager: NSLayoutManager, boundingBoxForControlGlyphAt glyphIndex: Int,
                       for textContainer: NSTextContainer, proposedLineFragment proposedRect: NSRect,
                       glyphPosition: NSPoint, characterIndex charIndex: Int) -> NSRect {
        let font = layoutManager.textStorage?.attribute(.font, at: charIndex, effectiveRange: nil) as? NSFont
            ?? NSFont.systemFont(ofSize: DaybookType.bodySize)
        return NSRect(x: 0, y: 0, width: (" " as NSString).size(withAttributes: [.font: font]).width, height: proposedRect.height)
    }

    /// 非编辑态使用同一排版规则绘制原文；此 storage 只供绘制，没有可编辑的镜像查询。
    static func draw(_ text: NSAttributedString, in rect: NSRect) {
        let storage = NSTextStorage(attributedString: text)
        let layout = NSLayoutManager()
        let presentation = DaybookSingleLineLayout()
        layout.delegate = presentation
        let container = NSTextContainer(size: NSSize(width: .greatestFiniteMagnitude, height: rect.height))
        container.lineFragmentPadding = 0
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        layout.ensureLayout(for: container)
        NSGraphicsContext.saveGraphicsState()
        rect.clip()
        let range = layout.glyphRange(for: container)
        // 背景归 DaybookInputShell；不绘制 cell 字符属性中携带的系统文本背景。
        layout.drawGlyphs(forGlyphRange: range, at: rect.origin)
        NSGraphicsContext.restoreGraphicsState()
    }
}
