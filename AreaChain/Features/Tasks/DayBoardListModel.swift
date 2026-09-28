import Foundation
import SwiftData

/// DayBoardList 一次 body 求值内复用的行列表与查找表。失效条件：dayKey / filter / 模型数组 / 标签 / 附件变化。
@MainActor
struct DayBoardListIdentity {
    let source: DayBoardSource
    let openRows: [BoardRow]
    let doneRows: [BoardRow]
    let todosByID: [UUID: TodoItem]
    let routinesByID: [UUID: DailyRoutine]
    let checksByRoutine: [UUID: [CheckSnapshot]]
    let catalogs: TaskCatalogContext
    let streaks: [UUID: Int]

    var openIDs: [UUID] { openRows.map(\.id) }

    func visibleRows(showCompleted: Bool) -> [BoardRow] {
        showCompleted ? openRows + doneRows : openRows
    }

    func visibleIDs(showCompleted: Bool) -> [UUID] {
        visibleRows(showCompleted: showCompleted).map(\.id)
    }

    func todo(_ id: UUID) -> TodoItem? { todosByID[id] }
    func routine(_ id: UUID) -> DailyRoutine? { routinesByID[id] }

    func routineLookups(for id: UUID) -> RoutineDisplayLookups {
        RoutineDisplayLookups(
            checkIndex: source.checkIndex,
            currentStreak: streaks[id],
            routineCheckSnaps: checksByRoutine[id] ?? []
        )
    }

    static func make(
        dayKey: String,
        todayKey: String,
        filter: BoardFilter,
        routines: [DailyRoutine],
        checks: [RoutineCheck],
        todos: [TodoItem],
        catalogs: TaskCatalogContext,
        includeDoneStreaks: Bool
    ) -> DayBoardListIdentity {
        let source = DayBoardSource(routines: routines, checks: checks, todos: todos)
        let lists = DayBoardDayProjection.partition(source: source, dayKey: dayKey)
            .matchingListed(
                dayKey: dayKey,
                todayKey: todayKey,
                filter: filter,
                index: source.checkIndex
            )
        let todosByID = Dictionary(todos.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let routinesByID = Dictionary(routines.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let openRows = mixedRows(
            todos: lists.openTodos,
            routines: lists.openRoutines,
            todosByID: todosByID,
            routinesByID: routinesByID
        )
        let doneRows = mixedRows(
            todos: lists.doneTodos,
            routines: lists.doneRoutines,
            todosByID: todosByID,
            routinesByID: routinesByID
        )
        let streakRows = includeDoneStreaks ? openRows + doneRows : openRows
        let streakSnaps = streakRows.compactMap { row -> RoutineSnapshot? in
            guard case .resident(let routine) = row else { return nil }
            return source.routinesByID[routine.id]
        }
        let checksByRoutine = Dictionary(grouping: source.checks, by: \.routineId)
        return DayBoardListIdentity(
            source: source,
            openRows: openRows,
            doneRows: doneRows,
            todosByID: todosByID,
            routinesByID: routinesByID,
            checksByRoutine: checksByRoutine,
            catalogs: catalogs,
            streaks: DayBoardPageProjection.currentStreaks(
                routines: streakSnaps,
                checksByRoutine: checksByRoutine,
                todayKey: todayKey
            )
        )
    }

    private static func mixedRows(
        todos: [TodoSnapshot],
        routines: [RoutineSnapshot],
        todosByID: [UUID: TodoItem],
        routinesByID: [UUID: DailyRoutine]
    ) -> [BoardRow] {
        var rows: [BoardRow] = []
        rows.reserveCapacity(todos.count + routines.count)
        for snap in todos {
            if let todo = todosByID[snap.id] {
                rows.append(.todo(todo))
            }
        }
        for snap in routines {
            if let routine = routinesByID[snap.id] {
                rows.append(.resident(routine))
            }
        }
        return rows.sorted { Classification.precedes($0.boardSortKey, $1.boardSortKey) }
    }
}
