import Foundation
import SwiftUI

struct DashboardTrendSection: View {
    var days: [DashboardDayStat]
    var locale: Locale
    var navigation: WorkspaceNavigation

    @State private var hoveredDay: DashboardDayStat?

    private var isEnglish: Bool {
        locale.language.languageCode?.identifier == "en"
    }

    private var maxScheduledCount: Int {
        max(days.map(\.scheduledCount).max() ?? 1, 1)
    }

    private var headerBadgeText: String? {
        if let day = hoveredDay {
            let shortDate = DayKey.shortStamp(day.dayKey, locale: locale)
            return "\(shortDate) · \(day.completedCount)/\(day.scheduledCount)"
        }
        return isEnglish ? "Done / Scheduled" : "完成 / 排期"
    }

    var body: some View {
        let percentFormatter = makePercentFormatter()
        VStack(alignment: .leading, spacing: 8) {
            DashboardSidebarSectionHeader(
                "dashboard.trend.title",
                badgeText: headerBadgeText,
                isHighlightedBadge: hoveredDay != nil
            )
            if days.allSatisfy({ $0.scheduledCount == 0 }) {
                Text("dashboard.trend.empty")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .padding(.horizontal, 4)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(days, id: \.dayKey) { day in
                        trendColumn(day, percentFormatter: percentFormatter)
                    }
                }
                .padding(.horizontal, 10)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 94)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.regular, style: .continuous) // control: 近 7 日趋势纯白微浮内衬底板（与左侧卡片等高 94pt）
                    .fill(DaybookPalette.fill.surface)
            )
        }
        .frame(minWidth: 260, maxWidth: 360, alignment: .topLeading)
        .accessibilityIdentifier("dashboard.trend")
    }

    private func trendColumn(_ day: DashboardDayStat, percentFormatter: NumberFormatter) -> some View {
        let isHovered = hoveredDay?.dayKey == day.dayKey
        return Button {
            DashboardNavigation.openCalendar(dayKey: day.dayKey, isPadding: false, navigation: navigation)
        } label: {
            columnLabel(day, isHovered: isHovered, percentFormatter: percentFormatter)
        }
        .buttonStyle(.plain) // control: 近 7 日趋势柱状按钮
        .onHover { hovering in
            if hovering {
                hoveredDay = day
            } else if hoveredDay?.dayKey == day.dayKey {
                hoveredDay = nil
            }
        }
        .accessibilityIdentifier("dashboard.trend.\(day.dayKey)")
        .dashboardCommandPopover(arrowEdge: .top) {
            trendHUD(day, percentFormatter: percentFormatter)
        }
    }

    private func columnLabel(
        _ day: DashboardDayStat,
        isHovered: Bool,
        percentFormatter: NumberFormatter
    ) -> some View {
        let hasDone = day.completedCount > 0
        let hasScheduled = day.scheduledCount > 0
        return VStack(spacing: 4) {
            Text(verbatim: "\(day.completedCount)/\(day.scheduledCount)")
                .font(DaybookType.badge.monospacedDigit())
                .foregroundStyle(isHovered ? DaybookPalette.accent.base : DaybookPalette.text.tertiary)
                .lineLimit(1)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous) // control: 近 7 天柱状图背景底槽
                    .fill(DaybookPalette.fill.hover)
                if hasScheduled {
                    RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous) // control: 近 7 天当日排期量浅蓝灰柱
                        .fill(DaybookPalette.fill.selection)
                        .frame(height: scheduledBarHeight(day))
                }
                if hasDone {
                    RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous) // control: 近 7 天已完成量原生蓝实心柱
                        .fill(DaybookPalette.accent.base)
                        .frame(height: completedBarHeight(day))
                }
            }
            .frame(width: 20, height: 44)
            Text(verbatim: compactDayLabel(day.dayKey))
                .font(DaybookType.badge.monospacedDigit())
                .foregroundStyle(isHovered ? DaybookPalette.accent.base : DaybookPalette.text.secondary)
                .lineLimit(1)
        }
        .frame(width: 38)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.regular, style: .continuous) // control: 近 7 天单日悬停底板
                .fill(isHovered ? DaybookPalette.fill.hover : Color.clear)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label(day, percentFormatter: percentFormatter)))
    }

    private func scheduledBarHeight(_ day: DashboardDayStat) -> CGFloat {
        guard day.scheduledCount > 0 else { return 0 }
        let ratio = CGFloat(day.scheduledCount) / CGFloat(maxScheduledCount)
        return max(8, 44 * ratio)
    }

    private func completedBarHeight(_ day: DashboardDayStat) -> CGFloat {
        guard day.completedCount > 0 else { return 0 }
        let ratio = CGFloat(day.completedCount) / CGFloat(maxScheduledCount)
        return max(5, 44 * ratio)
    }

    private func compactDayLabel(_ dayKey: String) -> String {
        let parts = dayKey.split(separator: "-")
        guard parts.count == 3, let dayNum = Int(parts[2]) else {
            return DayKey.shortStamp(dayKey, locale: locale)
        }
        return isEnglish ? "\(dayNum)" : "\(dayNum)日"
    }

    private func trendHUD(_ day: DashboardDayStat, percentFormatter: NumberFormatter) -> some View {
        let rateString = day.completionRate.flatMap { percentFormatter.string(from: NSNumber(value: $0)) }
            ?? L10n.string("dashboard.trend.noRate", locale: locale)
        return DashboardHUDCard(
            icon: "chart.bar.fill",
            title: DayKey.displayName(day.dayKey, locale: locale),
            subtitle: rateString,
            items: [
                .init(
                    symbol: "checkmark.circle.fill",
                    symbolColor: DaybookPalette.status.success,
                    title: isEnglish ? "Completed" : "已完成",
                    trailing: "\(day.completedCount)"
                ),
                .init(
                    symbol: "circle",
                    symbolColor: DaybookPalette.accent.base,
                    title: isEnglish ? "Open" : "未完成",
                    trailing: "\(day.openCount)"
                ),
                .init(
                    symbol: "forward.end.fill",
                    symbolColor: DaybookPalette.text.tertiary,
                    title: isEnglish ? "Skipped" : "已跳过",
                    trailing: "\(day.skippedCount)"
                )
            ],
            emptyText: ""
        )
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
