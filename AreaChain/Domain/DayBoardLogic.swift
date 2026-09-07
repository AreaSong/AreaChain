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
}

struct CheckSnapshot: Equatable {
    var routineId: UUID
    var dayKey: String
    var isDone: Bool
    var isSkipped: Bool = false
}

struct TodoSnapshot: Equatable, Identifiable {
    var id: UUID
    var title: String
    var isDone: Bool
    var dayKey: String
    var createdAt: Date = Date(timeIntervalSince1970: 0)
    var remindMinutes: Int? = nil
    var deletedAt: Date? = nil
}

struct DiarySnapshot: Equatable, Identifiable {
    var id: UUID
    var text: String
    var dayKey: String
    var createdAt: Date
    var deletedAt: Date? = nil
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
    static func isRoutineDue(_ routine: RoutineSnapshot, on dayKey: String) -> Bool {
        guard routine.deletedAt == nil, routine.isEnabled, routine.createdDayKey <= dayKey else { return false }
        return WeekdayMask.contains(routine.weekdayMask, dayKey: dayKey)
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
        guard let mark = check(for: routine, checks: checks, on: dayKey) else { return false }
        return mark.isDone || mark.isSkipped
    }

    static func isRoutineSkipped(
        _ routine: RoutineSnapshot,
        checks: [CheckSnapshot],
        on dayKey: String
    ) -> Bool {
        check(for: routine, checks: checks, on: dayKey)?.isSkipped == true
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
        self.routines(for: dayKey, in: routines)
            .filter { isRoutineDone($0, checks: checks, on: dayKey) }
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

    static func routines(for dayKey: String, in routines: [RoutineSnapshot]) -> [RoutineSnapshot] {
        routines
            .filter { isRoutineDue($0, on: dayKey) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    static func unfinishedRoutines(
        routines: [RoutineSnapshot],
        checks: [CheckSnapshot],
        dayKey: String
    ) -> [RoutineSnapshot] {
        self.routines(for: dayKey, in: routines)
            .filter { !isRoutineDone($0, checks: checks, on: dayKey) }
    }

    static func todos(for dayKey: String, in todos: [TodoSnapshot]) -> [TodoSnapshot] {
        todos.filter { $0.deletedAt == nil && $0.dayKey == dayKey }
    }

    static func unfinishedTodos(todos: [TodoSnapshot], dayKey: String) -> [TodoSnapshot] {
        self.todos(for: dayKey, in: todos).filter { !$0.isDone }
    }

    static func upcomingTodos(todos: [TodoSnapshot], todayKey: String) -> [TodoSnapshot] {
        todos
            .filter { $0.deletedAt == nil && !$0.isDone && $0.dayKey > todayKey }
            .sorted {
                if $0.dayKey != $1.dayKey { return $0.dayKey < $1.dayKey }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
    }

    static func todayBadgeCount(
        routines: [RoutineSnapshot],
        checks: [CheckSnapshot],
        todos: [TodoSnapshot],
        dayKey: String
    ) -> Int {
        unfinishedRoutines(routines: routines, checks: checks, dayKey: dayKey).count
            + unfinishedTodos(todos: todos, dayKey: dayKey).count
    }

    static func yesterdayUnfinished(
        routines: [RoutineSnapshot],
        checks: [CheckSnapshot],
        todos: [TodoSnapshot],
        yesterdayKey: String
    ) -> [UnfinishedItem] {
        let routineItems = unfinishedRoutines(
            routines: routines,
            checks: checks,
            dayKey: yesterdayKey
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
