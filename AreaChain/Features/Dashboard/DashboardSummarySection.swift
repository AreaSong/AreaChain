import Foundation
import SwiftUI

// MARK: - 第 1 层（通栏浅灰托盘）：4 张纯白微浮大数字 KPI 卡 + 今日习惯/手记速览条

struct DashboardSummarySection: View {
    @Environment(\.locale) private var locale
    var summary: DashboardSummary
    var navigation: WorkspaceNavigation
    var todayKey: String = DayClock.shared.todayKey
    var todos: [TodoItem] = []
    var routines: [DailyRoutine] = []
    var checks: [RoutineCheck] = []
    var diaries: [DiaryEntry] = []

    private var isEnglish: Bool {
        locale.language.languageCode?.identifier == "en"
    }

    var body: some View {
        DashboardSidebarPanel {
            HStack(spacing: DaybookSpacing.sm) {
                todayKPICard
                pendingKPICard
                streakKPICard
                recentAndHabitsKPICard
            }
            habitsAndDiaryQuickStrip
        }
    }

    // MARK: - KPI 1：今日完成（固定 68pt 高度，单行防折行）

    private var todayKPICard: some View {
        let openText = isEnglish
            ? "\(summary.todayStat.openCount) left"
            : "余 \(summary.todayStat.openCount)"
        return DashboardSurfaceTile(isSelected: true, fixedHeight: 68) {
            DashboardNavigation.openToday(navigation)
        } content: {
            HStack(spacing: 10) {
                DaybookProgressRing(
                    progress: summary.todayStat.completionRate ?? 0,
                    lineWidth: 4,
                    size: 36
                )
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("dashboard.today.title")
                            .font(DaybookType.caption.weight(.medium))
                            .foregroundStyle(DaybookPalette.text.secondary)
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        Text(verbatim: openText)
                            .font(DaybookType.badge.monospacedDigit())
                            .foregroundStyle(DaybookPalette.accent.base)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(
                                RoundedRectangle(cornerRadius: DaybookRadius.full, style: .continuous) // control: 今日剩余待办胶囊
                                    .fill(DaybookPalette.fill.surface)
                            )
                            .accessibilityIdentifier("dashboard.open")
                    }
                    Text(todayValue)
                        .font(DaybookType.display.monospacedDigit())
                        .foregroundStyle(DaybookPalette.text.primary)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityIdentifier("dashboard.today")
        .accessibilityLabel(Text(todayAccessibility))
        .accessibilityHint(Text("dashboard.today.skipNote"))
        .dashboardCommandPopover(arrowEdge: .bottom) {
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
                emptyText: isEnglish ? "No tasks scheduled for today" : "今日暂无排期事项"
            )
        }
    }

    // MARK: - KPI 2：逾期积压 & 即将到来（固定 68pt 高度）

    private var pendingKPICard: some View {
        let upcomingText = isEnglish
            ? "Next \(summary.upcomingCount)"
            : "即将 \(summary.upcomingCount)"
        return DashboardSurfaceTile(fixedHeight: 68) {
            DashboardNavigation.openPending(navigation, lane: .overdue)
        } content: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "tray.full")
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookPalette.text.secondary)
                    Text("dashboard.pending.overdue")
                        .font(DaybookType.caption.weight(.medium))
                        .foregroundStyle(DaybookPalette.text.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    Button {
                        DashboardNavigation.openPending(navigation, lane: .upcoming)
                    } label: {
                        Text(verbatim: upcomingText)
                            .font(DaybookType.badge.monospacedDigit())
                            .foregroundStyle(DaybookPalette.text.secondary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(
                                RoundedRectangle(cornerRadius: DaybookRadius.full, style: .continuous) // control: 即将到来胶囊徽章
                                    .fill(DaybookPalette.fill.hover)
                            )
                    }
                    .buttonStyle(.plain) // control: 即将到来子胶囊按钮
                    .accessibilityIdentifier("dashboard.upcoming")
                }
                Text("\(summary.overdueCount)")
                    .font(DaybookType.display.monospacedDigit())
                    .foregroundStyle(DaybookPalette.text.primary)
                    .lineLimit(1)
            }
        }
        .accessibilityIdentifier("dashboard.overdue")
        .dashboardCommandPopover(arrowEdge: .bottom) {
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
                emptyText: isEnglish ? "Zero overdue tasks!" : "当前没有任何逾期积压"
            )
        }
    }

    // MARK: - KPI 3：当前连击 & 历史最高（固定 68pt 高度）

    private var streakKPICard: some View {
        let bestText = isEnglish
            ? "Best \(summary.strongestBestStreak)d"
            : "最高 \(summary.strongestBestStreak)天"
        return DashboardSurfaceTile(fixedHeight: 68) {
            navigation.revealRecurringList()
        } content: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "flame")
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookPalette.text.secondary)
                    Text("dashboard.streak.current")
                        .font(DaybookType.caption.weight(.medium))
                        .foregroundStyle(DaybookPalette.text.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    Text(verbatim: bestText)
                        .font(DaybookType.badge.monospacedDigit())
                        .foregroundStyle(DaybookPalette.text.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: DaybookRadius.full, style: .continuous) // control: 历史最高连击胶囊徽章
                                .fill(DaybookPalette.fill.hover)
                        )
                        .accessibilityIdentifier("dashboard.streak.best")
                }
                Text(verbatim: isEnglish ? "\(summary.strongestCurrentStreak)d" : "\(summary.strongestCurrentStreak) 天")
                    .font(DaybookType.display.monospacedDigit())
                    .foregroundStyle(DaybookPalette.text.primary)
                    .lineLimit(1)
            }
        }
        .accessibilityIdentifier("dashboard.streak.current")
        .dashboardCommandPopover(arrowEdge: .bottom) {
            routinesHUD
        }
    }

    // MARK: - KPI 4：近 7 日完成 & 习惯/手记计数（固定 68pt 高度）

    private var recentAndHabitsKPICard: some View {
        DashboardSurfaceTile(fixedHeight: 68) {
            navigation.revealTab(.calendar)
        } content: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar")
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookPalette.text.secondary)
                    Text("dashboard.trend.title")
                        .font(DaybookType.caption.weight(.medium))
                        .foregroundStyle(DaybookPalette.text.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    HStack(spacing: 3) {
                        Button {
                            navigation.revealRecurringList()
                        } label: {
                            Text(verbatim: isEnglish ? "\(summary.activeRoutineCount)H" : "\(summary.activeRoutineCount)习惯")
                                .font(DaybookType.badge.monospacedDigit())
                                .foregroundStyle(DaybookPalette.text.secondary)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain) // control: 习惯计数微标
                        .accessibilityIdentifier("dashboard.routines.active")

                        Text(verbatim: "·")
                            .font(DaybookType.badge)
                            .foregroundStyle(DaybookPalette.text.tertiary)

                        Button {
                            navigation.revealTab(.diary)
                        } label: {
                            Text(verbatim: isEnglish ? "\(summary.todayDiaryCount)N" : "\(summary.todayDiaryCount)手记")
                                .font(DaybookType.badge.monospacedDigit())
                                .foregroundStyle(DaybookPalette.text.secondary)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain) // control: 今日手记计数微标
                        .accessibilityIdentifier("dashboard.diary.today")
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: DaybookRadius.full, style: .continuous) // control: 习惯与手记胶囊徽章
                            .fill(DaybookPalette.fill.hover)
                    )
                }
                Text(rangeValue)
                    .font(DaybookType.display.monospacedDigit())
                    .foregroundStyle(DaybookPalette.text.primary)
                    .lineLimit(1)
                    .accessibilityIdentifier("dashboard.range.recent")
            }
        }
        .dashboardCommandPopover(arrowEdge: .bottom) {
            routinesHUD
        }
    }

    // MARK: - 底部习惯与今日手记直显速览条（告别只有冷冰冰的数字）

    @ViewBuilder
    private var habitsAndDiaryQuickStrip: some View {
        let activeRoutines = routines.filter { $0.deletedAt == nil && $0.isEnabled }
        let todayDiaries = diaries.filter { $0.deletedAt == nil && !$0.hasProtectedContent && $0.dayKey == todayKey }
        if !activeRoutines.isEmpty || !todayDiaries.isEmpty {
            HStack(spacing: 6) {
                Text(verbatim: isEnglish ? "Active Today" : "今日习惯与手记")
                    .font(DaybookType.badge.weight(.semibold))
                    .foregroundStyle(DaybookPalette.text.tertiary)
                    .padding(.leading, 4)

                ForEach(activeRoutines.prefix(4)) { routine in
                    routineQuickPill(routine)
                }

                if let latestDiary = todayDiaries.first {
                    diaryQuickPill(latestDiary)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func routineQuickPill(_ routine: DailyRoutine) -> some View {
        let routineID = routine.id
        let isCheckedToday = checks.contains { check in
            check.routine?.id == routineID && check.dayKey == todayKey && check.isDone
        }
        return Button {
            navigation.revealRecurringList()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: isCheckedToday ? "checkmark.circle.fill" : "repeat")
                    .font(DaybookType.badge)
                    .foregroundStyle(isCheckedToday ? DaybookPalette.accent.base : DaybookPalette.text.secondary)
                Text(verbatim: routine.title)
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookPalette.text.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.full, style: .continuous) // control: 今日习惯状态微浮胶囊
                    .fill(isCheckedToday ? DaybookPalette.fill.selection : DaybookPalette.fill.surface)
            )
        }
        .buttonStyle(.plain) // control: 习惯胶囊点击跳转
    }

    private func diaryQuickPill(_ entry: DiaryEntry) -> some View {
        let firstLine = entry.text
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let fallback = isEnglish ? "Today's Note" : "今日手记"
        return Button {
            navigation.revealTab(.diary)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "book.closed")
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookPalette.accent.base)
                Text(verbatim: firstLine.isEmpty ? fallback : firstLine)
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookPalette.text.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.full, style: .continuous) // control: 今日手记标题微浮胶囊
                    .fill(DaybookPalette.fill.surface)
            )
        }
        .buttonStyle(.plain) // control: 今日手记胶囊点击跳转
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
            emptyText: isEnglish ? "No active routines" : "暂无启用中的重复事项"
        )
    }

    private var rangeValue: String {
        "\(summary.recentRangeStat.completedCount)/\(summary.recentRangeStat.scheduledCount)"
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
