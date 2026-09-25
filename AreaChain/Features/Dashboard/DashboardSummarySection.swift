import SwiftUI

struct DashboardSummarySection: View {
    @Environment(\.locale) private var locale
    var summary: DashboardSummary
    var navigation: WorkspaceNavigation

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.md) {
            DaybookSectionHeader(title: "dashboard.summary.title", icon: "chart.bar")
            todayRow
            pendingRow
            streakRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .daybookSurface(.card)
    }

    private var todayRow: some View {
        Button {
            DashboardNavigation.openToday(navigation)
        } label: {
            HStack(spacing: DaybookSpacing.md) {
                DaybookProgressRing(
                    progress: summary.todayStat.completionRate ?? 0,
                    lineWidth: 3.5,
                    size: 36
                )
                VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
                    Text("dashboard.today.title")
                        .font(DaybookType.body)
                        .foregroundStyle(DaybookPalette.text.primary)
                    Text(todayValue)
                        .font(DaybookType.caption.monospacedDigit())
                        .foregroundStyle(DaybookPalette.text.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(DaybookButtonStyle(.quiet))
        .accessibilityIdentifier("dashboard.today")
        .accessibilityLabel(Text(todayAccessibility))
    }

    private var pendingRow: some View {
        HStack(spacing: DaybookSpacing.sm) {
            metricButton(
                title: "dashboard.pending.overdue",
                value: summary.overdueCount,
                identifier: "dashboard.overdue"
            ) {
                DashboardNavigation.openPending(navigation)
            }
            metricButton(
                title: "dashboard.pending.upcoming",
                value: summary.upcomingCount,
                identifier: "dashboard.upcoming"
            ) {
                DashboardNavigation.openPending(navigation)
            }
            metricButton(
                title: "dashboard.today.open",
                value: summary.todayStat.openCount,
                identifier: "dashboard.open"
            ) {
                DashboardNavigation.openToday(navigation)
            }
        }
    }

    private var streakRow: some View {
        HStack(spacing: DaybookSpacing.md) {
            labeledCount("dashboard.streak.current", summary.strongestCurrentStreak)
            labeledCount("dashboard.streak.best", summary.strongestBestStreak)
            labeledCount("dashboard.diary.today", summary.todayDiaryCount)
        }
        .accessibilityElement(children: .combine)
    }

    private var todayValue: String {
        "\(summary.todayStat.completedCount)/\(summary.todayStat.scheduledCount)"
    }

    private var todayAccessibility: String {
        L10n.format(
            "dashboard.today.accessibility",
            locale: locale,
            summary.todayStat.completedCount,
            summary.todayStat.scheduledCount
        )
    }

    private func metricButton(
        title: LocalizedStringKey,
        value: Int,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
                Text(title)
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
                Text("\(value)")
                    .font(DaybookType.title.monospacedDigit())
                    .foregroundStyle(DaybookPalette.text.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(DaybookButtonStyle(.quiet))
        .accessibilityIdentifier(identifier)
    }

    private func labeledCount(_ key: LocalizedStringKey, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            Text(key)
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
            Text("\(value)")
                .font(DaybookType.body.monospacedDigit())
                .foregroundStyle(DaybookPalette.text.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(Text(key))
        .accessibilityValue(Text("\(value)"))
    }
}
