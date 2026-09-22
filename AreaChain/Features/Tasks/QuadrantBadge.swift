import SwiftUI

/// 待办列表项中的优先级彩色微型标牌。P4 不显示。
struct QuadrantBadge: View {
    var slot: QuadrantSlot
    var isHighlighted: Bool = false

    var body: some View {
        if slot != .rest {
            QuadrantMiniMark(slot: slot, metrics: .row, isHighlighted: isHighlighted)
                .help(helpText)
                .accessibilityLabel(helpText)
        }
    }

    private var helpText: Text {
        Text("\(slot.badgeText) · ") + Text(LocalizedStringKey(slot.titleKeyName)) + Text(" · ") + Text(LocalizedStringKey(slot.subtitleKeyName))
    }
}
