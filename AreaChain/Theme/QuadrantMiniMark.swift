import SwiftUI

extension QuadrantSlot {
    var themeColor: Color {
        switch self {
        case .importantUrgent: DaybookPalette.Syntax.p1
        case .important: DaybookPalette.Syntax.p2
        case .urgent: DaybookPalette.Syntax.p3
        case .rest: DaybookPalette.Syntax.p4
        }
    }

    var themeFill: Color {
        switch self {
        case .importantUrgent: DaybookPalette.Syntax.p1Fill
        case .important: DaybookPalette.Syntax.p2Fill
        case .urgent: DaybookPalette.Syntax.p3Fill
        case .rest: DaybookPalette.Syntax.p4Fill
        }
    }
}

/// 四象限彩色小标。行内徽章用 `.row`，象限页和详情格子用 `.compact`。
struct QuadrantMiniMark: View {
    enum Metrics {
        case row
        case compact
    }

    var slot: QuadrantSlot
    var metrics: Metrics = .compact
    var isHighlighted = false

    var body: some View {
        HStack(spacing: metrics == .row ? 2.5 : 2) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 8.5, weight: .bold)) // token-exempt: 小于 9pt，kbd 是等宽
            Text(slot.badgeText)
                .font(.system(size: metrics == .row ? 10 : 9.5, weight: .bold, design: .rounded)) // token-exempt: 象限徽章用圆体
        }
        .fixedSize()
        .foregroundStyle(slot.themeColor)
        .padding(.horizontal, metrics == .row ? 5 : 4.5)
        .padding(.vertical, metrics == .row ? 0 : 1.5)
        .frame(height: metrics == .row ? 18 : nil)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                .fill(slot.themeFill)
        )
        .overlay {
            if metrics == .row {
                RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                    .stroke(slot.themeColor.opacity(isHighlighted ? 0.35 : 0.15), lineWidth: 0.6) // token-exempt: 象限色 35% 与 15% 不是印章色
            }
        }
    }
}
