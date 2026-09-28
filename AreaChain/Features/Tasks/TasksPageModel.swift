import Foundation
import SwiftData

/// TasksPage 一次 body 求值内复用的派生结果。失效条件：routines / checks / todos / tags / attachments / filter / 日键变化。
@MainActor
struct TasksPageViewModel {
    let source: DayBoardSource
    let page: DayBoardPageSnapshot
    let todosByID: [UUID: TodoItem]
    let routinesByID: [UUID: DailyRoutine]
    let checksByRoutine: [UUID: [CheckSnapshot]]
    let catalogs: TaskCatalogContext
    let streaks: [UUID: Int]

    var yesterdayItems: [UnfinishedItem] { page.yesterdayItems }
    var upcomingModels: [TodoItem] {
        page.upcomingTodos.compactMap { todosByID[$0.id] }
    }
    var todayVisibleIDs: [UUID] { page.todayVisibleIDs }
    var todayBundleIDs: [String] { page.todayBundleIDs }
    var untaggedTodosCount: Int { page.untaggedOpenTodoCount }
    var totalOpenTodosCount: Int { page.totalOpenTodoCount }
    var isTodayEmpty: Bool { page.isTodayEmpty }

    func allVisibleIDs(showYesterday: Bool, showUpcoming: Bool) -> [UUID] {
        var ids: [UUID] = []
        if showYesterday {
            ids.append(contentsOf: yesterdayItems.map(\.id))
        }
        if showUpcoming {
            ids.append(contentsOf: upcomingModels.map(\.id))
        }
        ids.append(contentsOf: todayVisibleIDs)
        return ids
    }

    func dayKey(for id: UUID, listDayKey: String, yesterdayKey: String) -> String {
        BoardFocusDay.key(
            for: id,
            listDayKey: listDayKey,
            yesterdayKey: yesterdayKey,
            yesterdayIDs: page.yesterdayIDs,
            upcomingDayKeys: page.upcomingDayKeys
        )
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
        todayKey: String,
        yesterdayKey: String,
        routines: [DailyRoutine],
        checks: [RoutineCheck],
        todos: [TodoItem],
        catalogs: TaskCatalogContext,
        filter: BoardFilter
    ) -> TasksPageViewModel {
        let source = DayBoardSource(routines: routines, checks: checks, todos: todos)
        let page = DayBoardPageProjection.project(
            source: source,
            todayKey: todayKey,
            yesterdayKey: yesterdayKey,
            filter: filter
        )
        let leftoverRoutineIDs = page.yesterdayItems.compactMap { item -> UUID? in
            item.kind == .routine ? item.id : nil
        }
        let leftoverSnaps = leftoverRoutineIDs.compactMap { source.routinesByID[$0] }
        let checksByRoutine = Dictionary(grouping: source.checks, by: \.routineId)
        return TasksPageViewModel(
            source: source,
            page: page,
            todosByID: Dictionary(todos.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }),
            routinesByID: Dictionary(routines.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }),
            checksByRoutine: checksByRoutine,
            catalogs: catalogs,
            streaks: DayBoardPageProjection.currentStreaks(
                routines: leftoverSnaps,
                checksByRoutine: checksByRoutine,
                todayKey: todayKey
            )
        )
    }
}
