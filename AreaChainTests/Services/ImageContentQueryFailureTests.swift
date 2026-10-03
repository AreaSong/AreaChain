import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct ImageContentQueryFailureTests {
    enum Failure: Error { case synthetic }

    @Test func newPartialBatchCannotRetainPreviousCompleteAssociation() async throws {
        var complete = true
        let f = try SearchReadFixture(imageMode: true, configureImages: { reads in
            let original = reads.attachments
            reads.attachments = { complete ? try original() : .partial([]) }
        })
        let task = f.data.tags.family.task.todo()
        f.image(.init(kind: .todo, id: task.id))
        #expect(try SearchReadFixture.todos(await f.publishImages("/tasks has:image")).matches.map(\.id.id) == [task.id])
        complete = false
        let next = try SearchReadFixture.todos(await f.publishImages("/tasks has:image"))
        #expect(next.matches.isEmpty && next.undeterminedObjects.contains { $0.id == task.id })
    }

    @Test(arguments: [0, 1, 2, 3]) func unavailablePartialFailureAndCompleteEmptyStayDistinct(mode: Int) async throws {
        let f = try SearchReadFixture(imageMode: true, configureImages: { reads in
            reads.attachments = {
                switch mode {
                case 0: return .notProvided
                case 1: return .partial([])
                case 2: throw Failure.synthetic
                default: return .complete([])
                }
            }
        })
        let task = f.data.tags.family.task.todo()
        let response = try SearchReadFixture.todos(await f.publishImages("/tasks has:image"))
        if mode == 3 { #expect(response.matches.isEmpty && response.undeterminedObjects.isEmpty) }
        else {
            #expect(response.matches.isEmpty)
            #expect(response.undeterminedObjects.contains { $0.id == task.id })
        }
    }

    @Test func completeCannotLieAboutMissingTombstoneOrDuplicatePhysicalRows() throws {
        var subset: [AttachmentItem] = []
        let f = try SearchReadFixture(imageMode: true, configureImages: { reads in
            reads.attachments = { .complete(subset) }
        })
        let task = f.data.tags.family.task.todo()
        let live = f.image(.init(kind: .todo, id: task.id))
        f.image(.init(kind: .todo, id: task.id), deleted: TodoQueryFixture.created).id = live.id
        subset = [live]
        #expect(throws: ContentQueryReadSessionError.self) { try f.prepareImages() }
        #expect(!f.session.hasPublicationPermit)
    }

    @Test func imageAndOwnerDuplicateLiveDeletedCollisionsAreNotFirstWins() async throws {
        let f = try SearchReadFixture(imageMode: true)
        let task = f.data.tags.family.task.todo()
        let routine = f.data.tags.family.routine()
        let first = f.image(.init(kind: .todo, id: task.id))
        f.image(.init(kind: .routine, id: routine.id), deleted: TodoQueryFixture.created).id = first.id
        let duplicateTask = f.data.tags.family.task.todo(deleted: TodoQueryFixture.created); duplicateTask.id = task.id
        let response = try SearchReadFixture.images(await f.publishImages())
        #expect(response.matches.isEmpty)
        #expect(response.associations[.init(kind: .todo, id: task.id)]?.ownerState == .ambiguous)
        #expect(response.associationDiagnostics.contains { $0.issue == .duplicateImageID })
        #expect(response.associationDiagnostics.contains { $0.issue == .duplicateOwnerID })
    }

    @Test func missingUnknownKindAndFailedOwnerAreNeverAbsent() async throws {
        let f = try SearchReadFixture(imageMode: true, configureImages: { reads in
            reads.tasks.todos = { throw Failure.synthetic }
        })
        let absentOwner = UUID()
        f.image(.init(kind: .todo, id: absentOwner))
        let routine = f.data.tags.family.routine()
        f.image(.init(kind: .routine, id: UUID()))
        f.image(.init(kind: .routine, id: routine.id)).ownerKind = "unknown"
        let response = try SearchReadFixture.images(await f.publishImages())
        #expect(response.matches.isEmpty)
        #expect(response.associations[.init(kind: .todo, id: absentOwner)]?.ownerState == .unknown)
        #expect(response.associations[.init(kind: .routine, id: routine.id)]?.presence == .unknown)
        #expect(response.associationDiagnostics.contains { $0.issue == .missingOwner })
    }

    @Test func tagFailureAndBodyFailureNeverPublishDiaryImages() async throws {
        let f = try SearchReadFixture(imageMode: true, configure: { reads in
            reads.tags.allTags = { throw Failure.synthetic }
        })
        let row = f.data.diary("public-looking")
        f.image(.init(kind: .diary, id: row.id))
        let response = try SearchReadFixture.images(await f.publishImages())
        #expect(response.matches.isEmpty)
        #expect(response.associations[.init(kind: .diary, id: row.id)]?.presence == .protected)
        let broken = try SearchReadFixture(imageMode: true, configure: { reads in
            reads.observeContent = { _ in throw Failure.synthetic }
        })
        let entry = broken.data.diary("public-looking")
        broken.image(.init(kind: .diary, id: entry.id))
        #expect(try SearchReadFixture.images(await broken.publishImages()).matches.isEmpty)
    }

    @Test func metadataProjectionContainsNoLocatorAndReadingDoesNotSaveOrRollback() async throws {
        let f = try SearchReadFixture(imageMode: true)
        let task = f.data.tags.family.task.todo()
        let row = f.image(.init(kind: .todo, id: task.id))
        row.storageID = UUID(); row.retiredStorageID = UUID()
        let storage = row.storageID; let retired = row.retiredStorageID
        try f.data.context.save() // 仅合成夹具建立已保存基线。
        task.title = "UNSAVED_CHANGE"
        let projection = ImageContentQueryReads.metadata(row)
        let labels = Set(Mirror(reflecting: projection).children.compactMap(\.label))
        #expect(labels == ["id", "ownerKind", "ownerID", "filename", "createdAt", "deletedAt", "protection"])
        _ = try await f.publishImages()
        #expect(f.data.context.hasChanges && task.title == "UNSAVED_CHANGE")
        #expect(row.storageID == storage && row.retiredStorageID == retired)
        let isolated = ModelContext(f.data.tags.family.task.container)
        #expect(try isolated.fetch(FetchDescriptor<TodoItem>()).first?.title != "UNSAVED_CHANGE")
    }
}
