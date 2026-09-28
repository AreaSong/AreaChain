import Foundation

/// 一次映射的看板快照与闭合索引。失效条件：传入的 routines / checks / todos 数组本身变化。
struct DayBoardSource {
    let routines: [RoutineSnapshot]
    let checks: [CheckSnapshot]
    let todos: [TodoSnapshot]
    let checkIndex: DayBoardCheckIndex
    let routinesByID: [UUID: RoutineSnapshot]
    let todosByID: [UUID: TodoSnapshot]

    init(routines: [RoutineSnapshot], checks: [CheckSnapshot], todos: [TodoSnapshot]) {
        self.routines = routines
        self.checks = checks
        self.todos = todos
        self.checkIndex = DayBoardCheckIndex(checks)
        self.routinesByID = Dictionary(routines.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.todosByID = Dictionary(todos.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    init(routines: [DailyRoutine], checks: [RoutineCheck], todos: [TodoItem]) {
        self.init(
            routines: routines.map(\.snapshot),
            checks: checks.compactMap(\.snapshot),
            todos: todos.map(\.snapshot)
        )
    }
}

/// 某一看板日的未完成 / 已完成快照分区。过滤前先按日切分，避免 open 与 completed 各建一次闭合索引。
struct DayBoardDayLists: Equatable {
    var openTodos: [TodoSnapshot]
    var doneTodos: [TodoSnapshot]
    var openRoutines: [RoutineSnapshot]
    var doneRoutines: [RoutineSnapshot]

    func matchingListed(
        dayKey: String,
        todayKey: String,
        filter: BoardFilter,
        index: DayBoardCheckIndex
    ) -> DayBoardDayLists {
        guard filter.isActive else { return self }
        return DayBoardDayLists(
            openTodos: openTodos.filter {
                Classification.matchesListedRow(
                    $0.classifyBits,
                    dayKey: $0.dayKey,
                    isDone: $0.isDone,
                    remindMinutes: $0.remindMinutes,
                    todayKey: todayKey,
                    filter: filter
                )
            },
            doneTodos: doneTodos.filter {
                Classification.matchesListedRow(
                    $0.classifyBits,
                    dayKey: $0.dayKey,
                    isDone: $0.isDone,
                    remindMinutes: $0.remindMinutes,
                    todayKey: todayKey,
                    filter: filter
                )
            },
            openRoutines: openRoutines.filter {
                Classification.matchesListedRow(
                    $0.classifyBits,
                    dayKey: dayKey,
                    isDone: false,
                    remindMinutes: $0.remindMinutes,
                    todayKey: todayKey,
                    filter: filter
                )
            },
            doneRoutines: doneRoutines.filter {
                Classification.matchesListedRow(
                    $0.classifyBits,
                    dayKey: dayKey,
                    isDone: index.isClosed(routineId: $0.id, dayKey: dayKey),
                    remindMinutes: $0.remindMinutes,
                    todayKey: todayKey,
                    filter: filter
                )
            }
        )
    }
}

enum DayBoardDayProjection {
    static func partition(
        source: DayBoardSource,
        dayKey: String,
        calendar: Calendar = .current
    ) -> DayBoardDayLists {
        let dueRoutines = DayBoardLogic.routines(for: dayKey, in: source.routines, calendar: calendar)
        var openRoutines: [RoutineSnapshot] = []
        var doneRoutines: [RoutineSnapshot] = []
        openRoutines.reserveCapacity(dueRoutines.count)
        doneRoutines.reserveCapacity(dueRoutines.count)
        for routine in dueRoutines {
            if source.checkIndex.isClosed(routineId: routine.id, dayKey: dayKey) {
                doneRoutines.append(routine)
            } else {
                openRoutines.append(routine)
            }
        }
        let dayTodos = DayBoardLogic.todos(for: dayKey, in: source.todos)
        var openTodos: [TodoSnapshot] = []
        var doneTodos: [TodoSnapshot] = []
        openTodos.reserveCapacity(dayTodos.count)
        doneTodos.reserveCapacity(dayTodos.count)
        for todo in dayTodos {
            if todo.isDone {
                doneTodos.append(todo)
            } else {
                openTodos.append(todo)
            }
        }
        return DayBoardDayLists(
            openTodos: openTodos,
            doneTodos: doneTodos,
            openRoutines: openRoutines,
            doneRoutines: doneRoutines
        )
    }
}

/// 今日页芯片、可见行和空态共用的一次投影。不持有 SwiftData 活对象。
struct DayBoardPageSnapshot: Equatable {
    var yesterdayItems: [UnfinishedItem]
    var upcomingTodos: [TodoSnapshot]
    var todayVisibleIDs: [UUID]
    var todayBundleIDs: [String]
    var untaggedOpenTodoCount: Int
    var totalOpenTodoCount: Int
    var isTodayEmpty: Bool
    var yesterdayIDs: Set<UUID>
    var upcomingDayKeys: [UUID: String]
}

enum DayBoardPageProjection {
    static func project(
        source: DayBoardSource,
        todayKey: String,
        yesterdayKey: String,
        filter: BoardFilter,
        calendar: Calendar = .current
    ) -> DayBoardPageSnapshot {
        let yesterdayItems = listedYesterday(
            source: source,
            yesterdayKey: yesterdayKey,
            todayKey: todayKey,
            filter: filter,
            calendar: calendar
        )
        let upcomingTodos = listedUpcoming(
            source: source,
            todayKey: todayKey,
            filter: filter
        )
        let todayLists = DayBoardDayProjection.partition(
            source: source, dayKey: todayKey, calendar: calendar
        )
        let todayVisibleIDs = listedTodayVisibleIDs(from: todayLists, todayKey: todayKey, filter: filter, index: source.checkIndex)
        let dueRoutines = todayLists.openRoutines + todayLists.doneRoutines
        let dayTodos = todayLists.openTodos + todayLists.doneTodos
        let todayBundleIDs = Array(
            Set(
                (dueRoutines.map(\.sourceBundleID) + dayTodos.map(\.sourceBundleID))
                    .filter { !$0.isEmpty }
            )
        ).sorted()
        let openDayTodos = todayLists.openTodos
        let hasClosedTodos = !todayLists.doneTodos.isEmpty
        let hasClosedRoutines = !todayLists.doneRoutines.isEmpty
        return DayBoardPageSnapshot(
            yesterdayItems: yesterdayItems,
            upcomingTodos: upcomingTodos,
            todayVisibleIDs: todayVisibleIDs,
            todayBundleIDs: todayBundleIDs,
            untaggedOpenTodoCount: openDayTodos.filter { TagIDList.parse($0.tagIDs).isEmpty }.count,
            totalOpenTodoCount: openDayTodos.count,
            isTodayEmpty: todayVisibleIDs.isEmpty && !hasClosedTodos && !hasClosedRoutines,
            yesterdayIDs: Set(yesterdayItems.map(\.id)),
            upcomingDayKeys: Dictionary(
                uniqueKeysWithValues: upcomingTodos.map { ($0.id, $0.dayKey) }
            )
        )
    }

    /// 先按 routineId 分组再算连击，避免每行再扫整表 checks。规则仍只走 `HabitStreakLogic.calculate`。
    static func currentStreaks(
        routines: [RoutineSnapshot],
        checks: [CheckSnapshot],
        todayKey: String,
        calendar: Calendar = .current
    ) -> [UUID: Int] {
        currentStreaks(
            routines: routines,
            checksByRoutine: Dictionary(grouping: checks, by: \.routineId),
            todayKey: todayKey,
            calendar: calendar
        )
    }

    static func currentStreaks(
        routines: [RoutineSnapshot],
        checksByRoutine: [UUID: [CheckSnapshot]],
        todayKey: String,
        calendar: Calendar = .current
    ) -> [UUID: Int] {
        var result: [UUID: Int] = [:]
        result.reserveCapacity(routines.count)
        for routine in routines {
            result[routine.id] = HabitStreakLogic.calculate(
                routine: routine,
                checks: checksByRoutine[routine.id] ?? [],
                todayKey: todayKey,
                calendar: calendar
            ).currentStreak
        }
        return result
    }

    private static func listedYesterday(
        source: DayBoardSource,
        yesterdayKey: String,
        todayKey: String,
        filter: BoardFilter,
        calendar: Calendar
    ) -> [UnfinishedItem] {
        let unfinished = DayBoardLogic.yesterdayUnfinished(
            routines: source.routines,
            index: source.checkIndex,
            todos: source.todos,
            yesterdayKey: yesterdayKey,
            calendar: calendar
        )
        return unfinished.filter { item in
            if item.kind == .todo, let todo = source.todosByID[item.id] {
                return matchesListed(
                    todo.classifyBits,
                    dayKey: todo.dayKey,
                    isDone: todo.isDone,
                    remindMinutes: todo.remindMinutes,
                    todayKey: todayKey,
                    filter: filter
                )
            }
            guard let routine = source.routinesByID[item.id] else { return false }
            return matchesListed(
                routine.classifyBits,
                dayKey: yesterdayKey,
                isDone: source.checkIndex.isClosed(routineId: routine.id, dayKey: yesterdayKey),
                remindMinutes: routine.remindMinutes,
                todayKey: todayKey,
                filter: filter
            )
        }
    }

    private static func listedUpcoming(
        source: DayBoardSource,
        todayKey: String,
        filter: BoardFilter
    ) -> [TodoSnapshot] {
        DayBoardLogic.upcomingTodos(todos: source.todos, todayKey: todayKey).filter {
            matchesListed(
                $0.classifyBits,
                dayKey: $0.dayKey,
                isDone: $0.isDone,
                remindMinutes: $0.remindMinutes,
                todayKey: todayKey,
                filter: filter
            )
        }
    }

    private static func listedTodayVisibleIDs(
        from lists: DayBoardDayLists,
        todayKey: String,
        filter: BoardFilter,
        index: DayBoardCheckIndex
    ) -> [UUID] {
        let visible = lists.matchingListed(
            dayKey: todayKey,
            todayKey: todayKey,
            filter: filter,
            index: index
        )
        let entries = visible.openTodos.map { (BoardItemReference.todo($0.id), $0.boardSortKey) }
            + visible.openRoutines.map { (BoardItemReference.recurring($0.id), $0.boardSortKey) }
        return entries
            .sorted { Classification.precedes($0.1, $1.1) }
            .map(\.0.modelID)
    }

    private static func matchesListed(
        _ bits: ClassifyBits,
        dayKey: String,
        isDone: Bool,
        remindMinutes: Int?,
        todayKey: String,
        filter: BoardFilter
    ) -> Bool {
        guard filter.isActive else { return true }
        return Classification.matchesListedRow(
            bits,
            dayKey: dayKey,
            isDone: isDone,
            remindMinutes: remindMinutes,
            todayKey: todayKey,
            filter: filter
        )
    }
}
