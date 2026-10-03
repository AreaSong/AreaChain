import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TaskContentQueryIntegrationTests {
    @Test func realModelsFlowThroughSortSummaryGroupingAndPagination() throws {
        let f = try TaskContentQueryFixture()
        let notes = f.todo("other")
        notes.notes = "before needle after"
        let exact = f.todo("needle")
        let child = f.child(exact)
        let tag = TagItem(name: "工作", sortOrder: 0)
        f.context.insert(tag)
        notes.tagIDs = TagIDList.encode([tag.id])
        exact.tagIDs = notes.tagIDs
        child.tagIDs = notes.tagIDs
        try f.context.save()
        let owner = try QueryReadFixture.owner(f.read("/tasks needle #工作").batch, pageSize: 1)
        let first = try #require(owner.published)
        let snapshot = first.pagination.snapshot
        #expect(first.response.definiteMatchCount == 3)
        #expect(snapshot.source.source.ordered.first?.id.id == exact.id)
        #expect(snapshot.source.rows.first { $0.id.id == notes.id }?.summary?.text.contains("needle") == true)
        #expect(snapshot.units.count == 3 && snapshot.visible.count == 1)
        let childRow = try #require(snapshot.source.rows.first { $0.id.id == child.id })
        #expect(childRow.relations.contains { $0.role == .parentTask && $0.object.id == exact.id })
        #expect(owner.loadMore(QueryReadFixture.load(owner)).didPublish)
        #expect(owner.published?.pagination.snapshot.visible.count == 2)
        #expect(owner.published?.pagination.snapshot.sharesSource(with: snapshot) == true)
        #expect(owner.loadMore(QueryReadFixture.load(owner)).didPublish)
        #expect(owner.published?.pagination.snapshot.visible.count == 3)
    }

    @Test func frozenPublicationAndExplicitRereadRejectOldSourceAndTicket() throws {
        let f = try TaskContentQueryFixture()
        let todo = f.todo()
        let child = f.child(todo)
        try f.context.save()
        let result = f.read("/tasks needle")
        let owner = try QueryReadFixture.owner(result.batch)
        let old = try #require(owner.published)
        let task = try owner.begin(result.batch)
        let ticket = try owner.evaluate(task)
        todo.title = "changed"
        child.title = "changed child"
        #expect(old.pagination.snapshot.source.rows.contains { $0.primary?.text == "needle" })
        #expect(owner.published?.task == old.task)
        #expect(result.batch.snapshots.todos.values?.first?.title == "needle")
        let reread = f.read("/tasks needle")
        let next = try owner.begin(reread.batch)
        #expect(next.requestID == task.requestID && next.source != task.source)
        #expect(throws: ContentQueryReadError.self) { try owner.publish(ticket) }
        #expect(throws: ContentQueryReadError.self) { try owner.evaluate(task) }
        #expect(throws: ContentQueryReadError.self) { try owner.continueReading(source: old.task.source, budget: .init()) }
        try owner.publish(owner.evaluate(next))
        #expect(owner.published?.response.definiteMatchCount == 0)
        #expect(owner.loadMore(.init(stamp: old.pagination.stamp, action: .loadMoreUnits)).rejection == .staleSource)
        #expect(f.context.hasChanges)
    }

    @Test func realTombstonesReachExistingGroupBuilderWithoutNestedDuplicateInput() throws {
        let f = try TaskContentQueryFixture()
        let stamp = TodoQueryFixture.created
        let parent = f.todo("needle", deleted: stamp)
        let child = f.child(parent, title: "needle", deleted: stamp)
        try f.context.save()
        let result = f.read("/trash needle")
        let owner = try QueryReadFixture.owner(result.batch)
        let snapshot = try #require(owner.published?.pagination.snapshot)
        #expect(result.batch.snapshots.todos.values?.first?.subtasks.isEmpty == true)
        #expect(snapshot.units.contains { $0.sourceGroup?.id == parent.id && $0.hits.contains { $0.id == child.id } })
        #expect(owner.published?.response.completeness.matchingIsComplete == false)
    }
}
