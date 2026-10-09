import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchMultiPlanPresentationTests {
    @Test(arguments: [false, true]) func longPlanAndIncompleteLastItemRemainBounded(incomplete: Bool) async throws {
        let creation = try TaskCreateCommandIO()
        let fixture = try UnifiedSearchResultsFixture(QueryBatchFixture.empty("/tasks"),
            taskCreateEnvironment: creation.environment(), privacyCenter: NotificationCenter(), enableMultiPlan: true)
        defer { fixture.stop() }
        let controller = fixture.controller!
        for index in 0..<12 {
            var arguments = TaskCreateCommandFixture.arguments("合成计划第\(index + 1)项 Long ordinary task \(index + 1)")
            if incomplete && index == 11 { arguments.removeAll { $0.parameter == .day } }
            try fixture.handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source,
                                            commandID: .init(rawValue: "todo.create"), arguments: arguments))
        }
        _ = controller.publishOperation(text: "")
        _ = try await fixture.publish()
        let host = UnifiedSearchTestHost(layout: incomplete ? .compact : .standard, width: incomplete ? 304 : 444,
            locale: incomplete ? "zh-Hans" : "en", dark: !incomplete, results: controller, operations: true)
        defer { host.close() }
        try await host.start()
        let input = try host.field.frame
        try await host.clickCompositionControl("unified.multi.prepare")
        let last = try #require(controller.plan?.items.last)
        if incomplete {
            #expect(controller.currentMultiPlanPreview == nil && controller.multiPlanFailure != nil)
            try await host.revealSettingControlInsidePanel("unified.multi.issue")
        } else {
            #expect(controller.currentMultiPlanPreview?.members.count == 12)
            try await host.revealSettingControlInsidePanel("unified.multi.preview." + last.id.uuidString)
        }
        #expect(try host.field.frame == input)
        #expect(try creation.capture.readTodos().isEmpty)
        #expect(controller.plan?.items.count == 12 && controller.settingExecution == nil)
        try host.snapshot("pm1-long-plan-\(incomplete)")
    }
}
