import Foundation
import Testing
@testable import AreaChain

struct ContentQueryDisplayTests {
    @Test func ordinaryResultsStayFlatInOriginalRankOrder() {
        let display = QueryDisplayFixture.display()
        #expect(display.units.flatMap(\.hits) == display.source.source.ordered.map(\.id))
        #expect(display.units.allSatisfy { $0.hits.count == 1 && $0.sourceGroup == nil && $0.context.isEmpty })
        #expect(display.diagnostics.isEmpty)
    }

    @Test func childBestRankDoesNotChangeStableGroupOrSourceAnchor() throws {
        let original = QueryPresentationFixture.project(QueryBatchFixture.trash())
        let parent = TrashFixture.ref(.todo)
        let child = TrashFixture.ref(.subtask, TrashFixture.childID)
        let image = TrashFixture.ref(.image, TrashFixture.imageID)
        let byID = Dictionary(uniqueKeysWithValues: original.source.ordered.map { ($0.id, $0) })
        let sorted = QueryPresentationFixture.replacing(original.source, ordered: [child, image, parent].compactMap { byID[$0] })
        let reordered = ContentQueryPresenter.project(sorted, budget: QueryPresentationFixture.budget,
                                                      locale: QueryPresentationFixture.locale)
        let first = try #require(ContentQueryDisplayBuilder.build(original).units.first)
        let second = try #require(ContentQueryDisplayBuilder.build(reordered).units.first)
        #expect(first.id == second.id && second.id == .trashGroup(parent))
        #expect(second.bestMatch == child && second.displayAnchor == parent && second.sourceGroup == parent)
        #expect(second.hits == [child, image, parent])
    }

    @Test func groupsAppearAtTheirBestRankAndMembersFollowGlobalRank() throws {
        var batch = QueryBatchFixture.trash()
        batch.snapshots.todos = .complete([TrashFixture.todo(), TrashFixture.todo(TrashFixture.otherID)])
        let source = QueryPresentationFixture.project(batch)
        let parent = TrashFixture.ref(.todo)
        let other = TrashFixture.ref(.todo, TrashFixture.otherID)
        let child = TrashFixture.ref(.subtask, TrashFixture.childID)
        let image = TrashFixture.ref(.image, TrashFixture.imageID)
        let ranks = Dictionary(uniqueKeysWithValues: source.source.ordered.map { ($0.id, $0) })
        let sorted = QueryPresentationFixture.replacing(source.source, ordered: [child, other, parent, image].compactMap { ranks[$0] })
        let response = ContentQueryPresenter.project(sorted, budget: QueryPresentationFixture.budget, locale: QueryPresentationFixture.locale)
        let result = ContentQueryDisplayBuilder.build(response)
        #expect(result.units.map(\.id) == [.trashGroup(parent), .trashGroup(other)])
        #expect(result.units.map(\.hits) == [[child, parent, image], [other]])
        #expect(result.diagnostics.isEmpty)
    }

    @Test func nonmatchingParentIsCollapsedContextAndNeverKeyboardHit() throws {
        let result = QueryDisplayFixture.display(QueryBatchFixture.trash("/trash 合成子任务"))
        let unit = try #require(result.units.first)
        let child = TrashFixture.ref(.subtask, TrashFixture.childID)
        #expect(unit.hits == [child] && unit.bestMatch == child && unit.context.count == 2)
        #expect(result.visible == [child] && result.known == [child])
        #expect(unit.context.allSatisfy { result.context($0)?.id == $0.object })
        var state = ContentQueryBrowseState(snapshot: result)
        #expect(state.expanded.isEmpty)
        _ = state.apply(QueryDisplayFixture.event(state, .move(.next, inputEditing: false)))
        #expect(state.active == child)
        let parent = TrashFixture.ref(.todo)
        #expect(state.apply(QueryDisplayFixture.event(state, .activate(parent))).rejection == .invalidTarget)
        #expect(state.apply(QueryDisplayFixture.event(state, .select(parent, true))).rejection == .invalidTarget)
    }

    @Test func missingGroupFallsBackWithoutLosingHits() {
        let source = QueryPresentationFixture.project(QueryBatchFixture.trash())
        let result = QueryDisplayFixture.changed(source) { _ in [] }
        #expect(result.units.flatMap(\.hits) == source.rows.map(\.id))
        #expect(result.units.allSatisfy { $0.sourceGroup == nil })
        #expect(result.diagnostics.count == source.rows.count)
    }

    @Test func duplicateGroupsAreRejectedTogetherRatherThanFirstWins() {
        let source = QueryPresentationFixture.project(QueryBatchFixture.trash())
        let result = QueryDisplayFixture.changed(source) { $0 + $0 }
        #expect(result.units.count == source.rows.count)
        #expect(result.units.allSatisfy { $0.context.isEmpty && $0.sourceGroup == nil })
        #expect(Set(result.visible).count == result.visible.count)
        #expect(result.diagnostics.contains(.conflictingGroup(TrashFixture.ref(.todo))))
    }

    @Test func missingMemberAndConflictingClaimsSafelyFallBack() {
        let source = QueryPresentationFixture.project(QueryBatchFixture.trash("/trash 合成子任务"))
        let result = QueryDisplayFixture.changed(source) { groups in
            groups.map { QueryDisplayFixture.group($0, context: []) }
        }
        #expect(result.visible == source.rows.map(\.id))
        #expect(result.units.allSatisfy { $0.sourceGroup == nil })
        #expect(result.diagnostics.contains(.invalidGroup(TrashFixture.ref(.todo))))
        #expect(result.diagnostics.contains(.missingGroupReference(group: TrashFixture.ref(.todo), object: TrashFixture.ref(.todo))))
        let overlap = QueryDisplayFixture.changed(source) { groups in
            let group = groups[0]
            let extra = TrashTombstoneGroup(id: TrashFixture.ref(.todo, TrashFixture.otherID),
                members: group.source.members, subtaskRead: .completeIncludingDeleted,
                imageInputRead: .completeIncludingDeleted, imageRead: .displayLimited)
            return groups + [QueryDisplayFixture.group(group, source: extra)]
        }
        #expect(overlap.visible == source.rows.map(\.id))
        #expect(overlap.units.allSatisfy { $0.sourceGroup == nil })
    }

    @Test func duplicateMemberAndForeignHitDoNotHideLegitimateResults() {
        let source = QueryPresentationFixture.project(QueryBatchFixture.trash())
        for foreign in [false, true] {
            let result = QueryDisplayFixture.changed(source) { groups in
                groups.map { group in
                    let extra = foreign ? TrashFixture.ref(.todo, TrashFixture.otherID) : group.matches[0]
                    return QueryDisplayFixture.group(group, matches: group.matches + [extra])
                }
            }
            #expect(result.visible == source.rows.map(\.id))
            #expect(result.units.allSatisfy { $0.sourceGroup == nil })
        }
    }

    @Test func independentAndUnknownChildrenAreNotForcedIntoParentGroup() {
        for parent in [TrashFixture.parentID, TrashFixture.otherID] {
            var batch = QueryBatchFixture.trash()
            batch.snapshots.subtasks = .complete([TrashFixture.child(parent: parent, deleted: TrashFixture.date + 1)])
            let result = QueryDisplayFixture.display(batch)
            let child = TrashFixture.ref(.subtask, TrashFixture.childID)
            let unit = result.units.first { $0.hits.contains(child) }
            #expect(unit?.hits == [child] && unit?.context.isEmpty == true)
            #expect(unit?.id != .trashGroup(TrashFixture.ref(.todo)))
        }
    }

    @Test func invalidRankIdentityCannotEnterSelection() {
        let source = QueryPresentationFixture.project(QueryBatchFixture.mixed())
        let repeated = QueryPresentationFixture.replacing(source.source, ordered: source.source.ordered + [source.source.ordered[0]])
        let presented = ContentQueryPresenter.project(repeated, budget: QueryPresentationFixture.budget,
                                                     locale: QueryPresentationFixture.locale)
        let result = ContentQueryDisplayBuilder.build(presented)
        #expect(!result.known.contains(source.source.ordered[0].id))
        #expect(result.diagnostics.contains(.invalidHit(source.source.ordered[0].id)))
    }
}
