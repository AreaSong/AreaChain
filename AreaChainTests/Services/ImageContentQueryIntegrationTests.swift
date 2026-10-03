import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct ImageContentQueryIntegrationTests {
    @Test func threeTypedOwnersAndSameUUIDReachDisplayWithoutAuxiliaryContent() async throws {
        let probe = ImageReadProbe()
        let f = try SearchReadFixture(imageMode: true, configureImages: probe.configure, configure: probe.bodies)
        let task = f.data.tags.family.task.todo("OWNER_BODY_NOT_FOR_IMAGES")
        let routine = f.data.tags.family.routine("ROUTINE_BODY_NOT_FOR_IMAGES")
        let diary = f.data.diary("DIARY_BODY_NOT_FOR_IMAGES")
        routine.id = task.id; diary.id = task.id
        let rows = [f.image(.init(kind: .todo, id: task.id), name: "alpha.png"),
                    f.image(.init(kind: .routine, id: routine.id), name: "beta.jpg"),
                    f.image(.init(kind: .diary, id: diary.id), name: "gamma.heic")]
        let publication = try await f.publishImages()
        let response = try SearchReadFixture.images(publication)
        #expect(Set(response.matches.map(\.id.id)) == Set(rows.map(\.id)))
        #expect(Set(response.matches.map(\.owner.kind)) == [.todo, .routine, .diary])
        #expect(publication.response.readings.count == 1)
        #expect(publication.pagination.snapshot.source.rows.count == 3)
        #expect(publication.pagination.snapshot.source.rows.allSatisfy { $0.primary != nil })
        let strings = TrashQueryFixture.strings(publication)
        #expect(!strings.contains("BODY_NOT_FOR_IMAGES"))
        #expect(probe.attachments == 1 && probe.todos == 1 && probe.routines == 1 && probe.diaries == 1 && probe.tags == 1)
        #expect(f.data.context.hasChanges)
        #expect(await f.system.items.isEmpty)
    }

    @Test func hasImageUsesSameTypedFactsForAllRecordProviders() async throws {
        let f = try SearchReadFixture(imageMode: true)
        let task = f.data.tags.family.task.todo()
        let noImage = f.data.tags.family.task.todo("empty")
        let routine = f.data.tags.family.routine()
        let diary = f.data.diary("ordinary diary")
        let keys = [AttachmentOwnerKey(kind: .todo, id: task.id), .init(kind: .routine, id: routine.id),
                    .init(kind: .diary, id: diary.id)]
        for key in keys { f.image(key) }
        let images = try SearchReadFixture.images(await f.publishImages())
        #expect(keys.allSatisfy { images.associations[$0]?.presence == .present })
        #expect(images.associations[.init(kind: .todo, id: noImage.id)]?.presence == .absent)
        #expect(try SearchReadFixture.todos(await f.publishImages("/tasks has:image")).matches.map(\.id.id) == [task.id])
        #expect(try SearchReadFixture.routines(await f.publishImages("/routines has:image")).matches.map(\.id.id) == [routine.id])
        #expect(try SearchReadFixture.diaryResponse(await f.publishImages("/diaries has:image")).matches.map(\.id.id) == [diary.id])
    }

    @Test func noDemandSkipsAttachmentsAndHasImageReadsOnlyRequestedOwnerType() async throws {
        let probe = ImageReadProbe()
        let f = try SearchReadFixture(imageMode: true, configureImages: probe.configure, configure: probe.bodies)
        let task = f.data.tags.family.task.todo()
        f.image(.init(kind: .todo, id: task.id))
        _ = try await f.publishImages("/routines")
        #expect(probe.attachments == 0 && probe.diaries == 0 && probe.todos == 0)
        _ = try await f.publishImages("/routines has:image")
        #expect(probe.attachments == 1 && probe.diaries == 0 && probe.todos == 0 && probe.routines == 2)
    }

    @Test func filenameFilteringSummaryAndPaginationUsePublicProjectionOnly() async throws {
        let f = try SearchReadFixture(imageMode: true)
        let task = f.data.tags.family.task.todo()
        for index in 0..<45 { f.image(.init(kind: .todo, id: task.id), name: "needle-\(index).png") }
        f.image(.init(kind: .todo, id: task.id), name: "excluded.png")
        let result = try await f.publishImages("/images needle")
        #expect(try SearchReadFixture.images(result).matches.count == 45)
        #expect(result.pagination.snapshot.source.rows.count == 45)
        #expect(result.pagination.snapshot.source.rows.allSatisfy { $0.primary?.highlights.isEmpty == false })
        #expect(result.pagination.snapshot.visible.count == 20)
        let event = ContentQueryPaginationEvent(stamp: result.pagination.stamp, action: .loadMoreUnits)
        #expect(try f.session.loadMore(event).didPublish)
        #expect(try f.session.presentation().pagination.snapshot.visible.count == 40)
        #expect(try f.session.loadMore(event).rejection == .staleRevision)
    }
}
