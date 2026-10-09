import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchMultiPlanLifecycleTests {
    @Test func lostDisplayRequiresNewRealReviewAndAcceptanceBeforeRemainingUnits() async throws {
        let fields = try TaskFieldCommandFixture()
        fields.io.notificationResult = .succeeded
        fields.io.calendarResult = .succeeded
        let fixture = try UnifiedSearchResultsFixture(QueryBatchFixture.empty("/tasks"), privacyCenter: NotificationCenter(),
            taskFieldEnvironment: fields.environment, enableMultiPlan: true)
        defer { fixture.stop() }
        let controller = fixture.controller!
        try UnifiedSearchMultiPlanTests().queueFields(fixture, fields: fields)
        _ = try await fixture.publish()
        let host = UnifiedSearchTestHost(layout: .standard, width: 444, locale: "zh-Hans", dark: true,
                                         results: controller, operations: true)
        defer { host.close() }
        try await host.start()
        try await host.clickCompositionControl("unified.multi.prepare")
        let old = controller.buffer
        fields.io.onRefresh = { try fixture.session.loseFocus(expecting: old.lease.ownership) }
        try await host.clickCompositionControl("unified.multi.submit")
        await controller.multiPlanTask?.value
        #expect(!controller.operationVisible && controller.multiPlan?.requiresDisplayReview == true)
        let before = try #require(controller.settingExecution)
        #expect(before.units[0].local == .committed && before.units[1].attempt == 0 && fields.count("save") == 1)
        fields.io.onRefresh = nil
        try fixture.session.resumeDisplay(expecting: controller.buffer.lease)
        controller.refreshOperationPresentation()
        try await host.settle()
        controller.requestOperationSubmit(old)
        #expect(fields.count("save") == 1 && controller.settingExecution == before)
        try await host.clickCompositionControl("unified.multi.reviewRemaining")
        #expect(controller.multiPlan?.pending != nil && fields.count("save") == 1)
        try await host.revealSettingControlInsidePanel("unified.multi.confirm")
        try host.snapshot("pm1-display-new-acceptance")
        try await host.clickCompositionControl("unified.multi.confirm")
        await controller.multiPlanTask?.value
        try await host.settle()
        #expect(controller.settingExecution?.units.allSatisfy { $0.state == .succeeded } == true)
        #expect(controller.settingExecution?.units[0] == before.units[0] && fields.count("save") == 3)
    }

    @Test func cancellingUnstartedUnitKeepsSavedResultAndFrozenContent() async throws {
        let fields = try TaskFieldCommandFixture()
        fields.io.notificationResult = .succeeded
        fields.io.calendarResult = .succeeded
        let fixture = try UnifiedSearchResultsFixture(QueryBatchFixture.empty("/tasks"), privacyCenter: NotificationCenter(),
            taskFieldEnvironment: fields.environment, enableMultiPlan: true)
        defer { fixture.stop() }
        let controller = fixture.controller!
        try UnifiedSearchMultiPlanTests().queueFields(fixture, fields: fields)
        _ = try await fixture.publish()
        let host = UnifiedSearchTestHost(layout: .compact, width: 304, locale: "en", dark: false,
                                         results: controller, operations: true)
        defer { host.close() }
        try await host.start()
        try await host.clickCompositionControl("unified.multi.prepare")
        let adapter = try #require(controller.multiPlan)
        try adapter.submit(#require(controller.currentMultiPlanPreview), expecting: controller.buffer.lease,
                           displaySession: fixture.session, maximumUnits: 1)
        _ = controller.publishOperation(text: "")
        try await host.settle()
        let before = try #require(controller.settingExecution)
        try await host.clickCompositionControl("unified.multi.cancel." + before.units[1].id.uuidString)
        let cancelled = try #require(controller.settingExecution)
        #expect(cancelled.units[1].state == .notExecuted && cancelled.units[1].attempt == 0)
        #expect(cancelled.snapshot == before.snapshot && cancelled.units[0] == before.units[0])
        try await host.clickCompositionControl("unified.multi.resume")
        await controller.multiPlanTask?.value
        #expect(fields.count("save") == 2 && fields.base.todo.isImportant && !fields.base.todo.isUrgent)
        #expect(fields.base.todo.remindMinutes == 570)
        try await host.revealSettingControlInsidePanel("unified.multi.unit." + before.units[1].id.uuidString)
        try host.snapshot("pm1-cancel-unstarted")
    }
}
