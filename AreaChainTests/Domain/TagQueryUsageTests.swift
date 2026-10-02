import Foundation
import Testing
@testable import AreaChain

struct TagQueryUsageTests {
    @Test func unavailablePartialAndCompleteZeroAreDistinct() {
        let tag = TagQueryFixture.tag(1)
        let none = TagQueryFixture.read("/tags", [tag])
        let partial = TagQueryFixture.read("/tags", [tag], usage: .init(records: [], coverage: .partial(completeTagIDs: [])))
        let zero = TagQueryFixture.read("/tags", [tag], usage: .init(records: [], coverage: .complete))
        #expect(none.matches[0].usageState == .unavailable && none.matches[0].usage == nil)
        #expect(partial.matches[0].usageState == .partial && partial.matches[0].usage == nil)
        #expect(zero.matches[0].usageState == .complete && zero.matches[0].usage?.activeCount == 0)
        #expect(none.coverage.usage == nil && zero.coverage.usage == .complete)
        #expect(none.isCompleteForCoveredTypes && partial.isCompleteForCoveredTypes)
    }

    @Test func perTagCompletenessDoesNotSpreadAndPartialCountsAreNotPublished() {
        let tags = [TagQueryFixture.tag(1), TagQueryFixture.tag(2), TagQueryFixture.tag(3)]
        let usage = TagQueryUsageInput(records: [TagQueryFixture.record(tags[2])], coverage: .partial(completeTagIDs: [tags[0].id]))
        let result = TagQueryFixture.read("/tags", tags, usage: usage, view: .catalog(.unused))
        #expect(result.matches.map(\.tag.id) == [tags[0].id])
        #expect(result.undeterminedObjects.map(\.id) == [tags[1].id, tags[2].id])
        #expect(!result.isCompleteForCoveredTypes && !result.ordering.isComplete)
        let normal = TagQueryFixture.read("/tags", tags, usage: usage)
        #expect(normal.matches.map(\.usageState) == [.complete, .partial, .partial])
        #expect(normal.matches[2].usage == nil)
    }

    @Test func allFourViewsKeepExistingMeaningAndTieBreaks() {
        var tags = [TagQueryFixture.tag(1), TagQueryFixture.tag(2), TagQueryFixture.tag(3), TagQueryFixture.tag(4)]
        for index in tags.indices { tags[index].sortOrder = [3, 0, 2, 1][index] }
        let usage = TagQueryUsageInput(records: [TagQueryFixture.record(tags[0], count: 4, time: 10),
                                               TagQueryFixture.record(tags[2], count: 1, time: 50),
                                               TagQueryFixture.record(tags[3], count: 4, time: 10)], coverage: .complete)
        let cases: [(TagListFilter, [Int], TagQuerySortBasis)] = [
            (.all, [1, 3, 2, 0], .sortOrder), (.frequent, [3, 0, 2, 1], .activeCountThenSortOrder),
            (.recent, [2, 3, 0], .latestCreatedAtThenSortOrder), (.unused, [1], .sortOrder)
        ]
        for (filter, indices, basis) in cases {
            let result = TagQueryFixture.read("/tags", tags, usage: usage, view: .catalog(filter))
            #expect(result.matches.map(\.tag.id) == indices.map { tags[$0].id })
            #expect(result.ordering.requested == basis && result.ordering.applied == basis && result.ordering.isComplete)
            #expect(result.isCompleteForCoveredTypes)
        }
    }

    @Test func frequentWithMissingCountsKeepsMembershipAndDeclaresSortFallback() {
        let tags = [TagQueryFixture.tag(1), TagQueryFixture.tag(2)]
        let usage = TagQueryUsageInput(records: [TagQueryFixture.record(tags[1], count: 8)],
                                       coverage: .partial(completeTagIDs: [tags[1].id]))
        let result = TagQueryFixture.read("/tags", tags, usage: usage, view: .catalog(.frequent))
        #expect(result.matches.map(\.tag.id) == tags.map(\.id))
        #expect(result.undeterminedObjects.isEmpty)
        #expect(result.ordering.requested == .activeCountThenSortOrder && result.ordering.applied == .inputOrder)
        #expect(!result.ordering.isComplete && !result.isCompleteForCoveredTypes)
        #expect(result.diagnostics.contains { $0.issue == .usageIncomplete && $0.affectsDetermination })
    }

    @Test func missingUsageCannotProveUnusedOrRecentEvenIfNoRowsAreGiven() {
        let tag = TagQueryFixture.tag(1)
        for filter in [TagListFilter.unused, .recent] {
            let result = TagQueryFixture.read("/tags", [tag], view: .catalog(filter))
            #expect(result.matches.isEmpty && result.undeterminedObjects.map(\.id) == [tag.id])
            #expect(result.diagnostics.contains { $0.issue == .usageUnavailable })
            let empty = TagQueryFixture.read("/tags", [], view: .catalog(filter))
            #expect(empty.diagnostics.contains { $0.issue == .usageUnavailable })
        }
    }

    @Test func invalidAndDuplicateRecordsAreDiagnosedWithoutPoisoningNameMatching() {
        let tag = TagQueryFixture.tag(1)
        let cases: [([TagUsageRecord], TagQueryIssue)] = [
            ([.init(tagID: tag.id, activeCount: -1, latestCreatedAt: nil)], .negativeUsageCount),
            ([.init(tagID: tag.id, activeCount: 1, latestCreatedAt: Date(timeIntervalSince1970: .infinity))], .invalidUsageTimestamp),
            ([.init(tagID: tag.id, activeCount: 1, latestCreatedAt: Date(timeIntervalSince1970: 1e15))], .invalidUsageTimestamp),
            ([.init(tagID: tag.id, activeCount: 0, latestCreatedAt: Date(timeIntervalSince1970: 10))], .inconsistentUsageRecord),
            ([.init(tagID: tag.id, activeCount: 1, latestCreatedAt: nil)], .inconsistentUsageRecord),
            ([TagQueryFixture.record(tag), TagQueryFixture.record(tag, count: 0)], .duplicateUsageID)
        ]
        for (records, issue) in cases {
            let usage = TagQueryUsageInput(records: records, coverage: .complete)
            let normal = TagQueryFixture.read("/tags", [tag], usage: usage)
            #expect(normal.matches.count == 1 && normal.matches[0].usageState == .invalid)
            #expect(normal.matches[0].usage == nil && normal.isCompleteForCoveredTypes)
            #expect(normal.diagnostics.contains { $0.issue == issue && !$0.affectsDetermination })
            let unused = TagQueryFixture.read("/tags", [tag], usage: usage, view: .catalog(.unused))
            #expect(unused.matches.isEmpty && unused.undeterminedObjects.map(\.id) == [tag.id])
            #expect(unused.diagnostics.contains { $0.issue == issue && $0.affectsDetermination })
        }
    }

    @Test func fullUsageUsesOriginalSubjectCountingAndDoesNotCreateTagDateFields() {
        let tag = TagQueryFixture.tag(1)
        let subjects = [TagUsageSubject(tagIDs: tag.id.uuidString, createdAt: Date(timeIntervalSince1970: 10), isDeleted: false),
                        TagUsageSubject(tagIDs: tag.id.uuidString, createdAt: Date(timeIntervalSince1970: 90), isDeleted: true)]
        let input = TagQueryUsageInput(records: Array(TagUsage.records(subjects).values), coverage: .complete)
        let result = TagQueryFixture.read("/tags", [tag], usage: input)
        #expect(result.matches[0].usage == TagQueryFixture.record(tag))
        for source in ["/tags created:1970-01-01", "/tags date:1970-01-01"] {
            #expect(TagQueryFixture.read(source, [tag], usage: input).state == .inapplicableConditions)
        }
    }

    @Test func definiteNameMissDoesNotBecomeUnknownDueToUsage() {
        let result = TagQueryFixture.read("/tags 不存在", [TagQueryFixture.tag(1)], view: .catalog(.unused))
        #expect(result.matches.isEmpty && result.undeterminedObjects.isEmpty)
        #expect(result.isCompleteForCoveredTypes)
    }

    @Test func invalidUsageStillDiagnosesNameMissAndDoesNotHideOtherMatches() {
        let tags = [TagQueryFixture.tag(1, "归档"), TagQueryFixture.tag(2)]
        let usage = TagQueryUsageInput(records: [.init(tagID: tags[0].id, activeCount: -1, latestCreatedAt: nil)], coverage: .complete)
        let result = TagQueryFixture.read("/tags 工作", tags, usage: usage, view: .catalog(.unused))
        #expect(result.matches.map(\.tag.id) == [tags[1].id])
        #expect(result.isCompleteForCoveredTypes)
        #expect(result.diagnostics.contains { $0.issue == .negativeUsageCount && !$0.affectsDetermination })
    }
}
