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
                return Phase1Work(rows: rows == nil ? 0 : 1, fetchCalls: 1)
            },
            hot: {
                let rows = try corpus.tasks.fetchTodo(id: corpus.probeTodoID)
                return Phase1Work(rows: rows == nil ? 0 : 1, fetchCalls: 1)
            }
        )
        try Phase1Measure.record(
            scenario: "fetch.routine.byId",
            corpus: corpus,
            notes: "SwiftDataRoutineRepository.fetchRoutine：整表再 first。"
        ) {
            let rows = try corpus.routines.fetchRoutine(id: corpus.probeRoutineID)
            return Phase1Work(rows: rows == nil ? 0 : 1, fetchCalls: 1)
        }
        try Phase1Measure.record(
            scenario: "fetch.diary.byId",
            corpus: corpus,
            notes: "SwiftDataDiaryRepository.fetchDiary：整表再 first。"
        ) {
            let rows = try corpus.diaries.fetchDiary(id: corpus.probeDiaryID)
            return Phase1Work(rows: rows == nil ? 0 : 1, fetchCalls: 1)
        }
        try Phase1Measure.record(
            scenario: "fetch.tag.byId",
            corpus: corpus,
            notes: "SwiftDataCatalogRepository.fetchTag：整表再 first。"
        ) {
            let rows = try corpus.catalog.fetchTag(id: corpus.probeTagID)
            return Phase1Work(rows: rows == nil ? 0 : 1, fetchCalls: 1)
        }
    }

    private static func measureListReads(_ corpus: Phase1Corpus) throws {
        try Phase1Measure.record(
            scenario: "fetch.todos.byDay",
            corpus: corpus,
            notes: "fetchTodos(for:) 先 fetchAll 再按 dayKey 过滤。"
        ) {
            Phase1Work(rows: try corpus.tasks.fetchTodos(for: corpus.todayKey).count, fetchCalls: 1)
        }
        try Phase1Measure.record(
            scenario: "fetch.todos.byTag",
            corpus: corpus,
            notes: "fetchTodos(forTag:) 先 fetchAll 再 TagIDList.contains。"
        ) {
            Phase1Work(rows: try corpus.tasks.fetchTodos(forTag: corpus.probeTagID).count, fetchCalls: 1)
        }
        try Phase1Measure.record(
            scenario: "fetch.todos.byStatusOpen",
            corpus: corpus,
            notes: "仓储没有按状态接口；按生产习惯 fetchAll 后滤 isDone。"
        ) {
            let rows = try corpus.tasks.fetchAllTodos(includeDeleted: false).filter { !$0.isDone }.count
            return Phase1Work(rows: rows, fetchCalls: 1)
        }
    }

    private static func measureChecks(_ corpus: Phase1Corpus) throws {
        try Phase1Measure.record(
            scenario: "fetch.checks.byDay",
            corpus: corpus,
            notes: "fetchChecks(for dayKey:) 整表 RoutineCheck 再按日过滤。"
        ) {
            Phase1Work(rows: try corpus.routines.fetchChecks(for: corpus.todayKey).count, fetchCalls: 1)
        }
        try Phase1Measure.record(
            scenario: "fetch.checks.byRoutine",
            corpus: corpus,
            notes: "fetchChecks(for routineID:) 整表再按 routine.id 过滤。"
        ) {
            Phase1Work(rows: try corpus.routines.fetchChecks(for: corpus.probeRoutineID).count, fetchCalls: 1)
        }
    }

    private static func measureSearch(_ corpus: Phase1Corpus) throws {
        let tagCountBefore = try corpus.catalog.fetchTags(includeDeleted: true).count
        try Phase1Measure.record(
            scenario: "search.global.remapHits",
            corpus: corpus,
            notes: "五表 fetch + 每条明文手记 DiaryContent.read 再 fetch 标签 + BoardSearch.hits。不含 @Query 物化和附件文件名。"
        ) {
            try globalHits(corpus)
        }
        try Phase1Measure.record(
            scenario: "search.diary.repository",
            corpus: corpus,
            notes: "searchDiaries：fetch 手记 + fetch 标签，再对每条明文 DiaryContent.read 可能再 fetch 标签。"
        ) {
            let rows = try corpus.diaries.searchDiaries(query: "baseline", tagID: nil, includeDeleted: false).count
            let liveUnprotected = corpus.graph.diaries - corpus.graph.deletedDiaries - corpus.graph.privateDiaries
            return Phase1Work(rows: rows, fetchCalls: 2 + liveUnprotected)
        }
        let tagCountAfter = try corpus.catalog.fetchTags(includeDeleted: true).count
        guard tagCountBefore == tagCountAfter else {
            throw Phase1ContractError.message("搜索改变了标签数量，违反搜索不创建标签")
        }
    }

    private static func globalHits(_ corpus: Phase1Corpus) throws -> Phase1Work {
        let todos = try corpus.context.fetch(FetchDescriptor<TodoItem>())
        let diaries = try corpus.context.fetch(FetchDescriptor<DiaryEntry>())
        let routines = try corpus.context.fetch(FetchDescriptor<DailyRoutine>())
        let checks = try corpus.context.fetch(FetchDescriptor<RoutineCheck>())
        let tags = try corpus.context.fetch(FetchDescriptor<TagItem>())
        let tagMap = Dictionary(uniqueKeysWithValues: tags.filter { $0.deletedAt == nil }.map { ($0.id, $0.name) })
        let hits = BoardSearch.hits(
            query: "baseline",
            todos: todos.map(\.snapshot),
            diaries: diaries.map { DiaryContent.snapshot($0, vault: corpus.vault) },
            routines: routines.map(\.snapshot),
            checks: checks.compactMap(\.snapshot),
            todayKey: corpus.todayKey,
            tagMap: tagMap,
            privacy: BoardSearchPrivacy.protected(diaries: diaries, tags: tags, locale: Locale(identifier: "zh-Hans"))
        )
        let plaintextReads = diaries.filter { !$0.hasProtectedContent }.count
        return Phase1Work(rows: hits.count, fetchCalls: 5 + plaintextReads)
    }

    private static func measureProjections(_ corpus: Phase1Corpus) throws {
        try Phase1Measure.record(
            scenario: "projection.dashboard",
            corpus: corpus,
            repeatScans: 1,
            notes: "五表 fetch（对齐 DashboardView @Query）+ diarySource(tags:) + project 一次。不是 SwiftUI body。"
        ) {
            _ = try dashboard(corpus)
            return Phase1Work(rows: 1, fetchCalls: 5)
        }
        try Phase1Measure.record(
            scenario: "projection.dashboard.viewLikeRepeat",
            corpus: corpus,
            repeatScans: 6,
            notes: "同一份模型上连续 6 次 diarySource+project，近似 DashboardView body 多次读计算属性。"
        ) {
            let pack = try dashboardPack(corpus)
            for _ in 0..<6 {
                _ = projectDashboard(pack, todayKey: corpus.todayKey)
            }
            return Phase1Work(rows: 1, fetchCalls: 5)
        }
        try Phase1Measure.record(
            scenario: "projection.agendaPending",
            corpus: corpus,
            notes: "AgendaProjection.pending。fetch 对齐 WorkspacePendingView 四表 @Query（含未用于 pending 的 tags）。"
        ) {
            let routines = try corpus.context.fetch(FetchDescriptor<DailyRoutine>())
            let todos = try corpus.context.fetch(FetchDescriptor<TodoItem>())
            let checks = try corpus.context.fetch(FetchDescriptor<RoutineCheck>())
            _ = try corpus.context.fetch(FetchDescriptor<TagItem>())
            let pending = AgendaProjection.pending(
                routines: routines.map(\.snapshot),
                checks: checks.compactMap(\.snapshot),
                todos: todos.map(\.snapshot),
                todayKey: corpus.todayKey
            )
            return Phase1Work(rows: pending.overdueCount + pending.upcomingCount, fetchCalls: 4)
        }
    }

    private struct DashboardPack {
        var todos: [TodoItem]
        var routines: [DailyRoutine]
        var checks: [RoutineCheck]
        var diaries: [DiaryEntry]
        var tags: [TagItem]
    }

    private static func dashboardPack(_ corpus: Phase1Corpus) throws -> DashboardPack {
        DashboardPack(
            todos: try corpus.context.fetch(FetchDescriptor<TodoItem>()),
            routines: try corpus.context.fetch(FetchDescriptor<DailyRoutine>()),
            checks: try corpus.context.fetch(FetchDescriptor<RoutineCheck>()),
            diaries: try corpus.context.fetch(FetchDescriptor<DiaryEntry>()),
            tags: try corpus.context.fetch(FetchDescriptor<TagItem>())
        )
    }

    private static func projectDashboard(_ pack: DashboardPack, todayKey: String) -> DashboardSnapshot {
        DashboardProjection.project(
            todos: pack.todos.map(\.snapshot),
            routines: pack.routines.map(\.snapshot),
            checks: pack.checks.compactMap(\.snapshot),
            diaries: pack.diaries.map { DashboardProjection.diarySource($0.snapshot, tags: pack.tags) },
            todayKey: todayKey
        )
    }

    private static func dashboard(_ corpus: Phase1Corpus) throws -> DashboardSnapshot {
        try projectDashboard(dashboardPack(corpus), todayKey: corpus.todayKey)
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
            notes: "toggleTodo：按 id 整表查找 + save + BoardEvents.changed。测试进程会跳过通知排程和日历。"
        ) {
            try corpus.tasks.toggleTodo(id: corpus.probeTodoID)
            return Phase1Work(rows: 1, fetchCalls: 1)
        }
        let singlePosts = posts.value
        posts.value = 0
        try Phase1Measure.record(
            scenario: "edit.batch.toggleDone",
            corpus: corpus,
            notes: "batchToggleDone 各测一次 markDone true/false；每次 fetchAll + 一事务，共 2 次 fetch。"
        ) {
            try corpus.tasks.batchToggleDone(ids: corpus.batchIDs, markDone: true)
            try corpus.tasks.batchToggleDone(ids: corpus.batchIDs, markDone: false)
            return Phase1Work(rows: corpus.batchIDs.count, fetchCalls: 2)
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
            extraCalls: ["reminderCatalog": 1, "menuBarStatus": 1],
            notes: "分别复现 loadCatalog 与 StatusItem.refreshCount 各 3 次整表 fetch，共 6 次。不是系统通知中心或状态栏按钮。"
        ) {
            let catalogPack = try fetchSnaps(corpus)
            let menuPack = try fetchSnaps(corpus)
            let catalog = ReminderPlanning.catalog(
                routines: catalogPack.routines,
                checks: catalogPack.checks,
                todos: catalogPack.todos,
                todayKey: corpus.todayKey
            )
            _ = MenuBarStatus.forDay(
                routines: menuPack.routines,
                checks: menuPack.checks,
                todos: menuPack.todos,
                dayKey: corpus.todayKey
            )
            return Phase1Work(rows: catalog.count, fetchCalls: 6)
        }
    }

    private struct DaySnaps {
        var routines: [RoutineSnapshot]
        var todos: [TodoSnapshot]
        var checks: [CheckSnapshot]
    }

    private static func fetchSnaps(_ corpus: Phase1Corpus) throws -> DaySnaps {
        let routines = try corpus.context.fetch(FetchDescriptor<DailyRoutine>())
        let todos = try corpus.context.fetch(FetchDescriptor<TodoItem>())
        let checks = try corpus.context.fetch(FetchDescriptor<RoutineCheck>())
        return DaySnaps(
            routines: routines.map(\.snapshot),
            todos: todos.map(\.snapshot),
            checks: checks.compactMap(\.snapshot)
        )
    }
}
