import Foundation
import os
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TagUsageContentQueryIntegrationTests {
    @Test(arguments: [TagListFilter.frequent, .recent, .unused])
    func legacyOrderSurvivesSummaryAndPaginationWithoutPublishingTime(filter: TagListFilter) async throws {
        let f = try SearchReadFixture.tagUsage()
        let tags = (0..<24).map { f.data.tags.tag("needle \($0)", order: 24 - $0) }
        let todo = f.data.tags.family.task.todo()
        todo.tagIDs = TagIDList.encode([tags[0].id, tags[0].id, tags[1].id])
        let diary = f.data.diary("DO_NOT_DISCLOSE")
        diary.tagIDs = tags[2].id.uuidString
        diary.isPrivate = true
        diary.createdAt = TodoQueryFixture.created.addingTimeInterval(97)
        let expected = TagUsage.filtered(tags, filter: filter, usage: TagUsage.records(
            TagUsage.subjects(todos: [todo], routines: [], diaries: [diary]))).map(\.id)
        let publication = try await f.publishUsage("/tags needle", view: .catalog(filter))
        let response = try SearchReadFixture.usageResponse(publication)
        #expect(response.matches.map(\.tag.id) == expected && response.ordering.isComplete)
        let presented = publication.pagination.snapshot.source
        #expect(presented.source.ordered.map(\.id.id) == expected)
        #expect(presented.source.ordered.allSatisfy { $0.time.instant == nil && $0.time.day == nil })
        #expect(presented.rows.map(\.id.id) == expected)
        for row in presented.rows {
            for metadata in row.metadata {
                if case .tagUsage(let state, let count) = metadata {
                    #expect(state == .complete)
                    #expect(Mirror(reflecting: try #require(count)).children.compactMap(\.label) == ["activeCount"])
                }
            }
        }
        if expected.count > 20 {
            #expect(publication.pagination.snapshot.visible.count == 20)
            let effect = try f.session.loadMore(.init(stamp: publication.pagination.stamp, action: .loadMoreUnits))
            #expect(effect.didPublish)
            #expect(try f.session.presentation().pagination.snapshot.visible.count == expected.count)
        }
        for match in response.matches {
            #expect(!String(reflecting: match).contains(diary.id.uuidString))
            #expect(Mirror(reflecting: try #require(match.usage)).children.compactMap(\.label) == ["activeCount"])
        }
    }

    @Test(arguments: [TagListFilter.frequent, .recent, .unused])
    func missingDiaryUsesUnknownAndProviderFallback(filter: TagListFilter) async throws {
        let f = try SearchReadFixture.tagUsage { $0.diaries = { .notProvided } }
        let first = f.data.tags.tag("first", order: 2)
        let second = f.data.tags.tag("second", order: 1)
        let publication = try await f.publishUsage(view: .catalog(filter))
        let response = try SearchReadFixture.usageResponse(publication)
        #expect(!response.ordering.isComplete)
        if filter == .frequent {
            #expect(response.matches.map(\.tag.id) == [second.id, first.id])
            #expect(publication.pagination.snapshot.source.source.ordered.map(\.id.id) == [second.id, first.id])
            #expect(response.matches.allSatisfy { $0.usage == nil && $0.usageState == .partial })
        } else {
            #expect(response.matches.isEmpty && response.undeterminedObjects.count == 2)
        }
    }

    @Test func pendingChangesSurviveSuccessAndFailureWithoutWritesOrNotifications() async throws {
        let probe = TagUsageReadProbe()
        let f = try SearchReadFixture.tagUsage(configure: probe.configure)
        let tag = f.data.tags.tag()
        let task = f.data.tags.family.task.todo("saved")
        let removed = f.data.diary("saved removable")
        try f.data.context.save()
        task.tagIDs = tag.id.uuidString
        task.title = "pending"
        f.data.context.delete(removed)
        let inserted = f.data.diary("pending inserted")
        inserted.tagIDs = tag.id.uuidString
        let notifications = OSAllocatedUnfairLock(initialState: 0)
        let token = NotificationCenter.default.addObserver(forName: .boardDidChange, object: nil, queue: nil) { _ in
            notifications.withLock { $0 += 1 }
        }
        defer { NotificationCenter.default.removeObserver(token) }
        _ = try await f.publishUsage()
        probe.replacement = (.routine, .failed)
        _ = try await f.publishUsage()
        #expect(f.data.context.hasChanges && task.title == "pending" && task.tagIDs == tag.id.uuidString)
        #expect(inserted.modelContext === f.data.context && !f.data.context.autosaveEnabled)
        let other = ModelContext(f.data.tags.family.task.container)
        #expect(try other.fetch(FetchDescriptor<TodoItem>()).first?.title == "saved")
        #expect(try other.fetch(FetchDescriptor<TodoItem>()).first?.tagIDs == "")
        #expect(try other.fetch(FetchDescriptor<DiaryEntry>()).contains { $0.id == removed.id })
        #expect(!(try other.fetch(FetchDescriptor<DiaryEntry>())).contains { $0.id == inserted.id })
        #expect(notifications.withLock { $0 } == 0 && f.vault.configuration == nil)
        #expect(await f.system.items.isEmpty)
    }
}
