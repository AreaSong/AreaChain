import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TagContentQueryUsageTests {
    @Test(arguments: [TagListFilter.frequent, .recent, .unused])
    func absentStatisticsKeepExistingUnknownAndFallbackFeedback(filter: TagListFilter) throws {
        let f = try TagContentQueryFixture()
        let first = f.tag(order: 2)
        let second = f.tag("second", order: 1)
        let result = f.read(view: .catalog(filter))
        let response = try TagContentQueryFixture.response(result)
        #expect(result.tagCatalog.usageOrigin == .notProvided && response.coverage.usage == nil)
        #expect(response.diagnostics.contains { $0.issue == .usageUnavailable })
        #expect(!response.ordering.isComplete)
        if filter == .frequent {
            #expect(response.matches.map(\.tag.id) == [second.id, first.id])
            #expect(response.matches.allSatisfy { $0.usage == nil && $0.usageState == .unavailable })
            #expect(response.ordering.requested == .activeCountThenSortOrder && response.ordering.applied == .inputOrder)
            #expect(ContentQueryBatchReader.read(result.batch).completeness.matchingIsComplete)
        } else {
            #expect(response.matches.isEmpty && Set(response.undeterminedObjects.map(\.id)) == [first.id, second.id])
            #expect(!ContentQueryBatchReader.read(result.batch).completeness.matchingIsComplete)
        }
    }

    @Test func taskFamilyReadDoesNotInventGlobalUsageOrUnused() throws {
        let f = try TagContentQueryFixture()
        let linked = f.tag()
        let unseen = f.tag("unknown", order: 1)
        f.family.task.todo().tagIDs = TagIDList.encode([linked.id])
        f.family.routine().tagIDs = TagIDList.encode([linked.id])
        let result = f.read("", view: .catalog(.unused))
        #expect(result.batch.snapshots.todos.coverage == .complete && result.batch.snapshots.routines.coverage == .complete)
        #expect(result.batch.snapshots.diaries.coverage == .notProvided)
        #expect(result.batch.facts.tagUsage == nil && result.tagCatalog.usageOrigin == .notProvided)
        let response = try TagContentQueryFixture.response(result)
        #expect(response.matches.isEmpty && Set(response.undeterminedObjects.map(\.id)) == [linked.id, unseen.id])
        #expect(response.coverage.usage == nil)
    }

    @Test func injectedPartialTaskStatisticsDoNotProveZeroOrExactCounts() throws {
        let f = try TagContentQueryFixture()
        let used = f.tag()
        let zero = f.tag("unknown zero", order: 1)
        let todo = f.family.task.todo()
        todo.tagIDs = TagIDList.encode([used.id])
        let records = Array(TagUsage.records(TagUsage.subjects(todos: [todo], routines: [], diaries: [])).values)
        let input = TagQueryUsageInput(records: records, coverage: .partial(completeTagIDs: []))
        let result = f.read(usage: input)
        let response = try TagContentQueryFixture.response(result)
        #expect(result.tagCatalog.usageOrigin == .injected)
        #expect(result.batch.facts.tagUsage?.records == records && response.coverage.usage == input.coverage)
        #expect(response.matches.allSatisfy { $0.usageState == .partial && $0.usage == nil })
        let unused = try TagContentQueryFixture.response(f.read(view: .catalog(.unused), usage: input))
        #expect(unused.matches.isEmpty && Set(unused.undeterminedObjects.map(\.id)) == [used.id, zero.id])
        let frequent = try TagContentQueryFixture.response(f.read(view: .catalog(.frequent), usage: input))
        #expect(frequent.ordering.applied == .inputOrder && !frequent.ordering.isComplete)
    }

    @Test func explicitlyInjectedCompleteStatisticsReuseOriginalFilters() throws {
        let f = try TagContentQueryFixture()
        let first = f.tag("first", order: 2)
        let second = f.tag("second", order: 1)
        let unused = f.tag("unused", order: 0)
        let subjects = [
            TagUsageSubject(tagIDs: TagIDList.encode([first.id, second.id]), createdAt: TodoQueryFixture.created, isDeleted: false),
            TagUsageSubject(tagIDs: first.id.uuidString, createdAt: TodoQueryFixture.created.addingTimeInterval(60), isDeleted: false),
            TagUsageSubject(tagIDs: unused.id.uuidString, createdAt: TodoQueryFixture.created, isDeleted: true)
        ]
        let records = TagUsage.records(subjects)
        let input = TagQueryUsageInput(records: Array(records.values), coverage: .complete)
        for filter in TagListFilter.allCases {
            let result = f.read(view: .catalog(filter), usage: input)
            let response = try TagContentQueryFixture.response(result)
            let expected = TagUsage.filtered([first, second, unused], filter: filter, usage: records)
            #expect(response.matches.map(\.tag.id) == expected.map(\.id))
            #expect(response.coverage.usage == .complete && response.ordering.isComplete)
            #expect(result.tagCatalog.usageOrigin == .injected && result.batch.snapshots.diaries.coverage == .notProvided)
        }
    }

    @Test func perIDInjectedCompletenessAndInvalidRecordsRemainProviderOwned() throws {
        let f = try TagContentQueryFixture()
        let complete = f.tag()
        let unknown = f.tag("unknown", order: 1)
        let input = TagQueryUsageInput(records: [], coverage: .partial(completeTagIDs: [complete.id]))
        let response = try TagContentQueryFixture.response(f.read(view: .catalog(.unused), usage: input))
        #expect(response.matches.map(\.tag.id) == [complete.id] && response.undeterminedObjects.map(\.id) == [unknown.id])
        let invalid = TagQueryUsageInput(records: [.init(tagID: complete.id, activeCount: -1, latestCreatedAt: nil)], coverage: .complete)
        let normal = try TagContentQueryFixture.response(f.read(usage: invalid))
        #expect(normal.matches.count == 2 && normal.diagnostics.contains { $0.issue == .negativeUsageCount })
        #expect(normal.matches.first { $0.tag.id == complete.id }?.usageState == .invalid)
    }
}
