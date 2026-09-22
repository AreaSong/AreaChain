import SwiftUI

extension QuadrantSlot {
    var themeColor: Color {
        switch self {
        case .importantUrgent: DaybookTheme.Syntax.p1
        case .important: DaybookTheme.Syntax.p2
        case .urgent: DaybookTheme.Syntax.p3
        case .rest: DaybookTheme.Syntax.p4
        }
    }

    var themeFill: Color {
        switch self {
        case .importantUrgent: DaybookTheme.Syntax.p1Fill
        case .important: DaybookTheme.Syntax.p2Fill
        case .urgent: DaybookTheme.Syntax.p3Fill
        case .rest: DaybookTheme.Syntax.p4Fill
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
                .font(.system(size: 8.5, weight: .bold))
            Text(slot.badgeText)
                .font(.system(size: metrics == .row ? 10 : 9.5, weight: .bold, design: .rounded))
        }
        .fixedSize()
        .foregroundStyle(slot.themeColor)
        .padding(.horizontal, metrics == .row ? 5 : 4.5)
        .padding(.vertical, metrics == .row ? 0 : 1.5)
        .frame(height: metrics == .row ? 18 : nil)
        .background(
            RoundedRectangle(cornerRadius: metrics == .row ? 4 : 3.5, style: .continuous)
                .fill(slot.themeFill)
        )
        .overlay {
            if metrics == .row {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(slot.themeColor.opacity(isHighlighted ? 0.35 : 0.15), lineWidth: 0.6)
            }
        }
    }
}
