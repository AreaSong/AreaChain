import Foundation
import os
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TagContentQueryFailureTests {
    private enum FetchFailure: Error { case syntheticDatabaseAndTagValue }

    @Test func failedCatalogIsNotCompleteEmptyAndIndependentTasksSurvive() throws {
        let f = try TagContentQueryFixture()
        let tag = f.tag()
        let todo = f.family.task.todo()
        todo.tagIDs = tag.id.uuidString
        var reads = TagContentQueryReads(context: f.context)
        reads.allTags = { throw FetchFailure.syntheticDatabaseAndTagValue }
        let result = f.read("", tags: reads)
        #expect(result.tagCatalog.source == .failed && result.tagCatalog.issues == [.fetchFailed])
        #expect(result.batch.snapshots.tags.values == nil && result.batch.snapshots.tags.coverage == .failed)
        #expect(result.tagNamesCoverage == .failed && result.tagIssues == [.fetchFailed])
        #expect(result.batch.facts.metadata.tagNames == nil && result.batch.facts.metadata.privateTagIDs == nil)
        #expect(result.batch.snapshots.todos.values?.map(\.id) == [todo.id])
        let response = ContentQueryBatchReader.read(result.batch)
        #expect(response.definiteMatchCount == 1 && !response.completeness.matchingIsComplete)
        #expect(response.completeness.providers.contains { $0.limitations.contains(.source(.tag, .failed)) })
        #expect(!String(reflecting: result).contains("syntheticDatabase"))
        #expect(!String(reflecting: result.tagCatalog).contains("syntheticDatabase"))
        #expect(!String(reflecting: result.tagCatalog.issues).contains("syntheticDatabase"))
        let tagOnly = f.read(tags: reads)
        #expect(tagOnly.tagNamesCoverage == .notProvided && tagOnly.tagCatalog.source == .failed)
        #expect(!ContentQueryBatchReader.read(tagOnly.batch).completeness.matchingIsComplete)
    }

    @Test func failedTasksDoNotSuppressSuccessfulCatalog() throws {
        let f = try TagContentQueryFixture()
        let tag = f.tag()
        var tasks = TaskContentQueryReads(context: f.context)
        tasks.todos = { throw FetchFailure.syntheticDatabaseAndTagValue }
        tasks.subtasks = { throw FetchFailure.syntheticDatabaseAndTagValue }
        let result = f.read("", tasks: tasks)
        #expect(result.batch.snapshots.todos.coverage == .failed && result.batch.snapshots.subtasks.coverage == .failed)
        #expect(result.tagCatalog.source == .complete)
        #expect(try TagContentQueryFixture.response(result).matches.map(\.tag.id) == [tag.id])
    }

    @Test func failedReplacementDoesNotRetainEarlierCatalogCoverage() throws {
        let f = try TagContentQueryFixture()
        f.tag()
        var batch = f.read().batch
        var reads = TagContentQueryReads(context: f.context)
        reads.allTags = { throw FetchFailure.syntheticDatabaseAndTagValue }
        _ = TagContentQueryReader(reads: reads).readSources(into: &batch)
        #expect(batch.snapshots.tags.coverage == .failed && batch.snapshots.tags.values == nil)
        #expect(batch.facts.trashCoverage.types[.tag] == .notProvided)
    }

    @Test func pendingInsertUpdateDeleteSurviveSuccessAndFailureWithoutEvents() throws {
        let f = try TagContentQueryFixture()
        let original = f.tag("saved")
        let removed = f.tag("removed", order: 1)
        try f.context.save()
        original.name = "pending"
        original.colorToken = "raw-pending"
        original.sortOrder = 9
        original.isPrivateDiary = true
        f.context.delete(removed)
        let inserted = f.tag("inserted")
        let counter = TagReadEventCounter()
        let token = NotificationCenter.default.addObserver(forName: .boardDidChange, object: nil, queue: nil) { _ in counter.increment() }
        defer { NotificationCenter.default.removeObserver(token) }
        let result = f.read()
        #expect(Set(result.batch.snapshots.tags.values?.map(\.name) ?? []) == ["pending", "inserted"])
        var reads = TagContentQueryReads(context: f.context)
        reads.allTags = { throw FetchFailure.syntheticDatabaseAndTagValue }
        #expect(f.read(tags: reads).tagCatalog.source == .failed)
        #expect(f.context.hasChanges && inserted.modelContext === f.context && !f.context.autosaveEnabled)
        #expect(original.name == "pending" && original.colorToken == "raw-pending" && original.isPrivateDiary && original.sortOrder == 9)
        let independent = ModelContext(f.family.task.container)
        let saved = try independent.fetch(FetchDescriptor<TagItem>())
        #expect(Set(saved.map(\.name)) == ["saved", "removed"])
        #expect(saved.allSatisfy { !$0.isPrivateDiary && $0.colorToken == "moss" })
        #expect(counter.count == 0)
    }
}

private final class TagReadEventCounter: Sendable {
    private let value = OSAllocatedUnfairLock(initialState: 0)
    var count: Int { value.withLock { $0 } }
    func increment() { value.withLock { $0 += 1 } }
}
