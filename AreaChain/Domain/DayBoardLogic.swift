import Foundation

struct RoutineSnapshot: Equatable, Identifiable {
    var id: UUID
    var title: String
    var sortOrder: Int
    var isEnabled: Bool
    var createdDayKey: String
    var weekdayMask: Int = WeekdayMask.all
    var createdAt: Date = Date(timeIntervalSince1970: 0)
    var remindMinutes: Int? = nil
    var deletedAt: Date? = nil
    var tagIDs: String = ""
    var isImportant: Bool = false
    var isUrgent: Bool = false
    var sourceBundleID: String = ""
    var notes: String = ""
    var pausedOnDayKey: String? = nil

    var classifyBits: ClassifyBits {
        ClassifyBits(
            tagIDs: tagIDs,
            isImportant: isImportant,
            isUrgent: isUrgent,
            sourceBundleID: sourceBundleID
        )
    }

    var boardSortKey: BoardSortKey {
        BoardSortKey(
            sortOrder: sortOrder,
            isImportant: isImportant,
            isUrgent: isUrgent,
            remindMinutes: remindMinutes,
            createdAt: createdAt
        )
    }
}

struct CheckSnapshot: Equatable {
    var routineId: UUID
    var dayKey: String
    var isDone: Bool
    var isSkipped: Bool = false
}

struct SubtaskSnapshot: Equatable, Identifiable {
    var id: UUID
    var todoId: UUID
    var title: String
    var isDone: Bool
    var sortOrder: Int = 0
    var createdAt: Date = Date(timeIntervalSince1970: 0)
    var deletedAt: Date? = nil
    var tagIDs: String = ""
}

struct TodoSnapshot: Equatable, Identifiable {
    var id: UUID
    var title: String
    var isDone: Bool
    var dayKey: String
    var createdAt: Date = Date(timeIntervalSince1970: 0)
    var remindMinutes: Int? = nil
    var dueMinutes: Int? = nil
    var sortOrder: Int = 0
    var deletedAt: Date? = nil
    var tagIDs: String = ""
    var isImportant: Bool = false
    var isUrgent: Bool = false
    var sourceBundleID: String = ""
    var notes: String = ""
    var subtasks: [SubtaskSnapshot] = []

    var classifyBits: ClassifyBits {
        ClassifyBits(
            tagIDs: tagIDs,
            isImportant: isImportant,
            isUrgent: isUrgent,
            sourceBundleID: sourceBundleID
        )
    }

    var boardSortKey: BoardSortKey {
        BoardSortKey(
            sortOrder: sortOrder,
            isImportant: isImportant,
            isUrgent: isUrgent,
            remindMinutes: remindMinutes,
            createdAt: createdAt
        )
    }
}

struct DiarySnapshot: Equatable, Identifiable {
    var id: UUID
    var text: String
    var dayKey: String
    var createdAt: Date
    var deletedAt: Date? = nil
    var tagIDs: String = ""
    var isPinned: Bool = false
    var isPrivate: Bool = false
    var isContentAvailable: Bool = true
}

enum UnfinishedKind: String, Equatable {
    case routine
    case todo
}

struct UnfinishedItem: Equatable, Identifiable {
    var id: UUID
    var title: String
    var kind: UnfinishedKind
}

enum DayBoardLogic {
    /// 看板闭合看同一 (routineId, dayKey) 的**第一条**打卡；后写的完成/跳过不能覆盖先写的未闭合。
    /// 待处理逾期用「任一条完成或跳过即闭合」，两套规则不能合成一张表。
    /// 多次查询时复用 `DayBoardCheckIndex`，不要每次再扫一遍 checks。
    static func isRoutineDue(
        _ routine: RoutineSnapshot,
        on dayKey: String,
        calendar: Calendar = .current
    ) -> Bool {
        guard routine.deletedAt == nil, routine.isEnabled, routine.createdDayKey <= dayKey else { return false }
        return WeekdayMask.contains(routine.weekdayMask, dayKey: dayKey, calendar: calendar)
    }

    static func check(
        for routine: RoutineSnapshot,
        checks: [CheckSnapshot],
        on dayKey: String
    ) -> CheckSnapshot? {
        checks.first { $0.routineId == routine.id && $0.dayKey == dayKey }
    }

    static func isRoutineDone(
        _ routine: RoutineSnapshot,
        checks: [CheckSnapshot],
        on dayKey: String
    ) -> Bool {
        isRoutineDone(routine, index: DayBoardCheckIndex(checks), on: dayKey)
    }

    static func isRoutineDone(
        _ routine: RoutineSnapshot,
        index: DayBoardCheckIndex,
        on dayKey: String
    ) -> Bool {
        index.isClosed(routineId: routine.id, dayKey: dayKey)
    }

    static func isRoutineSkipped(
        _ routine: RoutineSnapshot,
        checks: [CheckSnapshot],
        on dayKey: String
    ) -> Bool {
        isRoutineSkipped(routine, index: DayBoardCheckIndex(checks), on: dayKey)
    }

    static func isRoutineSkipped(
        _ routine: RoutineSnapshot,
        index: DayBoardCheckIndex,
        on dayKey: String
    ) -> Bool {
        index.isSkipped(routineId: routine.id, dayKey: dayKey)
    }

    static func openRoutines(
        routines: [RoutineSnapshot],
        checks: [CheckSnapshot],
        dayKey: String
    ) -> [RoutineSnapshot] {
        unfinishedRoutines(routines: routines, checks: checks, dayKey: dayKey)
    }

    static func completedRoutines(
        routines: [RoutineSnapshot],
        checks: [CheckSnapshot],
        dayKey: String
    ) -> [RoutineSnapshot] {
        completedRoutines(routines: routines, index: DayBoardCheckIndex(checks), dayKey: dayKey)
    }

    static func completedRoutines(
        routines: [RoutineSnapshot],
        index: DayBoardCheckIndex,
        dayKey: String,
        calendar: Calendar = .current
    ) -> [RoutineSnapshot] {
        self.routines(for: dayKey, in: routines, calendar: calendar)
            .filter { index.isClosed(routineId: $0.id, dayKey: dayKey) }
    }

    static func openTodos(todos: [TodoSnapshot], dayKey: String) -> [TodoSnapshot] {
        unfinishedTodos(todos: todos, dayKey: dayKey)
    }

    static func completedTodos(todos: [TodoSnapshot], dayKey: String) -> [TodoSnapshot] {
        self.todos(for: dayKey, in: todos).filter(\.isDone)
    }

    static func moveTodo(_ todo: TodoSnapshot, to dayKey: String) -> TodoSnapshot {
        var next = todo
        next.dayKey = dayKey
        return next
    }

    static func routines(
        for dayKey: String,
        in routines: [RoutineSnapshot],
        calendar: Calendar = .current
    ) -> [RoutineSnapshot] {
        routines
            .filter { isRoutineDue($0, on: dayKey, calendar: calendar) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    static func unfinishedRoutines(
        routines: [RoutineSnapshot],
        checks: [CheckSnapshot],
        dayKey: String
    ) -> [RoutineSnapshot] {
        unfinishedRoutines(routines: routines, index: DayBoardCheckIndex(checks), dayKey: dayKey)
    }

    static func unfinishedRoutines(
        routines: [RoutineSnapshot],
        index: DayBoardCheckIndex,
        dayKey: String,
        calendar: Calendar = .current
    ) -> [RoutineSnapshot] {
        self.routines(for: dayKey, in: routines, calendar: calendar)
            .filter { !index.isClosed(routineId: $0.id, dayKey: dayKey) }
    }

    static func todos(for dayKey: String, in todos: [TodoSnapshot]) -> [TodoSnapshot] {
        todos.filter { $0.deletedAt == nil && $0.dayKey == dayKey }
    }

    static func unfinishedTodos(todos: [TodoSnapshot], dayKey: String) -> [TodoSnapshot] {
        self.todos(for: dayKey, in: todos).filter { !$0.isDone }
    }

    static func upcomingTodos(todos: [TodoSnapshot], todayKey: String) -> [TodoSnapshot] {
        AgendaProjection.upcomingTodos(todos: todos, todayKey: todayKey)
    }

    /// 今日进度。工作台进度环、侧栏今日角标和菜单栏共用；含当天排定的一次性事项和重复事项，跳过算闭合，子任务不算顶层。
    static func todayProgress(
        routines: [RoutineSnapshot],
        checks: [CheckSnapshot],
        todos: [TodoSnapshot],
        dayKey: String,
        calendar: Calendar = .current
    ) -> BoardProgress {
        let dueTodos = self.todos(for: dayKey, in: todos)
        let dueRoutines = self.routines(for: dayKey, in: routines, calendar: calendar)
        let lookup = DayBoardCheckIndex(checks)
        let completed = dueTodos.filter(\.isDone).count
            + dueRoutines.filter { lookup.isClosed(routineId: $0.id, dayKey: dayKey) }.count
        return BoardProgress(completed: completed, total: dueTodos.count + dueRoutines.count)
    }

    static func todayBadgeCount(
        routines: [RoutineSnapshot],
        checks: [CheckSnapshot],
        todos: [TodoSnapshot],
        dayKey: String,
        calendar: Calendar = .current
    ) -> Int {
        let progress = todayProgress(
            routines: routines, checks: checks, todos: todos, dayKey: dayKey, calendar: calendar
        )
        return progress.total - progress.completed
    }

    static func monthUnfinished(
        routines: [RoutineSnapshot],
        checks: [CheckSnapshot],
        todos: [TodoSnapshot],
        containing dayKey: String,
        calendar: Calendar = .current
    ) -> [String: Int] {
        let keys = DayKey.daysInMonth(containing: dayKey, calendar: calendar)
        guard !keys.isEmpty else { return [:] }
        let lookup = DayBoardCheckIndex(checks)
        var openTodosByDay: [String: Int] = [:]
        for todo in todos where todo.deletedAt == nil && !todo.isDone {
            openTodosByDay[todo.dayKey, default: 0] += 1
        }
        var weekdayByDay: [String: Int] = [:]
        weekdayByDay.reserveCapacity(keys.count)
        for key in keys {
            if let date = DayKey.date(from: key, calendar: calendar) {
                weekdayByDay[key] = calendar.component(.weekday, from: date)
            }
        }
        var counts: [String: Int] = [:]
        counts.reserveCapacity(keys.count)
        for key in keys {
            var unfinished = openTodosByDay[key] ?? 0
            let weekday = weekdayByDay[key]
            for routine in routines {
                if isDue(routine, on: key, weekday: weekday),
                   !lookup.isClosed(routineId: routine.id, dayKey: key) {
                    unfinished += 1
                }
            }
            counts[key] = unfinished
        }
        return counts
    }

    private static func isDue(_ routine: RoutineSnapshot, on dayKey: String, weekday: Int?) -> Bool {
        guard routine.deletedAt == nil, routine.isEnabled, routine.createdDayKey <= dayKey, let weekday else {
            return false
        }
        return WeekdayMask.contains(routine.weekdayMask, weekday: weekday)
    }

    static func yesterdayUnfinished(
        routines: [RoutineSnapshot],
        checks: [CheckSnapshot],
        todos: [TodoSnapshot],
        yesterdayKey: String
    ) -> [UnfinishedItem] {
        yesterdayUnfinished(
            routines: routines,
            index: DayBoardCheckIndex(checks),
            todos: todos,
            yesterdayKey: yesterdayKey
        )
    }

    static func yesterdayUnfinished(
        routines: [RoutineSnapshot],
        index: DayBoardCheckIndex,
        todos: [TodoSnapshot],
        yesterdayKey: String,
        calendar: Calendar = .current
    ) -> [UnfinishedItem] {
        let routineItems = unfinishedRoutines(
            routines: routines,
            index: index,
            dayKey: yesterdayKey,
            calendar: calendar
        ).map { UnfinishedItem(id: $0.id, title: $0.title, kind: .routine) }

        let todoItems = unfinishedTodos(todos: todos, dayKey: yesterdayKey)
            .map { UnfinishedItem(id: $0.id, title: $0.title, kind: .todo) }

        return routineItems + todoItems
    }

    static func diaries(for dayKey: String, in entries: [DiarySnapshot]) -> [DiarySnapshot] {
        entries
            .filter { $0.deletedAt == nil && $0.dayKey == dayKey }
            .sorted { $0.createdAt > $1.createdAt }
    }
}

enum BoardFocusDay {
    static func key(
        for id: UUID,
        listDayKey: String,
        yesterdayKey: String,
        yesterdayIDs: Set<UUID>,
        upcomingDayKeys: [UUID: String]
    ) -> String {
        if yesterdayIDs.contains(id) {
            return yesterdayKey
        }
        if let upcoming = upcomingDayKeys[id] {
            return upcoming
        }
        return listDayKey
    }

    /// 空格勾选跟点选检查日走同一天。同一习惯既在昨天芯片又在今日清单时，不能只凭 leftover 集合覆盖今日点选。
    static func checkDay(inspecting: String, mapped: String, listDayKey: String) -> String {
        if inspecting == listDayKey {
            return listDayKey
        }
        if mapped == inspecting {
            return inspecting
        }
        return listDayKey
    }
}
