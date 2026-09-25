import SwiftUI

struct DashboardActivitySection: View {
    var activities: [DashboardActivity]
    var locale: Locale
    var navigation: WorkspaceNavigation

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            DaybookSectionHeader(title: "dashboard.activity.title", icon: "clock", count: activities.count)
            if activities.isEmpty {
                Text("dashboard.activity.empty")
                    .font(DaybookType.body)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .accessibilityIdentifier("dashboard.activity.empty")
            } else {
                ForEach(activities) { activity in
                    activityRow(activity)
                }
            }
        }
        .accessibilityIdentifier("dashboard.activity")
    }

    private func activityRow(_ activity: DashboardActivity) -> some View {
        Button {
            DashboardNavigation.open(activity.route, navigation: navigation)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: DaybookSpacing.sm) {
                Text(kindKey(activity.kind))
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .frame(width: 72, alignment: .leading)
                Text(subject(activity))
                    .font(DaybookType.body)
                    .foregroundStyle(DaybookPalette.text.primary)
                    .lineLimit(1)
                Spacer(minLength: DaybookSpacing.sm)
                Text(DayKey.displayName(activity.dayKey, locale: locale))
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(DaybookButtonStyle(.quiet))
        .disabled(activity.route == nil)
        .accessibilityIdentifier("dashboard.activity.\(activity.id)")
        .accessibilityLabel(Text(accessibilityText(activity)))
    }

    private func subject(_ activity: DashboardActivity) -> String {
        if let key = activity.titleKey {
            return L10n.string(String.LocalizationValue(key), locale: locale)
        }
        return activity.title
    }

    private func kindKey(_ kind: DashboardActivityKind) -> LocalizedStringKey {
        switch kind {
        case .completed: return "dashboard.activity.kind.completed"
        case .skipped: return "dashboard.activity.kind.skipped"
        case .created: return "dashboard.activity.kind.created"
        case .trashed: return "dashboard.activity.kind.trashed"
        }
    }

    private func accessibilityText(_ activity: DashboardActivity) -> String {
        L10n.format(
            "dashboard.activity.row",
            locale: locale,
            L10n.string(String.LocalizationValue(kindStringKey(activity.kind)), locale: locale),
            subject(activity),
            DayKey.displayName(activity.dayKey, locale: locale)
        )
    }

    private func kindStringKey(_ kind: DashboardActivityKind) -> String {
        switch kind {
        case .completed: return "dashboard.activity.kind.completed"
        case .skipped: return "dashboard.activity.kind.skipped"
        case .created: return "dashboard.activity.kind.created"
        case .trashed: return "dashboard.activity.kind.trashed"
        }
    }
}
