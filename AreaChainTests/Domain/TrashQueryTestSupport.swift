import Foundation
@testable import AreaChain

enum TrashQueryFixture {
    static func read(_ source: String, _ input: TrashTombstoneInput = TrashFixture.family()) -> TrashQueryResponse {
        read(TodoQueryFixture.session(source), input)
    }
    static func read(_ session: ContentQuerySession, _ input: TrashTombstoneInput) -> TrashQueryResponse {
        TrashQueryProvider.read(.init(requestID: TodoQueryFixture.requestID, session: session, input: input,
            tagNames: TodoQueryFixture.names, tagNamesCoverage: .completeIncludingDeleted))
    }
    static func all() -> TrashTombstoneInput {
        var input = TrashFixture.family()
        input.routines = [TrashFixture.routine()]
        input.diaries = [TrashFixture.diary()]
        input.tags = [.init(id: TrashFixture.otherID, name: "合成标签", deletedAt: TrashFixture.date)]
        return input
    }
    static func strings(_ value: Any) -> Set<String> {
        if let string = value as? String { return [string] }
        if let id = value as? UUID { return [id.uuidString] }
        return Mirror(reflecting: value).children.reduce(into: Set<String>()) { values, child in
            values.formUnion(strings(child.value))
        }
    }
}
