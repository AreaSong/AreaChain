import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor
struct DiaryContentQueryFixture {
    let tags: TagContentQueryFixture
    var context: ModelContext { tags.context }
    init() throws { tags = try .init() }

    @discardableResult
    func diary(_ text: String = DiaryQueryFixture.secret, deleted: Date? = nil) -> DiaryEntry {
        let entry = DiaryEntry(text: text, dayKey: QuerySessionFixture.today,
                               createdAt: TodoQueryFixture.created, deletedAt: deleted)
        context.insert(entry)
        return entry
    }

    func read(_ source: String = "/diaries", diaries: DiaryContentQueryReads? = nil,
              catalog: TagContentQueryReads? = nil, tasks: TaskContentQueryReads? = nil,
              options: ContentQueryBatchOptions = .init()) -> TaskFamilyContentQueryReadResult {
        TaskFamilyContentQueryReader(tasks: tasks ?? .init(context: context), routines: .init(context: context),
            tags: catalog ?? .init(context: context), diaries: diaries ?? .init(context: context))
            .read(session: TodoQueryFixture.session(source), requestID: TodoQueryFixture.requestID,
                  observation: RoutineContentQueryFixture.observation(), options: options)
    }

    static func response(_ result: TaskFamilyContentQueryReadResult) throws -> DiaryQueryResponse {
        try #require(ContentQueryBatchReader.read(result.batch).readings.compactMap {
            if case .diary(let response) = $0 { return response }; return nil
        }.first)
    }
}
