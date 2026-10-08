import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct TaskFieldCommandBoundaryTests {
    @Test(arguments: [0, 1, 2]) func unknownVerificationBindsEnvironmentAndQualification(kind: Int) throws {
        let fixture = try TaskFieldCommandFixture()
        let accepted = try fixture.prepare(0)
        fixture.io.saveMode = .throwAfter
        #expect(try fixture.submit(accepted).state == .unknown)
        let run = try #require(fixture.handoff.state().execution)
        let operation = try #require(run.operation(run.snapshot.items[0].id))
        if kind == 0 {
            let other = try TaskTitleCommandIO()
            let adapter = TaskFieldCommandAdapter(coordinator: fixture.handoff.coordinator, environment: try other.environment())
            #expect(throws: (any Error).self) { try adapter.verifyUnknown(operation, expecting: fixture.handoff.owned().lease) }
        } else {
            if kind == 1 { fixture.io.notes = .unknown } else { fixture.io.revision = UUID() }
            #expect(try fixture.adapter.verifyUnknown(operation, expecting: fixture.handoff.owned().lease) == .unreadable)
        }
        #expect(try fixture.handoff.state().execution?.units[0].local == .unknown)
        #expect(fixture.count("save") == 1)
    }

    @Test func lastTransactionGatePreservesConflictAndExternalEdit() throws {
        let fixture = try TaskFieldCommandFixture()
        let accepted = try fixture.prepare(0)
        var calls = 0
        fixture.io.beforeTransaction = {
            calls += 1
            if calls == 2 {
                fixture.base.todo.dayKey = "2026-10-12"
                try fixture.base.io.context.save()
            }
        }
        let facts = try fixture.submit(accepted)
        #expect(facts.state == .notSubmitted && facts.conflict)
        #expect(try fixture.handoff.state().execution?.units[0].state == .conflict)
        #expect(fixture.base.todo.dayKey == "2026-10-12" && fixture.count("save") == 0 && fixture.count("ui") == 0)
    }

    @Test(arguments: [false, true]) func unknownRechecksCurrentD3Associations(title: Bool) throws {
        let fixture = try TaskFieldCommandFixture()
        let tag = TagItem(name: "私密关联", sortOrder: 9)
        tag.isPrivateDiary = true
        fixture.base.io.context.insert(tag)
        try fixture.base.io.context.save()
        let titleAdapter = TaskTitleCommandAdapter(coordinator: fixture.handoff.coordinator, environment: fixture.environment)
        if title {
            try fixture.base.queue("修改")
            let preview = try titleAdapter.prepare(plan: fixture.handoff.state().plan.stamp, expecting: fixture.handoff.owned().lease)
            let accepted = try titleAdapter.accept(preview, expecting: fixture.handoff.owned().lease)
            fixture.io.saveMode = .throwAfter
            #expect(try titleAdapter.submit(accepted: accepted, expecting: fixture.handoff.owned().lease).state == .unknown)
        } else {
            let accepted = try fixture.prepare(0)
            fixture.io.saveMode = .throwAfter
            #expect(try fixture.submit(accepted).state == .unknown)
        }
        fixture.base.todo.tagIDs = tag.id.uuidString
        try fixture.base.io.context.save()
        let run = try #require(fixture.handoff.state().execution)
        let operation = try #require(run.operation(run.snapshot.items[0].id))
        if title {
            #expect(try titleAdapter.verifyUnknown(operation, expecting: fixture.handoff.owned().lease).presence == .unreadable)
        } else {
            #expect(try fixture.adapter.verifyUnknown(operation, expecting: fixture.handoff.owned().lease) == .unreadable)
        }
        #expect(try fixture.handoff.state().execution?.units[0].local == .unknown)
    }

    @Test(arguments: [0, 1, 2, 3, 4, 5]) func malformedOrMultipleInputsNeverPrepare(kind: Int) throws {
        let fixture = try TaskFieldCommandFixture()
        var argument = TaskFieldCommandFixture.argument(2)
        var extra: [CommandArgument] = []
        var targets = CommandDraftTargets(.single, objects: [.init(type: .todo, id: fixture.base.todo.id)])
        switch kind {
        case 0: argument = .init(parameter: .time, operation: .cancelReminder, value: .time(600))
        case 1: argument = .init(parameter: .time, operation: .setReminder, value: .time(1440))
        case 2: argument = .init(parameter: .time, operation: .unspecified, value: nil)
        case 3: extra = [.init(parameter: .notes, operation: .replace, value: .longText("不可开放"))]
        case 4: targets = .init(.selected, objects: [.init(type: .todo, id: fixture.base.todo.id), .init(type: .todo, id: UUID())])
        default: targets = .init(.single, objects: [.init(type: .subtask, id: fixture.base.todo.id)])
        }
        let draft = CommandDraft(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "todo.reminder"),
                                 targets: targets, arguments: [argument] + extra)
        try fixture.handoff.queue(draft)
        #expect(throws: (any Error).self) {
            try fixture.adapter.prepare(plan: fixture.handoff.state().plan.stamp, expecting: fixture.handoff.owned().lease)
        }
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0)
    }

    @Test func multipleAdaptersAndSourceReentryCannotMutateTwice() throws {
        let fixture = try TaskFieldCommandFixture()
        let accepted = try fixture.prepare(2)
        let another = TaskFieldCommandAdapter(coordinator: fixture.handoff.coordinator, environment: fixture.environment)
        fixture.io.beforeTransaction = {
            #expect(throws: (any Error).self) { try another.submit(accepted: accepted, expecting: fixture.handoff.owned().lease) }
        }
        #expect(try fixture.submit(accepted).state == .saved)
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 1 && fixture.base.io.authorizations == [570])
    }
}
