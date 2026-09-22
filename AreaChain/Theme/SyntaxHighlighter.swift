import AppKit
import SwiftUI

/// 负责捕获输入框的语法 Token 实时着色
@MainActor
enum SyntaxHighlighter {
    static func color(for token: SyntaxTokenKind) -> NSColor {
        switch token {
        case .time:
            return DaybookPalette.Syntax.timeNS
        case .tag:
            return DaybookPalette.Syntax.tagNS
        case .priority(let isImportant, let isUrgent, _):
            return DaybookPalette.Syntax.priorityColorNS(isImportant: isImportant, isUrgent: isUrgent)
        case .note:
            return NSColor(DaybookTheme.muted)
        }
    }

    /// 生成完整的带语法高亮的属性字符串
    static func attributedString(
        for text: String,
        font: NSFont,
        defaultColor: NSColor = NSColor(DaybookTheme.ink)
    ) -> NSAttributedString {
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [.font: font, .foregroundColor: defaultColor]
        )
        let tokens = NaturalLanguageParser.extractHighlightTokens(in: text)
        let nsString = text as NSString
        for token in tokens {
            guard token.range.location != NSNotFound,
                  NSMaxRange(token.range) <= nsString.length else { continue }
            let tokenColor = color(for: token.kind)
            attributed.addAttributes([
                .foregroundColor: tokenColor,
                .font: NSFont.systemFont(ofSize: font.pointSize, weight: .medium)
            ], range: token.range)
        }
        return attributed
    }

    /// 在 NSTextStorage 上增量应用语法高亮，严格保持光标与编辑状态稳定
    static func applyHighlighting(
        to textStorage: NSTextStorage,
        font: NSFont,
        defaultColor: NSColor = NSColor(DaybookTheme.ink)
    ) {
        let text = textStorage.string
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        guard fullRange.length > 0 else { return }

        let tokens = NaturalLanguageParser.extractHighlightTokens(in: text)
        textStorage.beginEditing()
        textStorage.setAttributes([.font: font, .foregroundColor: defaultColor], range: fullRange)
        for token in tokens {
            guard token.range.location != NSNotFound,
                  NSMaxRange(token.range) <= fullRange.length else { continue }
            let tokenColor = color(for: token.kind)
            textStorage.addAttributes([
                .foregroundColor: tokenColor,
                .font: NSFont.systemFont(ofSize: font.pointSize, weight: .medium)
            ], range: token.range)
        }
        textStorage.endEditing()
    }
}
