import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchMultiPlanCompositionTests {
    @Test func nativeBatchAndExplicitSettingsGroupCommitSeparately() async throws {
        let batch = try BatchCommandFixture()
        let settings = try FileSettingCommandFixture()
        let fixture = try UnifiedSearchResultsFixture(QueryBatchFixture.empty("/tasks"), filePreferences: settings.prefs,
            privacyCenter: NotificationCenter(), batchEnvironment: batch.environment, enableMultiPlan: true)
        defer { fixture.stop() }
        let controller = fixture.controller!
        try fixture.handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source, commandID: .init(rawValue: "batch.move"),
            targets: .init(.selected, objects: batch.taskTargets), arguments: [batch.move]))
        for path in FileSettingCommandFixture.paths.prefix(2) {
            let parsed = CommandPathParser().parse(.init(text: path))
            try fixture.handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source,
                commandID: #require(parsed.command?.id), arguments: parsed.arguments))
        }
        _ = controller.publishOperation(text: "")
        _ = try await fixture.publish()
        let host = UnifiedSearchTestHost(layout: .standard, width: 444, locale: "zh-Hans", dark: false,
                                         results: controller, operations: true)
        defer { host.close() }
        try await host.start()
        let firstSetting = try #require(controller.plan?.items[1])
        try await host.clickCompositionControl("unified.multi.group." + firstSetting.id.uuidString)
        let plan = try #require(controller.plan)
        #expect(plan.items[1].atomicGroup != nil && plan.items[1].atomicGroup == plan.items[2].atomicGroup)
        try await host.clickCompositionControl("unified.multi.prepare")
        #expect(batch.count("save") == 0 && settings.store.metrics.snapshot().commits == 0)
        try await host.revealSettingControlInsidePanel("unified.multi.preview." + plan.items[0].id.uuidString)
        try host.snapshot("pm1-batch-group-preview")
        try await host.revealSettingControlInsidePanel("unified.multi.preview." + firstSetting.id.uuidString)
        try host.snapshot("pm1-file-group-preview")
        try await host.clickCompositionControl("unified.multi.submit")
        await controller.multiPlanTask?.value
        try await host.settle()
        let run = try #require(controller.settingExecution)
        #expect(run.units.count == 2 && run.units.allSatisfy { $0.state == .succeeded })
        #expect(run.units[0].batch?.targets == .init(.selected, objects: batch.taskTargets))
        #expect(batch.todos.allSatisfy { $0.dayKey == "2026-10-09" })
        #expect(batch.count("save") == 1 && batch.count("ui") == 1)
        #expect(batch.refreshTargets.count == 2)
        #expect(settings.store.metrics.snapshot().commits == 1 && settings.store.metrics.snapshot().replacements == 1)
        #expect(settings.prefs.language == .english && settings.prefs.appearance == .dark)
        try await host.revealSettingControlInsidePanel("unified.multi.unit." + run.units[1].id.uuidString)
        try host.snapshot("pm1-batch-group-saved")
    }

    @Test func nativeLargerCreationChainFailureAndRetryKeepBothCreatedIdentities() async throws {
        let io = try TaskChainCommandIO()
        let fixture = try UnifiedSearchResultsFixture(QueryBatchFixture.empty("/tasks"), privacyCenter: NotificationCenter(),
                                                       taskChainIO: io, enableMultiPlan: true)
        defer { fixture.stop() }
        let controller = fixture.controller!
        let producer = try fixture.enqueueOperation("todo.create", arguments: TaskCreateCommandFixture.arguments("第一项"))
        let consumer = try fixture.enqueueOperation("todo.title", arguments: [SubtaskCommandFixture.title("真实消费者 #新增 !p3")])
        _ = try fixture.enqueueOperation("todo.create", arguments: TaskCreateCommandFixture.arguments("独立项"))
        _ = try await fixture.publish()
        let host = UnifiedSearchTestHost(layout: .compact, width: 304, locale: "zh-Hans", dark: false,
                                         results: controller, operations: true)
        defer { host.close() }
        try await host.start()
        try await host.clickCompositionControl("unified.plan.edit." + consumer.id.uuidString)
        try await host.clickCompositionControl("unified.plan.reference.target." + producer.id.uuidString)
        try await host.clickCompositionControl("unified.plan.close")
        try await host.clickCompositionControl("unified.multi.prepare")
        try await host.clickCompositionControl("unified.multi.submit")
        await controller.multiPlanTask?.value
        try await host.settle()
        let firstRun = try #require(controller.settingExecution)
        let firstID = try #require(firstRun.units[0].taskCreation?.savedID)
        #expect(firstRun.units[1].attempt == 0 && firstRun.units[2].attempt == 0)
        guard case .taskTitle(let actual) = controller.multiPlan?.pending else { Issue.record("缺少真实目标预览"); return }
        #expect(actual.impact.target.id == firstID && actual.impact.originalValues[.title] == .text("第一项"))
        #expect(try io.creation.capture.readTodos().count == 1)
        try await host.revealSettingControlInsidePanel("unified.title.field.title")
        try host.snapshot("pm1-created-target-preview")
        try await host.revealSettingControlInsidePanel("unified.multi.confirm")
        try host.snapshot("pm1-created-real-confirmation")
        var validations = 0
        io.titleBeforeTransaction = {
            validations += 1
            if validations == 1 { throw TaskCreateCommandIO.Failure.injected }
        }
        try await host.clickCompositionControl("unified.multi.confirm")
        await controller.multiPlanTask?.value
        try await host.settle()
        let failedRun = try #require(controller.settingExecution)
        #expect(failedRun.units[1].state == .failed && failedRun.units[2].state == .succeeded)
        let secondID = try #require(failedRun.units[2].taskCreation?.savedID)
        let createdCount = try io.creation.capture.readTodos().count
        #expect(firstID != secondID && createdCount == 2)
        try await host.clickCompositionControl("unified.multi.retry." + consumer.id.uuidString)
        await controller.multiPlanTask?.value
        try await host.settle()
        let run = try #require(controller.settingExecution)
        #expect(run.units.allSatisfy { $0.state == .succeeded })
        #expect(run.units[0] == failedRun.units[0] && run.units[2] == failedRun.units[2])
        let rows = try io.creation.capture.readTodos()
        #expect(rows.count == 2 && Set(rows.map(\.id)) == [firstID, secondID])
        #expect(rows.first(where: { $0.id == firstID })?.title == "真实消费者")
        #expect(io.creation.capture.trace.filter { $0 == "save" }.count == 2)
        #expect(io.creation.capture.trace.filter { $0 == "saveTitle" }.count == 1)
        #expect(io.creation.capture.trace.filter { $0 == "ui" }.count == 3)
        try await host.revealSettingControlInsidePanel("unified.multi.unit." + consumer.id.uuidString)
        try host.snapshot("pm1-created-retried-saved")
    }
}
