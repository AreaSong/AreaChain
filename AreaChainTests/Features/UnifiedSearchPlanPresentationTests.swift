import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchPlanPresentationTests {
    @Test func longPlanScrollsInsideBothHostsInBothLanguagesAndThemes() async throws {
        for layout in UnifiedSearchInputLayout.allCases {
            for locale in ["en", "zh-Hans"] {
                for dark in [false, true] {
                    for minimum in [false, true] {
                        let fixture = try UnifiedSearchResultsFixture()
                        defer { fixture.stop() }
                        var ids: [UUID] = []
                        for _ in 0..<12 { ids.append(try fixture.enqueueOperation("setting.language").id) }
                        let width = minimum ? layout.minimumWidth + 24 : (layout == .standard ? 620 : 380)
                        let host = UnifiedSearchTestHost(layout: layout, width: width, locale: locale, dark: dark,
                                                         results: fixture.controller, operations: true)
                        defer { host.close() }
                        try await host.start()
                        let field = try host.field
                        let anchor = field.convert(field.bounds, to: nil)
                        try host.snapshot("plan-list-\(layout)-\(locale)-\(dark)-\(minimum)")
                        let last = try host.resultNode("unified.plan.edit." + ids.last!.uuidString)
                        try await SettingsButtonTestSupport.reveal(last, in: host.window)
                        try await SettingsButtonTestSupport.click(last, in: host.window)
                        #expect(fixture.controller.plan?.editing == ids.last)
                        #expect(field.convert(field.bounds, to: nil) == anchor)
                        try await SettingsButtonTestSupport.reveal(try host.resultNode("unified.parameter.value"), in: host.window)
                        try host.snapshot("plan-expanded-\(layout)-\(locale)-\(dark)-\(minimum)")
                        #expect(fixture.controller.plan?.items.count == 12)
                    }
                }
            }
        }
    }

    @Test func nativeCreationReferenceChoiceAndUnlink() async throws {
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        let parent = try fixture.enqueueOperation("todo.create")
        let child = try fixture.enqueueOperation("subtask.create")
        fixture.controller.beginPlanEditing(child.stamp, source: fixture.controller.buffer)
        let host = UnifiedSearchTestHost(layout: .compact, width: 304, locale: "zh-Hans", dark: true,
                                         results: fixture.controller, operations: true)
        defer { host.close() }
        try await host.start()
        try await host.clickResult("unified.plan.reference.parent." + parent.id.uuidString)
        #expect(try fixture.planItem(child.id).links.results[.parent]?.producer == parent.stamp)
        #expect(try fixture.planItem(child.id).draft.arguments.isEmpty)
        try host.snapshot("plan-output-reference")
        try await host.clickResult("unified.plan.reference.remove.parent")
        #expect(try fixture.planItem(child.id).links.results.isEmpty)
    }
}
