import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TagContentQueryReaderTests {
    @Test func emptyCatalogIsCompleteWithoutSeedingPresetsOrOtherSources() throws {
        let f = try TagContentQueryFixture()
        let result = f.read()
        #expect(result.batch.snapshots.tags.values == [])
        #expect(result.tagCatalog.source == .complete && result.tagCatalog.issues.isEmpty)
        #expect(result.tagCatalog.usageOrigin == .notProvided && result.batch.facts.tagUsage == nil)
        #expect(ContentQueryBatchReader.read(result.batch).completeness.matchingIsComplete)
        #expect(result.batch.snapshots.todos.coverage == .notProvided && result.batch.snapshots.routines.coverage == .notProvided)
        #expect(result.batch.snapshots.diaries.coverage == .notProvided && result.batch.snapshots.images.coverage == .notProvided)
        #expect(result.batch.snapshots.clipboard.coverage == .notProvided && result.tagNamesCoverage == .notProvided)
        #expect(result.batch.facts.metadata.privateTagIDs == nil && !f.context.hasChanges)
        #expect(try f.context.fetch(FetchDescriptor<TagItem>()).isEmpty)
    }

    @Test func rawFieldsPresetsPrivateFlagsAndTombstonesProjectExactly() throws {
        let f = try TagContentQueryFixture()
        let ordinary = f.tag("  Café 中文  ", order: 4)
        ordinary.colorToken = "unknown-raw-token"
        let preset = f.tag(try #require(DiaryMemoTags.presets.first), order: -2)
        preset.isPrivateDiary = true
        preset.colorToken = TagColorToken.stamp.rawValue
        let deleted = f.tag("removed", order: 8, deleted: TodoQueryFixture.created)
        try f.context.save()
        let result = f.read()
        let rows = try #require(result.batch.snapshots.tags.values)
        #expect(rows.map(\.id) == [preset.id, ordinary.id, deleted.id])
        #expect(rows == [
            .init(id: preset.id, name: preset.name, sortOrder: -2, isPrivateDiary: true, colorToken: "stamp"),
            .init(id: ordinary.id, name: "  Café 中文  ", sortOrder: 4, colorToken: "unknown-raw-token"),
            .init(id: deleted.id, name: "removed", sortOrder: 8, deletedAt: TodoQueryFixture.created)
        ])
        #expect(rows[0].isDiaryPreset && rows[0].isPrivateDiary)
        #expect(rows[1].resolvedColorToken == ordinary.resolvedColorToken)
        #expect(try TagContentQueryFixture.response(result).matches.map(\.tag.id) == [preset.id, ordinary.id])
        #expect(result.batch.facts.trashCoverage.types[.tag] == .completeIncludingDeleted)
        #expect(result.batch.facts.metadata.privateTagIDs == nil)
        #expect(!f.context.hasChanges && ordinary.colorToken == "unknown-raw-token")
    }

    @Test func duplicateLiveAndDeletedIDsAreRetainedForProviderIsolation() throws {
        let f = try TagContentQueryFixture()
        let live = f.tag()
        f.tag("tombstone", order: 1, id: live.id, deleted: TodoQueryFixture.created)
        let safe = f.tag("needle safe", order: 2)
        try f.context.save()
        let result = f.read("/tags needle")
        #expect(result.batch.snapshots.tags.values?.count == 3 && result.tagCatalog.source == .complete)
        let response = try TagContentQueryFixture.response(result)
        #expect(response.matches.map(\.tag.id) == [safe.id])
        #expect(response.undeterminedObjects.map(\.id) == [live.id])
        #expect(response.diagnostics.contains { $0.issue == .duplicateTagID && $0.inputIndices == [0, 1] })
        #expect(!ContentQueryBatchReader.read(result.batch).completeness.matchingIsComplete)
    }

    @Test func sameNameDifferentIDsAreNotMergedAndSearchNeedsNoStatistics() throws {
        let f = try TagContentQueryFixture()
        let first = f.tag("Café", order: 2)
        let second = f.tag("Café", order: 1)
        f.tag("different", order: 3)
        try f.context.save()
        let result = f.read("/tags cafe", view: .catalog(.all))
        let response = try TagContentQueryFixture.response(result)
        #expect(response.matches.map(\.tag.id) == [second.id, first.id])
        #expect(response.matches.allSatisfy { $0.usageState == .unavailable && $0.usage == nil })
        #expect(response.isCompleteForCoveredTypes && response.coverage.usage == nil)
        #expect(ContentQueryBatchReader.read(result.batch).completeness.matchingIsComplete)
    }

    @Test(arguments: ["/go/tasks", "/tasks", "/routines", "/diaries", "/images", "/clipboard", "/tags date:today", "/tags \""])
    func unrelatedCommandAndInvalidQueriesDoNotReadFullCatalog(source: String) throws {
        let f = try TagContentQueryFixture()
        var reads = TagContentQueryReads(context: f.context)
        var count = 0
        reads.allTags = { count += 1; return [] }
        let result = f.read(source, tags: reads)
        #expect(count == 0 && result.batch.snapshots.tags.coverage == .notProvided)
        #expect(result.tagCatalog.source == .notProvided && result.tagCatalog.usageOrigin == .notProvided)
    }

    @Test func taskOnlyUsesAssociatedIDsWhileTagOnlyDoesNotFetchTasks() throws {
        let f = try TagContentQueryFixture()
        let linked = f.tag("linked")
        f.tag("unrelated").isPrivateDiary = true
        f.family.task.todo().tagIDs = TagIDList.encode([linked.id])
        var tasks = TaskContentQueryReads(context: f.context)
        let fetch = tasks.tags
        var calls: [Set<UUID>] = []
        tasks.tags = { ids in calls.append(ids); return try fetch(ids) }
        let result = f.read("/tasks #linked", tasks: tasks)
        #expect(calls == [[linked.id]] && result.tagNamesCoverage == .complete)
        #expect(result.batch.facts.metadata.tagNames == [linked.id: "linked"])
        #expect(result.batch.snapshots.tags.coverage == .notProvided)
        tasks.todos = { Issue.record("unexpected todo read"); return [] }
        tasks.subtasks = { Issue.record("unexpected subtask read"); return [] }
        tasks.tags = { _ in Issue.record("unexpected ID read"); return [] }
        #expect(f.read(tasks: tasks).batch.snapshots.tags.values?.count == 2)
    }
}
