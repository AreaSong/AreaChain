import Foundation
import Testing
@testable import AreaChain

struct ContentQueryReadPublicationTests {
    @Test func reevaluationReplacesFullResponseResortsAndRestoresMinimumActivePrefix() throws {
        let owner = try QueryReadFixture.owner()
        let old = owner.published!
        let active = old.pagination.snapshot.visible[0]
        QueryReadFixture.browse(owner, .activate(active))
        QueryReadFixture.browse(owner, .selectAllKnown)
        let selection = owner.published!.pagination.browse.selected
        let anchor = owner.published!.pagination.browse.activeAnchor
        let staleLoad = QueryReadFixture.load(owner)
        let effect = try QueryReadFixture.complete(owner)
        let current = owner.published!
        #expect(effect.outcome == .published && effect.pagination?.previousAnchor == anchor && effect.activeAnchor == anchor)
        #expect(effect.pagination?.browse.focus == nil && effect.pagination?.browse.open == nil)
        #expect(current.task.source == old.task.source && current.task.requestID == old.task.requestID)
        #expect(current.pagination.stamp.sourceID != old.pagination.stamp.sourceID)
        #expect(current.response.definiteMatchCount == 10)
        #expect(current.pagination.snapshot.source.source.ordered.map(\.id.dayKey) ==
            (1...10).reversed().map { String(format: "2026-10-%02d", $0) })
        // 新日期排在前面；旧活动日 02 只需要前 9 项可见，日 01 不沿用旧页进度。
        #expect(current.pagination.snapshot.visible.count == 9)
        #expect(current.pagination.snapshot.visible.last == active)
        #expect(current.pagination.browse.selected == selection && selection.count == 2)
        #expect(owner.loadMore(staleLoad).rejection == .staleSource)
        #expect(owner.applyBrowse(.init(version: old.pagination.snapshot.version, action: .selectVisible)).rejection == .staleVersion)
    }

    @Test func latestBrowseAndPaginationChangesWhilePreparedAreUsedOnPublication() throws {
        let owner = try QueryReadFixture.owner()
        let task = try owner.continueReading(source: owner.source!, budget: QueryReadFixture.budget(owner, results: 5))
        let ticket = try owner.evaluate(task)
        owner.loadMore(QueryReadFixture.load(owner))
        let active = owner.published!.pagination.snapshot.visible.last!
        QueryReadFixture.browse(owner, .activate(active))
        QueryReadFixture.browse(owner, .select(active, true))
        let effect = try owner.publish(ticket)
        #expect(effect.activeAnchor?.hit == active && effect.pagination?.previousAnchor?.hit == active)
        #expect(owner.published!.pagination.browse.selected == [active])
        #expect(owner.published!.pagination.snapshot.visible.count == 5)
    }

    @Test func newRelevantHitIsSortedFirstAndDisappearingActiveFallsBackToInput() throws {
        var batch = QuerySortFixture.batch("needle", titles: [("needle other", ""), ("other", "needle")])
        let owner = try QueryReadFixture.owner(batch)
        let active = owner.published!.pagination.snapshot.visible[0]
        QueryReadFixture.browse(owner, .activate(active))
        QueryReadFixture.browse(owner, .selectAllKnown)
        var rows = batch.snapshots.todos.values!
        rows.append(TodoQueryFixture.todo(3, title: "needle"))
        batch.snapshots.todos = .complete(rows)
        let task = try owner.begin(batch)
        try owner.publish(owner.evaluate(task))
        let sorted = owner.published!.pagination.snapshot
        #expect(sorted.visible.first?.id == rows[2].id && sorted.visible.last == active && sorted.visible.count == 2)
        #expect(owner.published!.pagination.browse.selected.count == 2)
        #expect(!owner.published!.pagination.browse.selected.contains(sorted.visible[0]))
        batch.snapshots.todos = .complete([rows[2]])
        let next = try owner.begin(batch)
        let effect = try owner.publish(owner.evaluate(next))
        #expect(effect.pagination?.previousAnchor?.hit == active && effect.pagination?.browse.focus == .input)
        #expect(effect.activeAnchor == nil && owner.published!.pagination.browse.active == nil)
        #expect(owner.published!.pagination.browse.selected.isEmpty)
    }

    @Test func noActiveAnchorResetsToInitialPageInsteadOfKeepingOldIndex() throws {
        let owner = try QueryReadFixture.owner()
        owner.loadMore(QueryReadFixture.load(owner))
        #expect(owner.published!.pagination.snapshot.visible.count == 2)
        let effect = try QueryReadFixture.complete(owner)
        #expect(effect.activeAnchor == nil && effect.pagination?.previousAnchor == nil)
        #expect(owner.published!.pagination.snapshot.visible.count == 1)
    }

    @Test func groupsKeepRelationshipsRankingAndIndependentContextPagination() throws {
        var batch = QueryPaginationFixture.grouped(groups: 2, hits: 4, contexts: 3, independent: 1)
        let owner = try QueryReadFixture.owner(batch)
        let source = owner.published!.pagination.snapshot
        let group = source.units.first { $0.hits.count == 4 }!
        while !owner.published!.pagination.snapshot.visibility.units.contains(group.id) {
            owner.loadMore(QueryReadFixture.load(owner))
        }
        let toggle = ContentQueryDisplayControl.contextToggle(group.sourceGroup!)
        owner.loadMore(.init(stamp: owner.published!.pagination.stamp, action: .loadMoreMembers(group.id)))
        owner.loadMore(.init(stamp: owner.published!.pagination.stamp, action: .loadMoreContexts(group.id)))
        let active = group.hits[1]
        QueryReadFixture.browse(owner, .activate(active))
        QueryReadFixture.browse(owner, .selectVisible)
        QueryReadFixture.browse(owner, .expand(toggle))
        let selected = owner.published!.pagination.browse.selected
        let oldAnchor = owner.published!.pagination.browse.activeAnchor
        let contextFocus = ContentQueryDisplayControl.context(group.context[1])
        var children = batch.snapshots.subtasks.values!
        let member = children.firstIndex { $0.id == group.hits[0].id }!
        children[member].title = "needle"
        batch.snapshots.subtasks = .complete(children)
        let task = try owner.begin(batch)
        let effect = try owner.publish(owner.evaluate(task), focused: contextFocus)
        let current = owner.published!.pagination
        #expect(effect.pagination?.previousAnchor == oldAnchor && effect.activeAnchor?.hit == active)
        #expect(current.browse.selected == selected && current.browse.expanded == [toggle])
        #expect(effect.pagination?.browse.focus == .control(toggle))
        #expect(current.status.groups.first?.loadedContextCount == 1)
        let expected = QueryPaginationFixture.sorted(batch, mode: .relevance)
        #expect(current.snapshot.units == expected.units)
        #expect(current.snapshot.source.source.ordered == expected.source.source.ordered)
        #expect(Set(current.snapshot.units.flatMap(\.context)) == Set(source.units.flatMap(\.context)))
        #expect(current.snapshot.units.first?.bestMatch.id == children[member].id)
    }
}
