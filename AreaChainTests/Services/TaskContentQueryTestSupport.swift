import Foundation
import SwiftData
@testable import AreaChain

/// 从原任务仓储测试提取同一内存 schema 夹具，不触及 Persistence 或真实存储。
@MainActor
enum TaskRepositoryFixture {
    static func container() throws -> ModelContainer {
        try ModelContainer(for: Schema(AreaChainSchema.models),
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
}

@MainActor
struct TaskContentQueryFixture {
    let container: ModelContainer
    let context: ModelContext
    var reader: TaskContentQueryReader { .init(context: context) }

    init() throws {
        container = try TaskRepositoryFixture.container()
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    @discardableResult
    func todo(_ title: String = "needle", deleted: Date? = nil) -> TodoItem {
        let item = TodoItem(title: title, dayKey: QuerySessionFixture.today,
                            createdAt: TodoQueryFixture.created, deletedAt: deleted)
        context.insert(item)
        return item
    }

    @discardableResult
    func child(_ parent: TodoItem?, title: String = "needle child", deleted: Date? = nil) -> SubtaskItem {
        let item = SubtaskItem(title: title, createdAt: TodoQueryFixture.created, deletedAt: deleted, todo: parent)
        context.insert(item)
        return item
    }

    func read(_ source: String = "/tasks", reads: TaskContentQueryReads? = nil) -> TaskContentQueryReadResult {
        let adapter = reads.map(TaskContentQueryReader.init(reads:)) ?? reader
        return adapter.readTasks(session: TodoQueryFixture.session(source), requestID: TodoQueryFixture.requestID)
    }
}
