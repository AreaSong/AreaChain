import Foundation
import SwiftUI

struct DashboardTrendSection: View {
    var days: [DashboardDayStat]
    var locale: Locale
    var navigation: WorkspaceNavigation

    var body: some View {
        let percentFormatter = makePercentFormatter()
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            DaybookSectionHeader(title: "dashboard.trend.title", icon: "chart.bar")
            if days.allSatisfy({ $0.scheduledCount == 0 }) {
                Text("dashboard.trend.empty")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: DaybookSpacing.sm) {
                    ForEach(days, id: \.dayKey) { day in
                        trendColumn(day, percentFormatter: percentFormatter)
                    }
                }
            }
        }
        .accessibilityIdentifier("dashboard.trend")
    }

    private func trendColumn(_ day: DashboardDayStat, percentFormatter: NumberFormatter) -> some View {
        Button {
            DashboardNavigation.openCalendar(dayKey: day.dayKey, isPadding: false, navigation: navigation)
        } label: {
            columnLabel(day, percentFormatter: percentFormatter)
        }
        .buttonStyle(DaybookButtonStyle(.quiet))
        .accessibilityIdentifier("dashboard.trend.\(day.dayKey)")
    }

    private func columnLabel(_ day: DashboardDayStat, percentFormatter: NumberFormatter) -> some View {
        VStack(spacing: DaybookSpacing.xs) {
            ZStack(alignment: .bottom) {
                Color.clear
                RoundedRectangle(cornerRadius: DaybookRadius.xxs)
                    .fill(day.scheduledCount == 0 ? DaybookPalette.fill.subtle : DaybookPalette.accent.base)
                    .frame(height: barHeight(day))
            }
            .frame(width: DaybookMetrics.controlHeight, height: DaybookMetrics.Heatmap.trendHeight)
            Text(DayKey.shortStamp(day.dayKey, locale: locale))
                .font(DaybookType.badge)
                .foregroundStyle(DaybookPalette.text.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label(day, percentFormatter: percentFormatter)))
    }

    private func barHeight(_ day: DashboardDayStat) -> CGFloat {
        guard let rate = day.completionRate else { return 0 }
        return DaybookMetrics.Heatmap.trendHeight * CGFloat(rate)
    }

    private func label(_ day: DashboardDayStat, percentFormatter: NumberFormatter) -> String {
        let percent: String
        if let rate = day.completionRate {
            percent = percentFormatter.string(from: NSNumber(value: rate)) ?? ""
        } else {
            percent = L10n.string("dashboard.trend.noRate", locale: locale)
        }
        return L10n.format(
            "dashboard.trend.accessibility",
            locale: locale,
            DayKey.displayName(day.dayKey, locale: locale),
            day.completedCount,
            day.scheduledCount,
            percent
        )
    }

    private func makePercentFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .percent
        return formatter
    }
}
