import Foundation
import Testing
@testable import AreaChain

struct ContentQueryGroupPaginationTests {
    @Test func largeGroupIsOneUnitAndBestHitIsInInitialSegment() throws {
        let source = QueryDisplayFixture.display(QueryPaginationFixture.grouped(groups: 21))
        var state = try ContentQueryPaginationState(snapshot: source)
        #expect(source.units.count == 21 && state.status.units == .init(displayed: 20, known: 21))
        #expect(state.snapshot.visible.count == 400 && state.status.hits.known == 945)
        for unit in source.units.prefix(20) {
            #expect(state.snapshot.visible.contains(unit.bestMatch))
            #expect(state.snapshot.knownUndisplayedCount(in: unit.id) == 25)
        }
        _ = state.apply(QueryPaginationFixture.event(state, .loadMoreUnits))
        #expect(state.status.units == .init(displayed: 21, known: 21))
        #expect(state.snapshot.visible.count == 420 && !state.status.hasMoreUnits && state.status.hasMoreKnownHits)
    }

    @Test func independentTrashRowsConsumeOneUnitEach() throws {
        let source = QueryDisplayFixture.display(QueryPaginationFixture.grouped(groups: 1, independent: 21))
        #expect(source.units.count == 22 && source.units.filter { $0.hits.count > 1 }.count == 1)
        #expect(source.units.filter { $0.hits.count == 1 && $0.context.isEmpty }.count == 21)
        var state = try ContentQueryPaginationState(snapshot: source)
        #expect(state.snapshot.visibility.units == Set(source.units.prefix(20).map(\.id)))
        _ = state.apply(QueryPaginationFixture.event(state, .loadMoreUnits))
        #expect(state.status.units.displayed == 22 && !state.status.hasMoreUnits)
        #expect(state.snapshot.units == source.units)
    }

    @Test func fallbackTrashRowsAlsoConsumeOneUnitEach() throws {
        var batch = QueryBatchFixture.empty("/trash")
        batch.snapshots.todos = .complete((0..<25).map { _ in TrashFixture.todo(UUID()) })
        let source = QueryDisplayFixture.changed(QueryPresentationFixture.project(batch)) { _ in [] }
        #expect(source.units.allSatisfy { if case .row = $0.id { return true }; return false })
        var state = try ContentQueryPaginationState(snapshot: source)
        #expect(state.status.units == .init(displayed: 20, known: 25))
        _ = state.apply(QueryPaginationFixture.event(state, .loadMoreUnits))
        #expect(state.snapshot.visible == source.visible && state.status.units.displayed == 25)
        #expect(state.snapshot.diagnostics == source.diagnostics)
    }

    @Test func topLevelAppendPreservesMemberAndContextProgressAndExpansion() throws {
        let source = QueryDisplayFixture.display(QueryPaginationFixture.grouped())
        let group = try #require(source.units.first)
        let toggle = ContentQueryDisplayControl.contextToggle(try #require(group.sourceGroup))
        var state = try ContentQueryPaginationState(snapshot: source, policy: .init(units: 1, members: 7, contexts: 3))
        #expect(state.apply(QueryPaginationFixture.event(state, .loadMoreMembers(group.id))).didPublish)
        #expect(state.apply(QueryPaginationFixture.event(state, .loadMoreContexts(group.id))).didPublish)
        _ = QueryPaginationFixture.browse(&state, .expand(toggle))
        let before = try #require(state.status.groups.first)
        #expect(before.hits.displayed == 14 && before.contexts.displayed == 6)
        _ = state.apply(QueryPaginationFixture.event(state, .loadMoreUnits))
        #expect(state.status.groups.first == before && state.browse.expanded == [toggle])
        #expect(state.status.groups[1].hits.displayed == 7 && state.status.groups[1].loadedContextCount == 3)
        #expect(state.status.groups[1].contexts.displayed == 0)
    }

    @Test func memberLoadsOnlyChangeTheirGroupAndNeverCountContextAsHits() throws {
        let source = QueryDisplayFixture.display(QueryPaginationFixture.grouped())
        let group = try #require(source.units.first)
        var state = try ContentQueryPaginationState(snapshot: source)
        let second = state.status.groups[1]
        let contexts = state.snapshot.visibility.contexts
        let event = QueryPaginationFixture.event(state, .loadMoreMembers(group.id))
        #expect(state.apply(event).didPublish)
        #expect(state.apply(event).rejection == .staleRevision)
        #expect(state.status.groups[0].hits == .init(displayed: 40, known: 45))
        #expect(state.status.groups[1] == second && state.snapshot.visibility.contexts == contexts)
        #expect(state.snapshot.visible.prefix(40) == group.hits.prefix(40))
        _ = state.apply(QueryPaginationFixture.event(state, .loadMoreMembers(group.id)))
        #expect(state.status.groups[0].hits == .init(displayed: 45, known: 45))
        #expect(state.apply(QueryPaginationFixture.event(state, .loadMoreMembers(group.id))).rejection == .exhausted)
        #expect(state.snapshot.visible.count == 65 && state.status.hits.known == 90)
    }

    @Test func collapsedContextIsBoundedAndTabCannotReachUnloadedMembers() throws {
        let source = QueryDisplayFixture.display(QueryPaginationFixture.grouped(groups: 1))
        let group = try #require(source.units.first)
        let toggle = ContentQueryDisplayControl.contextToggle(try #require(group.sourceGroup))
        let beyond = group.context[20]
        var state = try ContentQueryPaginationState(snapshot: source)
        #expect(state.status.groups[0].contexts == .init(displayed: 0, known: 25))
        #expect(state.status.groups[0].loadedContextCount == 20 && state.browse.reachableControls == [toggle])
        #expect(QueryPaginationFixture.browse(&state, .expand(toggle)).focus == nil)
        #expect(state.status.groups[0].contexts == .init(displayed: 20, known: 25))
        #expect(state.browse.reachableControls == [toggle] + group.context.prefix(20).map(ContentQueryDisplayControl.context))
        #expect(QueryPaginationFixture.browse(&state, .focusControl(.context(beyond))).rejection == .invalidTarget)
        let hits = state.snapshot.visible
        let event = QueryPaginationFixture.event(state, .loadMoreContexts(group.id))
        #expect(state.apply(event).browse == .init())
        #expect(state.apply(event).rejection == .staleRevision)
        #expect(state.status.groups[0].contexts.displayed == 25 && state.snapshot.visible == hits)
        #expect(QueryPaginationFixture.browse(&state, .focusControl(.context(beyond))).focus == .control(.context(beyond)))
        _ = QueryPaginationFixture.browse(&state, .selectAllKnown)
        #expect(state.browse.selected == Set(group.hits))
        #expect(state.browse.selected.isDisjoint(with: Set(group.context.map(\.object))))
        let collapse = QueryPaginationFixture.browse(&state, .collapse(toggle, focused: .context(beyond)))
        #expect(collapse.focus == .control(toggle) && state.status.groups[0].contexts.displayed == 0)
        #expect(state.status.groups[0].loadedContextCount == 25)
        _ = QueryPaginationFixture.browse(&state, .expand(toggle))
        #expect(state.status.groups[0].contexts.displayed == 25)
    }

    @Test func unloadedOrUnknownGroupRejectsBothSegmentActions() throws {
        let source = QueryDisplayFixture.display(QueryPaginationFixture.grouped())
        var state = try ContentQueryPaginationState(snapshot: source, policy: .init(units: 1))
        let stamp = state.stamp
        for id in [source.units[1].id, .trashGroup(TrashFixture.ref(.todo, UUID()))] {
            for action in [ContentQueryPaginationAction.loadMoreMembers(id), .loadMoreContexts(id)] {
                #expect(state.apply(QueryPaginationFixture.event(state, action)).rejection == .invalidTarget)
            }
        }
        #expect(state.stamp == stamp && state.status.units.displayed == 1)
    }
}
