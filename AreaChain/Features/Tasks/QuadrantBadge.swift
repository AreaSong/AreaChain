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

/// 待办列表项中的优先级彩色微型标牌（! P1 / ! P2 / ! P3）
struct QuadrantBadge: View {
    var slot: QuadrantSlot
    var isHighlighted: Bool = false

    var body: some View {
        if slot != .rest {
            HStack(spacing: 2.5) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 8.5, weight: .bold))
                Text(slot.badgeText)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .fixedSize()
            .foregroundStyle(slot.themeColor)
            .padding(.horizontal, 5)
            .frame(height: 18)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(slot.themeFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(slot.themeColor.opacity(isHighlighted ? 0.35 : 0.15), lineWidth: 0.6)
            )
            .help(helpText)
            .accessibilityLabel(helpText)
        }
    }

    private var helpText: Text {
        Text("\(slot.badgeText) · ") + Text(LocalizedStringKey(slot.titleKeyName)) + Text(" · ") + Text(LocalizedStringKey(slot.subtitleKeyName))
    }
}
