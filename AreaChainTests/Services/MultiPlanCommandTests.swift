import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct MultiPlanCommandTests {
    @Test func sequentialFieldsUseRealMembersAndSeparateCommits() throws {
        let fixture = try TaskFieldCommandFixture()
        fixture.io.notificationResult = .succeeded
        fixture.io.calendarResult = .succeeded
        let adapter = MultiPlanCommandAdapter(coordinator: fixture.handoff.coordinator,
                                              adapters: .init(taskField: fixture.adapter))
        for kind in 0..<3 { try enqueue(kind, fixture: fixture) }
        let plan = try fixture.handoff.state().plan
        let preview = try adapter.prepare(plan: plan.stamp, expecting: fixture.handoff.owned().lease)
        #expect(fixture.count("save") == 0)
        try adapter.submit(preview, expecting: fixture.handoff.owned().lease)
        let run = try #require(fixture.handoff.state().execution)
        #expect(run.units.count == 3 && run.units.allSatisfy { $0.state == .succeeded })
        #expect(run.units.map(\.id) == plan.items.map(\.id))
        #expect(run.units.allSatisfy { $0.taskField?.targetID == fixture.base.todo.id })
        #expect(fixture.base.todo.dayKey == "2026-10-09")
        #expect(!fixture.base.todo.isImportant && fixture.base.todo.isUrgent)
        #expect(fixture.base.todo.remindMinutes == 570)
        #expect(fixture.count("save") == 3 && fixture.count("ui") == 3)
        #expect(fixture.io.notificationProcessed == 3 && fixture.io.calendarProcessed == 3)
        #expect(throws: (any Error).self) { try adapter.submit(preview, expecting: fixture.handoff.owned().lease) }
        #expect(fixture.count("save") == 3)
    }

    @Test func definiteFailureContinuesIndependentButBlocksDependent() throws {
        let fixture = try TaskFieldCommandFixture()
        fixture.io.notificationResult = .succeeded
        fixture.io.calendarResult = .succeeded
        for kind in 0..<3 { try enqueue(kind, fixture: fixture) }
        var host = try fixture.handoff.owned()
        let items = host.session.plan.items
        try fixture.handoff.coordinator.send(.plan(.link(items[1].stamp, .init(predecessors: [items[0].id])),
                                                   host.session.plan.stamp), expecting: host.lease)
        host = try fixture.handoff.owned()
        let adapter = MultiPlanCommandAdapter(coordinator: fixture.handoff.coordinator,
                                              adapters: .init(taskField: fixture.adapter))
        let preview = try adapter.prepare(plan: host.session.plan.stamp, expecting: host.lease)
        var calls = 0
        fixture.io.beforeTransaction = {
            calls += 1
            if calls == 1 { throw TaskCreateCommandIO.Failure.injected }
        }
        try adapter.submit(preview, expecting: fixture.handoff.owned().lease)
        let run = try #require(fixture.handoff.state().execution)
        #expect(run.units[0].state == .failed && run.units[0].local == .notSubmitted)
        #expect(run.units[1].state == .blocked && run.units[1].attempt == 0)
        #expect(run.units[2].state == .succeeded)
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 1)
        #expect(fixture.base.todo.dayKey == "2026-10-05" && fixture.base.todo.remindMinutes == 570)
    }

    @Test(arguments: [0, 1, 2]) func unknownStopsWholePlanAndCannotResume(position: Int) throws {
        let fixture = try TaskFieldCommandFixture()
        fixture.io.notificationResult = .succeeded
        fixture.io.calendarResult = .succeeded
        for kind in 0..<3 { try enqueue(kind, fixture: fixture) }
        let adapter = MultiPlanCommandAdapter(coordinator: fixture.handoff.coordinator,
                                              adapters: .init(taskField: fixture.adapter))
        let preview = try adapter.prepare(plan: fixture.handoff.state().plan.stamp, expecting: fixture.handoff.owned().lease)
        fixture.io.beforeTransaction = {
            if fixture.count("save") == position { fixture.io.saveMode = .throwAfter }
        }
        #expect(throws: CommandExecutionError.requiresVerification) {
            try adapter.submit(preview, expecting: fixture.handoff.owned().lease)
        }
        let run = try #require(fixture.handoff.state().execution)
        #expect(run.hasUnknownCommit && run.units[position].local == .unknown)
        #expect(run.units.prefix(position).allSatisfy { $0.state == .succeeded })
        #expect(run.units.dropFirst(position + 1).allSatisfy { $0.attempt == 0 })
        #expect(fixture.count("save") == position + 1)
        #expect(throws: CommandExecutionError.requiresVerification) {
            try adapter.resume(expecting: fixture.handoff.owned().lease)
        }
        #expect(throws: CommandExecutionError.requiresVerification) { _ = try fixture.handoff.begin() }
        #expect(fixture.count("save") == position + 1)
    }

    @Test func unassembledLastMemberRejectsBeforeAnyCommit() throws {
        let fixture = try TaskFieldCommandFixture()
        try enqueue(0, fixture: fixture)
        try fixture.handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source,
            commandID: .init(rawValue: "todo.title"), targets: .init(.single, objects: [.init(type: .todo, id: fixture.base.todo.id)]),
            arguments: [.init(parameter: .title, operation: .assign, value: .shortText("合成标题"))]))
        let adapter = MultiPlanCommandAdapter(coordinator: fixture.handoff.coordinator,
                                              adapters: .init(taskField: fixture.adapter))
        #expect(throws: CommandMultiPlanIssue.unassembled) {
            try adapter.prepare(plan: fixture.handoff.state().plan.stamp, expecting: fixture.handoff.owned().lease)
        }
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0)
        #expect(try fixture.handoff.state().execution == nil)
    }

    private func enqueue(_ kind: Int, fixture: TaskFieldCommandFixture) throws {
        try fixture.handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source,
            commandID: .init(rawValue: TaskFieldCommandFixture.command(kind)),
            targets: .init(.single, objects: [.init(type: .todo, id: fixture.base.todo.id)]),
            arguments: [TaskFieldCommandFixture.argument(kind)]))
    }
}
