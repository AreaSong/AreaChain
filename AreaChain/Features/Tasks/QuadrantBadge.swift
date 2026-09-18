import SwiftUI

extension QuadrantSlot {
    var themeColor: Color {
        switch self {
        case .importantUrgent: .red
        case .important: .blue
        case .urgent: .orange
        case .rest: DaybookTheme.muted
        }
    }
}

/// 待办列表项中的优先级彩色微型胶囊
struct QuadrantBadge: View {
    var slot: QuadrantSlot
    var isHighlighted: Bool = false

    var body: some View {
        if slot != .rest {
            HStack(spacing: 2) {
                Image(systemName: slot.iconName)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(slot.themeColor)
            }
            .fixedSize()
            .padding(.horizontal, 4.5)
            .frame(height: 18)
            .background(
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(slot.themeColor.opacity(isHighlighted ? 0.18 : 0.10))
            )
            .help(helpText)
            .accessibilityLabel(helpText)
        }
    }

    private var helpText: Text {
        Text(LocalizedStringKey(slot.titleKeyName)) + Text(" · ") + Text(LocalizedStringKey(slot.subtitleKeyName))
    }
}
