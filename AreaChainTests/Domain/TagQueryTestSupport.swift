import Foundation
@testable import AreaChain

enum TagQueryFixture {
    static func tag(_ number: Int, _ name: String = "工作") -> TagQuerySnapshot {
        .init(id: UUID(uuidString: String(format: "71000000-0000-0000-0000-%012d", number))!, name: name)
    }

    static func read(
        _ source: String, _ tags: [TagQuerySnapshot], usage: TagQueryUsageInput? = nil, view: TagQueryView = .inputOrder
    ) -> TagQueryResponse {
        read(TodoQueryFixture.session(source), tags, usage: usage, view: view)
    }

    static func read(
        _ session: ContentQuerySession, _ tags: [TagQuerySnapshot], usage: TagQueryUsageInput? = nil, view: TagQueryView = .inputOrder
    ) -> TagQueryResponse {
        TagQueryProvider.read(.init(requestID: TodoQueryFixture.requestID, session: session, tags: tags, usage: usage, view: view))
    }

    static func record(_ tag: TagQuerySnapshot, count: Int = 1, time: TimeInterval = 10) -> TagUsageRecord {
        .init(tagID: tag.id, activeCount: count, latestCreatedAt: count == 0 ? nil : Date(timeIntervalSince1970: time))
    }
}
