import Foundation
import Testing
@testable import AreaChain

struct ContentQueryBrowseTests {
    @Test func arrowsClampAndReturnOpensOnlyActiveVisibleIdentity() {
        let display = QueryDisplayFixture.display()
        var state = ContentQueryBrowseState(snapshot: display)
        #expect(state.apply(QueryDisplayFixture.event(state, .open(inputEditing: false))).rejection == .invalidTarget)
        _ = state.apply(QueryDisplayFixture.event(state, .move(.next, inputEditing: false)))
        #expect(state.active == display.visible.first)
        _ = state.apply(QueryDisplayFixture.event(state, .move(.previous, inputEditing: false)))
        #expect(state.active == display.visible.first)
        for _ in 0...display.visible.count { _ = state.apply(QueryDisplayFixture.event(state, .move(.next, inputEditing: false))) }
        #expect(state.active == display.visible.last)
        #expect(state.apply(QueryDisplayFixture.event(state, .open(inputEditing: false))).open?.object == state.active)
        #expect(state.selected.isEmpty)
    }

    @Test func editorKeepsArrowAndReturnPriority() {
        var state = ContentQueryBrowseState(snapshot: QueryDisplayFixture.display())
        #expect(state.apply(QueryDisplayFixture.event(state, .move(.next, inputEditing: true))).rejection == .editorHasPriority)
        #expect(state.apply(QueryDisplayFixture.event(state, .open(inputEditing: true))).rejection == .editorHasPriority)
        #expect(state.active == nil && state.selected.isEmpty)
    }

    @Test func visibleAndAllKnownSelectionAreDistinctAndAppendDoesNotSelect() throws {
        let all = QueryDisplayFixture.display()
        let first = try #require(all.visible.first)
        let partial = QueryDisplayFixture.visibility(all, hits: [first])
        var state = ContentQueryBrowseState(snapshot: partial)
        _ = state.apply(QueryDisplayFixture.event(state, .selectVisible))
        #expect(state.selected == [first])
        #expect(partial.knownUndisplayedCount == all.known.count - 1)
        _ = state.publish(all, replacing: partial.version)
        #expect(state.selected == [first])
        _ = state.apply(QueryDisplayFixture.event(state, .selectAllKnown))
        #expect(state.selected == all.known)
        _ = state.apply(QueryDisplayFixture.event(state, .select(first, false)))
        #expect(!state.selected.contains(first))
        _ = state.apply(QueryDisplayFixture.event(state, .select(first, true)))
        #expect(state.selected == all.known)
    }

    @Test func hidingActiveRowKeepsMultiSelectionButReturnsInputWithoutReplacement() throws {
        let all = QueryDisplayFixture.display()
        let first = try #require(all.visible.first)
        var state = ContentQueryBrowseState(snapshot: all)
        _ = state.apply(QueryDisplayFixture.event(state, .activate(first)))
        _ = state.apply(QueryDisplayFixture.event(state, .selectAllKnown))
        let next = QueryDisplayFixture.visibility(all, hits: all.known.subtracting([first]))
        let effect = state.publish(next, replacing: all.version)
        #expect(state.selected == all.known && state.active == nil && effect.focus == .input)
        #expect(state.apply(QueryDisplayFixture.event(state, .open(inputEditing: false))).open == nil)
    }

    @Test func reorderPreservesIdentityAndRemovalClearsRatherThanSubstitutes() throws {
        let original = QueryPresentationFixture.project(QuerySortFixture.batch("", titles: [("same", ""), ("same", "")]))
        let snapshot = ContentQueryDisplayBuilder.build(original)
        let id = try #require(snapshot.visible.first)
        var state = ContentQueryBrowseState(snapshot: snapshot)
        _ = state.apply(QueryDisplayFixture.event(state, .activate(id)))
        _ = state.apply(QueryDisplayFixture.event(state, .select(id, true)))
        let reversed = QueryPresentationFixture.replacing(original.source, ordered: original.source.ordered.reversed())
        let reordered = ContentQueryDisplayBuilder.build(ContentQueryPresenter.project(reversed,
            budget: QueryPresentationFixture.budget, locale: QueryPresentationFixture.locale))
        #expect(state.publish(reordered, replacing: snapshot.version).focus == nil)
        #expect(state.active == id && state.selected == [id])
        var removedBatch = QuerySortFixture.batch("", titles: [("same", ""), ("same", "")])
        removedBatch.snapshots.todos = .complete(removedBatch.snapshots.todos.values!.filter { $0.id != id.id })
        let next = QueryDisplayFixture.display(removedBatch)
        #expect(state.publish(next, replacing: reordered.version).focus == .input)
        #expect(state.active == nil && state.selected.isEmpty && next.visible.count == 1)
    }

    @Test func staleCallbacksAndSnapshotReplayAreRejected() throws {
        let old = QueryDisplayFixture.display()
        let id = try #require(old.visible.first)
        var state = ContentQueryBrowseState(snapshot: old)
        let next = QueryDisplayFixture.display()
        _ = state.publish(next, replacing: old.version)
        let actions: [ContentQueryBrowseAction] = [.activate(id), .select(id, true), .selectVisible, .selectAllKnown,
            .move(.next, inputEditing: false), .open(inputEditing: false), .focusInput,
            .expand(.contextToggle(id)), .collapse(.contextToggle(id), focused: nil), .focusControl(.contextToggle(id))]
        for action in actions {
            let result = state.apply(.init(version: old.version, action: action))
            #expect(result.rejection == .staleVersion && result.focus == nil && result.open == nil)
        }
        #expect(state.publish(old, replacing: next.version).rejection == .staleVersion)
        #expect(state.publish(QueryDisplayFixture.display(), replacing: old.version).rejection == .staleVersion)
        #expect(state.active == nil && state.selected.isEmpty)
    }

    @Test func contextExpansionDoesNotStealFocusAndCollapseReturnsItsToggle() throws {
        let snapshot = QueryDisplayFixture.display(QueryBatchFixture.trash("/trash 合成子任务"))
        let context = try #require(snapshot.units.first?.context.first)
        let toggle = ContentQueryDisplayControl.contextToggle(context.group)
        var state = ContentQueryBrowseState(snapshot: snapshot)
        _ = state.apply(QueryDisplayFixture.event(state, .move(.next, inputEditing: false)))
        let before = state.active
        #expect(state.apply(QueryDisplayFixture.event(state, .expand(toggle))).focus == nil)
        #expect(state.reachableControls.contains(.context(context)))
        #expect(state.apply(QueryDisplayFixture.event(state, .focusControl(.context(context)))).focus == .control(.context(context)))
        #expect(state.active == before && snapshot.visible.count == 1)
        let collapse = state.apply(QueryDisplayFixture.event(state, .collapse(toggle, focused: .context(context))))
        #expect(collapse.focus == .control(toggle) && state.active == before)
        #expect(!state.reachableControls.contains(.context(context)))
        #expect(state.apply(QueryDisplayFixture.event(state, .collapse(toggle, focused: nil))).focus == nil)
    }

    @Test func bodyUsesExistingExpansionReferenceAndDisappearingControlReturnsInput() throws {
        let batch = QuerySortFixture.batch("alpha", titles: [(String(repeating: "alpha ", count: 30), "")])
        let snapshot = QueryDisplayFixture.display(batch)
        var state = ContentQueryBrowseState(snapshot: snapshot)
        let reference = try #require(snapshot.source.rows.first?.expansion.first)
        let toggle = ContentQueryDisplayControl.bodyToggle(reference.object, reference.field)
        let body = ContentQueryDisplayControl.body(reference.object, reference.field)
        #expect(state.expansionReference(for: body) == nil)
        #expect(state.apply(QueryDisplayFixture.event(state, .expand(toggle))).focus == nil)
        #expect(state.expansionReference(for: body) == reference)
        #expect(state.apply(QueryDisplayFixture.event(state, .collapse(toggle, focused: body))).focus == .control(toggle))
        let empty = QueryDisplayFixture.visibility(snapshot, hits: [])
        #expect(state.publish(empty, replacing: snapshot.version, focused: body).focus == .input)
        #expect(state.reachableControls.isEmpty)
    }

    @Test func subtaskAndOccurrenceOpenPreserveSpecificIdentityAndParent() throws {
        for batch in [QueryBatchFixture.mixed(), QueryBatchFixture.occurrences(), QueryBatchFixture.trash()] {
            let snapshot = QueryDisplayFixture.display(batch)
            var state = ContentQueryBrowseState(snapshot: snapshot)
            let id = try #require(snapshot.visible.first { $0.type == .subtask || $0.type == .routineOccurrence })
            _ = state.apply(QueryDisplayFixture.event(state, .activate(id)))
            let open = try #require(state.apply(QueryDisplayFixture.event(state, .open(inputEditing: false))).open)
            #expect(open.object == id && open.parent != nil && open.requiresFreshBusinessValidation)
            if id.type == .routineOccurrence { #expect(open.object.dayKey != nil) }
            let isTrash = batch.session.scope == .catalog(.trash)
            #expect(open.viewingTrash == isTrash)
        }
    }

    @Test func groupMemberVisibilityRetainsSelectionAndReportsHiddenCount() throws {
        let all = QueryDisplayFixture.display(QueryBatchFixture.trash())
        let group = try #require(all.units.first)
        let first = try #require(group.hits.first)
        let partial = QueryDisplayFixture.visibility(all, hits: [first])
        #expect(partial.knownUndisplayedCount(in: group.id) == group.hits.count - 1)
        var state = ContentQueryBrowseState(snapshot: all)
        _ = state.apply(QueryDisplayFixture.event(state, .selectAllKnown))
        _ = state.publish(partial, replacing: all.version)
        #expect(state.selected == all.known && state.snapshot.visible == [first])
        _ = state.apply(QueryDisplayFixture.event(state, .selectVisible))
        #expect(state.selected == [first])
    }

    @Test func visibilityRequiresBothUnitAndMemberAndCannotInjectUnknownIdentity() {
        let all = QueryDisplayFixture.display()
        let unknown = TrashFixture.ref(.todo, UUID())
        let empty = ContentQueryDisplayBuilder.build(all.source, visibility: .init(units: [], members: all.known.union([unknown])))
        #expect(empty.visible.isEmpty && empty.known == all.known)
        var state = ContentQueryBrowseState(snapshot: empty)
        #expect(state.apply(QueryDisplayFixture.event(state, .move(.next, inputEditing: false))).focus == .input)
        #expect(state.apply(QueryDisplayFixture.event(state, .select(unknown, true))).rejection == .invalidTarget)
        _ = state.apply(QueryDisplayFixture.event(state, .selectVisible))
        #expect(state.selected.isEmpty)
    }
}
