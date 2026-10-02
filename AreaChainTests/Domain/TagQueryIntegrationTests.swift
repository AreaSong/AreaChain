import Foundation
import Testing
@testable import AreaChain

struct TagQueryIntegrationTests {
    @Test func rawParserSessionProviderRetainsConditionAndAlternativeIdentity() {
        let source = "/tags (missing | 工作) -归档"
        let session = TodoQueryFixture.session(source)
        let parsed = ContentQueryParser().parse(source, context: session.queryDates)
        #expect(session.input == parsed)
        let result = TagQueryFixture.read(session, [TagQueryFixture.tag(1)])
        #expect(result.matches.count == 1 && result.requestID == TodoQueryFixture.requestID)
        #expect(result.typeAnalysis == session.typeAnalysis)
        #expect(result.matches[0].evidence.allSatisfy { evidence in session.conditions.contains { $0.id == evidence.conditionID } })
        #expect(result.matches[0].evidence.contains { $0.field == .tagName && $0.alternativeIndex == 1 })
    }

    @Test func tagsPageAndHandoffFreezeScopeWithoutTargetPageConditions() {
        let tags = [TagQueryFixture.tag(1), TagQueryFixture.tag(2, "学习")]
        let session = TodoQueryFixture.session("工作", page: .tags)
        #expect(session.conditions.contains { $0.origin.isPage && $0.value == .scope(.catalog(.tags)) })
        let target = ContentQuerySession(page: QuerySessionFixture.page(.today(.init()), visit: "target"))
        let frozen = session.handedOff(to: target)
        let result = TagQueryFixture.read(frozen, tags)
        #expect(result.matches.map(\.tag.id) == [tags[0].id])
        #expect(result.matches[0].evidence.contains { evidence in
            frozen.conditions.contains { $0.id == evidence.conditionID && $0.origin.isHandoffPage }
        })
        #expect(frozen.queryDates.todayKey == session.queryDates.todayKey)
        #expect(frozen.queryDates.calendar == session.queryDates.calendar)
        let user = ContentQueryReducer.reduce(frozen, .setInput("学习")).state
        #expect(TagQueryFixture.read(user, tags).matches.map(\.tag.id) == [tags[1].id])
    }

    @Test func frozenTagAssociationRemainsInapplicableAndIsNeverSelfAssociation() {
        let tag = TagQueryFixture.tag(1)
        let session = TodoQueryFixture.session("工作", page: .tagContents(tagID: tag.id, types: [.tag, .todo]))
        let frozen = session.handedOff(to: ContentQuerySession(page: QuerySessionFixture.page(.tags, visit: "target")))
        let result = TagQueryFixture.read(frozen, [tag])
        #expect(result.queryIsValid && result.state == .inapplicableConditions)
        let reasonIDs = result.typeAnalysis.assessment(for: .tag)?.reasons.flatMap(\.conditionIDs) ?? []
        #expect(frozen.conditions.contains { $0.origin.isHandoffPage && reasonIDs.contains($0.id) && $0.value.dimension == .content(.tag) })
    }

    @Test func explicitViewOptionIsReadOnlyAndDoesNotBecomeQueryTruth() {
        let session = TodoQueryFixture.session("/tags 工作")
        let tag = TagQueryFixture.tag(1)
        let input = TagQueryUsageInput(records: [], coverage: .complete)
        for filter in TagListFilter.allCases {
            let request = TagQueryRequest(requestID: UUID(), session: session, tags: [tag], usage: input, view: .catalog(filter))
            let result = TagQueryProvider.read(request)
            #expect(request.session == session && result.view == .catalog(filter))
        }
    }

    @Test @MainActor func oldDirectoryNameSearchMatchesCommonInputsAndAllViews() {
        let tags = [TagItem(name: "Cafe\u{301} 工作", sortOrder: 2), TagItem(name: "工作 Alpha beta", sortOrder: 0),
                    TagItem(name: "工作", sortOrder: 1), TagItem(name: "工作 已删", sortOrder: 3, deletedAt: .now)]
        let snapshots = tags.map { TagQuerySnapshot(id: $0.id, name: $0.name, sortOrder: $0.sortOrder,
                                                   deletedAt: $0.deletedAt, isPrivateDiary: $0.isPrivateDiary, colorToken: $0.colorToken) }
        let records = [TagQueryFixture.record(snapshots[0], count: 2), TagQueryFixture.record(snapshots[1], count: 1, time: 50)]
        let usage = Dictionary(uniqueKeysWithValues: records.map { ($0.tagID, $0) })
        for filter in TagListFilter.allCases {
            for needle in ["", "工作", "CAFE", "Alpha beta", "不存在"] {
                let old = TagUsage.filtered(tags, filter: filter, usage: usage).filter {
                    needle.isEmpty || $0.name.localizedStandardContains(needle)
                }
                let source = needle.isEmpty ? "/tags" : "/tags \"\(needle)\""
                let result = TagQueryFixture.read(source, snapshots, usage: .init(records: records, coverage: .complete), view: .catalog(filter))
                #expect(result.matches.map(\.tag.id) == old.map(\.id))
            }
        }
    }

    @Test @MainActor func extractedRuleMatchesIndependentOldAlgorithmIncludingEqualSortOrders() {
        let tags = [TagItem(name: "甲", sortOrder: 1), TagItem(name: "乙", sortOrder: 0), TagItem(name: "丙", sortOrder: 1),
                    TagItem(name: "删", sortOrder: -1, deletedAt: .now)]
        let usage = [tags[0].id: TagUsageRecord(tagID: tags[0].id, activeCount: 2, latestCreatedAt: Date(timeIntervalSince1970: 10)),
                     tags[2].id: TagUsageRecord(tagID: tags[2].id, activeCount: 2, latestCreatedAt: Date(timeIntervalSince1970: 20))]
        let live = Catalog.liveTags(tags)
        for filter in TagListFilter.allCases {
            let expected: [TagItem]
            switch filter {
            case .all: expected = live
            case .unused: expected = live.filter { (usage[$0.id]?.activeCount ?? 0) == 0 }
            case .recent:
                expected = live.filter { usage[$0.id]?.latestCreatedAt != nil }.sorted {
                    let left = usage[$0.id]?.latestCreatedAt ?? .distantPast
                    let right = usage[$1.id]?.latestCreatedAt ?? .distantPast
                    return left == right ? $0.sortOrder < $1.sortOrder : left > right
                }
            case .frequent:
                expected = live.sorted {
                    let left = usage[$0.id]?.activeCount ?? 0
                    let right = usage[$1.id]?.activeCount ?? 0
                    return left == right ? $0.sortOrder < $1.sortOrder : left > right
                }
            }
            #expect(TagUsage.filtered(tags, filter: filter, usage: usage).map(\.id) == expected.map(\.id))
        }
    }
}
