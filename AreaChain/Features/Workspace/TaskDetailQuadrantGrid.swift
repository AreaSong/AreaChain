import SwiftUI

struct TaskDetailQuadrantGrid: View {
    var isImportant: Bool
    var isUrgent: Bool
    var onSelect: (Bool, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("四象限优先级")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DaybookTheme.muted)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                card(
                    title: "重要且紧急",
                    subtitle: "立即处理",
                    icon: "exclamationmark.3",
                    color: Color.red,
                    isActive: isImportant && isUrgent,
                    action: { onSelect(true, true) }
                )
                card(
                    title: "重要不紧急",
                    subtitle: "制定规划",
                    icon: "calendar.badge.clock",
                    color: Color.blue,
                    isActive: isImportant && !isUrgent,
                    action: { onSelect(true, false) }
                )
                card(
                    title: "紧急不重要",
                    subtitle: "授权委托",
                    icon: "arrow.triangle.branch",
                    color: Color.orange,
                    isActive: !isImportant && isUrgent,
                    action: { onSelect(false, true) }
                )
                card(
                    title: "不重要不紧急",
                    subtitle: "顺延简化",
                    icon: "archivebox",
                    color: DaybookTheme.muted,
                    isActive: !isImportant && !isUrgent,
                    action: { onSelect(false, false) }
                )
            }
        }
    }

    private func card(
        title: String,
        subtitle: String,
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
