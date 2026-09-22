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
                .foregroundStyle(DaybookTheme.muted)

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
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DaybookTheme.ink)
                    Spacer()
                    if isActive {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(slot.themeColor)
                    }
                }
                Text(LocalizedStringKey(slot.subtitleKeyName))
                    .font(.system(size: 9))
                    .foregroundStyle(DaybookTheme.muted)
            }
            .padding(7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isActive ? slot.themeFill : DaybookTheme.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(isActive ? slot.themeColor.opacity(0.7) : DaybookTheme.rule.opacity(0.25), lineWidth: isActive ? 1.2 : 0.6)
                    )
            )
        }
        .buttonStyle(.plain) // control: 象限选择格，P4 迁 daybookSurface(.cell)
    }
}
