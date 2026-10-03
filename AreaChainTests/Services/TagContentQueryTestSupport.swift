import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 继续使用全 schema 内存容器；最终 Batch 必须由真实模型读取生成。
@MainActor
struct TagContentQueryFixture {
    let family: RoutineContentQueryFixture
    var context: ModelContext { family.context }
    init() throws { family = try .init() }

    @discardableResult
    func tag(_ name: String = "needle", order: Int = 0, id: UUID = UUID(), deleted: Date? = nil) -> TagItem {
        let value = TagItem(id: id, name: name, sortOrder: order, deletedAt: deleted)
        context.insert(value)
        return value
    }

    func read(_ source: String = "/tags", view: TagQueryView = .inputOrder, usage: TagQueryUsageInput? = nil,
              tags: TagContentQueryReads? = nil, tasks: TaskContentQueryReads? = nil) -> TaskFamilyContentQueryReadResult {
        let reader = TaskFamilyContentQueryReader(tasks: tasks ?? .init(context: context),
            routines: .init(context: context), tags: tags ?? .init(context: context))
        return reader.read(session: TodoQueryFixture.session(source), requestID: TodoQueryFixture.requestID,
            observation: RoutineContentQueryFixture.observation(), options: .init(tagView: view), injectedUsage: usage)
    }

    static func response(_ result: TaskFamilyContentQueryReadResult) throws -> TagQueryResponse {
        try #require(ContentQueryBatchReader.read(result.batch).readings.compactMap {
            if case .tag(let response) = $0 { return response }; return nil
        }.first)
    }
}
