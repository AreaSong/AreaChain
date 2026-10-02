import Foundation
@testable import AreaChain

enum ImageQueryFixture {
    static let ownerID = ImageAssociationFixture.key.id
    static let filename = "📷 Cafe\u{301} 合成 工作 photo.png"
    static let dates = QuerySessionFixture.page().dates
    static let names = TodoQueryFixture.names

    static var owners: ImageOwnerSnapshots {
        var todo = ImageAssociationFixture.todo()
        todo.tagIDs = TodoQueryFixture.work.uuidString
        todo.isImportant = true
        todo.remindMinutes = 540
        var routine = ImageAssociationFixture.routine()
        routine.tagIDs = todo.tagIDs
        routine.isImportant = true
        routine.remindMinutes = 540
        var diary = ImageAssociationFixture.diary()
        diary.tagIDs = todo.tagIDs
        return .init(todos: [todo], routines: [routine], diaries: [diary])
    }

    static var images: [ImageAttachmentMetadata] {
        [AttachmentOwner.todo, .routine, .diary].enumerated().map { index, kind in
            var image = ImageAssociationFixture.image(owner: .init(kind: kind, id: ownerID),
                id: UUID(uuidString: String(format: "72000000-0000-0000-0000-%012d", index + 1))!)
            image.filename = filename
            return image
        }
    }

    static func association(
        images: [ImageAttachmentMetadata]? = images, owners: ImageOwnerSnapshots = owners,
        coverage: ImageAssociationCoverage = ImageAssociationFixture.coverage
    ) -> ImageAssociationRequest {
        .init(images: images, owners: owners, privacy: .init(tagNames: names, privateTagIDs: []), coverage: coverage)
    }

    static func request(_ source: String = "/images", association: ImageAssociationRequest = association()) -> ImageQueryRequest {
        .init(requestID: TodoQueryFixture.requestID, session: TodoQueryFixture.session(source),
              association: association, tagNames: names)
    }

    static func read(_ source: String, association: ImageAssociationRequest = association()) -> ImageQueryResponse {
        ImageQueryProvider.read(request(source, association: association))
    }

    static func scheduled(_ source: String, checks: [CheckSnapshot] = []) -> ImageQueryRequest {
        var request = request(source)
        request.scheduleEvidence = [RoutineQueryFixture.evidence("2026-09-01", "2026-10-07", id: ownerID)]
        request.checks = checks
        request.checkCoverage = [.init(routineID: ownerID, completeIntervals: [QuerySessionFixture.interval()])]
        return request
    }
}
