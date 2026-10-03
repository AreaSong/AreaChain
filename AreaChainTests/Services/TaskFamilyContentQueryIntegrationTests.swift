import Foundation
import os
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TaskFamilyContentQueryIntegrationTests {
    @Test func taskFamilySharesOneTagReadAndFlowsThroughReadOwnerToPagination() throws {
        let f = try RoutineContentQueryFixture()
        let todo = f.task.todo("needle")
        let child = f.task.child(todo)
        let routine = f.routine("other")
        routine.notes = "before needle after"
        let tags = [TagItem(name: "工作", sortOrder: 0), TagItem(name: "学习", sortOrder: 1), TagItem(name: "习惯", sortOrder: 2)]
        tags.forEach { f.context.insert($0) }
        todo.tagIDs = TagIDList.encode([tags[0].id])
        child.tagIDs = TagIDList.encode([tags[1].id])
        routine.tagIDs = TagIDList.encode([tags[2].id])
        try f.context.save()
        var tasks = TaskContentQueryReads(context: f.context)
        let fetch = tasks.tags
        var calls: [Set<UUID>] = []
        tasks.tags = { ids in calls.append(ids); return try fetch(ids) }
        let result = f.read("/tasks needle", tasks: tasks)
        #expect(calls == [Set(tags.map(\.id))])
        #expect(result.batch.facts.metadata.tagNames == Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0.name) }))
        let owner = try QueryReadFixture.owner(result.batch, pageSize: 1)
        let publication = try #require(owner.published)
        #expect(publication.response.definiteMatchCount == 3 && publication.response.completeness.matchingIsComplete)
        #expect(publication.response.readings.count == 3)
        #expect(publication.pagination.snapshot.source.source.ordered.first?.id.id == todo.id)
        #expect(publication.pagination.snapshot.source.rows.first { $0.id.id == routine.id }?.summary?.text.contains("needle") == true)
        #expect(publication.pagination.snapshot.visible.count == 1)
        #expect(owner.loadMore(QueryReadFixture.load(owner)).didPublish)
        #expect(owner.loadMore(QueryReadFixture.load(owner)).didPublish)
        #expect(owner.published?.pagination.snapshot.visible.count == 3)
        #expect(result.batch.snapshots.diaries.coverage == .notProvided && result.batch.snapshots.images.coverage == .notProvided)
        #expect(result.batch.snapshots.tags.coverage == .notProvided && result.batch.snapshots.clipboard.coverage == .notProvided)
        #expect(!ContentQueryBatchReader.read(f.read("/tasks has:image").batch).completeness.matchingIsComplete)
        #expect(!ContentQueryBatchReader.read(f.read("/tasks status:done").batch).completeness.matchingIsComplete)
    }

    @Test func sessionOptionsAndOccurrenceBudgetRemainAuthoritative() throws {
        let f = try RoutineContentQueryFixture()
        f.routine()
        f.routine()
        var options = ContentQueryBatchOptions()
        options.locale = Locale(identifier: "zh-Hans")
        options.occurrenceBudget.maxInputItems = 1
        let result = f.records(options: options)
        #expect(result.batch.snapshots.routines.values?.count == 2)
        #expect(result.batch.options.locale == options.locale && result.batch.options.occurrenceBudget == options.occurrenceBudget)
        #expect(result.batch.requestID == TodoQueryFixture.requestID)
        #expect(result.batch.session == RoutineOccurrenceQueryFixture().session)
        #expect(try !RoutineContentQueryFixture.occurrence(result).coverage.enumerationIsComplete)
    }

    @Test func unsavedChangesSurviveSuccessAndFailureWithoutSaveRollbackOrEvents() throws {
        let f = try RoutineContentQueryFixture()
        let parent = f.routine("saved")
        let removed = f.routine("removed")
        let check = f.check(parent)
        try f.context.save()
        parent.title = "pending"
        check.isDone = true
        f.context.delete(removed)
        let inserted = f.routine("inserted")
        let counter = FamilyReadEventCounter()
        let token = NotificationCenter.default.addObserver(forName: .boardDidChange, object: nil, queue: nil) { _ in counter.increment() }
        defer { NotificationCenter.default.removeObserver(token) }
        let result = f.read("/routines on:today")
        #expect(Set(result.batch.snapshots.routines.values?.map(\.title) ?? []) == ["pending", "inserted"])
        #expect(result.batch.facts.routine.checks.first?.isDone == true)
        #expect(f.context.hasChanges && inserted.modelContext === f.context && !f.context.autosaveEnabled)
        struct Failure: Error {}
        var reads = RoutineContentQueryReads(context: f.context)
        reads.allChecks = { throw Failure() }
        #expect(f.read("/routines on:today", reads: reads).routine.checkSource == .failed)
        #expect(f.context.hasChanges && parent.title == "pending" && check.isDone)
        let other = ModelContext(f.task.container)
        #expect(Set(try other.fetch(FetchDescriptor<DailyRoutine>()).map(\.title)) == ["saved", "removed"])
        #expect(try other.fetch(FetchDescriptor<RoutineCheck>()).first?.isDone == false)
        #expect(counter.count == 0)
    }

    @Test func explicitRereadChangesSourceAndCannotPublishOldTicket() throws {
        let f = try RoutineContentQueryFixture()
        let parent = f.routine()
        let row = f.check(parent)
        try f.context.save()
        let original = f.records("date:today status:open")
        let owner = try QueryReadFixture.owner(original.batch)
        let oldPublication = try #require(owner.published)
        let task = try owner.begin(original.batch)
        let ticket = try owner.evaluate(task)
        parent.title = "changed"
        row.isDone = true
        #expect(original.batch.snapshots.routines.values?.first?.title == "needle")
        #expect(original.batch.facts.routine.checks.first?.isDone == false)
        #expect(owner.published?.task == oldPublication.task)
        let fresh = try owner.begin(f.records("date:today status:open").batch)
        #expect(fresh.source != task.source && fresh.requestID == task.requestID)
        #expect(throws: ContentQueryReadError.self) { try owner.publish(ticket) }
        try owner.publish(owner.evaluate(fresh))
        #expect(owner.published?.response.definiteMatchCount == 0)
        #expect(f.context.hasChanges)
    }
}

private final class FamilyReadEventCounter: Sendable {
    private let value = OSAllocatedUnfairLock(initialState: 0)
    var count: Int { value.withLock { $0 } }
    func increment() { value.withLock { $0 += 1 } }
}
