import Foundation
@testable import AreaChain

/// 冻结 PHASE-3C 之前的按日×习惯扫描，只给等价测试对照，不是产品入口。
enum DashboardProjectionOracle {
    static func project(
        todos: [TodoSnapshot],
        routines: [RoutineSnapshot],
        checks: [CheckSnapshot],
        diaries: [DiarySnapshot],
        todayKey: String,
        calendar: Calendar
    ) -> DashboardSnapshot {
        let days = DashboardProjection.closedDays(
            ending: todayKey, count: DashboardProjection.heatmapDayCount, calendar: calendar
        )
        let stats = nestedDayStats(
            days: days, todos: todos, routines: routines, checks: checks, calendar: calendar
        )
        let byDay = Dictionary(uniqueKeysWithValues: stats.map { ($0.dayKey, $0) })
        let today = byDay[todayKey] ?? DashboardDayStat.make(
            dayKey: todayKey, scheduledCount: 0, completedCount: 0, skippedCount: 0
        )
        let trendDays = DashboardProjection.closedDays(
            ending: todayKey, count: DashboardProjection.trendDayCount, calendar: calendar
        )
        let trend = trendDays.map {
            byDay[$0] ?? DashboardDayStat.make(
                dayKey: $0, scheduledCount: 0, completedCount: 0, skippedCount: 0
            )
        }
        let pending = AgendaProjection.pending(
            routines: routines, checks: checks, todos: todos, todayKey: todayKey, calendar: calendar
        )
        let streaks = streakPeaks(routines: routines, checks: checks, todayKey: todayKey, calendar: calendar)
        return DashboardSnapshot(
            summary: DashboardSummary(
                todayStat: today,
                overdueCount: pending.overdueCount,
                upcomingCount: pending.upcomingCount,
                recentRangeStat: DashboardDayStat.make(
                    dayKey: todayKey,
                    scheduledCount: trend.reduce(0) { $0 + $1.scheduledCount },
                    completedCount: trend.reduce(0) { $0 + $1.completedCount },
                    skippedCount: trend.reduce(0) { $0 + $1.skippedCount }
                ),
                activeRoutineCount: routines.filter { $0.deletedAt == nil && $0.isEnabled }.count,
                strongestCurrentStreak: streaks.current,
                strongestBestStreak: streaks.best,
                todayDiaryCount: diaries.filter {
                    $0.deletedAt == nil && !$0.isPrivate && $0.isContentAvailable && $0.dayKey == todayKey
                }.count
            ),
            trend: trend,
            heatmap: DashboardProjection.heatmap(
                ending: todayKey,
                dayCount: DashboardProjection.heatmapDayCount,
                stats: byDay,
                calendar: calendar,
                titles: DashboardCompletionTitles.previews(
                    todos: todos, routines: routines, marks: dashboardMarks(checks)
                )
            ),
            activities: DashboardProjection.activities(
                todos: todos, routines: routines, checks: checks, diaries: diaries,
                todayKey: todayKey, calendar: calendar
            )
        )
    }

    static func nestedDayStats(
        days: [String],
        todos: [TodoSnapshot],
        routines: [RoutineSnapshot],
        checks: [CheckSnapshot],
        calendar: Calendar
    ) -> [DashboardDayStat] {
        var todoCounts: [String: (scheduled: Int, completed: Int)] = [:]
        for todo in todos where todo.deletedAt == nil && DayKey.date(from: todo.dayKey, calendar: calendar) != nil {
            var entry = todoCounts[todo.dayKey] ?? (0, 0)
            entry.scheduled += 1
            if todo.isDone { entry.completed += 1 }
            todoCounts[todo.dayKey] = entry
        }
        var marks: [UUID: [String: OracleMark]] = [:]
        for check in checks {
            guard let next = OracleMark.merge(marks[check.routineId]?[check.dayKey], check) else { continue }
            marks[check.routineId, default: [:]][check.dayKey] = next
        }
        let live = routines.filter { $0.deletedAt == nil }
        return days.map { day in
            var scheduled = todoCounts[day]?.scheduled ?? 0
            var completed = todoCounts[day]?.completed ?? 0
            var skipped = 0
            for routine in live {
                guard let contribution = routineContribution(
                    routine, dayKey: day, mark: marks[routine.id]?[day], calendar: calendar
                ) else { continue }
                scheduled += contribution.scheduled
                completed += contribution.completed
                skipped += contribution.skipped
            }
            return DashboardDayStat.make(
                dayKey: day, scheduledCount: scheduled, completedCount: completed, skippedCount: skipped
            )
        }
    }

    private static func streakPeaks(
        routines: [RoutineSnapshot],
        checks: [CheckSnapshot],
        todayKey: String,
        calendar: Calendar
    ) -> (current: Int, best: Int) {
        let checksByRoutine = Dictionary(grouping: checks, by: \.routineId)
        var current = 0
        var best = 0
        for routine in routines where routine.deletedAt == nil {
            let streak = HabitStreakLogic.calculate(
                routine: routine,
                checks: checksByRoutine[routine.id] ?? [],
                todayKey: todayKey,
                calendar: calendar
            )
            current = max(current, streak.currentStreak)
            best = max(best, streak.bestStreak)
        }
        return (current, best)
    }

    private static func routineContribution(
        _ routine: RoutineSnapshot,
        dayKey: String,
        mark: OracleMark?,
        calendar: Calendar
    ) -> (scheduled: Int, completed: Int, skipped: Int)? {
        guard DayKey.date(from: routine.createdDayKey, calendar: calendar) != nil else { return nil }
        guard dayKey >= routine.createdDayKey else { return nil }
        guard isScheduled(routine, on: dayKey, calendar: calendar) else { return nil }
        if mark == .skipped { return (1, 0, 1) }
        if mark == .done { return (1, 1, 0) }
        return (1, 0, 0)
    }

    private static func isScheduled(
        _ routine: RoutineSnapshot,
        on dayKey: String,
        calendar: Calendar
    ) -> Bool {
        guard !isPaused(routine, on: dayKey) else { return false }
        return WeekdayMask.contains(routine.weekdayMask, dayKey: dayKey, calendar: calendar)
    }

    /// 悬停标题跟产品投影走同一套完成标记；统计本身仍由上面的逐日扫描对照。
    private static func dashboardMarks(_ checks: [CheckSnapshot]) -> [UUID: [String: DashboardMark]] {
        var marks: [UUID: [String: DashboardMark]] = [:]
        for check in checks {
            guard let next = DashboardMark.merge(marks[check.routineId]?[check.dayKey], check) else { continue }
            marks[check.routineId, default: [:]][check.dayKey] = next
        }
        return marks
    }

    private static func isPaused(_ routine: RoutineSnapshot, on dayKey: String) -> Bool {
        guard !routine.isEnabled else { return false }
        if let start = routine.pausedOnDayKey, !start.isEmpty { return dayKey >= start }
        return true
    }
}

private enum OracleMark: Equatable {
    case done
    case skipped

    static func merge(_ existing: OracleMark?, _ check: CheckSnapshot) -> OracleMark? {
        if existing == .skipped || check.isSkipped { return .skipped }
        if existing == .done || check.isDone { return .done }
        return existing
    }
}
