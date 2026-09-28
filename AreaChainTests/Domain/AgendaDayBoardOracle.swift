import Foundation
@testable import AreaChain

/// 冻结 PHASE-3B 之前的逐日/逐条扫描，只给等价测试对照，不是产品入口。
enum AgendaDayBoardOracle {
    static func openScheduledDays(
        _ routine: RoutineSnapshot,
        checks: [CheckSnapshot],
        from start: String,
        through end: String,
        calendar: Calendar
    ) -> [String] {
        let closed = Set(
            checks.filter { $0.routineId == routine.id && ($0.isDone || $0.isSkipped) }.map(\.dayKey)
        )
        var days: [String] = []
        var cursor = start
        var steps = 0
        while cursor <= end, steps < 4000 {
            if WeekdayMask.contains(routine.weekdayMask, dayKey: cursor, calendar: calendar),
               !closed.contains(cursor) {
                days.append(cursor)
            }
            let next = DayKey.shifted(cursor, by: 1, calendar: calendar)
            guard next > cursor else { break }
            cursor = next
            steps += 1
        }
        return days
    }

    static func overdueRoutines(
        routines: [RoutineSnapshot],
        checks: [CheckSnapshot],
        todayKey: String,
        calendar: Calendar
    ) -> [RoutineAgendaRow] {
        let yesterday = DayKey.shifted(todayKey, by: -1, calendar: calendar)
        return routines.compactMap { routine in
            guard routine.deletedAt == nil, routine.isEnabled else { return nil }
            guard DayKey.date(from: routine.createdDayKey, calendar: calendar) != nil else { return nil }
            guard routine.createdDayKey <= yesterday else { return nil }
            let open = openScheduledDays(
                routine, checks: checks, from: routine.createdDayKey, through: yesterday, calendar: calendar
            )
            guard let latest = open.max() else { return nil }
            return RoutineAgendaRow(
                routineID: routine.id,
                displayDayKey: latest,
                openCount: open.count,
                sortOrder: routine.sortOrder,
                isEnabled: routine.isEnabled,
                boardSortKey: routine.boardSortKey
            )
        }
    }

    static func monthUnfinished(
        routines: [RoutineSnapshot],
        checks: [CheckSnapshot],
        todos: [TodoSnapshot],
        containing dayKey: String,
        calendar: Calendar
    ) -> [String: Int] {
        Dictionary(
            uniqueKeysWithValues: DayKey.daysInMonth(containing: dayKey, calendar: calendar).map { key in
                let dueTodos = todos.filter { $0.deletedAt == nil && $0.dayKey == key }
                let dueRoutines = routines.filter { DayBoardLogic.isRoutineDue($0, on: key, calendar: calendar) }
                let completedTodos = dueTodos.filter(\.isDone).count
                let completedRoutines = dueRoutines.filter { routine in
                    guard let mark = checks.first(where: { $0.routineId == routine.id && $0.dayKey == key }) else {
                        return false
                    }
                    return mark.isDone || mark.isSkipped
                }.count
                return (key, dueTodos.count + dueRoutines.count - completedTodos - completedRoutines)
            }
        )
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
}
