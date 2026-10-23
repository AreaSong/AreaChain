import Foundation
import SwiftData
import SwiftUI

/// 待处理页一次 body 求值内复用的投影与行。失效条件：routines / checks / todos / lane / filter / todayKey 变化。
@MainActor
struct WorkspacePendingPageModel {
    let todayKey: String
    let projection: PendingProjection
    let lane: PendingLane
    let visibleEntries: [WorkspaceItemEntry]
    let visibleIDs: [UUID]
    let bundleIDs: [String]

    static func make(
        routines: [DailyRoutine],
        todos: [TodoItem],
        checks: [RoutineCheck],
        todayKey: String,
        navigation: WorkspaceNavigation
    ) -> WorkspacePendingPageModel {
        let routineSnaps = routines.map(\.snapshot)
        let todoSnaps = todos.map(\.snapshot)
        let checkSnaps = checks.compactMap(\.snapshot)
        let projection = AgendaProjection.pending(
            routines: routineSnaps,
            checks: checkSnaps,
            todos: todoSnaps,
            todayKey: todayKey
        )
        let lane = navigation.pendingLaneSession?.lane
            ?? PendingLanePolicy.initial(overdueCount: projection.overdueCount)
        let todosByID = Dictionary(todos.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let routinesByID = Dictionary(routines.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let filtered = AgendaProjection.filtered(
            projection.entries(for: lane),
            filter: navigation.pendingFilter,
            routines: routineSnaps,
            checks: checkSnaps,
            todayKey: todayKey
        )
        let query = ItemsListingQuery(filter: navigation.pendingFilter, todayKey: todayKey)
        let visibleEntries = filtered.compactMap { item -> WorkspaceItemEntry? in
            switch item {
            case .todo(let snapshot):
                guard let todo = todosByID[snapshot.id] else { return nil }
                let listed = ItemsListing.todos([snapshot], query: query)
                let ids = listed.first.map { Set($0.subtasks.map(\.id)) }
                return .todo(todo, checkDayKey: snapshot.dayKey, subtaskIDs: ids)
            case .routine(let row):
                guard let routine = routinesByID[row.routineID] else { return nil }
                return .routine(
                    routine,
                    checkDayKey: row.displayDayKey,
                    allowsCompletion: lane == .overdue,
                    overdueCount: row.openCount,
                    noteDayKey: lane == .upcoming ? row.displayDayKey : nil
                )
            }
        }
        let bundleIDs = Array(
            Set(
                projection.entries(for: lane).compactMap { entry -> String? in
                    switch entry {
                    case .todo(let todo):
                        return todo.sourceBundleID
                    case .routine(let row):
                        return routinesByID[row.routineID]?.sourceBundleID
                    }
                }.filter { !$0.isEmpty }
            )
        ).sorted()
        return WorkspacePendingPageModel(
            todayKey: todayKey,
            projection: projection,
            lane: lane,
            visibleEntries: visibleEntries,
            visibleIDs: visibleEntries.map(\.modelID),
            bundleIDs: bundleIDs
        )
    }
}

/// 全部事项页一次 body 求值内复用的分组。失效条件：listing query / 模型数组 / todayKey 变化。
@MainActor
struct WorkspaceAllItemsPageModel {
    let liveQuery: ItemsListingQuery
    let groups: [WorkspaceItemGroup]
    let visibleIDs: [UUID]
    let bundleIDs: [String]

    private struct CacheKey: Equatable {
        let liveQuery: ItemsListingQuery
        let todayKey: String
        let localeID: String
        let fingerprint: Int
    }

    private static var cachedKey: CacheKey?
    private static var cachedModel: WorkspaceAllItemsPageModel?

    private static func computeFingerprint(
        todos: [TodoItem],
        routines: [DailyRoutine],
        checks: [RoutineCheck]
    ) -> Int {
        var hasher = Hasher()
        hasher.combine(todos.count)
        hasher.combine(routines.count)
        hasher.combine(checks.count)
        for todo in todos {
            hasher.combine(todo.id)
            hasher.combine(todo.deletedAt)
            hasher.combine(todo.isDone)
            hasher.combine(todo.dayKey)
            hasher.combine(todo.title)
            hasher.combine(todo.sortOrder)
            hasher.combine(todo.tagIDs)
            hasher.combine(todo.isImportant)
            hasher.combine(todo.isUrgent)
            hasher.combine(todo.remindMinutes)
            hasher.combine(todo.sourceBundleID)
            hasher.combine(todo.subtasks.count)
            for sub in todo.subtasks {
                hasher.combine(sub.id)
                hasher.combine(sub.deletedAt)
                hasher.combine(sub.isDone)
                hasher.combine(sub.sortOrder)
                hasher.combine(sub.tagIDs)
                hasher.combine(sub.title)
            }
        }
        for routine in routines {
            hasher.combine(routine.id)
            hasher.combine(routine.deletedAt)
            hasher.combine(routine.isEnabled)
            hasher.combine(routine.sortOrder)
            hasher.combine(routine.title)
            hasher.combine(routine.tagIDs)
            hasher.combine(routine.isImportant)
            hasher.combine(routine.isUrgent)
            hasher.combine(routine.remindMinutes)
            hasher.combine(routine.sourceBundleID)
            hasher.combine(routine.weekdayMask)
            hasher.combine(routine.subtasksJSON)
        }
        for check in checks {
            hasher.combine(check.id)
            hasher.combine(check.dayKey)
            hasher.combine(check.isDone)
            hasher.combine(check.isSkipped)
            hasher.combine(check.completedSubtaskIDs)
        }
        return hasher.finalize()
    }

    static func make(
        routines: [DailyRoutine],
        todos: [TodoItem],
        checks: [RoutineCheck],
        todayKey: String,
        navigation: WorkspaceNavigation,
        locale: Locale
    ) -> WorkspaceAllItemsPageModel {
        var liveQuery = navigation.allItemsQuery
        liveQuery.todayKey = todayKey
        let fingerprint = computeFingerprint(todos: todos, routines: routines, checks: checks)
        let key = CacheKey(liveQuery: liveQuery, todayKey: todayKey, localeID: locale.identifier, fingerprint: fingerprint)
        if cachedKey == key, let cachedModel {
            return cachedModel
        }

        let todoSnaps = todos.map(\.snapshot)
        let routineSnaps = routines.map(\.snapshot)
        let checkSnaps = checks.compactMap(\.snapshot)
        let todosByID = Dictionary(todos.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let routinesByID = Dictionary(routines.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let listedTodos = ItemsListing.todos(todoSnaps, query: liveQuery)
        let listedRoutines = ItemsListing.routines(routineSnaps, checks: checkSnaps, query: liveQuery)
        let todoEntries = listedTodos.compactMap { listed -> WorkspaceItemEntry? in
            guard let todo = todosByID[listed.id] else { return nil }
            return .todo(todo, checkDayKey: listed.todo.dayKey, subtaskIDs: Set(listed.subtasks.map(\.id)))
        }
        let routineEntries = listedRoutines.compactMap { snapshot -> WorkspaceItemEntry? in
            guard let routine = routinesByID[snapshot.id] else { return nil }
            let dueToday = DayBoardLogic.isRoutineDue(snapshot, on: todayKey)
            let next = AgendaProjection.nextDay(after: todayKey, routine: snapshot)
            return .routine(
                routine,
                checkDayKey: AgendaProjection.inspectionDay(for: snapshot, todayKey: todayKey),
                allowsCompletion: dueToday,
                overdueCount: 0,
                noteDayKey: dueToday ? nil : next
            )
        }
        var groups: [WorkspaceItemGroup] = []
        if liveQuery.kind != .recurring, !todoEntries.isEmpty {
            let entriesByDay = Dictionary(grouping: todoEntries, by: \.checkDayKey)
            let days = AllItemsDayOrder.ordered(Array(entriesByDay.keys), todayKey: todayKey)
            for (index, day) in days.enumerated() {
                guard let entries = entriesByDay[day], !entries.isEmpty else { continue }
                groups.append(WorkspaceItemGroup(
                    id: "todos-\(day)",
                    title: index == 0 ? "items.section.todos" : nil,
                    entries: entries,
                    titleText: DayKey.displayName(day, locale: locale),
                    sectionCount: index == 0 ? todoEntries.count : nil
                ))
            }
        }
        if liveQuery.kind != .oneOff, !routineEntries.isEmpty {
            groups.append(WorkspaceItemGroup(id: "routines", title: "items.section.routines", entries: routineEntries))
        }
        let bundleValues = todos.map(\.sourceBundleID) + routines.map(\.sourceBundleID)
        let result = WorkspaceAllItemsPageModel(
            liveQuery: liveQuery,
            groups: groups,
            visibleIDs: (todoEntries + routineEntries).map(\.modelID),
            bundleIDs: Array(Set(bundleValues.filter { !$0.isEmpty })).sorted()
        )
        cachedKey = key
        cachedModel = result
        return result
    }
}

/// 标签筛选清单一次 body 求值内复用的分区、开项计数和行查找。
/// 失效条件：tag / todos / routines / checks / tags / attachments / showCompleted / todayKey 变化。
@MainActor
struct WorkspaceFilteredListModel {
    let todayKey: String
    let openRows: [BoardRow]
    let doneRows: [BoardRow]
    let matchingSubtasks: [SubtaskItem]
    let matchingDiaries: [DiaryEntry]
    let orderedVisibleIDs: [UUID]
    let openCount: Int
    let catalogs: TaskCatalogContext
    let checkIndex: DayBoardCheckIndex
    let checksByRoutine: [UUID: [CheckSnapshot]]
    let streaks: [UUID: Int]
    let checks: [RoutineCheck]
    let locale: Locale

    var canBatchSelect: Bool { !orderedVisibleIDs.isEmpty }

    var isEmpty: Bool {
        openRows.isEmpty && doneRows.isEmpty && matchingSubtasks.isEmpty && matchingDiaries.isEmpty
    }

    func routineLookups(for id: UUID) -> RoutineDisplayLookups {
        RoutineDisplayLookups(
            checkIndex: checkIndex,
            currentStreak: streaks[id],
            routineCheckSnaps: checksByRoutine[id] ?? []
        )
    }

    static func make(
        tag: TagItem,
        todos: [TodoItem],
        routines: [DailyRoutine],
        diaries: [DiaryEntry] = [],
        checks: [RoutineCheck],
        catalogs: TaskCatalogContext,
        locale: Locale,
        showCompleted: Bool
    ) -> WorkspaceFilteredListModel {
        let todayKey = DayClock.shared.todayKey
        let taggedTodos = Catalog.matchingTodos(todos, tag: tag)
        let matchingSubtasks = Catalog.matchingSubtasks(todos, tag: tag)
        let matchingDiaries = Catalog.matchingDiaries(diaries, tag: tag)
        let openTodos = taggedTodos.filter { !$0.isDone }
        let doneTodos = taggedTodos.filter { $0.isDone }
        let openRoutines = Catalog.matchingListedRoutines(
            routines, checks: checks, tag: tag, dayKey: todayKey, open: true
        )
        let doneRoutines = Catalog.matchingListedRoutines(
            routines, checks: checks, tag: tag, dayKey: todayKey, open: false
        )
        let openRows = mixedRows(todos: openTodos, routines: openRoutines)
        let doneRows = mixedRows(todos: doneTodos, routines: doneRoutines)
        let checkSnaps = checks.compactMap(\.snapshot)
        let checkIndex = DayBoardCheckIndex(checkSnaps)
        let checksByRoutine = Dictionary(grouping: checkSnaps, by: \.routineId)
        let listedRoutines = openRoutines + doneRoutines
        return WorkspaceFilteredListModel(
            todayKey: todayKey,
            openRows: openRows,
            doneRows: doneRows,
            matchingSubtasks: matchingSubtasks,
            matchingDiaries: matchingDiaries,
            orderedVisibleIDs: openRows.map(\.id) + (showCompleted ? doneRows.map(\.id) : []),
            openCount: openTodos.count
                + openRoutines.count
                + matchingSubtasks.filter { !$0.isDone }.count,
            catalogs: catalogs,
            checkIndex: checkIndex,
            checksByRoutine: checksByRoutine,
            streaks: DayBoardPageProjection.currentStreaks(
                routines: listedRoutines.map(\.snapshot),
                checksByRoutine: checksByRoutine,
                todayKey: todayKey
            ),
            checks: checks,
            locale: locale
        )
    }

    private static func mixedRows(todos: [TodoItem], routines: [DailyRoutine]) -> [BoardRow] {
        let rows = todos.map(BoardRow.todo) + routines.map(BoardRow.resident)
        return rows.sorted { Classification.precedes($0.boardSortKey, $1.boardSortKey) }
    }
}

/// 侧栏角标一次 body 共用快照。今日角标走看板 first-wins，待处理走 Agenda 任一条闭合，索引不能混用。
enum WorkspaceSidebarBadges {
    static func make(
        routines: [DailyRoutine],
        checks: [RoutineCheck],
        todos: [TodoItem],
        todayKey: String
    ) -> (todayUnfinished: Int?, pending: Int?) {
        let routineSnaps = routines.map(\.snapshot)
        let checkSnaps = checks.compactMap(\.snapshot)
        let todoSnaps = todos.map(\.snapshot)
        let today = DayBoardLogic.todayBadgeCount(
            routines: routineSnaps, checks: checkSnaps, todos: todoSnaps, dayKey: todayKey
        )
        let pending = AgendaProjection.pending(
            routines: routineSnaps, checks: checkSnaps, todos: todoSnaps, todayKey: todayKey
        )
        let pendingCount = pending.overdueCount + pending.upcomingCount
        return (today > 0 ? today : nil, pendingCount > 0 ? pendingCount : nil)
    }
}
