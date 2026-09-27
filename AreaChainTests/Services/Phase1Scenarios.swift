import Foundation
import SwiftData
@testable import AreaChain

@MainActor
enum Phase1Scenarios {
    static func runAll(on corpus: Phase1Corpus) async throws {
        try measureIdentityReads(corpus)
        try measureListReads(corpus)
        try measureChecks(corpus)
        try measureSearch(corpus)
        try measureProjections(corpus)
        try measureEdits(corpus)
        try measureFanoutWork(corpus)
        try await Phase1IOScenarios.run(on: corpus)
    }

    private static func measureIdentityReads(_ corpus: Phase1Corpus) throws {
        try Phase1Measure.coldThenHot(
            scenario: "fetch.todo.byId",
            corpus: corpus,
            notes: "SwiftDataTaskRepository.fetchTodo：整表 FetchDescriptor 再 first。",
            cold: {
                let context = corpus.freshContext()
                let rows = try SwiftDataTaskRepository(context: context, container: corpus.container)
                    .fetchTodo(id: corpus.probeTodoID)
                return (1, rows == nil ? 0 : 1)
            },
            hot: {
                try corpus.tasks.fetchTodo(id: corpus.probeTodoID) == nil ? 0 : 1
            }
        )
        try Phase1Measure.record(
            scenario: "fetch.routine.byId",
            corpus: corpus,
            fetchCalls: 1,
            resultRows: 1,
            notes: "SwiftDataRoutineRepository.fetchRoutine：整表再 first。"
        ) {
            try corpus.routines.fetchRoutine(id: corpus.probeRoutineID) == nil ? 0 : 1
        }
        try Phase1Measure.record(
            scenario: "fetch.diary.byId",
            corpus: corpus,
            fetchCalls: 1,
            resultRows: 1,
            notes: "SwiftDataDiaryRepository.fetchDiary：整表再 first。"
        ) {
            try corpus.diaries.fetchDiary(id: corpus.probeDiaryID) == nil ? 0 : 1
        }
        try Phase1Measure.record(
            scenario: "fetch.tag.byId",
            corpus: corpus,
            fetchCalls: 1,
            resultRows: 1,
            notes: "SwiftDataCatalogRepository.fetchTag：整表再 first。"
        ) {
            try corpus.catalog.fetchTag(id: corpus.probeTagID) == nil ? 0 : 1
        }
    }

    private static func measureListReads(_ corpus: Phase1Corpus) throws {
        try Phase1Measure.record(
            scenario: "fetch.todos.byDay",
            corpus: corpus,
            fetchCalls: 1,
            resultRows: 0,
            notes: "fetchTodos(for:) 先 fetchAll 再按 dayKey 过滤。"
        ) {
            try corpus.tasks.fetchTodos(for: corpus.todayKey).count
        }
        try Phase1Measure.record(
            scenario: "fetch.todos.byTag",
            corpus: corpus,
            fetchCalls: 1,
            resultRows: 0,
            notes: "fetchTodos(forTag:) 先 fetchAll 再 TagIDList.contains。"
        ) {
            try corpus.tasks.fetchTodos(forTag: corpus.probeTagID).count
        }
        try Phase1Measure.record(
            scenario: "fetch.todos.byStatusOpen",
            corpus: corpus,
            fetchCalls: 1,
            resultRows: 0,
            notes: "仓储没有按状态接口；按生产习惯 fetchAll 后滤 isDone。"
        ) {
            try corpus.tasks.fetchAllTodos(includeDeleted: false).filter { !$0.isDone }.count
        }
    }

    private static func measureChecks(_ corpus: Phase1Corpus) throws {
        try Phase1Measure.record(
            scenario: "fetch.checks.byDay",
            corpus: corpus,
            fetchCalls: 1,
            resultRows: 0,
            notes: "fetchChecks(for dayKey:) 整表 RoutineCheck 再按日过滤。"
        ) {
            try corpus.routines.fetchChecks(for: corpus.todayKey).count
        }
        try Phase1Measure.record(
            scenario: "fetch.checks.byRoutine",
            corpus: corpus,
            fetchCalls: 1,
            resultRows: 0,
            notes: "fetchChecks(for routineID:) 整表再按 routine.id 过滤。"
        ) {
            try corpus.routines.fetchChecks(for: corpus.probeRoutineID).count
        }
    }

    private static func measureSearch(_ corpus: Phase1Corpus) throws {
        let tagCountBefore = try corpus.catalog.fetchTags(includeDeleted: true).count
        try Phase1Measure.record(
            scenario: "search.global.remapHits",
            corpus: corpus,
            fetchCalls: 6,
            resultRows: 0,
            repeatScans: 1,
            notes: "模拟工作台顶栏：六表已在 context 中，再 map snapshot（手记走 DiaryContent.snapshot）+ BoardSearch.hits。不含 @Query 物化。"
        ) {
            try globalHits(corpus).count
        }
        try Phase1Measure.record(
            scenario: "search.diary.repository",
            corpus: corpus,
            fetchCalls: 2,
            resultRows: 0,
            notes: "searchDiaries：fetch 手记 + fetch 标签，再对每条明文 DiaryContent.read 可能再 fetch 标签。"
        ) {
            try corpus.diaries.searchDiaries(query: "baseline", tagID: nil, includeDeleted: false).count
        }
        let tagCountAfter = try corpus.catalog.fetchTags(includeDeleted: true).count
        guard tagCountBefore == tagCountAfter else {
            throw Phase1ContractError.message("搜索改变了标签数量，违反搜索不创建标签")
        }
    }

    private static func globalHits(_ corpus: Phase1Corpus) throws -> [BoardSearchHit] {
        let todos = try corpus.context.fetch(FetchDescriptor<TodoItem>())
        let diaries = try corpus.context.fetch(FetchDescriptor<DiaryEntry>())
        let routines = try corpus.context.fetch(FetchDescriptor<DailyRoutine>())
        let checks = try corpus.context.fetch(FetchDescriptor<RoutineCheck>())
        let tags = try corpus.context.fetch(FetchDescriptor<TagItem>())
        let tagMap = Dictionary(uniqueKeysWithValues: tags.filter { $0.deletedAt == nil }.map { ($0.id, $0.name) })
        return BoardSearch.hits(
            query: "baseline",
            todos: todos.map(\.snapshot),
            diaries: diaries.map { DiaryContent.snapshot($0, vault: corpus.vault) },
            routines: routines.map(\.snapshot),
            checks: checks.compactMap(\.snapshot),
            todayKey: corpus.todayKey,
            tagMap: tagMap,
            privacy: BoardSearchPrivacy.protected(diaries: diaries, tags: tags, locale: Locale(identifier: "zh-Hans"))
        )
    }

    private static func measureProjections(_ corpus: Phase1Corpus) throws {
        try Phase1Measure.record(
            scenario: "projection.dashboard",
            corpus: corpus,
            fetchCalls: 4,
            resultRows: 1,
            repeatScans: 1,
            notes: "四表 fetch + 各 map snapshot 一次 + DashboardProjection.project。不是 SwiftUI body 多次读计算属性。"
        ) {
            _ = try dashboard(corpus)
            return 1
        }
        try Phase1Measure.record(
            scenario: "projection.dashboard.viewLikeRepeat",
            corpus: corpus,
            fetchCalls: 4,
            resultRows: 1,
            repeatScans: 4,
            notes: "同一份模型上连续 4 次 map snapshot 再 project，近似 DashboardView 多次读 snapshot。"
        ) {
            let pack = try boardPack(corpus)
            for _ in 0..<4 {
                _ = DashboardProjection.project(
                    todos: pack.todos.map(\.snapshot),
                    routines: pack.routines.map(\.snapshot),
                    checks: pack.checks.compactMap(\.snapshot),
                    diaries: pack.diaries.map(\.snapshot),
                    todayKey: corpus.todayKey
                )
            }
            return 1
        }
        try Phase1Measure.record(
            scenario: "projection.agendaPending",
            corpus: corpus,
            fetchCalls: 3,
            resultRows: 0,
            notes: "AgendaProjection.pending：侧栏/待处理共用入口。"
        ) {
            let pack = try boardPack(corpus)
            let pending = AgendaProjection.pending(
                routines: pack.routines.map(\.snapshot),
                checks: pack.checks.compactMap(\.snapshot),
                todos: pack.todos.map(\.snapshot),
                todayKey: corpus.todayKey
            )
            return pending.overdueCount + pending.upcomingCount
        }
    }

    private struct BoardPack {
        var todos: [TodoItem]
        var routines: [DailyRoutine]
        var checks: [RoutineCheck]
        var diaries: [DiaryEntry]
    }

    private static func boardPack(_ corpus: Phase1Corpus) throws -> BoardPack {
        BoardPack(
            todos: try corpus.context.fetch(FetchDescriptor<TodoItem>()),
            routines: try corpus.context.fetch(FetchDescriptor<DailyRoutine>()),
            checks: try corpus.context.fetch(FetchDescriptor<RoutineCheck>()),
            diaries: try corpus.context.fetch(FetchDescriptor<DiaryEntry>())
        )
    }

    private static func dashboard(_ corpus: Phase1Corpus) throws -> DashboardSnapshot {
        let pack = try boardPack(corpus)
        return DashboardProjection.project(
            todos: pack.todos.map(\.snapshot),
            routines: pack.routines.map(\.snapshot),
            checks: pack.checks.compactMap(\.snapshot),
            diaries: pack.diaries.map(\.snapshot),
            todayKey: corpus.todayKey
        )
    }

    private static func measureEdits(_ corpus: Phase1Corpus) throws {
        final class PostCounter: @unchecked Sendable {
            var value = 0
        }
        let posts = PostCounter()
        let observer = NotificationCenter.default.addObserver(forName: .boardDidChange, object: nil, queue: nil) { _ in
            posts.value += 1
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        posts.value = 0
        try Phase1Measure.record(
            scenario: "edit.single.toggleTodo",
            corpus: corpus,
            fetchCalls: 1,
            resultRows: 1,
            notes: "toggleTodo：按 id 整表查找 + save + BoardEvents.changed。测试进程会跳过通知排程和日历。"
        ) {
            try corpus.tasks.toggleTodo(id: corpus.probeTodoID)
            return 1
        }
        let singlePosts = posts.value
        posts.value = 0
        try Phase1Measure.record(
            scenario: "edit.batch.toggleDone",
            corpus: corpus,
            fetchCalls: 1,
            resultRows: corpus.batchIDs.count,
            notes: "batchToggleDone 各测一次 markDone true/false；每次 fetchAll + 一事务。"
        ) {
            try corpus.tasks.batchToggleDone(ids: corpus.batchIDs, markDone: true)
            try corpus.tasks.batchToggleDone(ids: corpus.batchIDs, markDone: false)
            return corpus.batchIDs.count
        }
        try Phase1Measure.writeSingle(
            scenario: "edit.fanout.boardDidChange",
            corpus: corpus,
            elapsedMs: 0,
            fetchCalls: 0,
            resultRows: 0,
            extraCalls: ["singleTogglePosts": singlePosts, "batchTwoTogglePosts": posts.value],
            notes: "只计 NotificationCenter.boardDidChange。NotificationScheduler/CalendarSync 在 XCTest 中被 BoardEvents 跳过。",
            temperature: "n/a"
        )
    }

    private static func measureFanoutWork(_ corpus: Phase1Corpus) throws {
        try Phase1Measure.record(
            scenario: "fanout.notificationCatalogAndMenuBar",
            corpus: corpus,
            fetchCalls: 3,
            resultRows: 0,
            extraCalls: ["reminderCatalog": 1, "menuBarStatus": 1],
            notes: "复现 loadCatalog + StatusItem.refreshCount：3 次整表 fetch + catalog + MenuBarStatus。不是系统通知中心或状态栏按钮。"
        ) {
            let routines = try corpus.context.fetch(FetchDescriptor<DailyRoutine>())
            let todos = try corpus.context.fetch(FetchDescriptor<TodoItem>())
            let checks = try corpus.context.fetch(FetchDescriptor<RoutineCheck>())
            let routineSnaps = routines.map(\.snapshot)
            let todoSnaps = todos.map(\.snapshot)
            let checkSnaps = checks.compactMap(\.snapshot)
            let catalog = ReminderPlanning.catalog(
                routines: routineSnaps, checks: checkSnaps, todos: todoSnaps, todayKey: corpus.todayKey
            )
            _ = MenuBarStatus.forDay(
                routines: routineSnaps, checks: checkSnaps, todos: todoSnaps, dayKey: corpus.todayKey
            )
            return catalog.count
        }
    }
}
