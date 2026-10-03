import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TrashContentQueryIntegrationTests {
    @Test func promotedChildIsSelectableWhileParentContextIsNotAnOperationTarget() async throws {
        let f = try SearchReadFixture.trash()
        let task = f.data.tags.family.task.todo("parent", deleted: TodoQueryFixture.created)
        let child = f.data.tags.family.task.child(task, title: "needle", deleted: TodoQueryFixture.created)
        let publication = try await f.publishTrash("/trash needle")
        let version = publication.pagination.snapshot.version
        let parentID = CommandObjectReference(type: .todo, id: task.id)
        #expect(try f.session.browse(.init(version: version, action: .select(parentID, true))).rejection == .invalidTarget)
        _ = try f.session.browse(.init(version: version, action: .move(.next, inputEditing: false)))
        _ = try f.session.browse(.init(version: version, action: .open(inputEditing: false)))
        let intent = try f.session.consumeOpenIntent()
        #expect(intent.object == .init(type: .subtask, id: child.id))
        #expect(intent.parent == parentID && intent.viewingTrash && intent.requiresFreshBusinessValidation)
        #expect(throws: ContentQueryReadSessionError.noOpenIntent) { try f.session.consumeOpenIntent() }
    }

    @Test func sixTypesAndLiveParentsReadOnceThroughPublication() async throws {
        let probe = TrashReadProbe()
        let f = try SearchReadFixture.trash(configure: probe.configure)
        let date = TodoQueryFixture.created
        let task = f.data.tags.family.task.todo("needle task", deleted: date)
        let child = f.data.tags.family.task.child(task, title: "needle child", deleted: date)
        let routine = f.data.tags.family.routine("needle routine", deleted: date)
        let diary = f.data.diary("needle diary", deleted: date)
        let tag = f.data.tags.tag("needle tag", deleted: date)
        let image = f.image(.init(kind: .diary, id: diary.id), name: "needle.png", deleted: date)
        let live = f.data.tags.family.task.todo("live parent")
        let independent = f.data.tags.family.task.child(live, title: "needle independent", deleted: date)
        let publication = try await f.publishTrash("/trash needle")
        let response = try SearchReadFixture.trashResponse(publication)
        let expected = Set([task.id, child.id, routine.id, diary.id, tag.id, image.id, independent.id])
        #expect(Set(response.matches.map(\.id.id)) == expected)
        #expect(response.typeCoverage.values.allSatisfy { $0 == .completeIncludingDeleted })
        #expect(response.matches.first { $0.id.id == independent.id }?.object.relation
            == .independent(parent: .init(type: .todo, id: live.id), reason: .parentIsLive))
        #expect(probe.calls.count == 6 && probe.calls.values.allSatisfy { $0 == 1 })
        #expect(publication.response.readings.count == 1)
        #expect(publication.pagination.snapshot.source.rows.count == 7)
        #expect(await f.system.items.isEmpty)
    }

    @Test func exactCascadeEarlierIndependentAndChildPromotionKeepCounts() async throws {
        let f = try SearchReadFixture.trash()
        let date = TodoQueryFixture.created
        let task = f.data.tags.family.task.todo("parent", deleted: date)
        let child = f.data.tags.family.task.child(task, title: "child", deleted: date)
        let earlier = f.data.tags.family.task.child(task, title: "earlier", deleted: date.addingTimeInterval(-0.001))
        let image = f.image(.init(kind: .todo, id: task.id), name: "picture.png", deleted: date)
        let onlyChild = try SearchReadFixture.trashResponse(await f.publishTrash("/trash child"))
        #expect(onlyChild.definiteMatchCount == 1 && onlyChild.visibleGroupCount == 1 && onlyChild.visibleContextCount == 2)
        #expect(onlyChild.groups.first?.displayAnchor == .init(type: .subtask, id: child.id))
        #expect(onlyChild.groups.first?.source.id == .init(type: .todo, id: task.id))
        #expect(Set(onlyChild.groups.first?.context.map(\.id.id) ?? []) == [task.id, image.id])
        #expect(onlyChild.matches.first?.object.restoration.independent == .notProvided)
        let all = try SearchReadFixture.trashResponse(await f.publishTrash())
        #expect(all.definiteMatchCount == 4 && all.visibleGroupCount == 2 && all.visibleContextCount == 0)
        #expect(all.matches.first { $0.id.id == earlier.id }?.object.relation
            == .independent(parent: .init(type: .todo, id: task.id), reason: .timestampsDiffer))
        #expect(all.matches.allSatisfy { $0.object.restoration.requiresFreshBusinessValidation })
        #expect(all.matches.allSatisfy { !$0.object.restoration.provesFileAvailability })
    }

    @Test func normalScopesDoNotReadAndTagOnlyDoesNotFetchOwners() async throws {
        let probe = TrashReadProbe()
        let bodies = BodyReadProbe()
        let f = try SearchReadFixture.trash(configure: probe.configure, bodies: { $0.observeContent = bodies.observe })
        for source in ["needle", "/tasks", "/diaries", "/images", "/tags"] { _ = try f.prepareTrash(source) }
        #expect(probe.calls.isEmpty && bodies.calls == 0)
        f.data.tags.tag("deleted", deleted: TodoQueryFixture.created)
        let result = try SearchReadFixture.trashResponse(await f.publishTrash(types: [.tag]))
        #expect(result.matches.count == 1)
        #expect(probe.calls == [.tag: 1] && bodies.calls == 0)
    }

    @Test func paginationAndHighlightsUseSafeMatchesAndFreezeCopies() async throws {
        let f = try SearchReadFixture.trash()
        for index in 0..<45 { f.data.tags.family.task.todo("needle \(index)", deleted: TodoQueryFixture.created) }
        let publication = try await f.publishTrash("/trash needle")
        #expect(publication.pagination.snapshot.source.rows.count == 45)
        #expect(publication.pagination.snapshot.source.rows.allSatisfy { $0.primary?.highlights.isEmpty == false })
        #expect(publication.pagination.snapshot.visible.count == 20)
        let event = ContentQueryPaginationEvent(stamp: publication.pagination.stamp, action: .loadMoreUnits)
        #expect(try f.session.loadMore(event).didPublish)
        #expect(try f.session.presentation().pagination.snapshot.visible.count == 40)
        #expect(try f.session.loadMore(event).rejection == .staleRevision)
        let row = try #require(f.data.context.fetch(FetchDescriptor<TodoItem>()).first)
        row.title = "MUTATED_AFTER_FREEZE"
        #expect(!TrashQueryFixture.strings(publication).contains("MUTATED_AFTER_FREEZE"))
        #expect(throws: ContentQueryReadSessionError.self) { try f.session.presentation() }
    }

    @Test func readDoesNotSaveRollbackRestoreDeleteOrAccessAttachmentFiles() async throws {
        let f = try SearchReadFixture.trash()
        let date = TodoQueryFixture.created
        let task = f.data.tags.family.task.todo("saved", deleted: date)
        let image = f.image(.init(kind: .todo, id: task.id), deleted: date)
        image.storageID = UUID(); image.retiredStorageID = UUID()
        let storage = image.storageID; let retired = image.retiredStorageID
        try f.data.context.save() // 仅隔离夹具基线；搜索不持有保存接口。
        task.title = "unsaved"
        let publication = try await f.publishTrash()
        #expect(f.data.context.hasChanges && task.title == "unsaved")
        #expect(task.deletedAt == date && image.deletedAt == date)
        #expect(image.storageID == storage && image.retiredStorageID == retired)
        let other = ModelContext(f.data.tags.family.task.container)
        #expect(try other.fetch(FetchDescriptor<TodoItem>()).first?.title == "saved")
        let strings = TrashQueryFixture.strings(publication)
        #expect(!strings.contains(storage!.uuidString))
        #expect(!strings.contains(retired!.uuidString))
        #expect(await f.system.items.isEmpty)
    }
}
