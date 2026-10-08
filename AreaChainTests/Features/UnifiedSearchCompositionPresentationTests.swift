import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchCompositionPresentationTests {
    @Test(arguments: ["en", "zh-Hans"], [false, true])
    func nativeRepresentativeLayouts(locale: String, dark: Bool) async throws {
        for compact in [false, true] {
            let fixture = try UnifiedSearchTaskCreateFixture(capability: .ordinaryComposition)
            defer { fixture.stop() }
            _ = try fixture.seedTag("A long ordinary label 合成普通标签")
            _ = try fixture.seedTag("restore", deleted: true)
            try fixture.start(title: "Synthetic title #new #restore !p2 @09:30")
            let host = try await fixture.host(layout: compact ? .compact : .standard,
                width: compact ? 304 : 444, locale: locale, dark: dark)
            defer { host.close() }
            try await host.clickCompositionControl("unified.tags.choose")
            try host.snapshot("composition-tags-\(locale)-\(dark)-\(compact)")
            try await host.clickCompositionControl("unified.tags.cancel")
            try await host.clickCompositionControl("unified.operation.disclosure")
            try host.snapshot("composition-attributes-\(locale)-\(dark)-\(compact)")
            try await host.clickCompositionControl("unified.task.prepare")
            let preview = try #require(fixture.controller.currentTaskComposition)
            #expect(preview.composition.tags.final.count == 2)
            try await host.revealSettingControlInsidePanel("unified.composition.tagSummary")
            try host.snapshot("composition-effects-\(locale)-\(dark)-\(compact)")
            try await host.clickCompositionControl("unified.composition.disclosure")
            let summary = try host.resultNode("unified.composition.tagSummary")
            try SettingsButtonTestSupport.assertBounds([summary], in: host.window)
            try host.snapshot("composition-collapsed-\(locale)-\(dark)-\(compact)")
            try fixture.noCompositionWrites()
        }
    }

    @Test func nativeClearCancelAndMetadataTaskUseFinalServiceValues() async throws {
        let fixture = try UnifiedSearchTaskCreateFixture(capability: .ordinaryComposition)
        defer { fixture.stop() }
        try fixture.start(title: "#new")
        let host = try await fixture.host(width: 444)
        defer { host.close() }
        try await host.compositionMode(.priority, .clear, fixture: fixture)
        try await host.compositionMode(.time, .cancelReminder, fixture: fixture)
        let accepted = try await host.prepareAndAcceptComposition(fixture)
        #expect(accepted.preview?.composition.title == "")
        #expect(accepted.preview?.composition.priority.explicit == .clear)
        #expect(accepted.preview?.composition.reminder.explicit == .clear)
        try await host.clickCompositionControl("unified.task.create")
        let task = try #require(fixture.io.capture.readTodos().first)
        #expect(task.title.isEmpty && task.remindMinutes == nil && !task.isImportant && !task.isUrgent)
        #expect(fixture.count("save") == 1 && fixture.io.capture.authorizations.isEmpty)
    }
}
