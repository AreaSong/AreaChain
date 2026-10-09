import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct MultiPlanBoundaryTests {
    @Test(arguments: [false, true]) func creatingRetryRetainsReservedIdentityAndRejectsCollision(collision: Bool) throws {
        let fixture = try TaskCreateCommandFixture()
        fixture.io.capture.calendarEnabled = true
        fixture.io.notificationResult = .succeeded
        fixture.io.calendarResult = .succeeded
        try fixture.queue(TaskCreateCommandFixture.arguments("首次创建"))
        try fixture.queue(TaskCreateCommandFixture.arguments("独立创建"))
        let adapter = MultiPlanCommandAdapter(coordinator: fixture.handoff.coordinator, adapters: .init(taskCreate: fixture.adapter))
        let preview = try adapter.prepare(plan: fixture.handoff.state().plan.stamp, expecting: fixture.handoff.owned().lease)
        var validations = 0
        fixture.io.beforeTransaction = {
            validations += 1
            if validations == 1 { throw TaskCreateCommandIO.Failure.injected }
        }
        try adapter.submit(preview, expecting: fixture.handoff.owned().lease)
        let before = try #require(fixture.handoff.state().execution)
        let failedID = try #require(before.units[0].taskCreation?.creationID)
        let savedID = try #require(before.units[1].taskCreation?.savedID)
        #expect(failedID != savedID && before.units[0].local == .notSubmitted)
        if collision {
            fixture.io.capture.context.insert(TodoItem(id: failedID, title: "已占用身份", dayKey: "2026-10-05"))
            try fixture.io.capture.context.save()
        }
        let attempt = try #require(before.attempt(before.units[0].id))
        if collision {
            #expect(throws: TaskCreateCommandIssue.identityCollision) {
                try adapter.retryLocal(attempt, expecting: fixture.handoff.owned().lease)
            }
        } else { try adapter.retryLocal(attempt, expecting: fixture.handoff.owned().lease) }
        let after = try #require(fixture.handoff.state().execution)
        #expect(after.stamp == before.stamp && after.units[1] == before.units[1])
        #expect(after.units[0].taskCreation?.creationID == failedID)
        #expect(after.units[0].state == (collision ? .failed : .succeeded))
        #expect(fixture.count("save") == (collision ? 1 : 2))
        let rows = try fixture.io.capture.readTodos()
        #expect(rows.count == 2 && Set(rows.map(\.id)) == [failedID, savedID])
        #expect(collision ? after.units[0] == before.units[0] : after.units[0].history.first?.taskCreation?.state == .notSubmitted)
    }

    @Test func laterSourceCannotDirtyContextAfterWholePlanPreflightAndAllowEarlierSettingWrite() throws {
        let settings = try LocalSettingCommandFixture()
        defer { settings.cleanup() }
        let title = try TaskTitleCommandFixture()
        try settings.queue(realBaseline: false)
        try settings.handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "todo.title"),
            targets: .init(.single, objects: [.init(type: .todo, id: title.base.todo.id)]),
            arguments: [SubtaskCommandFixture.title("预检标题")]))
        let titleAdapter = TaskTitleCommandAdapter(coordinator: settings.handoff.coordinator, environment: title.environment)
        let adapter = MultiPlanCommandAdapter(coordinator: settings.handoff.coordinator,
                                              adapters: .init(taskTitle: titleAdapter, localSettings: settings.adapter))
        let preview = try adapter.prepare(plan: settings.state().plan.stamp, expecting: settings.owned().lease)
        title.io.sourceRead = { title.base.todo.dueMinutes = 999 }
        #expect(throws: TaskTitleCommandIssue.dirtyContext) { try adapter.submit(preview, expecting: settings.owned().lease) }
        #expect(settings.io.writes.isEmpty && title.count("save") == 0)
        #expect(try settings.state().execution == nil)
        #expect(title.base.io.context.hasChanges && title.base.todo.dueMinutes == 999)
    }

    @Test func changedEffectRequiresNewAcceptanceWithoutReplayingEarlierUnit() throws {
        let fields = try TaskFieldCommandFixture()
        fields.io.notificationResult = .succeeded
        fields.io.calendarResult = .succeeded
        for day in ["2026-10-09", "2026-10-10"] {
            try fields.handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "todo.move"),
                targets: .init(.single, objects: [.init(type: .todo, id: fields.base.todo.id)]),
                arguments: [.init(parameter: .day, operation: .assign, value: .day(day))]))
        }
        let adapter = MultiPlanCommandAdapter(coordinator: fields.handoff.coordinator, adapters: .init(taskField: fields.adapter))
        let preview = try adapter.prepare(plan: fields.handoff.state().plan.stamp, expecting: fields.handoff.owned().lease)
        try adapter.submit(preview, expecting: fields.handoff.owned().lease)
        let before = try #require(fields.handoff.state().execution)
        guard case .taskField(let revised) = adapter.pending else { Issue.record("必须等待新影响确认"); return }
        #expect(revised.original == .move("2026-10-09") && before.units[1].attempt == 0)
        #expect(fields.count("save") == 1)
        try adapter.confirmPending(expecting: fields.handoff.owned().lease)
        #expect(fields.base.todo.dayKey == "2026-10-10" && fields.count("save") == 2)
        #expect(try fields.handoff.state().execution?.units[0] == before.units[0])
    }

    @Test func reentryAnotherInstanceAndLateRequestCannotCallSecondUnit() throws {
        let fields = try TaskFieldCommandFixture()
        fields.io.notificationResult = .succeeded
        fields.io.calendarResult = .succeeded
        for kind in 0..<2 {
            try fields.handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source,
                commandID: .init(rawValue: TaskFieldCommandFixture.command(kind)),
                targets: .init(.single, objects: [.init(type: .todo, id: fields.base.todo.id)]),
                arguments: [TaskFieldCommandFixture.argument(kind)]))
        }
        let adapter = MultiPlanCommandAdapter(coordinator: fields.handoff.coordinator, adapters: .init(taskField: fields.adapter))
        let other = MultiPlanCommandAdapter(coordinator: fields.handoff.coordinator, adapters: .init(taskField: fields.adapter))
        let preview = try adapter.prepare(plan: fields.handoff.state().plan.stamp, expecting: fields.handoff.owned().lease)
        var requests: [TaskTitleCommandRequest] = []
        fields.io.beforeTransaction = {
            let host = try fields.handoff.owned()
            let run = try #require(host.session.execution)
            let unit = try #require(run.units.first { $0.state == .running })
            let request = try TaskTitleCommandRequest(lease: host.lease, operation: #require(run.operation(unit.id)),
                                                      attempt: #require(run.attempt(unit.id)))
            requests.append(request)
            #expect(throws: (any Error).self) { try fields.adapter.execute(request) }
            #expect(throws: (any Error).self) { try other.resume(expecting: host.lease) }
            #expect(throws: CommandExecutionError.busy) { _ = try fields.handoff.begin() }
        }
        try adapter.submit(preview, expecting: fields.handoff.owned().lease)
        for request in requests { #expect(throws: (any Error).self) { try fields.adapter.execute(request) } }
        #expect(fields.count("save") == 2 && fields.count("ui") == 2)
    }
}

extension MultiPlanBoundaryTests {
    @Test func invocationPreflightFailureAllowsIndependentSettingsAndExplicitRevalidationRetry() throws {
        let fields = try TaskFieldCommandFixture()
        fields.io.notificationResult = .succeeded
        fields.io.calendarResult = .succeeded
        let settings = try LocalSettingCommandFixture()
        defer { settings.cleanup() }
        for kind in 0..<2 {
            try fields.handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source,
                commandID: .init(rawValue: TaskFieldCommandFixture.command(kind)),
                targets: .init(.single, objects: [.init(type: .todo, id: fields.base.todo.id)]),
                arguments: [TaskFieldCommandFixture.argument(kind)]))
        }
        try fields.handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "setting.language"),
                                      arguments: [.init(parameter: .value, operation: .assign, value: .choice("english"))]))
        let local = LocalSettingCommandAdapter(coordinator: fields.handoff.coordinator, preferences: settings.prefs)
        let adapter = MultiPlanCommandAdapter(coordinator: fields.handoff.coordinator,
                                              adapters: .init(taskField: fields.adapter, localSettings: local))
        let preview = try adapter.prepare(plan: fields.handoff.state().plan.stamp, expecting: fields.handoff.owned().lease)
        fields.io.onRefresh = { fields.io.notes = .unknown }
        try adapter.submit(preview, expecting: fields.handoff.owned().lease)
        let before = try #require(fields.handoff.state().execution)
        #expect(before.units[0].state == .succeeded && before.units[1].validationFailedBeforeInvocation)
        #expect(before.units[2].state == .succeeded && settings.io.writes.count == 1 && fields.count("save") == 1)
        fields.io.notes = .absent
        fields.io.onRefresh = nil
        try adapter.retryLocal(#require(before.attempt(before.units[1].id)), expecting: fields.handoff.owned().lease)
        let after = try #require(fields.handoff.state().execution)
        #expect(after.units.allSatisfy { $0.state == .succeeded })
        #expect(after.units[0] == before.units[0] && after.units[2] == before.units[2])
        #expect(after.units[1].history.first?.validationFailedBeforeInvocation == true)
        #expect(fields.count("save") == 2 && settings.io.writes.count == 1)
    }
}

extension MultiPlanBoundaryTests {
    @Test func lateNoChangeCannotCloseRetryBeforeItsNewAttemptBegins() throws {
        let fields = try TaskFieldCommandFixture()
        fields.io.notificationResult = .succeeded
        fields.io.calendarResult = .succeeded
        for kind in 0..<2 {
            try fields.handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source,
                commandID: .init(rawValue: TaskFieldCommandFixture.command(kind)),
                targets: .init(.single, objects: [.init(type: .todo, id: fields.base.todo.id)]),
                arguments: [TaskFieldCommandFixture.argument(kind)]))
        }
        let adapter = MultiPlanCommandAdapter(coordinator: fields.handoff.coordinator, adapters: .init(taskField: fields.adapter))
        let preview = try adapter.prepare(plan: fields.handoff.state().plan.stamp, expecting: fields.handoff.owned().lease)
        fields.io.beforeTransaction = { throw TaskCreateCommandIO.Failure.injected }
        try adapter.submit(preview, expecting: fields.handoff.owned().lease)
        var run = try #require(fields.handoff.state().execution)
        let attempt = try #require(run.attempt(run.units[0].id))
        try run.retry(attempt, assurance: .safeLocalReplay)
        let retained = run
        #expect(throws: CommandExecutionError.stale) {
            try run.recordTaskField(.init(targetID: fields.base.todo.id, state: .noChange), attempt: attempt)
        }
        #expect(run == retained && fields.count("save") == 0)
    }
}
