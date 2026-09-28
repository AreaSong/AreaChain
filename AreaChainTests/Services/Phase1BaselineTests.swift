import Foundation
import Testing
@testable import AreaChain

/// 阶段 1 隔离合成数据性能基线。不设产品预算，失败只报告数字。
@Suite(.serialized)
@MainActor
struct Phase1BaselineTests {
    @Test func memoryScale100() async throws {
        try await run(scale: 100, onDisk: false)
    }

    @Test func memoryScale1000() async throws {
        try await run(scale: 1_000, onDisk: false)
    }

    @Test func memoryScale10000() async throws {
        try await run(scale: 10_000, onDisk: false)
    }

    @Test func diskScale1000SelectedQueries() async throws {
        let corpus = try await Phase1Corpus.make(scale: 1_000, onDisk: true)
        defer { corpus.cleanup() }
        try Phase1Log.writeGraph(corpus.graph)
        try assertPhase1LogIsIsolated(requireSamples: false)
        try Phase1Measure.coldThenHot(
            scenario: "disk.fetch.todo.byId",
            corpus: corpus,
            notes: "临时磁盘库上的 fetchTodo。与内存 1000 条对照，不是独立 App 打开。",
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
            scenario: "disk.fetch.todos.byDay",
            corpus: corpus,
            notes: "临时磁盘库 fetchTodos(for:)。"
        ) {
            Phase1Work(rows: try corpus.tasks.fetchTodos(for: corpus.todayKey).count, fetchCalls: 1)
        }
        #expect(try corpus.tasks.fetchTodo(id: corpus.probeTodoID) != nil)
        try assertPhase1LogIsIsolated()
    }

    private func run(scale: Int, onDisk: Bool) async throws {
        let corpus = try await Phase1Corpus.make(scale: scale, onDisk: onDisk)
        defer { corpus.cleanup() }
        try Phase1Log.writeGraph(corpus.graph)
        try await Phase1Scenarios.runAll(on: corpus)
        try assertPhase1LogIsIsolated()
        try assertOwnerLookupMaterializesFewerRows(scale: scale, graph: corpus.graph)
        #expect(try corpus.tasks.fetchTodo(id: corpus.probeTodoID) != nil)
        #expect(try corpus.routines.fetchRoutine(id: corpus.probeRoutineID) != nil)
        #expect(try corpus.diaries.fetchDiary(id: corpus.probeDiaryID) != nil)
        #expect(try corpus.catalog.fetchTag(id: corpus.probeTagID) != nil)
        #expect(corpus.graph.todos == scale)
        #expect(corpus.graph.deletedTodos > 0)
        #expect(corpus.graph.subtasks > 0)
        #expect(corpus.graph.checks > 0)
        #expect(corpus.graph.attachments > 0)
        #expect(corpus.graph.privateDiaries > 0)
        #expect(!corpus.privateDiaryIDs.isEmpty)
    }

    private func assertPhase1LogIsIsolated(requireSamples: Bool = true) throws {
        #expect(
            Phase1Log.isolationLabel == "outside_app_container"
                || Phase1Log.isolationLabel == "stderr_and_memory"
        )
        #expect(!Phase1Log.combinedURL.path.contains("/Library/Containers/"))
        if Phase1Log.persistsFiles {
            #expect(FileManager.default.fileExists(atPath: Phase1Log.combinedURL.path))
        } else {
            #expect(!FileManager.default.fileExists(atPath: Phase1Log.combinedURL.path))
        }
        if requireSamples {
            let samples = try Phase1Log.samples()
            #expect(!samples.isEmpty)
            if Phase1Log.persistsFiles {
                #expect(samples.allSatisfy { $0.logIsolation == "outside_app_container" && !$0.logDirectory.isEmpty })
            } else {
                #expect(samples.allSatisfy { $0.logIsolation == "stderr_and_memory" && $0.logDirectory.isEmpty })
            }
        }
    }

    /// 同一次运行里对照物化行数：owner lookup 不是整表热点。
    /// scale≥1000 时再对照 p50，挡住整表 fetch 再 filter；不把 p50 写成产品预算。
    private func assertOwnerLookupMaterializesFewerRows(scale: Int, graph: Phase1Graph) throws {
        let samples = try Phase1Log.samples().filter { $0.scale == scale && $0.store == graph.store }
        let todo = try sample(samples, "fetch.owner.live.todo")
        let todoUnscoped = try sample(samples, "fetch.owner.live.todo.unscoped")
        let attachment = try sample(samples, "fetch.attachment.byOwner")
        let attachmentUnscoped = try sample(samples, "fetch.attachment.byOwner.unscoped")
        let byDay = try sample(samples, "fetch.todos.byDay")
        #expect(todo.resultRows == 1)
        #expect(todoUnscoped.resultRows == graph.todos)
        #expect(todoUnscoped.resultRows > todo.resultRows)
        #expect(attachment.resultRows >= 1)
        #expect(attachmentUnscoped.resultRows == graph.attachments)
        #expect(attachmentUnscoped.resultRows > attachment.resultRows)
        #expect(byDay.resultRows > todo.resultRows)
        if scale >= 1_000 {
            #expect(todo.p50Ms < todoUnscoped.p50Ms)
            #expect(attachment.p50Ms < attachmentUnscoped.p50Ms)
        }
    }

    private func sample(_ samples: [Phase1Sample], _ scenario: String) throws -> Phase1Sample {
        guard let match = samples.last(where: { $0.scenario == scenario }) else {
            throw Phase1ContractError.message("缺少场景 \(scenario)")
        }
        return match
    }
}
