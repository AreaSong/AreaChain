import Foundation
import Testing
@testable import AreaChain

struct ContentQueryPaginationTests {
    @Test(arguments: [0, 1, 19, 20, 21, 40, 60, 65])
    func defaultPagesPreserveExactSourceOrder(count: Int) throws {
        let source = QueryDisplayFixture.display(QueryPaginationFixture.flat(count))
        var state = try ContentQueryPaginationState(snapshot: source)
        #expect(state.policy == .init(units: 20, members: 20, contexts: 20))
        #expect(state.snapshot.visible == Array(source.visible.prefix(20)))
        #expect(state.status.hits.known == count && state.status.units.known == count)
        #expect(state.snapshot.sourceID == source.sourceID && state.snapshot.version != source.version)
        var expected = min(count, 20)
        while state.status.hasMoreUnits {
            let before = state.stamp
            let result = state.apply(QueryPaginationFixture.event(state, .loadMoreUnits))
            expected = min(expected + 20, count)
            #expect(result.didPublish && result.browse == .init())
            #expect(state.snapshot.visible == Array(source.visible.prefix(expected)))
            #expect(state.stamp.sourceID == before.sourceID && state.stamp.revision != before.revision)
            #expect(state.snapshot.sharesSource(with: source))
        }
        #expect(state.status.hits.remaining == 0 && !state.status.hasMoreToLoad)
        let stamp = state.stamp
        #expect(state.apply(QueryPaginationFixture.event(state, .loadMoreUnits)).rejection == .exhausted)
        #expect(state.stamp == stamp && state.snapshot.visible == source.visible)
        #expect(!state.status.hasProviderUnprocessedWork)
    }

    @Test(arguments: [0, -1, Int.min])
    func invalidQuotaInEachDimensionIsRejected(size: Int) {
        let source = QueryDisplayFixture.display(QueryPaginationFixture.flat(1))
        for policy in [ContentQueryPaginationPolicy(units: size), .init(members: size), .init(contexts: size)] {
            #expect(throws: ContentQueryPaginationError.invalidPageSize) {
                try ContentQueryPaginationState(snapshot: source, policy: policy)
            }
        }
    }

    @Test func maximumIntegerQuotasAndPartialLastPageDoNotOverflow() throws {
        let source = QueryDisplayFixture.display(QueryPaginationFixture.grouped(groups: 1))
        var state = try ContentQueryPaginationState(snapshot: source,
            policy: .init(units: Int.max, members: Int.max, contexts: Int.max))
        #expect(state.snapshot.visible == source.visible && !state.status.hasMoreToLoad)
        let group = try #require(source.units.first)
        #expect(state.apply(QueryPaginationFixture.event(state, .loadMoreMembers(group.id))).rejection == .exhausted)
        #expect(state.apply(QueryPaginationFixture.event(state, .loadMoreContexts(group.id))).rejection == .exhausted)
        var small = try ContentQueryPaginationState(snapshot: QueryDisplayFixture.display(QueryPaginationFixture.flat(8)),
            policy: .init(units: 3))
        _ = small.apply(QueryPaginationFixture.event(small, .loadMoreUnits))
        #expect(small.snapshot.visible.count == 6)
        _ = small.apply(QueryPaginationFixture.event(small, .loadMoreUnits))
        #expect(small.snapshot.visible.count == 8 && !small.status.hasMoreUnits)
    }

    @Test func repeatedLoadAndSameRevisionCompetingActionsAdvanceOnlyOnce() throws {
        var state = try ContentQueryPaginationState(snapshot: QueryDisplayFixture.display(QueryPaginationFixture.flat(65)))
        let event = QueryPaginationFixture.event(state, .loadMoreUnits)
        #expect(state.apply(event).didPublish)
        #expect(state.apply(event).rejection == .staleRevision)
        #expect(state.snapshot.visible.count == 40)
        let staleSource = ContentQueryPaginationEvent(stamp: .init(sourceID: UUID(), revision: state.stamp.revision),
            action: .loadMoreUnits)
        #expect(state.apply(staleSource).rejection == .staleSource)
        #expect(state.snapshot.visible.count == 40)
    }

    @Test func independentlyBuiltSourceWithSameRequestIDCannotUseOldEvent() throws {
        let before = QueryDisplayFixture.display(QueryPaginationFixture.flat(40))
        let after = QueryDisplayFixture.display(QueryPaginationFixture.flat(65))
        #expect(before.source.source.source.requestID == after.source.source.source.requestID)
        #expect(before.sourceID != after.sourceID && !before.sharesSource(with: after))
        var state = try ContentQueryPaginationState(snapshot: before)
        let event = QueryPaginationFixture.event(state, .loadMoreUnits)
        #expect(state.reset(to: after, replacing: state.stamp).didPublish)
        #expect(state.snapshot.visible.count == 20 && state.status.hits.known == 65)
        #expect(state.apply(event).rejection == .staleSource)
        let forged = ContentQueryPaginationEvent(stamp: .init(sourceID: before.sourceID, revision: state.stamp.revision),
            action: .loadMoreUnits)
        #expect(state.apply(forged).rejection == .staleSource)
        #expect(state.reset(to: before, replacing: state.stamp).rejection == .sourceAlreadyPublished)
    }

    @Test func staleResetAndSameSourceRevisionCannotRestartPagination() throws {
        let source = QueryDisplayFixture.display(QueryPaginationFixture.flat(60))
        var state = try ContentQueryPaginationState(snapshot: source)
        let before = state.stamp
        _ = state.apply(QueryPaginationFixture.event(state, .loadMoreUnits))
        #expect(state.reset(to: QueryDisplayFixture.display(), replacing: before).rejection == .staleRevision)
        let revision = source.revisingVisibility(.all(source.units))
        #expect(state.reset(to: revision, replacing: state.stamp).rejection == .sourceAlreadyPublished)
        #expect(state.snapshot.visible.count == 40)
    }
}
