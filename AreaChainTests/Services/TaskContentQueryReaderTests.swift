import Foundation
import os
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TaskContentQueryReaderTests {
    @Test func emptyStoreOnlyCompletesTaskSources() throws {
        let f = try TaskContentQueryFixture()
        let result = f.read()
        #expect(result.batch.snapshots.todos.coverage == .complete)
        #expect(result.batch.snapshots.subtasks.coverage == .complete)
        #expect(result.batch.snapshots.todos.values?.isEmpty == true && result.issues.isEmpty)
        #expect(result.batch.snapshots.routines.coverage == .notProvided)
        #expect(result.batch.snapshots.diaries.coverage == .notProvided)
        #expect(result.batch.snapshots.images.coverage == .notProvided)
        #expect(result.batch.snapshots.tags.coverage == .notProvided)
        #expect(result.batch.snapshots.clipboard.coverage == .notProvided)
        #expect(result.batch.facts.metadata.privateTagIDs == nil)
        let response = ContentQueryBatchReader.read(result.batch)
        #expect(!response.completeness.matchingIsComplete)
        #expect(response.completeness.providers.contains { $0.limitations.contains(.source(.routine, .notProvided)) })
    }

    @Test func fieldsAndFlatChildrenUseActualSnapshots() throws {
        let f = try TaskContentQueryFixture()
        let tag = TagItem(name: "工作", sortOrder: 0, deletedAt: TodoQueryFixture.created)
        f.context.insert(tag)
        let todo = f.todo()
        todo.isDone = true
        todo.notes = "synthetic notes"
        todo.tagIDs = TagIDList.encode([tag.id])
        todo.remindMinutes = 75
        todo.dueMinutes = 90
        todo.sortOrder = 7
        todo.isImportant = true
        todo.isUrgent = true
        todo.sourceBundleID = "fixture.source"
        let child = f.child(todo)
        child.tagIDs = todo.tagIDs
        child.isDone = true
        child.sortOrder = 3
        try f.context.save()
        let result = f.read()
        var expected = todo.snapshot
        expected.subtasks = []
        #expect(result.batch.snapshots.todos.values == [expected])
        #expect(result.batch.snapshots.subtasks.values == [child.snapshot!])
        #expect(result.batch.facts.metadata.tagNames == [tag.id: "工作"])
        let assembled = ContentQueryBatchAssembly(result.batch, needsTasks: true, needsSubtasks: true)
        #expect(assembled.todos?.first?.subtasks == [child.snapshot!])
        #expect(assembled.taskIssues.isEmpty)
    }

    @Test func liveAndDeletedParentsAndChildrenRemainEnumerated() throws {
        let f = try TaskContentQueryFixture()
        let stamp = TodoQueryFixture.created
        let live = f.todo("live")
        let deleted = f.todo("deleted", deleted: stamp)
        for parent in [live, deleted] {
            f.child(parent)
            f.child(parent, deleted: stamp)
        }
        try f.context.save()
        let result = f.read()
        #expect(result.batch.snapshots.todos.values?.count == 2)
        #expect(result.batch.snapshots.subtasks.values?.count == 4)
        #expect(result.batch.snapshots.subtasks.values?.filter { $0.deletedAt != nil }.count == 2)
        #expect(result.batch.snapshots.subtasks.values?.filter { $0.todoId == deleted.id }.count == 2)
        #expect(result.batch.snapshots.todos.values?.allSatisfy { $0.subtasks.isEmpty } == true)
        #expect(result.batch.snapshots.subtasks.coverage == .complete)
    }

    @Test func orphanIsDiagnosedWithoutInventedParentAndAmbiguousPeerIsSuppressed() throws {
        let f = try TaskContentQueryFixture()
        let parent = f.todo()
        let orphan = f.child(nil)
        orphan.deletedAt = TodoQueryFixture.created
        let peer = f.child(parent)
        peer.id = orphan.id
        let valid = f.child(parent)
        try f.context.save()
        let result = f.read()
        #expect(result.batch.snapshots.subtasks.coverage == .partial)
        #expect(result.batch.snapshots.subtasks.values?.map(\.id) == [valid.id])
        #expect(result.issues.contains { if case .unconvertibleSubtask(let id, _) = $0 { return id == orphan.id }; return false })
        #expect(orphan.todo == nil && peer.todo === parent)
        #expect(!ContentQueryBatchReader.read(result.batch).completeness.matchingIsComplete)
    }

    @Test func duplicateTaskAndChildRowsReachIdentityValidation() throws {
        let f = try TaskContentQueryFixture()
        let first = f.todo()
        let second = f.todo()
        second.id = first.id
        let child = f.child(first)
        let duplicate = f.child(first)
        duplicate.id = child.id
        try f.context.save()
        let batch = f.read("/tasks needle").batch
        #expect(batch.snapshots.todos.values?.count == 2 && batch.snapshots.subtasks.values?.count == 2)
        #expect(batch.snapshots.todos.coverage == .complete && batch.snapshots.subtasks.coverage == .complete)
        let response = ContentQueryBatchReader.read(batch)
        #expect(response.definiteMatchCount == 0 && !response.completeness.matchingIsComplete)
    }

    @Test func missingFetchedParentKeepsActualChildRelationshipAndPartialCoverage() throws {
        let f = try TaskContentQueryFixture()
        let parent = f.todo()
        let child = f.child(parent)
        var reads = TaskContentQueryReads(context: f.context)
        reads.todos = { [] }
        let result = f.read(reads: reads)
        #expect(result.batch.snapshots.subtasks.values == [child.snapshot!])
        #expect(result.batch.snapshots.subtasks.coverage == .partial)
        #expect(result.issues == [.uncontainedSubtask(id: child.id, index: 0)])
        #expect(ContentQueryBatchReader.read(result.batch).consistencyIssues.contains(.uncontainedSubtasks))
    }

    @Test func duplicateChildrenUnderUniqueParentAreNotFirstWins() throws {
        let f = try TaskContentQueryFixture()
        let parent = f.todo("parent")
        let first = f.child(parent)
        let second = f.child(parent, deleted: TodoQueryFixture.created)
        second.id = first.id
        try f.context.save()
        let result = f.read("/subtasks needle")
        #expect(result.batch.snapshots.subtasks.values?.count == 2)
        let response = ContentQueryBatchReader.read(result.batch)
        #expect(response.definiteMatchCount == 0 && !response.completeness.matchingIsComplete)
    }

    @Test func pendingDeletionAndInjectedSessionOptionsRemainUntouched() throws {
        let f = try TaskContentQueryFixture()
        let item = f.todo()
        try f.context.save()
        f.context.delete(item)
        let session = TodoQueryFixture.session("/tasks", page: .overview)
        let requestID = UUID()
        var options = ContentQueryBatchOptions()
        options.locale = Locale(identifier: "zh-Hans")
        options.occurrenceBudget.maxResults = 8
        let result = f.reader.readTasks(session: session, requestID: requestID, options: options)
        #expect(result.batch.session == session && result.batch.requestID == requestID)
        #expect(result.batch.options.locale == options.locale && result.batch.options.occurrenceBudget.maxResults == 8)
        #expect(result.batch.snapshots.todos.values?.isEmpty == true)
        #expect(f.context.hasChanges)
        let other = ModelContext(f.container)
        #expect(try other.fetch(FetchDescriptor<TodoItem>()).count == 1)
    }

    @Test func pendingModelEditsAreReadButNotSavedRolledBackOrPublished() throws {
        let f = try TaskContentQueryFixture()
        let todo = f.todo("saved")
        try f.context.save()
        todo.title = "pending"
        let inserted = f.todo("inserted")
        let child = f.child(todo)
        let uiDraft = "UI only draft"
        let observation = ReadNotificationCounter()
        let token = NotificationCenter.default.addObserver(forName: .boardDidChange, object: nil, queue: nil) { _ in
            observation.increment()
        }
        defer { NotificationCenter.default.removeObserver(token) }
        let result = f.read()
        #expect(f.context.hasChanges && todo.title == "pending" && inserted.modelContext === f.context)
        #expect(result.batch.snapshots.todos.values?.map(\.title).contains("pending") == true)
        #expect(result.batch.snapshots.todos.values?.map(\.title).contains(uiDraft) == false)
        #expect(result.batch.snapshots.subtasks.values == [child.snapshot!])
        let independent = ModelContext(f.container)
        let saved = try independent.fetch(FetchDescriptor<TodoItem>())
        #expect(saved.count == 1 && saved[0].title == "saved")
        #expect(observation.count == 0)
    }
}

/// NotificationCenter 的同步回调采用锁隔离计数，不让可变捕获绕过并发检查。
private final class ReadNotificationCounter: Sendable {
    private let value = OSAllocatedUnfairLock(initialState: 0)
    var count: Int { value.withLock { $0 } }
    func increment() { value.withLock { $0 += 1 } }
}
