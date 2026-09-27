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
        #expect(FileManager.default.fileExists(atPath: Phase1Log.combinedURL.path))
        try Phase1Measure.coldThenHot(
            scenario: "disk.fetch.todo.byId",
            corpus: corpus,
            notes: "临时磁盘库上的 fetchTodo。与内存 1000 条对照，不是独立 App 打开。",
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
            scenario: "disk.fetch.todos.byDay",
            corpus: corpus,
            fetchCalls: 1,
            resultRows: 0,
            notes: "临时磁盘库 fetchTodos(for:)。"
        ) {
            try corpus.tasks.fetchTodos(for: corpus.todayKey).count
        }
        #expect(try corpus.tasks.fetchTodo(id: corpus.probeTodoID) != nil)
    }

    private func run(scale: Int, onDisk: Bool) async throws {
        let corpus = try await Phase1Corpus.make(scale: scale, onDisk: onDisk)
        defer { corpus.cleanup() }
        try Phase1Log.writeGraph(corpus.graph)
        try await Phase1Scenarios.runAll(on: corpus)
        #expect(FileManager.default.fileExists(atPath: Phase1Log.combinedURL.path))
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
    }
}
