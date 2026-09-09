import SwiftUI

struct TaskDetailQuadrantGrid: View {
    var isImportant: Bool
    var isUrgent: Bool
    var onSelect: (Bool, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("drawer.quadrant.title")
                .font(DaybookType.label)
                .foregroundStyle(DaybookTheme.muted)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                card(
                    title: "quadrant.iu",
                    subtitle: "quadrant.iu.hint",
                    icon: "exclamationmark.3",
                    color: Color.red,
                    isActive: isImportant && isUrgent,
                    action: { onSelect(true, true) }
                )
                card(
                    title: "quadrant.i",
                    subtitle: "quadrant.i.hint",
                    icon: "calendar.badge.clock",
                    color: Color.blue,
                    isActive: isImportant && !isUrgent,
                    action: { onSelect(true, false) }
                )
                card(
                    title: "quadrant.u",
                    subtitle: "quadrant.u.hint",
                    icon: "arrow.triangle.branch",
                    color: Color.orange,
                    isActive: !isImportant && isUrgent,
                    action: { onSelect(false, true) }
                )
                card(
                    title: "quadrant.rest",
                    subtitle: "quadrant.rest.hint",
                    icon: "archivebox",
                    color: DaybookTheme.muted,
                    isActive: !isImportant && !isUrgent,
                    action: { onSelect(false, false) }
                )
            }
        }
    }

    private func card(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        icon: String,
        color: Color,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(color)
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DaybookTheme.ink)
                    Spacer()
                    if isActive {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(color)
                    }
                }
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(DaybookTheme.muted)
            }
            .padding(7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isActive ? color.opacity(0.12) : DaybookTheme.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(isActive ? color.opacity(0.7) : DaybookTheme.rule.opacity(0.25), lineWidth: isActive ? 1.2 : 0.6)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
