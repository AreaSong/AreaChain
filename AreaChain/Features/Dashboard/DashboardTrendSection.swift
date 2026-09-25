import SwiftUI

struct DashboardTrendSection: View {
    var days: [DashboardDayStat]
    var locale: Locale

    var body: some View {
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
                        trendColumn(day)
                    }
                }
            }
        }
        .accessibilityIdentifier("dashboard.trend")
    }

    private func trendColumn(_ day: DashboardDayStat) -> some View {
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
        .accessibilityLabel(Text(label(day)))
    }

    private func barHeight(_ day: DashboardDayStat) -> CGFloat {
        guard let rate = day.completionRate else { return 0 }
        return DaybookMetrics.Heatmap.trendHeight * CGFloat(rate)
    }

    private func label(_ day: DashboardDayStat) -> String {
        let percent: String
        if let rate = day.completionRate {
            percent = percentText(rate)
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

    private func percentText(_ rate: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .percent
        return formatter.string(from: NSNumber(value: rate)) ?? ""
    }
}
