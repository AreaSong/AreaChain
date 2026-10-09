import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchMultiPlanTests {
    @Test(arguments: [false, true]) func nativeSequentialFailureAndRetry(fails: Bool) async throws {
        let fields = try TaskFieldCommandFixture()
        fields.io.notificationResult = .succeeded
        fields.io.calendarResult = .succeeded
        let fixture = try UnifiedSearchResultsFixture(QueryBatchFixture.empty("/tasks"), privacyCenter: NotificationCenter(),
            taskFieldEnvironment: fields.environment, enableMultiPlan: true)
        defer { fixture.stop() }
        let controller = fixture.controller!
        try queueFields(fixture, fields: fields)
        let items = try #require(controller.plan?.items)
        if fails { controller.addPredecessor(items[0].id, item: items[1].stamp, source: controller.buffer) }
        _ = try await fixture.publish()
        let host = UnifiedSearchTestHost(layout: fails ? .compact : .standard, width: fails ? 304 : 444,
            locale: fails ? "zh-Hans" : "en", dark: fails, results: controller, operations: true)
        defer { host.close() }
        try await host.start()
        try await host.clickCompositionControl("unified.multi.prepare")
        #expect(fields.count("save") == 0)
        try await host.revealSettingControlInsidePanel("unified.multi.preview." + items[0].id.uuidString)
        try host.snapshot("pm1-fields-preview-\(fails)")
        var validationCalls = 0
        if fails {
            fields.io.beforeTransaction = {
                validationCalls += 1
                if validationCalls == 1 { throw TaskCreateCommandIO.Failure.injected }
            }
        }
        if fails { try await host.clickCompositionControl("unified.multi.submit") }
        else {
            host.window.makeFirstResponder(try host.field)
            try await host.settle()
            try await host.key(36, "\r", flags: .command)
        }
        await controller.multiPlanTask?.value
        try await host.settle()
        let initial = try #require(controller.settingExecution)
        if fails {
            #expect(initial.units[0].state == .failed && initial.units[1].state == .blocked)
            #expect(initial.units[2].state == .succeeded && fields.count("save") == 1)
            try await host.revealSettingControlInsidePanel("unified.multi.retry." + items[0].id.uuidString)
            try host.snapshot("pm1-failure-retained")
            try await host.clickCompositionControl("unified.multi.retry." + items[0].id.uuidString)
            await controller.multiPlanTask?.value
            try await host.settle()
            #expect(controller.settingExecution?.units[2] == initial.units[2])
            #expect(controller.settingExecution?.units[0].history.first?.taskField?.state == .notSubmitted)
        }
        #expect(controller.settingExecution?.units.allSatisfy { $0.state == .succeeded } == true)
        #expect(fields.base.todo.dayKey == "2026-10-09" && fields.base.todo.remindMinutes == 570)
        #expect(!fields.base.todo.isImportant && fields.base.todo.isUrgent)
        #expect(fields.count("save") == 3 && fields.count("ui") == 3)
        #expect(fields.io.notificationProcessed == 3 && fields.io.calendarProcessed == 3)
        try await host.revealSettingControlInsidePanel("unified.multi.progress")
        try host.snapshot("pm1-fields-saved-\(fails)")
    }

    @Test func nativeUnknownAndMarkedTextCannotRestartPlan() async throws {
        let fields = try TaskFieldCommandFixture()
        fields.io.notificationResult = .succeeded
        fields.io.calendarResult = .succeeded
        let privacy = NotificationCenter()
        let fixture = try UnifiedSearchResultsFixture(QueryBatchFixture.empty("/tasks"), privacyCenter: privacy,
            taskFieldEnvironment: fields.environment, enableMultiPlan: true)
        defer { fixture.stop() }
        let controller = fixture.controller!
        try queueFields(fixture, fields: fields)
        _ = try await fixture.publish()
        let host = UnifiedSearchTestHost(layout: .compact, width: 304, locale: "en", dark: true,
                                         results: controller, operations: true)
        defer { host.close() }
        try await host.start()
        let editor = try host.editor
        editor.setMarkedText("组合", selectedRange: .init(location: 2, length: 0), replacementRange: editor.selectedRange())
        controller.prepareMultiPlan(controller.buffer)
        try await host.key(36, "\r", flags: .command)
        #expect(controller.multiPlan?.preview == nil && fields.count("save") == 0)
        editor.unmarkText()
        try await host.clickCompositionControl("unified.multi.prepare")
        fields.io.beforeTransaction = { if fields.count("save") == 1 { fields.io.saveMode = .throwAfter } }
        let old = controller.buffer
        try await host.clickCompositionControl("unified.multi.submit")
        await controller.multiPlanTask?.value
        try await host.settle()
        let run = try #require(controller.settingExecution)
        #expect(run.hasUnknownCommit && run.units[0].state == .succeeded && run.units[2].attempt == 0)
        #expect(fields.count("save") == 2 && fields.count("ui") == 1)
        try await host.revealSettingControlInsidePanel("unified.multi.paused")
        try host.snapshot("pm1-unknown-paused")
        try await host.revealSettingControlInsidePanel("unified.multi.unit." + run.units[2].id.uuidString)
        try host.snapshot("pm1-unknown-retained")
        controller.operationExpanded = false
        controller.requestOperationSubmit(old)
        controller.requestOperationSubmit(controller.buffer)
        privacy.post(name: .privacyWillLock, object: fixture.vault)
        controller.requestOperationSubmit(controller.buffer)
        #expect(controller.settingExecution == run && fields.count("save") == 2)
    }

    func queueFields(_ fixture: UnifiedSearchResultsFixture, fields: TaskFieldCommandFixture) throws {
        for kind in 0..<3 {
            try fixture.handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source,
                commandID: .init(rawValue: TaskFieldCommandFixture.command(kind)),
                targets: .init(.single, objects: [.init(type: .todo, id: fields.base.todo.id)]),
                arguments: [TaskFieldCommandFixture.argument(kind)]))
        }
        _ = fixture.controller.publishOperation(text: "")
    }
}
