import Foundation
import Testing
@testable import AreaChain

extension SearchReadFixture {
    @discardableResult
    func image(_ owner: AttachmentOwnerKey, name: String = "synthetic.png", deleted: Date? = nil) -> AttachmentItem {
        let row = AttachmentItem(ownerKind: owner.kind.rawValue, ownerID: owner.id, filename: name,
                                 createdAt: TodoQueryFixture.created, deletedAt: deleted)
        data.context.insert(row)
        return row
    }

    func prepareImages(_ source: String = "/images") throws -> ContentQueryReadHandle {
        try handoff.send(.query(.setInput(source)))
        return try session.prepareImages(observation: RoutineContentQueryFixture.observation())
    }

    func publishImages(_ source: String = "/images") async throws -> ContentQueryReadPublication {
        let handle = try prepareImages(source)
        try session.evaluate(handle)
        try await session.publish(handle)
        return try session.presentation()
    }

    static func images(_ publication: ContentQueryReadPublication) throws -> ImageQueryResponse {
        try #require(publication.response.readings.compactMap {
            if case .image(let value) = $0 { return value }; return nil
        }.first)
    }

    static func todos(_ publication: ContentQueryReadPublication) throws -> TodoQueryResponse {
        try #require(publication.response.readings.compactMap {
            if case .todo(let value) = $0 { return value }; return nil
        }.first)
    }

    static func routines(_ publication: ContentQueryReadPublication) throws -> RoutineQueryResponse {
        try #require(publication.response.readings.compactMap {
            if case .routine(let value) = $0 { return value }; return nil
        }.first)
    }
}

@MainActor final class ImageReadProbe {
    var attachments = 0
    var todos = 0
    var routines = 0
    var diaries = 0
    var tags = 0
    func configure(_ reads: inout ImageContentQueryReads) {
        let original = reads.attachments
        reads.attachments = { self.attachments += 1; return try original() }
        let tasks = reads.tasks.todos
        reads.tasks.todos = { self.todos += 1; return try tasks() }
        let routines = reads.routines.definitions
        reads.routines.definitions = { self.routines += 1; return try routines() }
    }
    func bodies(_ reads: inout ContentQueryBodyReads) {
        let diaries = reads.diaries.allDiaries
        reads.diaries.allDiaries = { self.diaries += 1; return try diaries() }
        let tags = reads.tags.allTags
        reads.tags.allTags = { self.tags += 1; return try tags() }
    }
}
