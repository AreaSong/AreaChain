import Foundation
import SwiftData
import Testing
@testable import AreaChain

extension SearchReadFixture {
    static func tagUsage(configure: @escaping (inout TagUsageContentQueryReads) -> Void = { _ in }) throws -> SearchReadFixture {
        try .init(configureTagUsage: configure)
    }

    func prepareUsage(_ source: String = "/tags", view: TagQueryView = .catalog(.frequent)) throws
        -> (handle: ContentQueryReadHandle, details: TagUsageContentQueryDetails) {
        try handoff.send(.query(.setInput(source)))
        return try session.prepareTagUsage(requestID: TodoQueryFixture.requestID,
            observation: RoutineContentQueryFixture.observation(), options: .init(tagView: view))
    }

    func publishUsage(_ source: String = "/tags", view: TagQueryView = .catalog(.frequent)) async throws -> ContentQueryReadPublication {
        let prepared = try prepareUsage(source, view: view)
        try session.evaluate(prepared.handle)
        #expect(try await session.publish(prepared.handle).outcome == .published)
        return try session.presentation()
    }

    static func usageResponse(_ publication: ContentQueryReadPublication) throws -> TagQueryResponse {
        try #require(publication.response.readings.compactMap {
            if case .tag(let value) = $0 { return value }; return nil
        }.first)
    }
}

@MainActor final class TagUsageReadProbe {
    var calls: [CommandObjectType: Int] = [:]
    var replacement: (CommandObjectType, ContentQuerySourceCoverage)?
    var after: (() throws -> Void)?
    func configure(_ reads: inout TagUsageContentQueryReads) {
        reads.todos = wrap(.todo, reads.todos)
        reads.subtasks = wrap(.subtask, reads.subtasks)
        reads.routines = wrap(.routine, reads.routines)
        reads.diaries = wrap(.diary, reads.diaries)
        reads.tags = wrap(.tag, reads.tags)
    }
    private func wrap<Value>(_ type: CommandObjectType, _ read: @escaping () throws -> ContentQueryBatchSource<Value>)
        -> () throws -> ContentQueryBatchSource<Value> {
        {
            self.calls[type, default: 0] += 1
            if let (target, state) = self.replacement, target == type {
                switch state {
                case .notProvided: return .notProvided
                case .failed: throw TagUsageSyntheticFailure()
                case .partial: return .partial(try read().values ?? [])
                case .complete: break
                }
            }
            let rows = try read()
            try self.after?()
            return rows
        }
    }
}

struct TagUsageSyntheticFailure: Error {}
