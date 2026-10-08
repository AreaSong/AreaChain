import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchTaskTitlePresentationTests {
    @Test(arguments: ["en", "zh-Hans"], [false, true])
    func nativeMinimumWidthLayouts(locale: String, dark: Bool) async throws {
        for compact in [false, true] {
            let fixture = try UnifiedSearchTaskTitleFixture()
            defer { fixture.stop() }
            try await fixture.start("Synthetic long title 合成标题 #新建普通标签 #恢复 !p1 @09:30")
            let host = try await fixture.host(layout: compact ? .compact : .standard,
                width: compact ? 304 : 444, locale: locale, dark: dark)
            defer { host.close() }
            try await host.clickCompositionControl("unified.objects.choose.target")
            await fixture.controller.objectSelectionTask?.value
            try await host.settle()
            try host.snapshot("title-target-\(locale)-\(dark)-\(compact)")
            try await host.clickCompositionControl("unified.objects.cancel")
            try await host.clickCompositionControl("unified.title.prepare")
            #expect(fixture.controller.currentTaskTitlePreview?.impact.tags.associations.count == 2)
            try await host.revealSettingControlInsidePanel("unified.title.field.title")
            try host.snapshot("title-preview-\(locale)-\(dark)-\(compact)")
            try await host.revealSettingControlInsidePanel("unified.title.finalTags")
            try host.snapshot("title-tags-\(locale)-\(dark)-\(compact)")
            try await host.revealSettingControlInsidePanel("unified.title.field.remindMinutes")
            try host.snapshot("title-fields-\(locale)-\(dark)-\(compact)")
            try await host.clickCompositionControl("unified.title.disclosure")
            let summary = try host.resultNode("unified.title.tagSummary")
            try await host.revealCompositionControl(summary)
            try SettingsButtonTestSupport.assertBounds([summary], in: host.window)
            try host.snapshot("title-collapsed-\(locale)-\(dark)-\(compact)")
            try fixture.noWrites()
        }
    }

    @Test(arguments: ["修改 // 备注", "修改\n第二行"])
    func nativeUnsupportedTextStaysVisible(text: String) async throws {
        let fixture = try UnifiedSearchTaskTitleFixture()
        defer { fixture.stop() }
        try await fixture.start()
        let host = try await fixture.host(width: 444)
        defer { host.close() }
        let editor = try await host.focusParameter(.title)
        editor.insertText(text, replacementRange: .init(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        #expect(editor.string == text)
        let draftID = try #require(fixture.controller.editingDraft?.id)
        let newline = text.contains("\n")
        #expect(fixture.controller.editingDraft?.arguments.first?.value == (newline ? nil : .shortText(text)))
        #expect(fixture.controller.parameterText[draftID]?[.title]?.text == text)
        try await host.clickCompositionControl("unified.title.prepare")
        #expect(fixture.controller.taskTitleFailure == (newline ? "unified.title.input" : "unified.title.notes"))
        #expect(fixture.controller.parameterText[draftID]?[.title]?.text == text)
        if newline { #expect(fixture.controller.editingDraft?.id == draftID) }
        else { #expect(fixture.controller.plan?.items.first?.draft.arguments.first?.value == .shortText(text)) }
        try fixture.noWrites()
        try await host.revealSettingControlInsidePanel("unified.title.issue")
        try host.snapshot(text.contains("\n") ? "title-newline-refused" : "title-notes-refused")
    }
}
