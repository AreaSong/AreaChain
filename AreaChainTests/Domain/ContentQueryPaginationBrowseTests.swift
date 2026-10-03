import Foundation
import Testing
@testable import AreaChain

struct ContentQueryPaginationBrowseTests {
    @Test func appendPreservesActiveSelectionAndBodyExpansionWithoutOpeningOrFocusing() throws {
        var batch = QueryPaginationFixture.flat(45)
        var todos = batch.snapshots.todos.values!
        todos[0].title = String(repeating: "synthetic title ", count: 50)
        batch.snapshots.todos = .complete(todos)
        let source = QueryDisplayFixture.display(batch)
        var state = try ContentQueryPaginationState(snapshot: source)
        let active = try #require(state.snapshot.visible.first)
        let toggle = try #require(state.browse.toggleControls.first)
        _ = QueryPaginationFixture.browse(&state, .activate(active))
        _ = QueryPaginationFixture.browse(&state, .selectVisible)
        _ = QueryPaginationFixture.browse(&state, .expand(toggle))
        let selected = state.browse.selected
        let old = ContentQueryBrowseEvent(version: state.snapshot.version, action: .activate(source.visible[20]))
        let result = state.apply(QueryPaginationFixture.event(state, .loadMoreUnits))
        #expect(result.didPublish && result.browse.focus == nil && result.browse.open == nil)
        #expect(state.browse.active == active && state.browse.selected == selected && state.browse.expanded == [toggle])
        #expect(state.applyBrowse(old).rejection == .staleVersion)
        _ = QueryPaginationFixture.browse(&state, .selectAllKnown)
        #expect(state.browse.selected == source.known && state.browse.selected.count == 45)
        _ = QueryPaginationFixture.browse(&state, .selectVisible)
        #expect(state.browse.selected.count == 40)
        _ = state.apply(QueryPaginationFixture.event(state, .loadMoreUnits))
        #expect(state.browse.selected.count == 40)
    }

    @Test func arrowsOnlyTraverseVisibleHitsAndAppendExtendsSequence() throws {
        let source = QueryDisplayFixture.display(QueryPaginationFixture.flat(21))
        var state = try ContentQueryPaginationState(snapshot: source)
        let last = source.visible[19]
        let unloaded = source.visible[20]
        #expect(QueryPaginationFixture.browse(&state, .activate(unloaded)).rejection == .invalidTarget)
        _ = QueryPaginationFixture.browse(&state, .activate(last))
        _ = QueryPaginationFixture.browse(&state, .move(.next, inputEditing: false))
        #expect(state.browse.active == last)
        _ = state.apply(QueryPaginationFixture.event(state, .loadMoreUnits))
        _ = QueryPaginationFixture.browse(&state, .move(.next, inputEditing: false))
        #expect(state.browse.active == unloaded && state.browse.selected.isEmpty)
    }

    @Test func newSortResetsPagesRetainsSelectionAndReturnsStableAnchorForInvisibleActive() throws {
        var batch = QueryPaginationFixture.flat(40, query: "synthetic")
        var todos = batch.snapshots.todos.values!
        todos[39].title = "synthetic"
        batch.snapshots.todos = .complete(todos)
        let relevance = QueryPaginationFixture.sorted(batch, mode: .relevance)
        let recent = QueryPaginationFixture.sorted(batch, mode: .recent)
        var state = try ContentQueryPaginationState(snapshot: relevance)
        let active = try #require(relevance.visible.first)
        #expect(!recent.visible.prefix(20).contains(active))
        _ = QueryPaginationFixture.browse(&state, .activate(active))
        _ = QueryPaginationFixture.browse(&state, .select(active, true))
        let anchor = state.browse.activeAnchor
        let old = QueryPaginationFixture.event(state, .loadMoreUnits)
        _ = state.apply(old)
        let effect = state.reset(to: recent, replacing: state.stamp)
        #expect(effect.didPublish && effect.previousAnchor == anchor && effect.browse.focus == .input)
        #expect(state.browse.active == nil && state.browse.selected == [active])
        #expect(state.snapshot.visible == Array(recent.visible.prefix(20)))
        #expect(state.apply(old).rejection == .staleSource)
        #expect(QueryPaginationFixture.browse(&state, .open(inputEditing: false)).open == nil)
        #expect(QueryPaginationFixture.browse(&state, .activate(active)).rejection == .invalidTarget)
        _ = state.apply(QueryPaginationFixture.event(state, .loadMoreUnits))
        #expect(state.browse.active == nil && state.browse.selected == [active])
    }

    @Test func newQueryPreservesSurvivingIdentityButNeverSubstitutesSameIndex() throws {
        var state = try ContentQueryPaginationState(snapshot: QueryDisplayFixture.display(QueryPaginationFixture.flat(40)))
        let active = try #require(state.snapshot.visible.first)
        _ = QueryPaginationFixture.browse(&state, .activate(active))
        _ = QueryPaginationFixture.browse(&state, .selectAllKnown)
        _ = state.apply(QueryPaginationFixture.event(state, .loadMoreUnits))
        let next = QueryDisplayFixture.display(QueryPaginationFixture.flat(40, query: "item 39"))
        let effect = state.reset(to: next, replacing: state.stamp)
        #expect(effect.browse.focus == .input && state.browse.active == nil)
        #expect(!state.browse.selected.contains(active) && state.browse.selected == next.known)
        #expect(state.snapshot.visible == next.visible && next.visible.first != active)
    }

    @Test func freshBatchKeepsVisibleActiveAndLegalExpansionButResetsGroupProgress() throws {
        let batch = QueryPaginationFixture.grouped(groups: 1)
        let source = QueryDisplayFixture.display(batch)
        let group = try #require(source.units.first)
        let toggle = ContentQueryDisplayControl.contextToggle(try #require(group.sourceGroup))
        var state = try ContentQueryPaginationState(snapshot: source)
        _ = QueryPaginationFixture.browse(&state, .activate(group.bestMatch))
        _ = QueryPaginationFixture.browse(&state, .expand(toggle))
        _ = state.apply(QueryPaginationFixture.event(state, .loadMoreMembers(group.id)))
        _ = state.apply(QueryPaginationFixture.event(state, .loadMoreContexts(group.id)))
        let hiddenFocus = ContentQueryDisplayControl.context(group.context[20])
        let effect = state.reset(to: QueryDisplayFixture.display(batch), replacing: state.stamp, focused: hiddenFocus)
        #expect(effect.browse.focus == .control(toggle) && effect.browse.open == nil)
        #expect(state.browse.active == group.bestMatch && state.browse.expanded == [toggle])
        #expect(state.status.groups[0].hits.displayed == 20 && state.status.groups[0].contexts.displayed == 20)
        #expect(!state.browse.reachableControls.contains(hiddenFocus))
    }
}
