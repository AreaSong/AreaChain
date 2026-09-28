import Foundation

enum DashboardProjection {
    static let heatmapDayCount = 365
    static let trendDayCount = 7
    static let activityDayCount = 30
    static let activityDisplayLimit = 12

    static func project(
        todos: [TodoSnapshot],
        routines: [RoutineSnapshot],
        checks: [CheckSnapshot],
        diaries: [DiarySnapshot],
        todayKey: String,
        calendar: Calendar = .current
    ) -> DashboardSnapshot {
        let days = closedDays(ending: todayKey, count: heatmapDayCount, calendar: calendar)
        let marks = mergedMarks(checks)
        let stats = dayStats(
            days: days, todos: todos, routines: routines, marks: marks, calendar: calendar
        )
        let byDay = Dictionary(uniqueKeysWithValues: zip(days, stats).map { ($0, $1) })
        let today = byDay[todayKey] ?? emptyStat(todayKey)
        let trend = endingKeys(
            days, count: trendDayCount, ending: todayKey, calendar: calendar
        ).map { byDay[$0] ?? emptyStat($0) }
        let pending = AgendaProjection.pending(
            routines: routines, checks: checks, todos: todos, todayKey: todayKey, calendar: calendar
        )
        let streaks = streakPeaks(routines: routines, checks: checks, todayKey: todayKey, calendar: calendar)
        return DashboardSnapshot(
            summary: DashboardSummary(
                todayStat: today,
                overdueCount: pending.overdueCount,
                upcomingCount: pending.upcomingCount,
                recentRangeStat: aggregate(trend, dayKey: todayKey),
                activeRoutineCount: routines.filter { $0.deletedAt == nil && $0.isEnabled }.count,
                strongestCurrentStreak: streaks.current,
                strongestBestStreak: streaks.best,
                todayDiaryCount: publicDiaryCount(diaries, on: todayKey)
            ),
            trend: trend,
            heatmap: heatmap(
                ending: todayKey, dayCount: heatmapDayCount, stats: byDay, calendar: calendar, days: days
            ),
            activities: activityRows(
                todos: todos, routines: routines, diaries: diaries,
                todayKey: todayKey, calendar: calendar, limit: activityDisplayLimit,
                marks: marks,
                window: Set(endingKeys(days, count: activityDayCount, ending: todayKey, calendar: calendar))
            )
        )
    }

    static func closedDays(ending end: String, count: Int, calendar: Calendar) -> [String] {
        guard count > 0, DayKey.date(from: end, calendar: calendar) != nil else { return [] }
        let start = DayKey.shifted(end, by: 1 - count, calendar: calendar)
        return DayKey.keys(from: start, before: DayKey.shifted(end, by: 1, calendar: calendar), calendar: calendar)
    }

    static func intensityLevel(completedCount: Int) -> Int {
        min(4, max(0, completedCount))
    }

    static func heatmap(
        ending end: String,
        dayCount: Int,
        stats: [String: DashboardDayStat],
        calendar: Calendar,
        days: [String]? = nil
    ) -> [DashboardHeatmapDay] {
        let real = days ?? closedDays(ending: end, count: dayCount, calendar: calendar)
        guard let first = real.first, let firstDate = DayKey.date(from: first, calendar: calendar) else {
            return []
        }
        let leading = weekdaySlot(firstDate, calendar: calendar)
        let trailing = (7 - ((leading + real.count) % 7)) % 7
        var cells = (0..<leading).map { paddingCell(slot: $0) }
        cells += real.map { heatmapDay($0, stat: stats[$0]) }
        cells += (0..<trailing).map { paddingCell(slot: leading + real.count + $0) }
        return cells
    }

    static func activities(
        todos: [TodoSnapshot],
        routines: [RoutineSnapshot],
        checks: [CheckSnapshot],
        diaries: [DiarySnapshot],
        todayKey: String,
        calendar: Calendar,
        limit: Int = activityDisplayLimit
    ) -> [DashboardActivity] {
        activityRows(
            todos: todos, routines: routines, diaries: diaries,
            todayKey: todayKey, calendar: calendar, limit: limit,
            marks: mergedMarks(checks),
            window: Set(closedDays(ending: todayKey, count: activityDayCount, calendar: calendar))
        )
    }

    /// 总览不携带手记正文。敏感判定与卡片/搜索共用 `DiaryPrivacy.isSensitive`，不只看是否已加密。
    static func diarySource(_ entry: DiarySnapshot, tags: [TagItem]) -> DiarySnapshot {
        var projected = entry
        let sensitive = DiaryPrivacy.isSensitive(entry, tags: tags)
        projected.text = ""
        projected.isPrivate = sensitive
        projected.isContentAvailable = !sensitive
        return projected
    }
}

private extension DashboardProjection {
    static func emptyStat(_ dayKey: String) -> DashboardDayStat {
        DashboardDayStat.make(dayKey: dayKey, scheduledCount: 0, completedCount: 0, skippedCount: 0)
    }

    /// 热力窗口内每个习惯只解析一次创建日，并按民事日递增星期；不在每个日期再扫一遍习惯。
    static func dayStats(
        days: [String],
        todos: [TodoSnapshot],
        routines: [RoutineSnapshot],
        marks: [UUID: [String: DashboardMark]],
        calendar: Calendar
    ) -> [DashboardDayStat] {
        let todoCounts = todoCountsByDay(todos, calendar: calendar)
        var scheduled = days.map { todoCounts[$0]?.scheduled ?? 0 }
        var completed = days.map { todoCounts[$0]?.completed ?? 0 }
        var skipped = Array(repeating: 0, count: days.count)
        for routine in routines where routine.deletedAt == nil {
            addRoutineStats(
                routine, days: days, marks: marks[routine.id] ?? [:],
                scheduled: &scheduled, completed: &completed, skipped: &skipped, calendar: calendar
            )
        }
        return days.indices.map { index in
            DashboardDayStat.make(
                dayKey: days[index],
                scheduledCount: scheduled[index],
                completedCount: completed[index],
                skippedCount: skipped[index]
            )
        }
    }

    static func addRoutineStats(
        _ routine: RoutineSnapshot,
        days: [String],
        marks: [String: DashboardMark],
        scheduled: inout [Int],
        completed: inout [Int],
        skipped: inout [Int],
        calendar: Calendar
    ) {
        guard DayKey.date(from: routine.createdDayKey, calendar: calendar) != nil else { return }
        let start = firstIndex(days, reaching: routine.createdDayKey)
        let end: Int
        if routine.isEnabled {
            end = days.count
        } else if let pause = routine.pausedOnDayKey, !pause.isEmpty {
            end = firstIndex(days, reaching: pause)
        } else {
            return
        }
        guard start < end else { return }
        let allDays = WeekdayMask.isAll(routine.weekdayMask)
        var weekday = 0
        let stepped: Bool
        if allDays {
            stepped = false
        } else if let date = DayKey.date(from: days[start], calendar: calendar) {
            weekday = calendar.component(.weekday, from: date)
            stepped = true
        } else {
            stepped = false
        }
        for index in start..<end {
            let due: Bool
            if allDays {
                due = true
            } else if stepped {
                due = WeekdayMask.contains(routine.weekdayMask, weekday: weekday)
                weekday = weekday == 7 ? 1 : weekday + 1
            } else {
                due = WeekdayMask.contains(routine.weekdayMask, dayKey: days[index], calendar: calendar)
            }
            guard due else { continue }
            scheduled[index] += 1
            switch marks[days[index]] {
            case .skipped: skipped[index] += 1
            case .done: completed[index] += 1
            default: break
            }
        }
    }

    static func firstIndex(_ days: [String], reaching bound: String) -> Int {
        var low = 0
        var high = days.count
        while low < high {
            let mid = (low + high) / 2
            if days[mid] < bound {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }

    static func endingKeys(
        _ days: [String],
        count: Int,
        ending end: String,
        calendar: Calendar
    ) -> [String] {
        if days.count >= count { return Array(days.suffix(count)) }
        return closedDays(ending: end, count: count, calendar: calendar)
    }

    static func todoCountsByDay(
        _ todos: [TodoSnapshot],
        calendar: Calendar
    ) -> [String: (scheduled: Int, completed: Int)] {
        var counts: [String: (scheduled: Int, completed: Int)] = [:]
        for todo in todos where todo.deletedAt == nil && DayKey.date(from: todo.dayKey, calendar: calendar) != nil {
            var entry = counts[todo.dayKey] ?? (0, 0)
            entry.scheduled += 1
            if todo.isDone { entry.completed += 1 }
            counts[todo.dayKey] = entry
        }
        return counts
    }

    static func mergedMarks(_ checks: [CheckSnapshot]) -> [UUID: [String: DashboardMark]] {
        var marks: [UUID: [String: DashboardMark]] = [:]
        for check in checks {
            guard let next = DashboardMark.merge(marks[check.routineId]?[check.dayKey], check) else { continue }
            marks[check.routineId, default: [:]][check.dayKey] = next
        }
        return marks
    }

    /// 先按 routineId 分组，避免每个习惯再扫整表 checks。连击仍只走 `HabitStreakLogic.calculate`。
    static func streakPeaks(
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

    static func publicDiaryCount(_ diaries: [DiarySnapshot], on dayKey: String) -> Int {
        diaries.filter {
            $0.deletedAt == nil && !$0.isPrivate && $0.isContentAvailable && $0.dayKey == dayKey
        }.count
    }

    static func aggregate(_ stats: [DashboardDayStat], dayKey: String) -> DashboardDayStat {
        DashboardDayStat.make(
            dayKey: dayKey,
            scheduledCount: stats.reduce(0) { $0 + $1.scheduledCount },
            completedCount: stats.reduce(0) { $0 + $1.completedCount },
            skippedCount: stats.reduce(0) { $0 + $1.skippedCount }
        )
    }

    static func weekdaySlot(_ date: Date, calendar: Calendar) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    static func paddingCell(slot: Int) -> DashboardHeatmapDay {
        DashboardHeatmapDay(
            dayKey: "pad-\(slot)",
            completedCount: 0,
            skippedCount: 0,
            scheduledCount: 0,
            intensityLevel: 0,
            isPaddingCell: true
        )
    }

    static func heatmapDay(_ dayKey: String, stat: DashboardDayStat?) -> DashboardHeatmapDay {
        let completed = stat?.completedCount ?? 0
        return DashboardHeatmapDay(
            dayKey: dayKey,
            completedCount: completed,
            skippedCount: stat?.skippedCount ?? 0,
            scheduledCount: stat?.scheduledCount ?? 0,
            intensityLevel: intensityLevel(completedCount: completed),
            isPaddingCell: false
        )
    }
}

private enum DashboardMark: Equatable {
    case done
    case skipped

    static func merge(_ existing: DashboardMark?, _ check: CheckSnapshot) -> DashboardMark? {
        if existing == .skipped || check.isSkipped { return .skipped }
        if existing == .done || check.isDone { return .done }
        return existing
    }
}

private extension DashboardProjection {
    static func activityPrecedes(_ lhs: DashboardActivity, _ rhs: DashboardActivity) -> Bool {
        if lhs.dayKey != rhs.dayKey { return lhs.dayKey > rhs.dayKey }
        let leftKind = DashboardActivityKind.allCases.firstIndex(of: lhs.kind) ?? 0
        let rightKind = DashboardActivityKind.allCases.firstIndex(of: rhs.kind) ?? 0
        if leftKind != rightKind { return leftKind < rightKind }
        return lhs.subjectID.uuidString < rhs.subjectID.uuidString
    }

    static func inWindow(_ dayKey: String, window: Set<String>) -> Bool {
        window.contains(dayKey)
    }

    static func activityRows(
        todos: [TodoSnapshot],
        routines: [RoutineSnapshot],
        diaries: [DiarySnapshot],
        todayKey _: String,
        calendar: Calendar,
        limit: Int,
        marks: [UUID: [String: DashboardMark]],
        window: Set<String>
    ) -> [DashboardActivity] {
        var rows = todoActivities(todos, window: window, calendar: calendar)
        rows += routineActivities(routines, marks: marks, window: window, calendar: calendar)
        rows += diaryActivities(diaries, window: window, calendar: calendar)
        return Array(rows.sorted(by: activityPrecedes).prefix(max(0, limit)))
    }

    static func todoActivities(
        _ todos: [TodoSnapshot],
        window: Set<String>,
        calendar: Calendar
    ) -> [DashboardActivity] {
        todos.flatMap { todo -> [DashboardActivity] in
            var rows: [DashboardActivity] = []
            let createdDay = DayKey.from(todo.createdAt, calendar: calendar)
            if inWindow(createdDay, window: window) {
                rows.append(itemActivity(
                    .created, dayKey: createdDay, id: todo.id, kind: .todo, title: todo.title,
                    route: .inspectItem(id: todo.id, dayKey: todo.dayKey, kind: .todo)
                ))
            }
            if todo.isDone, DayKey.date(from: todo.dayKey, calendar: calendar) != nil,
               inWindow(todo.dayKey, window: window) {
                rows.append(itemActivity(
                    .completed, dayKey: todo.dayKey, id: todo.id, kind: .todo, title: todo.title,
                    route: .inspectItem(id: todo.id, dayKey: todo.dayKey, kind: .todo)
                ))
            }
            if let deleted = todo.deletedAt,
               let trashed = trashActivity(
                   dayKey: DayKey.from(deleted, calendar: calendar), id: todo.id, kind: .todo,
                   title: todo.title, window: window
               ) {
                rows.append(trashed)
            }
            return rows
        }
    }

    static func routineActivities(
        _ routines: [RoutineSnapshot],
        marks: [UUID: [String: DashboardMark]],
        window: Set<String>,
        calendar: Calendar
    ) -> [DashboardActivity] {
        let titles = Dictionary(uniqueKeysWithValues: routines.map { ($0.id, $0.title) })
        var rows = routines.flatMap { routine -> [DashboardActivity] in
            var items: [DashboardActivity] = []
            let createdDay = DayKey.from(routine.createdAt, calendar: calendar)
            if inWindow(createdDay, window: window) {
                let routeDay = WeekdayMask.nextScheduledDayKey(
                    mask: routine.weekdayMask, from: createdDay, calendar: calendar
                )
                items.append(itemActivity(
                    .created, dayKey: createdDay, id: routine.id, kind: .routine, title: routine.title,
                    route: .inspectItem(id: routine.id, dayKey: routeDay, kind: .routine)
                ))
            }
            if let deleted = routine.deletedAt,
               let trashed = trashActivity(
                   dayKey: DayKey.from(deleted, calendar: calendar), id: routine.id, kind: .routine,
                   title: routine.title, window: window
               ) {
                items.append(trashed)
            }
            return items
        }
        for (routineID, days) in marks {
            guard let title = titles[routineID] else { continue }
            for (dayKey, mark) in days {
                guard inWindow(dayKey, window: window) else { continue }
                let kind: DashboardActivityKind = mark == .skipped ? .skipped : .completed
                rows.append(itemActivity(
                    kind, dayKey: dayKey, id: routineID, kind: .routine, title: title,
                    route: .inspectItem(id: routineID, dayKey: dayKey, kind: .routine)
                ))
            }
        }
        return rows
    }

    static func diaryActivities(
        _ diaries: [DiarySnapshot],
        window: Set<String>,
        calendar: Calendar
    ) -> [DashboardActivity] {
        diaries.flatMap { diary -> [DashboardActivity] in
            guard !diary.isPrivate, diary.isContentAvailable else { return [] }
            var rows: [DashboardActivity] = []
            let createdDay = DayKey.from(diary.createdAt, calendar: calendar)
            if diary.deletedAt == nil, inWindow(createdDay, window: window) {
                rows.append(DashboardActivity(
                    id: activityID(.created, subject: diary.id, dayKey: createdDay),
                    kind: .created, dayKey: createdDay, subjectID: diary.id, subjectKind: .diary,
                    title: "", titleKey: "dashboard.activity.diaryCreated", isPrivate: false,
                    route: .diaryPage
                ))
            }
            if let deleted = diary.deletedAt {
                let day = DayKey.from(deleted, calendar: calendar)
                if inWindow(day, window: window) {
                    rows.append(DashboardActivity(
                        id: activityID(.trashed, subject: diary.id, dayKey: day),
                        kind: .trashed, dayKey: day, subjectID: diary.id, subjectKind: .diary,
                        title: "", titleKey: "dashboard.activity.diaryTrashed", isPrivate: false,
                        route: .trash
                    ))
                }
            }
            return rows
        }
    }

    static func itemActivity(
        _ kind: DashboardActivityKind,
        dayKey: String,
        id: UUID,
        kind subject: DashboardSubjectKind,
        title: String,
        route: DashboardActivityRoute
    ) -> DashboardActivity {
        DashboardActivity(
            id: activityID(kind, subject: id, dayKey: dayKey),
            kind: kind, dayKey: dayKey, subjectID: id, subjectKind: subject,
            title: title, titleKey: nil, isPrivate: false, route: route
        )
    }

    static func trashActivity(
        dayKey: String,
        id: UUID,
        kind: DashboardSubjectKind,
        title: String,
        window: Set<String>
    ) -> DashboardActivity? {
        guard inWindow(dayKey, window: window) else { return nil }
        return DashboardActivity(
            id: activityID(.trashed, subject: id, dayKey: dayKey),
            kind: .trashed, dayKey: dayKey, subjectID: id, subjectKind: kind,
            title: title, titleKey: nil, isPrivate: false, route: .trash
        )
    }

    static func activityID(_ kind: DashboardActivityKind, subject: UUID, dayKey: String) -> String {
        "\(kind.rawValue)|\(subject.uuidString)|\(dayKey)"
    }
}
