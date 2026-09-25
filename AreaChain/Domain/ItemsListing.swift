import Foundation

enum ItemKindScope: String, Equatable, CaseIterable {
    case all
    case oneOff
    case recurring

    var titleKey: String {
        switch self {
        case .all: "items.kind.all"
        case .oneOff: "items.kind.oneOff"
        case .recurring: "items.kind.recurring"
        }
    }
}

enum TodoStatusScope: String, Equatable, CaseIterable {
    case all
    case open
    case done

    var titleKey: String {
        switch self {
        case .all: "items.status.all"
        case .open: "items.status.open"
        case .done: "items.status.done"
        }
    }
}

enum RoutineStatusScope: String, Equatable, CaseIterable {
    case all
    case enabled
    case disabled

    var titleKey: String {
        switch self {
        case .all: "items.status.all"
        case .enabled: "items.status.enabled"
        case .disabled: "items.status.disabled"
        }
    }
}

struct ItemsListingQuery: Equatable {
    var kind: ItemKindScope = .all
    var todoStatus: TodoStatusScope = .all
    var routineStatus: RoutineStatusScope = .all
    var filter: BoardFilter = BoardFilter()
    var todayKey: String

    var isNarrowed: Bool {
        kind != .all || todoStatus != .all || routineStatus != .all || filter.isActive
    }

    func cleared() -> ItemsListingQuery {
        ItemsListingQuery(todayKey: todayKey)
    }
}

struct ListedTodo: Equatable, Identifiable {
    var todo: TodoSnapshot
    var subtasks: [SubtaskSnapshot]

    var id: UUID { todo.id }
}

enum ItemsListing {
    static func todos(_ todos: [TodoSnapshot], query: ItemsListingQuery, calendar: Calendar = .current) -> [ListedTodo] {
        guard query.kind != .recurring else { return [] }
        let matched = activeTodos(todos, calendar: calendar).filter { todo in
            statusAllows(todo, query.todoStatus) && matchesTodo(todo, query: query, calendar: calendar)
        }
        return sortedTodos(matched).map { todo in
            ListedTodo(todo: todo, subtasks: visibleSubtasks(of: todo, query: query))
        }
    }

    static func routines(
        _ routines: [RoutineSnapshot],
        checks: [CheckSnapshot],
        query: ItemsListingQuery,
        calendar: Calendar = .current
    ) -> [RoutineSnapshot] {
        guard query.kind != .oneOff else { return [] }
        let matched = routines.filter { routine in
            routine.deletedAt == nil
                && statusAllows(routine, query.routineStatus)
                && matchesRoutine(routine, checks: checks, query: query, calendar: calendar)
        }
        return sortedRoutines(matched)
    }

    static func sortedTodos(_ todos: [TodoSnapshot]) -> [TodoSnapshot] {
        todos.sorted { left, right in
            if left.isDone != right.isDone { return !left.isDone }
            if !left.isDone, left.dayKey != right.dayKey { return left.dayKey < right.dayKey }
            if !left.isDone {
                let leftFirst = Classification.precedes(left.boardSortKey, right.boardSortKey)
                let rightFirst = Classification.precedes(right.boardSortKey, left.boardSortKey)
                if leftFirst != rightFirst { return leftFirst }
            } else if left.createdAt != right.createdAt {
                return left.createdAt < right.createdAt
            }
            return left.id.uuidString < right.id.uuidString
        }
    }

    static func sortedRoutines(_ routines: [RoutineSnapshot]) -> [RoutineSnapshot] {
        routines.sorted { left, right in
            if left.isEnabled != right.isEnabled { return left.isEnabled }
            if left.sortOrder != right.sortOrder { return left.sortOrder < right.sortOrder }
            return left.id.uuidString < right.id.uuidString
        }
    }

    static func visibleSubtasks(of todo: TodoSnapshot, query: ItemsListingQuery) -> [SubtaskSnapshot] {
        let live = todo.subtasks.filter { $0.deletedAt == nil }.sorted { $0.sortOrder < $1.sortOrder }
        guard let tagID = query.filter.tagID, tagID != BoardFilter.noneID else { return live }
        guard !TagIDList.contains(todo.tagIDs, tagID) else { return live }
        return live.filter { TagIDList.contains($0.tagIDs, tagID) }
    }

    private static func activeTodos(_ todos: [TodoSnapshot], calendar: Calendar) -> [TodoSnapshot] {
        todos.filter { $0.deletedAt == nil && DayKey.date(from: $0.dayKey, calendar: calendar) != nil }
    }

    private static func statusAllows(_ todo: TodoSnapshot, _ status: TodoStatusScope) -> Bool {
        switch status {
        case .all: true
        case .open: !todo.isDone
        case .done: todo.isDone
        }
    }

    private static func statusAllows(_ routine: RoutineSnapshot, _ status: RoutineStatusScope) -> Bool {
        switch status {
        case .all: true
        case .enabled: routine.isEnabled
        case .disabled: !routine.isEnabled
        }
    }

    private static func matchesTodo(
        _ todo: TodoSnapshot,
        query: ItemsListingQuery,
        calendar: Calendar
    ) -> Bool {
        let bits = ClassifyBits(
            tagIDs: todo.tagIDs,
            isImportant: todo.isImportant,
            isUrgent: todo.isUrgent,
            sourceBundleID: todo.sourceBundleID
        )
        let untagged = query.filter.withTag(nil)
        guard Classification.matches(bits, filter: untagged) else { return false }
        guard matchesTodoDate(todo, scope: query.filter.dateScope, todayKey: query.todayKey, calendar: calendar) else {
            return false
        }
        guard let tagID = query.filter.tagID else { return true }
        if tagID == BoardFilter.noneID {
            return TagIDList.parse(todo.tagIDs).isEmpty
        }
        if TagIDList.contains(todo.tagIDs, tagID) { return true }
        return todo.subtasks.contains { $0.deletedAt == nil && TagIDList.contains($0.tagIDs, tagID) }
    }

    private static func matchesTodoDate(
        _ todo: TodoSnapshot,
        scope: DateFilterScope,
        todayKey: String,
        calendar: Calendar
    ) -> Bool {
        guard DayKey.date(from: todo.dayKey, calendar: calendar) != nil else { return scope == .all }
        return Classification.matchesDate(
            dayKey: todo.dayKey, isDone: todo.isDone, todayKey: todayKey, scope: scope
        )
    }

    private static func matchesRoutine(
        _ routine: RoutineSnapshot,
        checks: [CheckSnapshot],
        query: ItemsListingQuery,
        calendar: Calendar
    ) -> Bool {
        guard Classification.matches(routine.classifyBits, filter: query.filter.withTag(nil)) else { return false }
        if let tagID = query.filter.tagID {
            if tagID == BoardFilter.noneID {
                guard TagIDList.parse(routine.tagIDs).isEmpty else { return false }
            } else if !TagIDList.contains(routine.tagIDs, tagID) {
                return false
            }
        }
        return matchesRoutineDate(routine, checks: checks, scope: query.filter.dateScope, todayKey: query.todayKey, calendar: calendar)
    }

    private static func matchesRoutineDate(
        _ routine: RoutineSnapshot,
        checks: [CheckSnapshot],
        scope: DateFilterScope,
        todayKey: String,
        calendar: Calendar
    ) -> Bool {
        if scope == .all { return true }
        guard routine.isEnabled, routine.deletedAt == nil else { return false }
        switch scope {
        case .all:
            return true
        case .today:
            return DayBoardLogic.isRoutineDue(routine, on: todayKey)
        case .overdue:
            return !AgendaProjection.overdueRoutines(
                routines: [routine], checks: checks, todayKey: todayKey, calendar: calendar
            ).isEmpty
        case .upcoming:
            return AgendaProjection.nextDay(after: todayKey, routine: routine, calendar: calendar) != nil
        case .recent:
            guard let horizon = horizonDay(routine, todayKey: todayKey, calendar: calendar) else { return false }
            let weekAhead = DayKey.shifted(todayKey, by: 7, calendar: calendar)
            return horizon >= todayKey && horizon <= weekAhead
        }
    }

    private static func horizonDay(
        _ routine: RoutineSnapshot,
        todayKey: String,
        calendar: Calendar
    ) -> String? {
        if DayBoardLogic.isRoutineDue(routine, on: todayKey) { return todayKey }
        return AgendaProjection.nextDay(after: todayKey, routine: routine, calendar: calendar)
    }
}
