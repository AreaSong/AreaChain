import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchTaskCreateInteractionTests {
    @Test(arguments: [false, true]) func nativeCompletionTitleDayPlanAndRealSave(commandReturn: Bool) async throws {
        let fixture = try UnifiedSearchTaskCreateFixture()
        defer { fixture.stop() }
        let host = try await fixture.host()
        defer { host.close() }
        (try host.editor).insertText("/tasks/a", replacementRange: (try host.editor).selectedRange())
        try await host.settle()
        let state = try host.state
        let completion = try #require(state.completion)
        let candidate = try #require(completion.result.candidates.first { $0.command.id.rawValue == "todo.create" })
        state.suggestions.selectedIndex = try #require(completion.result.candidates.firstIndex(of: candidate))
        try await host.key(48, "\t")
        let draftID = try #require(fixture.controller.operations?.active?.id)
        let editor = try await host.focusParameter(.title)
        editor.insertText("Native synthetic task", replacementRange: editor.selectedRange())
        try await host.settle()
        try await host.key(36, "\r")
        #expect(fixture.count("save") == 0)
        try await host.clickResult("unified.parameter.date")
        #expect(fixture.controller.operations?.active?.arguments.contains { $0.parameter == .day } == false)
        try await host.revealSettingControlInsidePanel("daybook.datePicker")
        try await host.settle()
        let day = DayKey.today()
        try await host.clickResult("daybook.date." + day)
        #expect(fixture.controller.operations?.active?.arguments.first { $0.parameter == .day }?.value == .day(day))
        try await host.clickResult("unified.plan.enqueue")
        #expect(fixture.controller.operations?.active == nil && fixture.controller.plan?.items.first?.draft.id == draftID)
        try await host.clickResult("unified.task.prepare")
        let prepared = try #require(fixture.controller.currentTaskPreparation)
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0)
        try host.snapshot("task-create-prepared-\(commandReturn)")
        let old = fixture.controller.buffer
        if commandReturn {
            host.window.makeFirstResponder(try host.field)
            try await host.settle()
            try await host.key(53, "\u{1b}")
            try await host.key(36, "\r", flags: .command)
        } else { try await host.clickResult("unified.task.create") }
        #expect(try fixture.facts.state == .saved && fixture.facts.savedID == prepared.creationID)
        let rows = try fixture.io.capture.readTodos()
        #expect(rows.count == 1 && rows.first?.id == prepared.creationID)
        #expect(rows.first?.title == "Native synthetic task" && rows.first?.dayKey == day)
        #expect(rows.first?.sourceBundleID == prepared.source.bundleID)
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 1)
        #expect(fixture.count("calendarRefresh") == 1 && fixture.count("reminderRefresh") == 1)
        #expect(!state.accept(candidate, source: completion))
        fixture.controller.requestOperationSubmit(old)
        try await host.key(36, "\r", flags: .command)
        #expect(try fixture.io.capture.readTodos().count == 1 && fixture.count("save") == 1)
        try await host.revealSettingControlInsidePanel("unified.task.status")
        let node = try host.resultNode("unified.task.status")
        #expect(SettingsButtonTestSupport.value(node, "accessibilityValue") as? String == "Task created")
        try host.snapshot("task-create-saved-\(commandReturn)")
    }

    @Test func markedTextBlocksButtonEntryAndShortcut() async throws {
        let fixture = try UnifiedSearchTaskCreateFixture()
        defer { fixture.stop() }
        try fixture.start()
        let host = try await fixture.host()
        defer { host.close() }
        let editor = try await host.focusParameter(.title)
        editor.setMarkedText("合成", selectedRange: NSRange(location: 2, length: 0), replacementRange: editor.selectedRange())
        fixture.submit()
        try await host.key(36, "\r", flags: .command)
        #expect(fixture.count("save") == 0 && fixture.controller.settingExecution == nil)
        #expect(editor.hasMarkedText())
        editor.unmarkText()
    }

    @Test(arguments: ["en", "zh-Hans"], [false, true])
    func nativePresentationVariants(locale: String, dark: Bool) async throws {
        for compact in [false, true] {
            let fixture = try UnifiedSearchTaskCreateFixture()
            defer { fixture.stop() }
            try fixture.start(title: "Synthetic plain title 合成普通标题")
            let host = try await fixture.host(layout: compact ? .compact : .standard,
                width: compact ? 304 : 444, locale: locale, dark: dark)
            defer { host.close() }
            try await host.clickResult("unified.plan.enqueue")
            try await host.clickResult("unified.task.prepare")
            try await host.revealSettingControlInsidePanel("unified.task.create")
            try host.snapshot("task-create-\(locale)-\(dark)-\(compact)")
            #expect(fixture.count("save") == 0)
        }
    }
}
