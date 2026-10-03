import AppKit
import SwiftUI

/// 仅渲染片段内已发布的高亮；范围必须落在完整字素边界，不重新匹配正文。
enum DaybookSearchResultText {
    static func attributed(_ value: ContentQueryDisplayText) -> AttributedString {
        var result = AttributedString(value.text)
        for range in legalRanges(value) {
            guard let stringRange = Range(range, in: value.text),
                  let lower = AttributedString.Index(stringRange.lowerBound, within: result),
                  let upper = AttributedString.Index(stringRange.upperBound, within: result) else { continue }
            result[lower..<upper].font = DaybookType.body.weight(.semibold)
            result[lower..<upper].backgroundColor = DaybookPalette.accent.fill
        }
        return result
    }

    static func native(_ value: ContentQueryDisplayText, secondary: Bool) -> NSAttributedString {
        let result = NSMutableAttributedString(string: value.text, attributes: [
            .font: NSFont.systemFont(ofSize: DaybookType.bodySize),
            .foregroundColor: NSColor(secondary ? DaybookPalette.text.secondary : DaybookPalette.text.primary)])
        for range in legalRanges(value) {
            result.addAttributes([.font: NSFont.systemFont(ofSize: DaybookType.bodySize, weight: .semibold),
                                  .backgroundColor: NSColor(DaybookPalette.accent.fill)], range: range)
        }
        return result
    }

    private static func legalRanges(_ value: ContentQueryDisplayText) -> [NSRange] {
        let length = value.text.utf16.count
        let boundaries = Set(value.text.indices.map { $0.utf16Offset(in: value.text) } + [length])
        return value.highlights.map(\.range).filter { range in
            range.location >= 0 && range.location != NSNotFound && range.length > 0
                && range.location <= length && range.length <= length - range.location
                && boundaries.contains(range.location) && boundaries.contains(NSMaxRange(range))
        }
    }
}

/// 用原生多行标签落实最多两行；不把字符预算当成行数，也不参与输入或正文匹配。
struct DaybookSearchFragment: NSViewRepresentable {
    let value: ContentQueryDisplayText
    var secondary = false
    let identifier: String
    @Environment(\.colorScheme) private var scheme

    func makeNSView(context: Context) -> SearchFragmentLabel {
        let label = SearchFragmentLabel(wrappingLabelWithString: "")
        label.maximumNumberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateNSView(_ label: SearchFragmentLabel, context: Context) {
        _ = scheme
        label.attributedStringValue = DaybookSearchResultText.native(value, secondary: secondary)
        label.setAccessibilityIdentifier(identifier)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: SearchFragmentLabel, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        nsView.preferredMaxLayoutWidth = width
        let size = nsView.cell?.cellSize(forBounds: .init(x: 0, y: 0, width: width, height: 1_000)) ?? .zero
        let lineHeight = NSLayoutManager().defaultLineHeight(for: .systemFont(ofSize: DaybookType.bodySize))
        return CGSize(width: width, height: min(size.height, lineHeight * 2))
    }
}

final class SearchFragmentLabel: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

extension View {
    func daybookSearchResultSurface(isSelected: Bool) -> some View {
        daybookSurface(.row, isSelected: isSelected, configure: { $0.radius = DaybookRadius.regular })
    }
}
