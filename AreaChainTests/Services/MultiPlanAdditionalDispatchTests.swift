import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct MultiPlanAdditionalDispatchTests {
    @Test(arguments: ["move", "tags", "completion", "enabled"])
    func everyBatchCommandUsesWholeFixedSet(command: String) throws {
        let fixture = try BatchCommandFixture(stateOperations: true)
        let argument: CommandArgument
        let targets: [CommandObjectReference]
        switch command {
        case "move": argument = fixture.move; targets = fixture.taskTargets
        case "tags": argument = fixture.tagArgument(.add, index: 1); targets = fixture.mixedTargets
        case "completion": argument = .init(parameter: .enabled, operation: .assign, value: .boolean(true)); targets = fixture.taskTargets
        default: argument = .init(parameter: .enabled, operation: .assign, value: .boolean(true)); targets = [.init(type: .routine, id: fixture.routine.id)]
        }
        try fixture.queue("batch." + command, argument: argument, targets: targets)
        let run = try MultiPlanDispatchFixture.execute(fixture.handoff, adapters: .init(batch: fixture.adapter))
        let facts = try #require(run.units[1].batch)
        #expect(facts.state == .saved && facts.targets.objects == targets)
        #expect(run.units[1].members.count == 1 && fixture.count("save") == 1 && fixture.count("ui") == 1)
        switch command {
        case "move": #expect(fixture.todos.allSatisfy { $0.dayKey == "2026-10-09" })
        case "tags":
            #expect(fixture.todos.allSatisfy { TagIDList.parse($0.tagIDs).contains(fixture.tags[1].id) })
            #expect(TagIDList.parse(fixture.routine.tagIDs).contains(fixture.tags[1].id))
        case "completion": #expect(fixture.todos.allSatisfy { $0.isDone })
        default: #expect(fixture.routine.isEnabled && fixture.routine.pausedOnDayKey == nil)
        }
    }

    @Test func literalTitleUsesOwnTargetAfterIndependentCreation() throws {
        let fixture = try TaskTitleCommandFixture()
        fixture.io.notificationResult = .succeeded
        fixture.io.calendarResult = .succeeded
        try fixture.base.queue("独立标题")
        let run = try MultiPlanDispatchFixture.execute(fixture.handoff, adapters: .init(taskTitle: fixture.adapter))
        #expect(run.units[1].taskTitle?.state == .saved && fixture.base.todo.title == "独立标题")
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 1)
    }

    @Test func allFourLegacySettingsHaveDistinctWriteAndPresentationHistory() throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        try fixture.queue(realBaseline: false)
        try fixture.queue("setting.appearance", value: .choice("dark"), realBaseline: false)
        try fixture.queue("setting.truncation", value: .choice("middle"), realBaseline: false)
        try fixture.queue("setting.captureSource", value: .boolean(true), realBaseline: false)
        let adapter = MultiPlanCommandAdapter(coordinator: fixture.handoff.coordinator, adapters: .init(localSettings: fixture.adapter))
        let preview = try adapter.prepare(plan: fixture.state().plan.stamp, expecting: fixture.owned().lease)
        fixture.io.failAppearance = true
        try adapter.submit(preview, expecting: fixture.owned().lease)
        let before = try #require(fixture.state().execution)
        #expect(before.units.count == 4 && before.units.allSatisfy { $0.local == .committed || $0.state == .succeeded })
        #expect(fixture.prefs.language == .english && fixture.prefs.appearance == .dark)
        #expect(fixture.io.writes.count == before.units.filter { $0.local == .committed }.count)
        let appearance = before.units[1]
        #expect(appearance.local == .committed && appearance.state == .failed)
        fixture.io.failAppearance = false
        let writes = fixture.io.writes
        _ = try fixture.adapter.retryPresentation(#require(before.attempt(appearance.id)), expecting: fixture.owned().lease)
        let after = try #require(fixture.state().execution)
        #expect(after.units.allSatisfy { $0.state == .succeeded })
        #expect(fixture.io.writes == writes && after.units[2] == before.units[2] && after.units[3] == before.units[3])
        #expect(after.units[1].history.first?.preferenceWrite?.presentationFailed == true)
    }

    @Test func composedCreationsRequireNewAcceptanceAfterDirectoryChanges() throws {
        let io = try TaskCreateCommandIO()
        io.capture.calendarEnabled = true
        io.notificationResult = .succeeded
        io.calendarResult = .succeeded
        let handoff = try HandoffFixture()
        let create = TaskCreateCommandAdapter(coordinator: handoff.coordinator, environment: try io.environment(), capability: .ordinaryComposition)
        for title in ["新增一 #共享 !p3 @09:30", "新增二"] {
            try handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "todo.create"),
                                   arguments: TaskCreateCommandFixture.arguments(title)))
        }
        let adapter = MultiPlanCommandAdapter(coordinator: handoff.coordinator, adapters: .init(taskCreate: create))
        let preview = try adapter.prepare(plan: handoff.state().plan.stamp, expecting: handoff.owned().lease)
        try adapter.submit(preview, expecting: handoff.owned().lease)
        let secondAttempt = try handoff.state().execution?.units[1].attempt
        #expect(adapter.pending != nil && secondAttempt == 0)
        let firstID = try #require(handoff.state().execution?.units[0].taskCreation?.savedID)
        try adapter.confirmPending(expecting: handoff.owned().lease)
        let rows = try io.capture.readTodos()
        #expect(rows.count == 2 && rows.first(where: { $0.id == firstID })?.remindMinutes == 570)
        #expect(io.capture.trace.filter { $0 == "save" }.count == 2)
    }
}
