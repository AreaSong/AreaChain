import Foundation

enum PendingLane: String, Equatable, CaseIterable {
    case overdue
    case upcoming
}

enum PendingLanePolicy {
    static func initial(overdueCount: Int) -> PendingLane {
        overdueCount > 0 ? .overdue : .upcoming
    }
}

struct PendingLaneSession: Equatable {
    var lane: PendingLane
    var userChose: Bool

    init(overdueCount: Int) {
        lane = PendingLanePolicy.initial(overdueCount: overdueCount)
        userChose = false
    }

    mutating func choose(_ next: PendingLane) {
        lane = next
        userChose = true
    }

    mutating func refreshDefault(overdueCount: Int) {
        guard !userChose else { return }
        lane = PendingLanePolicy.initial(overdueCount: overdueCount)
    }
}

struct RoutineAgendaRow: Equatable, Identifiable {
    var routineID: UUID
    var displayDayKey: String
    var openCount: Int
    var sortOrder: Int
    var isEnabled: Bool
    var boardSortKey: BoardSortKey

    var id: UUID { routineID }
}

enum AgendaEntry: Equatable, Identifiable {
    case todo(TodoSnapshot)
    case routine(RoutineAgendaRow)

    var id: String {
        switch self {
        case .todo(let todo):
            return BoardItemReference.todo(todo.id).id
        case .routine(let row):
            return BoardItemReference.recurring(row.routineID).id
        }
    }

    var modelID: UUID {
        switch self {
        case .todo(let todo):
            return todo.id
        case .routine(let row):
            return row.routineID
        }
    }

    var dayKey: String {
        switch self {
        case .todo(let todo):
            return todo.dayKey
        case .routine(let row):
            return row.displayDayKey
        }
    }
}

struct PendingProjection: Equatable {
    var overdue: [AgendaEntry]
    var upcoming: [AgendaEntry]

    var overdueCount: Int { overdue.count }
    var upcomingCount: Int { upcoming.count }

    func entries(for lane: PendingLane) -> [AgendaEntry] {
        switch lane {
        case .overdue: overdue
        case .upcoming: upcoming
        }
    }
}

enum BatchSelectionKind: Equatable {
    case empty
    case todosOnly
    case routinesOnly
    case mixed
}

struct BatchCapability: Equatable {
    var kind: BatchSelectionKind
    var canReschedule: Bool
    var canComplete: Bool
    var canTag: Bool
    var canTrash: Bool
    var canToggleEnabled: Bool
    var noteKey: String?
}

enum AgendaProjection {
    static func pending(
        routines: [RoutineSnapshot],
        checks: [CheckSnapshot],
        todos: [TodoSnapshot],
        todayKey: String,
        calendar: Calendar = .current
    ) -> PendingProjection {
        PendingProjection(
            overdue: sorted(
                overdueTodos(todos: todos, todayKey: todayKey, calendar: calendar).map(AgendaEntry.todo)
                    + overdueRoutines(
                        routines: routines, checks: checks, todayKey: todayKey, calendar: calendar
                    ).map(AgendaEntry.routine)
            ),
            upcoming: sorted(
                upcomingTodos(todos: todos, todayKey: todayKey, calendar: calendar).map(AgendaEntry.todo)
                    + upcomingRoutines(
                        routines: routines, todayKey: todayKey, calendar: calendar
                    ).map(AgendaEntry.routine)
            )
        )
    }

    static func overdueTodos(
        todos: [TodoSnapshot],
        todayKey: String,
        calendar: Calendar = .current
    ) -> [TodoSnapshot] {
        sortedTodos(todos.filter {
            $0.deletedAt == nil && !$0.isDone && isValid($0.dayKey, calendar: calendar) && $0.dayKey < todayKey
        })
    }

    static func upcomingTodos(
        todos: [TodoSnapshot],
        todayKey: String,
        calendar: Calendar = .current
    ) -> [TodoSnapshot] {
        sortedTodos(todos.filter {
            $0.deletedAt == nil && !$0.isDone && isValid($0.dayKey, calendar: calendar) && $0.dayKey > todayKey
        })
    }

    static func overdueRoutines(
        routines: [RoutineSnapshot],
        checks: [CheckSnapshot],
        todayKey: String,
        calendar: Calendar = .current
    ) -> [RoutineAgendaRow] {
        let yesterday = DayKey.shifted(todayKey, by: -1, calendar: calendar)
        return routines.compactMap { routine in
            guard isActive(routine), isValid(routine.createdDayKey, calendar: calendar) else { return nil }
            guard routine.createdDayKey <= yesterday else { return nil }
            let open = openScheduledDays(
                routine, checks: checks, from: routine.createdDayKey, through: yesterday, calendar: calendar
            )
            guard let latest = open.max() else { return nil }
            return row(routine, dayKey: latest, openCount: open.count)
        }
    }

    static func upcomingRoutines(
        routines: [RoutineSnapshot],
        todayKey: String,
        calendar: Calendar = .current
    ) -> [RoutineAgendaRow] {
        routines.compactMap { routine in
            guard isActive(routine), let next = nextDay(after: todayKey, routine: routine, calendar: calendar) else {
                return nil
            }
            return row(routine, dayKey: next, openCount: 0)
        }
    }

    static func nextDay(
        after todayKey: String,
        routine: RoutineSnapshot,
        calendar: Calendar = .current
    ) -> String? {
        guard isValid(routine.createdDayKey, calendar: calendar) else { return nil }
        let tomorrow = DayKey.shifted(todayKey, by: 1, calendar: calendar)
        let start = max(tomorrow, routine.createdDayKey)
        let next = WeekdayMask.nextScheduledDayKey(mask: routine.weekdayMask, from: start, calendar: calendar)
        return next > todayKey ? next : nil
    }

    /// 全部事项打开检查器时用的日期：今天排定用今天，否则用下一次排定日。
    /// 没有下一次排定日时用暂停日或创建日，不用今天冒充检查日。
    static func inspectionDay(
        for routine: RoutineSnapshot,
        todayKey: String,
        calendar: Calendar = .current
    ) -> String {
        if DayBoardLogic.isRoutineDue(routine, on: todayKey, calendar: calendar) {
            return todayKey
        }
        if let next = nextDay(after: todayKey, routine: routine, calendar: calendar) {
            return next
        }
        if let paused = routine.pausedOnDayKey, isValid(paused, calendar: calendar) {
            return paused
        }
        if isValid(routine.createdDayKey, calendar: calendar) {
            return routine.createdDayKey
        }
        return todayKey
    }

    static func filtered(
        _ entries: [AgendaEntry],
        filter: BoardFilter,
        routines: [RoutineSnapshot],
        checks: [CheckSnapshot],
        todayKey: String
    ) -> [AgendaEntry] {
        guard filter.isActive else { return entries }
        let query = ItemsListingQuery(filter: filter, todayKey: todayKey)
        return entries.filter { entry in
            switch entry {
            case .todo(let todo):
                return !ItemsListing.todos([todo], query: query).isEmpty
            case .routine(let row):
                guard let routine = routines.first(where: { $0.id == row.routineID }) else { return false }
                return !ItemsListing.routines([routine], checks: checks, query: query).isEmpty
            }
        }
    }

    /// 把星期规则和逾期次数、下一次排定日拼在同一行。空片段省略。
    /// 逾期次数至少为 1 时，行内要同时带上最近逾期日和次数。
    static func overduePresentation(dayKey: String, count: Int) -> (dayKey: String, count: Int)? {
        guard count > 0 else { return nil }
        return (dayKey, count)
    }

    static func routineNote(schedule: String?, extras: [String]) -> String? {
        let parts = extras.filter { !$0.isEmpty } + (schedule.map { [$0] } ?? [])
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " · ")
    }

    static func capability(
        ids: Set<UUID>,
        todos: [TodoSnapshot],
        routines: [RoutineSnapshot],
        todayKey: String,
        routineCheckDays: [UUID: String]? = nil
    ) -> BatchCapability {
        let todoIDs = Set(todos.filter { $0.deletedAt == nil && ids.contains($0.id) }.map(\.id))
        let routineIDs = Set(routines.filter { $0.deletedAt == nil && ids.contains($0.id) }.map(\.id))
        let kind: BatchSelectionKind
        if todoIDs.isEmpty && routineIDs.isEmpty {
            kind = .empty
        } else if routineIDs.isEmpty {
            kind = .todosOnly
        } else if todoIDs.isEmpty {
            kind = .routinesOnly
        } else {
            kind = .mixed
        }
        let routinesDue = routinesCanComplete(
            routineIDs, routines: routines, todayKey: todayKey, routineCheckDays: routineCheckDays
        )
        switch kind {
        case .empty:
            return BatchCapability(
                kind: kind, canReschedule: false, canComplete: false, canTag: false,
                canTrash: false, canToggleEnabled: false, noteKey: "items.batch.none"
            )
        case .todosOnly:
            return BatchCapability(
                kind: kind, canReschedule: true, canComplete: true, canTag: true,
                canTrash: true, canToggleEnabled: false, noteKey: nil
            )
        case .routinesOnly:
            return BatchCapability(
                kind: kind, canReschedule: false, canComplete: routinesDue, canTag: true,
                canTrash: true, canToggleEnabled: true, noteKey: "items.routine.cannotMove"
            )
        case .mixed:
            return BatchCapability(
                kind: kind, canReschedule: false, canComplete: false, canTag: true,
                canTrash: true, canToggleEnabled: false, noteKey: "items.batch.mixed"
            )
        }
    }

    static func openScheduledDays(
        _ routine: RoutineSnapshot,
        checks: [CheckSnapshot],
        from start: String,
        through end: String,
        calendar: Calendar = .current
    ) -> [String] {
        let closed = Set(
            checks.filter { $0.routineId == routine.id && ($0.isDone || $0.isSkipped) }.map(\.dayKey)
        )
        var days: [String] = []
        var cursor = start
        var steps = 0
        while cursor <= end, steps < 4000 {
            if WeekdayMask.contains(routine.weekdayMask, dayKey: cursor, calendar: calendar), !closed.contains(cursor) {
                days.append(cursor)
            }
            let next = DayKey.shifted(cursor, by: 1, calendar: calendar)
            guard next > cursor else { break }
            cursor = next
            steps += 1
        }
        return days
    }

    private static func routinesCanComplete(
        _ routineIDs: Set<UUID>,
        routines: [RoutineSnapshot],
        todayKey: String,
        routineCheckDays: [UUID: String]?
    ) -> Bool {
        guard !routineIDs.isEmpty else { return false }
        if let routineCheckDays {
            return routineIDs.allSatisfy { routineCheckDays[$0]?.isEmpty == false }
        }
        return routines.filter { routineIDs.contains($0.id) }.allSatisfy {
            DayBoardLogic.isRoutineDue($0, on: todayKey)
        }
    }

    private static func isActive(_ routine: RoutineSnapshot) -> Bool {
        routine.deletedAt == nil && routine.isEnabled
    }

    private static func isValid(_ key: String, calendar: Calendar) -> Bool {
        DayKey.date(from: key, calendar: calendar) != nil
    }

    private static func row(_ routine: RoutineSnapshot, dayKey: String, openCount: Int) -> RoutineAgendaRow {
        RoutineAgendaRow(
            routineID: routine.id,
            displayDayKey: dayKey,
            openCount: openCount,
            sortOrder: routine.sortOrder,
            isEnabled: routine.isEnabled,
            boardSortKey: routine.boardSortKey
        )
    }

    private static func sortedTodos(_ todos: [TodoSnapshot]) -> [TodoSnapshot] {
        todos.sorted { left, right in
            if left.dayKey != right.dayKey { return left.dayKey < right.dayKey }
            let leftFirst = Classification.precedes(left.boardSortKey, right.boardSortKey)
            let rightFirst = Classification.precedes(right.boardSortKey, left.boardSortKey)
            if leftFirst != rightFirst { return leftFirst }
            return left.id.uuidString < right.id.uuidString
        }
    }

    private static func sorted(_ entries: [AgendaEntry]) -> [AgendaEntry] {
        entries.sorted { left, right in
            if left.dayKey != right.dayKey { return left.dayKey < right.dayKey }
            let leftFirst = Classification.precedes(sortKey(left), sortKey(right))
            let rightFirst = Classification.precedes(sortKey(right), sortKey(left))
            if leftFirst != rightFirst { return leftFirst }
            return left.id < right.id
        }
    }

    private static func sortKey(_ entry: AgendaEntry) -> BoardSortKey {
        switch entry {
        case .todo(let todo):
            return todo.boardSortKey
        case .routine(let row):
            return row.boardSortKey
        }
    }
}
