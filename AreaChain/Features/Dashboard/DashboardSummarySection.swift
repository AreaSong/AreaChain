import Foundation
import SwiftUI

// MARK: - 第 1 层（通栏浅灰托盘）：核心大 KPI 卡 + 右侧近 7 日趋势柱（等高 94pt）

struct DashboardSummarySection: View {
    @Environment(\.locale) private var locale
    var summary: DashboardSummary
    var trendDays: [DashboardDayStat] = []
    var navigation: WorkspaceNavigation
    var todayKey: String = DayClock.shared.todayKey
    var todos: [TodoItem] = []
    var routines: [DailyRoutine] = []
    var checks: [RoutineCheck] = []
    var diaries: [DiaryEntry] = []

    @State private var isInspectToday = false
    @State private var isInspectPending = false
    @State private var isInspectStreak = false

    private var isEnglish: Bool {
        locale.language.languageCode?.identifier == "en"
    }

    var body: some View {
        DashboardSidebarPanel {
            HStack(alignment: .top, spacing: DaybookSpacing.md) {
                // 左侧：上 1 全宽卡 + 下 2 半宽卡（总高 94pt，彻底告别文字挤压）
                VStack(alignment: .leading, spacing: 6) {
                    DashboardSidebarSectionHeader(
                        "dashboard.summary.title",
                        badgeText: isEnglish ? "Key Metrics" : "核心态势"
                    )
                    VStack(spacing: 6) {
                        todayKPICard
                        HStack(spacing: 6) {
                            pendingKPICard
                            streakKPICard
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                // 右侧：近 7 日动态双层趋势柱（等高 94pt）
                DashboardTrendSection(
                    days: trendDays,
                    locale: locale,
                    navigation: navigation
                )
            }
        }
    }

    // MARK: - KPI 1：今日完成（全宽卡片，高度 44pt，宽敞零截断）

    private var todayKPICard: some View {
        let openText = isEnglish
            ? "\(summary.todayStat.openCount) left"
            : "余 \(summary.todayStat.openCount)"
        let ratePercent = Int(((summary.todayStat.completionRate ?? 0) * 100).rounded())

        return DashboardSurfaceTile(
            isSelected: true,
            fixedHeight: 44,
            navigateAction: { DashboardNavigation.openToday(navigation) },
            navigateTooltip: isEnglish ? "Open Today View" : "前往今日视图"
        ) {
            isInspectToday.toggle()
        } content: {
            HStack(spacing: 10) {
                DaybookProgressRing(
                    progress: summary.todayStat.completionRate ?? 0,
                    lineWidth: 3,
                    size: 26
                )
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Image(systemName: "sun.max")
                            .font(DaybookType.micro)
                            .foregroundStyle(DaybookPalette.text.secondary)
                        Text("dashboard.today.title")
                            .font(DaybookType.caption.weight(.medium))
                            .foregroundStyle(DaybookPalette.text.secondary)
                            .lineLimit(1)
                    }
                    Text(todayValue)
                        .font(DaybookType.entity.monospacedDigit())
                        .contentTransition(.numericText())
                        .foregroundStyle(DaybookPalette.text.primary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(verbatim: openText)
                        .font(DaybookType.badge.monospacedDigit())
                        .contentTransition(.numericText())
                        .foregroundStyle(DaybookPalette.accent.base)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: DaybookRadius.full, style: .continuous) // control: 今日剩余待办胶囊
                                .fill(DaybookPalette.fill.surface)
                        )
                        .accessibilityIdentifier("dashboard.open")
                    Text(verbatim: isEnglish ? "\(ratePercent)% done" : "达成 \(ratePercent)%")
                        .font(DaybookType.micro.monospacedDigit())
                        .contentTransition(.numericText())
                        .foregroundStyle(DaybookPalette.text.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityIdentifier("dashboard.today")
        .accessibilityLabel(Text(todayAccessibility))
        .accessibilityHint(Text("dashboard.today.skipNote"))
        .dashboardCommandPopover(isPresented: $isInspectToday, arrowEdge: .bottom) {
            let todayItems = todos.filter { $0.deletedAt == nil && $0.dayKey == todayKey }
            DashboardHUDCard(
                icon: "sun.max",
                title: L10n.string("dashboard.today.title", locale: locale),
                subtitle: "\(todayValue) · " + L10n.string("dashboard.today.skipNote", locale: locale),
                items: todayItems.map {
                    .init(
                        symbol: $0.isDone ? "checkmark.circle.fill" : "circle",
                        symbolColor: $0.isDone ? DaybookPalette.status.success : DaybookPalette.text.tertiary,
                        title: $0.title,
                        trailing: $0.isDone ? (isEnglish ? "Done" : "已完成") : (isEnglish ? "Open" : "待办")
                    )
                },
                emptyText: isEnglish ? "No tasks scheduled for today" : "今日暂无排期事项",
                actionTitle: isEnglish ? "Go to Today View" : "前往“今日”事项页面",
                onAction: {
                    isInspectToday = false
                    DashboardNavigation.openToday(navigation)
                }
            )
        }
    }

    // MARK: - KPI 2：逾期积压（半宽卡片，高度 44pt，宽敞零截断）

    private var pendingKPICard: some View {
        let upcomingText = isEnglish
            ? "Next \(summary.upcomingCount)"
            : "即将 \(summary.upcomingCount)"
        let hasOverdue = summary.overdueCount > 0

        return DashboardSurfaceTile(
            fixedHeight: 44,
            navigateAction: { DashboardNavigation.openPending(navigation, lane: .overdue) },
            navigateTooltip: isEnglish ? "Open Pending Lane" : "前往待处理泳道"
        ) {
            isInspectPending.toggle()
        } content: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "tray.full")
                        .font(DaybookType.micro)
                        .foregroundStyle(hasOverdue ? DaybookPalette.status.danger : DaybookPalette.text.secondary)
                    Text("dashboard.pending.overdue")
                        .font(DaybookType.caption.weight(.medium))
                        .foregroundStyle(hasOverdue ? DaybookPalette.status.danger : DaybookPalette.text.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    Button {
                        DashboardNavigation.openPending(navigation, lane: .upcoming)
                    } label: {
                        Text(verbatim: upcomingText)
                            .font(DaybookType.badge.monospacedDigit())
                            .contentTransition(.numericText())
                            .foregroundStyle(DaybookPalette.text.secondary)
                            .lineLimit(1)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: DaybookRadius.full, style: .continuous) // control: 即将到来胶囊徽章
                                    .fill(DaybookPalette.fill.hover)
                            )
                    }
                    .buttonStyle(.plain) // control: 即将到来子胶囊按钮
                    .accessibilityIdentifier("dashboard.upcoming")
                }

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(summary.overdueCount)")
                        .font(DaybookType.entity.monospacedDigit())
                        .contentTransition(.numericText())
                        .foregroundStyle(hasOverdue ? DaybookPalette.status.danger : DaybookPalette.text.primary)
                        .lineLimit(1)
                    if hasOverdue {
                        Text(verbatim: isEnglish ? "Overdue" : "需处理")
                            .font(DaybookType.micro)
                            .foregroundStyle(DaybookPalette.status.danger)
                            .lineLimit(1)
                    }
                }
            }
        }
        .accessibilityIdentifier("dashboard.overdue")
        .dashboardCommandPopover(isPresented: $isInspectPending, arrowEdge: .bottom) {
            let overdueItems = todos.filter { $0.deletedAt == nil && !$0.isDone && $0.dayKey < todayKey }
            DashboardHUDCard(
                icon: "tray.full",
                title: L10n.string("dashboard.pending.overdue", locale: locale),
                subtitle: isEnglish ? "\(summary.overdueCount) overdue · \(summary.upcomingCount) upcoming" : "逾期 \(summary.overdueCount) 项 · 未来7天 \(summary.upcomingCount) 项",
                items: overdueItems.map {
                    .init(
                        symbol: "circle",
                        symbolColor: DaybookPalette.text.secondary,
                        title: $0.title,
                        trailing: DayKey.shortStamp($0.dayKey, locale: locale)
                    )
                },
                emptyText: isEnglish ? "Zero overdue tasks!" : "当前没有任何逾期积压",
                actionTitle: isEnglish ? "Go to Pending Page" : "前往“待处理”页面",
                onAction: {
                    isInspectPending = false
                    DashboardNavigation.openPending(navigation, lane: .overdue)
                }
            )
        }
    }

    // MARK: - KPI 3：自律连击（半宽卡片，高度 44pt，宽敞零截断）

    private var streakKPICard: some View {
        let bestText = isEnglish
            ? "Best \(summary.strongestBestStreak)d"
            : "最高 \(summary.strongestBestStreak)天"
        let activeRoutines = routines.filter { $0.deletedAt == nil && $0.isEnabled }

        return DashboardSurfaceTile(
            fixedHeight: 44,
            navigateAction: { navigation.revealRecurringList() },
            navigateTooltip: isEnglish ? "Open Recurring Routines" : "前往安排习惯"
        ) {
            isInspectStreak.toggle()
        } content: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(DaybookType.micro)
                        .foregroundStyle(DaybookPalette.text.secondary)
                    Text("dashboard.streak.current")
                        .font(DaybookType.caption.weight(.medium))
                        .foregroundStyle(DaybookPalette.text.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    Text(verbatim: bestText)
                        .font(DaybookType.badge.monospacedDigit())
                        .contentTransition(.numericText())
                        .foregroundStyle(DaybookPalette.text.secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: DaybookRadius.full, style: .continuous) // control: 历史最高连击胶囊徽章
                                .fill(DaybookPalette.fill.hover)
                        )
                        .accessibilityIdentifier("dashboard.streak.best")
                }

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(verbatim: isEnglish ? "\(summary.strongestCurrentStreak)d" : "\(summary.strongestCurrentStreak) 天")
                        .font(DaybookType.entity.monospacedDigit())
                        .contentTransition(.numericText())
                        .foregroundStyle(DaybookPalette.text.primary)
                        .lineLimit(1)
                    Text(verbatim: isEnglish ? "\(activeRoutines.count) habits" : "\(activeRoutines.count)个习惯")
                        .font(DaybookType.micro)
                        .contentTransition(.numericText())
                        .foregroundStyle(DaybookPalette.text.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityIdentifier("dashboard.streak.current")
        .dashboardCommandPopover(isPresented: $isInspectStreak, arrowEdge: .bottom) {
            routinesHUD
        }
    }

    private var routinesHUD: some View {
        let activeRoutines = routines.filter { $0.deletedAt == nil && $0.isEnabled }
        return DashboardHUDCard(
            icon: "repeat",
            title: isEnglish ? "Active Habits" : "启用中习惯",
            subtitle: isEnglish
                ? "Current \(summary.strongestCurrentStreak)d · Best \(summary.strongestBestStreak)d"
                : "当前连击 \(summary.strongestCurrentStreak) 天 · 最佳 \(summary.strongestBestStreak) 天",
            items: activeRoutines.map {
                .init(
                    symbol: "repeat",
                    symbolColor: DaybookPalette.text.secondary,
                    title: $0.title,
                    trailing: isEnglish ? "Active" : "启用中"
                )
            },
            emptyText: isEnglish ? "No active routines" : "暂无启用中的重复事项",
            actionTitle: isEnglish ? "Go to Routines" : "前往“安排”习惯清单",
            onAction: {
                isInspectStreak = false
                navigation.revealRecurringList()
            }
        )
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
}
