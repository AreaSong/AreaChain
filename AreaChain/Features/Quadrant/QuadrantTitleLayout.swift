import AppKit
import SwiftUI

/// 四象限格子随窗口变宽，按真实排版宽度判断标题是否被截断。
enum QuadrantTitleOverflow {
    /// 气泡只排开头约六行，避免超长标题整段进入排版。
    static let previewLineLimit = 6
    static let previewProbeLimit = 360
    static let overflowProbeLimit = 80

    struct Preview: Equatable {
        var excerpt: String
        var isPartial: Bool
    }

    static func isOverflowing(idealWidth: CGFloat, visibleWidth: CGFloat) -> Bool {
        visibleWidth > 1 && idealWidth > visibleWidth + 1
    }

    /// 只查看标题开头。超出六行或探测长度时，其余留给检查器。
    static func preview(_ title: String, width: CGFloat = 224) -> Preview {
        let probe = String(title.prefix(previewProbeLimit))
        let hasMore = title.dropFirst(probe.count).first != nil
        let excerpt = prefixFitting(probe, width: width, lines: previewLineLimit)
        let isPartial = hasMore || excerpt.count < probe.count
        return Preview(excerpt: excerpt, isPartial: isPartial)
    }

    static func overflowsProbe(_ title: String, visibleWidth: CGFloat) -> Bool {
        let probe = String(title.prefix(overflowProbeLimit))
        let hasMore = title.dropFirst(probe.count).first != nil
        let font = NSFont.systemFont(ofSize: DaybookType.subtitleSize)
        let ideal = (probe as NSString).size(withAttributes: [.font: font]).width
        return hasMore || isOverflowing(idealWidth: ideal, visibleWidth: visibleWidth)
    }

    private static func prefixFitting(_ text: String, width: CGFloat, lines: Int) -> String {
        let font = NSFont.systemFont(ofSize: DaybookType.captionSize, weight: .medium)
        let limit = font.boundingRectForFont.height * CGFloat(lines) + 1
        if textHeight(text, width: width, font: font) <= limit { return text }
        var low = 1
        var high = text.count
        var best = String(text.prefix(1))
        while low <= high {
            let mid = (low + high) / 2
            let candidate = String(text.prefix(mid))
            if textHeight(candidate, width: width, font: font) <= limit {
                best = candidate
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return best
    }

    private static func textHeight(_ text: String, width: CGFloat, font: NSFont) -> CGFloat {
        let rect = (text as NSString).boundingRect(
            with: NSSize(width: max(1, width), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        return ceil(rect.height)
    }
}

struct QuadrantTitlePreview: View {
    var excerpt: String
    var showsHint: Bool
    var onCopy: () -> Void
    var onHover: (Bool) -> Void

    @State private var isCopied = false
    @Environment(\.locale) private var locale

    var body: some View {
        previewBody
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: 260, alignment: .leading)
            .background(previewBackground)
            .overlay(previewBorder)
            .contentShape(RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous))
            .onHover(perform: onHover)
            .onTapGesture(perform: copyExcerpt)
            .task(id: isCopied) { await resetCopiedFlag() }
    }

    private var previewBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(isCopied ? L10n.string("diary.copied", locale: locale) : excerpt)
                .font(DaybookType.caption.weight(.medium))
                .foregroundStyle(isCopied ? DaybookPalette.accent.base : DaybookPalette.text.primary)
                .lineLimit(QuadrantTitleOverflow.previewLineLimit)
                .fixedSize(horizontal: false, vertical: true)
            if showsHint && !isCopied {
                Text("quadrant.preview.more")
                    .font(DaybookType.micro)
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
        }
    }

    private var previewBackground: some View {
        RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
            .fill(DaybookPalette.fill.page)
            .daybookElevation(.floating)
    }

    private var previewBorder: some View {
        RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
            .stroke(DaybookPalette.border.default.opacity(0.9), lineWidth: 0.8) // token-exempt: 90% 分隔线没有对应令牌
    }

    private func copyExcerpt() {
        onCopy()
        isCopied = true
    }

    private func resetCopiedFlag() async {
        guard isCopied else { return }
        try? await Task.sleep(for: .milliseconds(1200))
        isCopied = false
    }
}
