import Foundation
import os
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DiaryContentQueryFailureTests {
    private struct Failure: Error { let message = DiaryQueryFixture.secret }

    @Test func fetchFailureIsNotCompleteEmptyAndDoesNotEraseOtherSources() throws {
        let f = try DiaryContentQueryFixture()
        let todo = f.tags.family.task.todo()
        let tag = f.tags.tag()
        todo.tagIDs = tag.id.uuidString
        var reads = DiaryContentQueryReads(context: f.context)
        reads.allDiaries = { throw Failure() }
        let result = f.read("", diaries: reads)
        #expect(result.diary.source == .failed && result.diary.issues == [.fetchFailed])
        #expect(result.batch.snapshots.diaries.values == nil)
        #expect(result.batch.snapshots.todos.values?.map(\.id) == [todo.id])
        #expect(result.batch.snapshots.tags.coverage == .complete)
        #expect(result.batch.facts.metadata.tagNames == [tag.id: tag.name])
        #expect(!ContentQueryBatchReader.read(result.batch).completeness.matchingIsComplete)
        #expect(!DiaryQueryFixture.containsSecret(result))
    }

    @Test func catalogFailureKeepsMetadataMatchesHiddenAndBodyUnknownWithoutRetry() throws {
        let f = try DiaryContentQueryFixture()
        let diary = f.diary()
        diary.tagIDs = UUID().uuidString
        var catalog = TagContentQueryReads(context: f.context)
        var calls = 0
        catalog.allTags = { calls += 1; throw Failure() }
        var tasks = TaskContentQueryReads(context: f.context)
        tasks.tags = { _ in Issue.record("失败后不可用另一次 fetch 拼接"); return [] }
        let result = f.read("/diaries date:today", catalog: catalog, tasks: tasks)
        #expect(calls == 1 && result.diary.source == .complete)
        #expect(result.diaryTagPrivacy?.coverage == .failed && result.tagNamesCoverage == .failed)
        #expect(result.diaryTagPrivacy?.issues == [.fetchFailed] && result.tagIssues == [.fetchFailed])
        #expect(result.batch.facts.metadata.privateTagIDs == nil)
        let response = try DiaryContentQueryFixture.response(result)
        #expect(response.matches.map(\.id.id) == [diary.id])
        guard case .hiddenTitle = response.matches.first?.presentation else { Issue.record("必须隐藏"); return }
        #expect(!DiaryQueryFixture.containsSecret(result))
    }

    @Test func pendingInsertDeleteAndEditsSurviveBothReadsWithZeroBusinessNotifications() throws {
        let f = try DiaryContentQueryFixture()
        let saved = f.diary()
        let removed = f.diary()
        try f.context.save()
        saved.dayKey = "2026-01-01"
        f.context.delete(removed)
        let pending = f.diary()
        let counter = DiaryReadEventCounter()
        let token = NotificationCenter.default.addObserver(forName: .boardDidChange, object: nil, queue: nil) { _ in counter.increment() }
        defer { NotificationCenter.default.removeObserver(token) }
        let result = f.read()
        #expect(Set(result.batch.snapshots.diaries.values?.map(\.id) ?? []) == [saved.id, pending.id])
        #expect(result.batch.snapshots.diaries.values?.first { $0.id == saved.id }?.dayKey == "2026-01-01")
        var reads = DiaryContentQueryReads(context: f.context)
        reads.allDiaries = { throw Failure() }
        #expect(f.read(diaries: reads).diary.source == .failed)
        #expect(f.context.hasChanges && !f.context.autosaveEnabled && pending.modelContext === f.context)
        let other = ModelContext(f.tags.family.task.container)
        let stored = try SwiftDataDiaryRepository.fetchAllDiaries(in: other)
        #expect(Set(stored.map(\.id)) == [saved.id, removed.id])
        #expect(stored.first { $0.id == saved.id }?.dayKey == QuerySessionFixture.today)
        #expect(counter.count == 0)
    }
}

private final class DiaryReadEventCounter: Sendable {
    private let value = OSAllocatedUnfairLock(initialState: 0)
    var count: Int { value.withLock { $0 } }
    func increment() { value.withLock { $0 += 1 } }
}
