import AppKit
import ObjectiveC
import SwiftUI

private var syntaxHighlightSignatureKey: UInt8 = 0

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
            return NSColor(DaybookPalette.text.secondary)
        }
    }

    /// 生成完整的带语法高亮的属性字符串
    static func attributedString(
        for text: String,
        font: NSFont,
        defaultColor: NSColor = NSColor(DaybookPalette.text.primary)
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

    /// 在 NSTextStorage 上增量应用语法高亮，严格保持光标与编辑状态稳定。
    /// 文本、字体、默认色和外观未变时不整段 setAttributes，避免输入通知重复触发时重建。
    static func applyHighlighting(
        to textStorage: NSTextStorage,
        font: NSFont,
        defaultColor: NSColor = NSColor(DaybookPalette.text.primary)
    ) {
        let text = textStorage.string
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        guard fullRange.length > 0 else {
            HighlightSignature.clear(from: textStorage)
            return
        }

        let signature = HighlightSignature(text: text, font: font, defaultColor: defaultColor, storage: textStorage)
        if HighlightSignature.current(on: textStorage)?.matches(signature) == true {
            return
        }

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
        signature.store(on: textStorage)
    }
}

/// 绑在具体 textStorage 上。文本或外观变了就失效，不是跨输入框的结果缓存。
private final class HighlightSignature: NSObject {
    let text: String
    let fontName: String
    let pointSize: CGFloat
    let appearanceName: String
    let colorKey: String

    init(text: String, font: NSFont, defaultColor: NSColor, storage: NSTextStorage) {
        self.text = text
        self.fontName = font.fontName
        self.pointSize = font.pointSize
        self.appearanceName = Self.appearanceName(for: storage)
        self.colorKey = Self.resolvedColorKey(defaultColor)
    }

    /// 跟所属文本视图/窗口，避免菜单栏与工作台外观不一致时仍按 `NSApp` 跳过重建。
    private static func appearanceName(for storage: NSTextStorage) -> String {
        if let view = storage.layoutManagers.first?.firstTextView {
            return (view.window?.effectiveAppearance ?? view.effectiveAppearance).name.rawValue
        }
        return NSApp.effectiveAppearance.name.rawValue
    }

    func matches(_ other: HighlightSignature) -> Bool {
        text == other.text
            && fontName == other.fontName
            && pointSize == other.pointSize
            && appearanceName == other.appearanceName
            && colorKey == other.colorKey
    }

    func store(on storage: NSTextStorage) {
        objc_setAssociatedObject(storage, &syntaxHighlightSignatureKey, self, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    static func current(on storage: NSTextStorage) -> HighlightSignature? {
        objc_getAssociatedObject(storage, &syntaxHighlightSignatureKey) as? HighlightSignature
    }

    static func clear(from storage: NSTextStorage) {
        objc_setAssociatedObject(storage, &syntaxHighlightSignatureKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private static func resolvedColorKey(_ color: NSColor) -> String {
        guard let rgb = color.usingColorSpace(.deviceRGB) else { return String(describing: color) }
        return "\(rgb.redComponent) \(rgb.greenComponent) \(rgb.blueComponent) \(rgb.alphaComponent)"
    }
}
