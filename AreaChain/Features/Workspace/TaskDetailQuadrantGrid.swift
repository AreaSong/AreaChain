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
                card(.importantUrgent, isActive: isImportant && isUrgent) { onSelect(true, true) }
                card(.importantNotUrgent, isActive: isImportant && !isUrgent) { onSelect(true, false) }
                card(.urgentNotImportant, isActive: !isImportant && isUrgent) { onSelect(false, true) }
                card(.neither, isActive: !isImportant && !isUrgent) { onSelect(false, false) }
            }
        }
    }

    private enum QuadrantChoice {
        case importantUrgent
        case importantNotUrgent
        case urgentNotImportant
        case neither

        var title: LocalizedStringKey {
            switch self {
            case .importantUrgent: "quadrant.iu"
            case .importantNotUrgent: "quadrant.i"
            case .urgentNotImportant: "quadrant.u"
            case .neither: "quadrant.rest"
            }
        }

        var subtitle: LocalizedStringKey {
            switch self {
            case .importantUrgent: "quadrant.iu.hint"
            case .importantNotUrgent: "quadrant.i.hint"
            case .urgentNotImportant: "quadrant.u.hint"
            case .neither: "quadrant.rest.hint"
            }
        }

        var icon: String {
            switch self {
            case .importantUrgent: "exclamationmark.3"
            case .importantNotUrgent: "calendar.badge.clock"
            case .urgentNotImportant: "arrow.triangle.branch"
            case .neither: "archivebox"
            }
        }

        var color: Color {
            switch self {
            case .importantUrgent: .red
            case .importantNotUrgent: .blue
            case .urgentNotImportant: .orange
            case .neither: DaybookTheme.muted
            }
        }
    }

    private func card(
        _ choice: QuadrantChoice,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: choice.icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(choice.color)
                    Text(choice.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DaybookTheme.ink)
                    Spacer()
                    if isActive {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(choice.color)
                    }
                }
                Text(choice.subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(DaybookTheme.muted)
            }
            .padding(7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isActive ? choice.color.opacity(0.12) : DaybookTheme.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(isActive ? choice.color.opacity(0.7) : DaybookTheme.rule.opacity(0.25), lineWidth: isActive ? 1.2 : 0.6)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
