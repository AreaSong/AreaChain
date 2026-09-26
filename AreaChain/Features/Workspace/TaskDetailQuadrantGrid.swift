import SwiftUI

struct TaskDetailQuadrantGrid: View {
    var isImportant: Bool
    var isUrgent: Bool
    var onSelect: (Bool, Bool) -> Void

    private var currentSlot: QuadrantSlot {
        QuadrantSlot.of(important: isImportant, urgent: isUrgent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("drawer.quadrant.title")
                .font(DaybookType.label)
                .foregroundStyle(DaybookPalette.text.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(QuadrantSlot.allCases) { slot in
                    card(slot, isActive: slot == currentSlot) {
                        onSelect(slot.isImportant, slot.isUrgent)
                    }
                }
            }
        }
    }

    private func card(
        _ slot: QuadrantSlot,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    QuadrantMiniMark(slot: slot)

                    Text(LocalizedStringKey(slot.titleKeyName))
                        .font(DaybookType.caption.weight(.semibold))
                        .foregroundStyle(DaybookPalette.text.primary)
                    Spacer()
                    if isActive {
                        Image(systemName: "checkmark")
                            .font(DaybookType.micro.weight(.heavy))
                            .foregroundStyle(slot.themeColor)
                    }
                }
                Text(LocalizedStringKey(slot.subtitleKeyName))
                    .font(DaybookType.micro)
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
            .padding(7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .fill(isActive ? slot.themeFill : DaybookPalette.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                            .stroke(
                                isActive
                                    ? slot.themeColor.opacity(0.7) // token-exempt: 象限色 70% 没有对应令牌
                                    : DaybookPalette.border.default.opacity(0.25), // token-exempt: 分隔线 25% 没有对应令牌
                                lineWidth: isActive ? 1.2 : 0.6
                            ) // token-exempt: 象限色 70% 和分隔线 25% 没有对应令牌
                    )
            )
        }
        .buttonStyle(.plain) // control: 象限选择格保留象限色，不进通用表面
    }
}
