import Foundation
import Testing
@testable import AreaChain

extension SearchReadFixture {
    static func trash(configure: @escaping (inout TrashContentQueryReads) -> Void = { _ in },
                      bodies: ((inout ContentQueryBodyReads) -> Void)? = nil) throws -> SearchReadFixture {
        try .init(configureTrash: configure, configure: bodies)
    }

    func prepareTrash(_ source: String = "/trash", requestID: UUID = TodoQueryFixture.requestID,
                      types: Set<CommandObjectType>? = nil) throws
        -> (handle: ContentQueryReadHandle, details: TrashContentQueryReadDetails) {
        try handoff.send(.query(.setInput(source)))
        if let types { try handoff.send(.query(.addCondition(.page(.contentTypes(types))))) }
        return try session.prepareTrash(requestID: requestID, observation: RoutineContentQueryFixture.observation())
    }

    func publishTrash(_ source: String = "/trash", types: Set<CommandObjectType>? = nil) async throws -> ContentQueryReadPublication {
        let handle = try prepareTrash(source, types: types).handle
        try session.evaluate(handle)
        #expect(try await session.publish(handle).outcome == .published)
        return try session.presentation()
    }

    static func trashResponse(_ publication: ContentQueryReadPublication) throws -> TrashQueryResponse {
        try #require(publication.response.readings.compactMap {
            if case .trash(let value) = $0 { return value }; return nil
        }.first)
    }
}

@MainActor final class TrashReadProbe {
    var calls: [CommandObjectType: Int] = [:]
    func configure(_ reads: inout TrashContentQueryReads) {
        reads.todos = wrap(.todo, reads.todos)
        reads.subtasks = wrap(.subtask, reads.subtasks)
        reads.routines = wrap(.routine, reads.routines)
        reads.diaries = wrap(.diary, reads.diaries)
        reads.tags = wrap(.tag, reads.tags)
        reads.images = wrap(.image, reads.images)
    }
    private func wrap<Value>(_ type: CommandObjectType, _ fetch: @escaping () throws -> Value) -> () throws -> Value {
        { self.calls[type, default: 0] += 1; return try fetch() }
    }
}
