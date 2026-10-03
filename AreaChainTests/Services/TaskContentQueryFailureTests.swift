import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TaskContentQueryFailureTests {
    private enum FetchFailure: Error { case syntheticSQLAndBodyMustNotEscape }

    @Test func todoFailureDoesNotBecomeEmptyCompleteAndChildrenRemainAvailable() throws {
        let f = try TaskContentQueryFixture()
        let child = f.child(f.todo())
        var reads = TaskContentQueryReads(context: f.context)
        reads.todos = { throw FetchFailure.syntheticSQLAndBodyMustNotEscape }
        let result = f.read(reads: reads)
        #expect(result.batch.snapshots.todos.coverage == .failed)
        #expect(result.batch.snapshots.subtasks.values == [child.snapshot!])
        #expect(result.issues == [.todoFetchFailed])
        let response = ContentQueryBatchReader.read(result.batch)
        #expect(response.definiteMatchCount == 0 && !response.completeness.matchingIsComplete)
        #expect(!String(reflecting: result).contains("syntheticSQL"))
        #expect(!String(reflecting: result.issues).contains("syntheticSQL"))
    }

    @Test func subtaskFailureKeepsIndependentTodoMatches() throws {
        let f = try TaskContentQueryFixture()
        f.todo()
        var reads = TaskContentQueryReads(context: f.context)
        reads.subtasks = { throw FetchFailure.syntheticSQLAndBodyMustNotEscape }
        let result = f.read("/tasks needle", reads: reads)
        #expect(result.batch.snapshots.subtasks.coverage == .failed)
        #expect(result.batch.snapshots.todos.coverage == .complete)
        #expect(result.issues == [.subtaskFetchFailed])
        let response = ContentQueryBatchReader.read(result.batch)
        #expect(response.definiteMatchCount == 1 && !response.completeness.matchingIsComplete)
    }

    @Test(arguments: ["/go/tasks", "/diaries needle", "/clipboard needle", "/images needle", "/tags needle"])
    func unrelatedOrCommandScopeDoesNotFetch(source: String) throws {
        let f = try TaskContentQueryFixture()
        var reads = TaskContentQueryReads(context: f.context)
        var count = 0
        reads.todos = { count += 1; return [] }
        reads.subtasks = { count += 1; return [] }
        reads.tags = { _ in count += 1; return [] }
        let result = f.read(source, reads: reads)
        #expect(count == 0)
        #expect(result.batch.snapshots.todos.coverage == .notProvided)
        #expect(result.tagNamesCoverage == .notProvided)
    }

    @Test func tagFetchUsesOnlyAssociatedIDsAndDoesNotInstallTagProvider() throws {
        let f = try TaskContentQueryFixture()
        let tag = TagItem(name: "工作", sortOrder: 0)
        f.context.insert(tag)
        let unrelated = TagItem(name: "unrelated private", sortOrder: 1)
        unrelated.isPrivateDiary = true
        f.context.insert(unrelated)
        f.todo().tagIDs = TagIDList.encode([tag.id])
        var reads = TaskContentQueryReads(context: f.context)
        let fetch = reads.tags
        var calls: [Set<UUID>] = []
        reads.tags = { ids in calls.append(ids); return try fetch(ids) }
        let result = f.read("/tasks #工作", reads: reads)
        #expect(calls == [[tag.id]])
        #expect(result.batch.facts.metadata.tagNames == [tag.id: "工作"])
        #expect(result.batch.facts.metadata.privateTagIDs == nil)
        #expect(result.batch.snapshots.tags.coverage == .notProvided)
        #expect(ContentQueryBatchReader.read(result.batch).definiteMatchCount == 1)
    }

    @Test func noTagAssociationsAvoidTagFetch() throws {
        let f = try TaskContentQueryFixture()
        f.todo()
        var reads = TaskContentQueryReads(context: f.context)
        reads.tags = { _ in Issue.record("unexpected tag fetch"); return [] }
        #expect(f.read(reads: reads).tagNamesCoverage == .complete)
    }

    @Test(arguments: ["missing", "duplicate", "duplicateSameName", "private", "failed"])
    func unavailableTagNamesRemainUnknown(mode: String) throws {
        let f = try TaskContentQueryFixture()
        let tag = TagItem(name: "工作", sortOrder: 0)
        let todo = f.todo()
        todo.tagIDs = TagIDList.encode([tag.id])
        var reads = TaskContentQueryReads(context: f.context)
        if mode != "missing" { f.context.insert(tag) }
        if mode == "duplicate" || mode == "duplicateSameName" {
            f.context.insert(TagItem(id: tag.id, name: mode == "duplicate" ? "conflicting" : tag.name, sortOrder: 1))
        }
        if mode == "private" { tag.isPrivateDiary = true }
        if mode == "failed" { reads.tags = { _ in throw FetchFailure.syntheticSQLAndBodyMustNotEscape } }
        let result = f.read("/tasks #工作", reads: reads)
        #expect(result.batch.facts.metadata.tagNames == nil)
        #expect(result.tagNamesCoverage == (mode == "failed" ? .failed : .partial))
        #expect(!result.issues.isEmpty && result.batch.snapshots.todos.coverage == .complete)
        let response = ContentQueryBatchReader.read(result.batch)
        #expect(response.definiteMatchCount == 0 && !response.completeness.matchingIsComplete)
        #expect(todo.tagIDs == TagIDList.encode([tag.id]))
    }

    @Test func failedReadPreservesPendingEdits() throws {
        let f = try TaskContentQueryFixture()
        let todo = f.todo("saved")
        try f.context.save()
        todo.title = "pending"
        var reads = TaskContentQueryReads(context: f.context)
        reads.todos = { throw FetchFailure.syntheticSQLAndBodyMustNotEscape }
        #expect(f.read(reads: reads).batch.snapshots.todos.coverage == .failed)
        #expect(f.context.hasChanges && todo.title == "pending")
    }
}
