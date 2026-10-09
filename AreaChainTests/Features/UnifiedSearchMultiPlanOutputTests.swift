import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchMultiPlanOutputTests {
    @Test(arguments: [false, true]) func nativeTaskSubtaskTitleChainUsesRealTargets(compact: Bool) async throws {
        let io = try MultiPlanOutputFixture()
        let fixture = try makeFixture(io)
        defer { fixture.stop() }
        let controller = fixture.controller!
        let items = try queueChain(fixture)
        _ = try await fixture.publish()
        let host = makeHost(controller, compact: compact)
        defer { host.close() }
        try await host.start()
        try await link(host, consumer: items[1], producer: items[0], parameter: .parent)
        try await link(host, consumer: items[2], producer: items[1])
        for type in ["todo", "subtask", "routine"] {
            let key = "unified.plan.reference.type." + type
            #expect(L10n.format(key, locale: Locale(identifier: compact ? "zh-Hans" : "en")) != key)
        }
        try await host.clickCompositionControl("unified.multi.prepare")
        #expect(io.count("save") == 0 && io.subtaskSourceRequests.isEmpty)
        try await host.revealSettingControlInsidePanel("unified.multi.preview." + items[1].id.uuidString)
        try host.snapshot("pm2-future-parent-\(compact)")
        if compact { try await host.clickCompositionControl("unified.multi.submit") }
        else {
            host.window.makeFirstResponder(try host.field)
            try await host.settle()
            try await host.key(36, "\r", flags: .command)
        }
        try await settle(host, controller)
        let first = try #require(controller.settingExecution)
        let parentID = try #require(first.units[0].taskCreation?.savedID)
        guard case .subtask(let parentPreview) = controller.multiPlan?.pending else { Issue.record("缺少真实父预览"); return }
        #expect(parentPreview.parent.id == parentID && parentPreview.original == nil && parentPreview.input.target == nil)
        #expect(try io.children().isEmpty && first.units[1].attempt == 0 && io.count("ui") == 1)
        try await host.revealSettingControlInsidePanel("unified.subtask.parent")
        try host.snapshot("pm2-real-parent-\(compact)")
        try await host.clickCompositionControl("unified.multi.confirm")
        try await settle(host, controller)
        let second = try #require(controller.settingExecution)
        let childID = try #require(second.units[1].subtask?.createdObject?.id)
        guard case .subtask(let childPreview) = controller.multiPlan?.pending else { Issue.record("缺少真实子项预览"); return }
        #expect(childID != parentID && childPreview.original?.id == childID && childPreview.original?.title == "子任务")
        #expect(try io.children().count == 1 && io.count("saveSubtask") == 1 && io.count("ui") == 2)
        try await host.revealSettingControlInsidePanel("unified.subtask.values")
        try host.snapshot("pm2-real-child-\(compact)")
        try await host.clickCompositionControl("unified.multi.confirm")
        try await settle(host, controller)
        let child = try #require(io.children().first)
        let run = try #require(controller.settingExecution)
        #expect(run.units.allSatisfy { $0.state == .succeeded })
        #expect(child.id == childID && child.todo?.id == parentID && child.title == "新子标题")
        #expect(run.resolvedInput(items[1].id)?.targets == CommandDraftTargets.none)
        #expect(io.count("save") == 1 && io.count("saveSubtask") == 2 && io.count("ui") == 3)
        #expect(try io.context.fetchCount(FetchDescriptor<TodoItem>()) == 1)
        try await host.revealSettingControlInsidePanel("unified.multi.unit." + items[2].id.uuidString)
        try host.snapshot("pm2-chain-saved-\(compact)")
    }

    @Test(arguments: [false, true]) func nativeRoutineBranchChangesWeekdaysThenReminder(compact: Bool) async throws {
        let routine = try RoutineCreateFixture()
        let fixture = try UnifiedSearchResultsFixture(QueryBatchFixture.empty("/tasks"), privacyCenter: NotificationCenter(),
            routineEnvironment: routine.environment, enableMultiPlan: true, outputCapability: .typedCreation)
        defer { fixture.stop() }
        let controller = fixture.controller!
        let producer = try fixture.enqueueOperation("routine.create", arguments: [RoutineCommandFixture.title("新习惯"),
            .init(parameter: .weekdays, operation: .assign, value: .weekdays(WeekdayMask.workdays))])
        let weekdays = try fixture.enqueueOperation("routine.weekdays", arguments: [
            .init(parameter: .weekdays, operation: .assign, value: .weekdays(WeekdayMask.all))])
        let reminder = try fixture.enqueueOperation("routine.reminder", arguments: [
            .init(parameter: .time, operation: .setReminder, value: .time(570))])
        _ = try await fixture.publish()
        let host = makeHost(controller, compact: compact)
        defer { host.close() }
        try await host.start()
        try await link(host, consumer: weekdays, producer: producer)
        try await link(host, consumer: reminder, producer: producer)
        let beforeCount = try routine.snapshots().count
        try await host.clickCompositionControl("unified.multi.prepare")
        #expect(routine.base.count("save") == 0)
        try await host.clickCompositionControl("unified.multi.submit")
        try await settle(host, controller)
        let id = try #require(controller.settingExecution?.outputs[producer.id]?.id)
        guard case .routine(let actual) = controller.multiPlan?.pending else { Issue.record("缺少真实习惯预览"); return }
        #expect(actual.target.id == id && actual.original[.weekdayMask] == .number(WeekdayMask.workdays))
        try await host.revealSettingControlInsidePanel("unified.multi.confirm")
        try host.snapshot("pm2-routine-weekdays-\(compact)")
        try await host.clickCompositionControl("unified.multi.confirm")
        try await settle(host, controller)
        #expect(try routine.stored(id).weekdayMask == WeekdayMask.all && routine.base.count("save") == 2)
        guard case .routine(let latest) = controller.multiPlan?.pending else { Issue.record("缺少提醒确认"); return }
        #expect(latest.target.id == id && latest.original[.remindMinutes] == .number(nil))
        try await host.revealSettingControlInsidePanel("unified.multi.confirm")
        try host.snapshot("pm2-routine-reminder-\(compact)")
        try await host.clickCompositionControl("unified.multi.confirm")
        try await settle(host, controller)
        let saved = try routine.stored(id)
        #expect(saved.weekdayMask == WeekdayMask.all && saved.remindMinutes == 570 && saved.checks.isEmpty)
        #expect(try routine.snapshots().count == beforeCount + 1)
        #expect(controller.settingExecution?.units.allSatisfy { $0.state == .succeeded } == true)
        #expect(routine.base.count("save") == 3 && routine.base.count("ui") == 3 && routine.base.count("fact") == 3)
        try await host.revealSettingControlInsidePanel("unified.multi.unit." + reminder.id.uuidString)
        try host.snapshot("pm2-routine-saved-\(compact)")
    }

    @Test func nativeBranchReadsCurrentValueAndConsumerRetryNeverRecreates() async throws {
        let io = try MultiPlanOutputFixture()
        let fixture = try makeFixture(io)
        defer { fixture.stop() }
        let controller = fixture.controller!
        let producer = try fixture.enqueueOperation("todo.create", arguments: TaskCreateCommandFixture.arguments("第一步"))
        let first = try fixture.enqueueOperation("todo.title", arguments: [SubtaskCommandFixture.title("第一次 #新增")])
        let second = try fixture.enqueueOperation("todo.title", arguments: [SubtaskCommandFixture.title("第二次")])
        _ = try await fixture.publish()
        let host = makeHost(controller, compact: true)
        defer { host.close() }
        try await host.start()
        try await link(host, consumer: first, producer: producer)
        try await link(host, consumer: second, producer: producer)
        try await host.clickCompositionControl("unified.multi.prepare")
        try await host.clickCompositionControl("unified.multi.submit")
        try await settle(host, controller)
        try await host.clickCompositionControl("unified.multi.confirm")
        try await settle(host, controller)
        guard case .taskTitle(let actual) = controller.multiPlan?.pending else { Issue.record("缺少后项真实影响"); return }
        #expect(actual.impact.originalValues[.title] == .text("第一次") && actual.impact.tags.original.count == 1)
        let savedProducer = try #require(controller.settingExecution?.units.first)
        try await host.revealSettingControlInsidePanel("unified.title.field.title")
        try host.snapshot("pm2-branch-current-value")
        var rejected = false
        io.io.titleBeforeTransaction = {
            if !rejected { rejected = true; throw TaskCreateCommandIO.Failure.injected }
        }
        try await host.clickCompositionControl("unified.multi.confirm")
        try await settle(host, controller)
        #expect(controller.settingExecution?.units[2].state == .failed && io.count("saveTitle") == 1)
        try await host.revealSettingControlInsidePanel("unified.multi.retry." + second.id.uuidString)
        try host.snapshot("pm2-consumer-failure")
        try await host.clickCompositionControl("unified.multi.retry." + second.id.uuidString)
        try await settle(host, controller)
        #expect(controller.settingExecution?.units.allSatisfy { $0.state == .succeeded } == true)
        #expect(controller.settingExecution?.units[0] == savedProducer)
        let rows = try io.io.creation.capture.readTodos()
        #expect(rows.count == 1 && rows[0].id == savedProducer.taskCreation?.savedID && rows[0].title == "第二次")
        #expect(io.count("save") == 1 && io.count("saveTitle") == 2 && io.count("ui") == 3)
    }

    @Test func nativeLongBranchListAndStaleReferenceRemainBounded() async throws {
        let io = try MultiPlanOutputFixture()
        let fixture = try makeFixture(io)
        defer { fixture.stop() }
        let controller = fixture.controller!
        let producer = try fixture.enqueueOperation("todo.create", arguments: TaskCreateCommandFixture.arguments("长列表生产者"))
        for index in 0..<11 {
            let consumer = try fixture.enqueueOperation("todo.title", arguments: [SubtaskCommandFixture.title("后续步骤 \(index + 1)")])
            try fixture.handoff.plan(.link(consumer.stamp, .init(results: [.target: .init(producer: producer.stamp, outputType: .todo)])))
            _ = controller.publishOperation(text: "")
        }
        _ = try await fixture.publish()
        let host = makeHost(controller, compact: true)
        defer { host.close() }
        try await host.start()
        let inputFrame = try host.field.frame
        try await host.clickCompositionControl("unified.multi.prepare")
        let last = try #require(controller.plan?.items.last)
        #expect(controller.currentMultiPlanPreview?.identity.references.count == 11)
        try await host.revealSettingControlInsidePanel("unified.multi.preview." + last.id.uuidString)
        #expect(try host.field.frame == inputFrame && io.count("save") == 0)
        try host.snapshot("pm2-long-branch-list")
        try await host.clickCompositionControl("unified.plan.edit." + producer.id.uuidString)
        try fixture.planText(.title, "生产者修订")
        try await host.clickCompositionControl("unified.plan.close")
        try await host.clickCompositionControl("unified.multi.prepare")
        #expect(controller.currentMultiPlanPreview == nil && controller.multiPlanFailure != nil)
        #expect(controller.plan?.items.last?.links.results[.target]?.producer == producer.stamp)
        #expect(io.count("save") == 0 && controller.settingExecution == nil)
        try await host.revealSettingControlInsidePanel("unified.multi.issue")
        try host.snapshot("pm2-stale-reference")
    }

    func makeFixture(_ io: MultiPlanOutputFixture) throws -> UnifiedSearchResultsFixture {
        try .init(QueryBatchFixture.empty("/tasks"), privacyCenter: NotificationCenter(), taskChainIO: io.io,
                  subtaskEnvironment: io.subtaskEnvironment, enableMultiPlan: true, outputCapability: .typedCreation)
    }
    func makeHost(_ controller: UnifiedSearchController, compact: Bool) -> UnifiedSearchTestHost {
        .init(layout: compact ? .compact : .standard, width: compact ? 304 : 444,
              locale: compact ? "zh-Hans" : "en", dark: !compact, results: controller, operations: true)
    }
    func queueChain(_ fixture: UnifiedSearchResultsFixture) throws -> [CommandPlanItem] {
        [try fixture.enqueueOperation("todo.create", arguments: TaskCreateCommandFixture.arguments("父任务")),
         try fixture.enqueueOperation("subtask.create", arguments: [SubtaskCommandFixture.title("子任务")]),
         try fixture.enqueueOperation("subtask.title", arguments: [SubtaskCommandFixture.title("新子标题 #新标签")])]
    }
    func link(_ host: UnifiedSearchTestHost, consumer: CommandPlanItem, producer: CommandPlanItem,
              parameter: CommandParameterID = .target) async throws {
        try await host.clickCompositionControl("unified.plan.edit." + consumer.id.uuidString)
        try await host.clickCompositionControl("unified.plan.reference." + parameter.rawValue + "." + producer.id.uuidString)
        try await host.clickCompositionControl("unified.plan.close")
    }
    func settle(_ host: UnifiedSearchTestHost, _ controller: UnifiedSearchController) async throws {
        await controller.multiPlanTask?.value
        try await host.settle()
    }
}
