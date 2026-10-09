import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct MultiPlanMergeExecutionTests {
    @Test(arguments: [false, true]) func realBaselineFinalAssignmentCommitsOnceOrNoChange(noChange: Bool) throws {
        let fixture = try TaskFieldCommandFixture()
        let adapter = MultiPlanRevisionSupport.adapter(fixture)
        let first = try MultiPlanRevisionSupport.queue(fixture)
        let last = try MultiPlanRevisionSupport.queue(fixture, argument: .init(parameter: .day, operation: .assign,
            value: .day(noChange ? "2026-10-05" : "2026-10-10")))
        let host = try fixture.handoff.owned()
        let proposal = try adapter.proposeMerge(first.stamp, last.stamp, expecting: host.lease)
        #expect(proposal.baseline.original(.day, targets: first.draft.targets) == .uniform(.day("2026-10-05")))
        #expect(fixture.count("save") == 0)
        try adapter.acceptMerge(proposal, expecting: host.lease)
        let plan = try fixture.handoff.state().plan
        #expect(plan.items.count == 1 && plan.items[0].id == first.id && plan.items[0].draft.id == first.draft.id)
        #expect(plan.items[0].mergedOrigins == [last.draft.stamp] && plan.items[0].version > first.version)
        #expect(throws: (any Error).self) { _ = try fixture.adapter.prepare(plan: plan.stamp, expecting: fixture.handoff.owned().lease) }
        #expect(try fixture.handoff.state().execution == nil && fixture.handoff.state().plan == plan)
        #expect(throws: (any Error).self) { try adapter.acceptMerge(proposal, expecting: fixture.handoff.owned().lease) }
        try MultiPlanRevisionSupport.start(adapter, fixture.handoff)
        #expect(fixture.base.todo.dayKey == (noChange ? "2026-10-05" : "2026-10-10"))
        #expect(fixture.count("save") == (noChange ? 0 : 1) && fixture.count("ui") == (noChange ? 0 : 1))
        #expect(try fixture.handoff.state().execution?.units.first?.state == .succeeded)
    }

    @Test(arguments: [0, 1, 2]) func proposalExpiresWithRealFieldSourceOrCatalog(change: Int) throws {
        let fixture = try TaskFieldCommandFixture()
        let adapter = MultiPlanRevisionSupport.adapter(fixture)
        let first = try MultiPlanRevisionSupport.queue(fixture)
        let last = try MultiPlanRevisionSupport.queue(fixture)
        let host = try fixture.handoff.owned()
        let proposal = try adapter.proposeMerge(first.stamp, last.stamp, expecting: host.lease)
        if change == 0 { fixture.base.todo.dayKey = "2026-10-07" }
        else if change == 1 { fixture.base.todo.deletedAt = Date() }
        else { fixture.base.io.context.insert(TagItem(name: "目录改变", sortOrder: 99)) }
        try fixture.base.io.context.save()
        #expect(throws: (any Error).self) { try adapter.acceptMerge(proposal, expecting: host.lease) }
        #expect(try fixture.handoff.state().plan == host.session.plan)
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0)
    }

    @Test func fabricatedDomainMergeNeverBecomesExecutionPermission() throws {
        let fixture = try TaskFieldCommandFixture()
        let adapter = MultiPlanRevisionSupport.adapter(fixture)
        let targets = CommandDraftTargets(.single, objects: [.init(type: .todo, id: fixture.base.todo.id)])
        for day in ["2026-10-09", "2026-10-10"] {
            try fixture.handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "todo.move"),
                targets: targets, baseline: .init([.init(subject: .object(targets.objects[0]), parameter: .day): .uniform(.day("2026-10-05"))]),
                arguments: [.init(parameter: .day, operation: .assign, value: .day(day))]))
        }
        let items = try fixture.handoff.state().plan.items
        try fixture.handoff.plan(.merge(earlier: items[0].stamp, later: items[1].stamp))
        #expect(throws: (any Error).self) { try MultiPlanRevisionSupport.start(adapter, fixture.handoff) }
        #expect(fixture.count("save") == 0)
    }

    @Test func dependencyAndDifferentCommandCannotMerge() throws {
        let fixture = try TaskFieldCommandFixture()
        let adapter = MultiPlanRevisionSupport.adapter(fixture)
        let first = try MultiPlanRevisionSupport.queue(fixture)
        let last = try MultiPlanRevisionSupport.queue(fixture)
        try fixture.handoff.plan(.link(last.stamp, .init(predecessors: [first.id])))
        let items = try fixture.handoff.state().plan.items
        #expect(throws: (any Error).self) { try adapter.proposeMerge(items[0].stamp, items[1].stamp, expecting: fixture.handoff.owned().lease) }
        let third = try MultiPlanRevisionSupport.queue(fixture, kind: 1)
        #expect(throws: (any Error).self) { try adapter.proposeMerge(items[1].stamp, third.stamp, expecting: fixture.handoff.owned().lease) }
        #expect(fixture.count("save") == 0)
    }
}
