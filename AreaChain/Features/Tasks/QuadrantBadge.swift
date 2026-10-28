import SwiftUI

/// 待办列表项中的优先级彩色微型标牌。P4 不显示；行内仅保留彩色 P1~P3 文本以节省横向宽度。
struct QuadrantBadge: View {
    var slot: QuadrantSlot
    var isHighlighted: Bool = false

    var body: some View {
        if slot != .rest {
            Text(slot.badgeText)
                .font(.system(size: 10, weight: .bold, design: .rounded)) // token-exempt: 象限徽章用圆体
                .fixedSize()
                .foregroundStyle(slot.themeColor)
                .padding(.horizontal, 4.5)
                .frame(height: 18)
                .background(
                    RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                        .fill(slot.themeFill)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                        .stroke(slot.themeColor.opacity(isHighlighted ? 0.35 : 0.15), lineWidth: 0.6) // token-exempt: 象限色 35% 与 15% 不是印章色
                }
                .help(helpText)
                .accessibilityLabel(helpText)
        }
    }

    private var helpText: Text {
        Text("\(slot.badgeText) · ") + Text(LocalizedStringKey(slot.titleKeyName)) + Text(" · ") + Text(LocalizedStringKey(slot.subtitleKeyName))
    }
}
