import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchCompositionInteractionTests {
    @Test(arguments: [false, true]) func nativeExtendedCreation(commandReturn: Bool) async throws {
        let fixture = try UnifiedSearchTaskCreateFixture(capability: .ordinaryComposition)
        defer { fixture.stop() }
        let live = try fixture.seedTag("live")
        let restored = try fixture.seedTag("restore", deleted: true)
        let host = try await fixture.host()
        defer { host.close() }
        (try host.editor).insertText("/tasks/a", replacementRange: (try host.editor).selectedRange())
        try await host.settle()
        try await host.key(48, "\t")
        let editor = try await host.focusParameter(.title)
        editor.insertText("Native #new #restore !p1 @09:30", replacementRange: editor.selectedRange())
        try await host.settle()
        try await host.key(36, "\r")
        try fixture.noCompositionWrites()
        try await host.clickCompositionControl("unified.parameter.date")
        try await host.revealTaskDatePicker()
        try await host.clickCompositionControl("daybook.date." + DayKey.today())
        try await host.compositionMode(.priority, .assign, fixture: fixture)
        let priority = try await host.compositionPicker("unified.parameter.choice.priority")
        try await PickerNativeTestSupport.keyboardSelection(priority, moveDown: true, in: host.window)
        #expect(fixture.controller.editingDraft?.arguments.first { $0.parameter == .priority }?.value == .choice("p1"))
        try await host.compositionMode(.time, .setReminder, fixture: fixture)
        let time = try TimePickerNativeTestSupport.picker(in: host.window)
        try await SettingsButtonTestSupport.reveal(time, in: host.window)
        let calendar = try #require(time.calendar)
        let timeFrame = time.convert(time.bounds, to: nil)
        try await TimePickerNativeTestSupport.click(.init(x: timeFrame.minX + 10, y: timeFrame.midY), in: host.window)
        time.dateValue = try #require(DaybookTimePresentation(calendar: calendar).date(570))
        time.sendAction(time.action, to: time.target)
        try await host.settle()
        #expect(fixture.controller.editingDraft?.arguments.first { $0.parameter == .time }?.value == .time(570))
        try await host.clickCompositionControl("unified.tags.choose")
        try await host.clickCompositionControl("unified.tags.row." + live.id.uuidString)
        #expect(fixture.controller.editingDraft?.arguments.contains { $0.parameter == .tags } == false)
        try await host.clickCompositionControl("unified.tags.accept")
        #expect(fixture.controller.editingDraft?.targets == CommandDraftTargets.none)
        #expect(fixture.controller.editingDraft?.arguments.first { $0.parameter == .tags }?.value == .tags([live.id]))
        let accepted = try await host.prepareAndAcceptComposition(fixture)
        let preview = try #require(accepted.preview)
        #expect(preview.composition.priority.value == PriorityFlags(isImportant: true, isUrgent: true))
        #expect(preview.composition.reminder.value == 570)
        #expect(preview.composition.tags.final.map(\.effect) == [.createAndAssociate, .restoreAndAssociate, .associateLive])
        try await host.revealSettingControlInsidePanel("unified.composition.tagSummary")
        try host.snapshot("composition-native-prepared-\(commandReturn)")
        let old = fixture.controller.buffer
        if commandReturn {
            host.window.makeFirstResponder(try host.field)
            try await host.settle()
            try await host.key(53, "\u{1b}")
            try await host.key(36, "\r", flags: .command)
        } else { try await host.clickCompositionControl("unified.task.create") }
        let facts = try fixture.facts
        #expect(facts.state == .saved && facts.savedID == accepted.creationID)
        #expect(facts.savedTagEffects == [.createAndAssociate, .restoreAndAssociate, .associateLive])
        let rows = try fixture.io.capture.readTodos()
        let task = try #require(rows.first)
        #expect(rows.count == 1 && task.title == "Native" && task.dayKey == DayKey.today())
        #expect(task.remindMinutes == 570 && task.isImportant && task.isUrgent && task.notes.isEmpty)
        #expect(TagIDList.parse(task.tagIDs) == [try #require(accepted.tagCreationIDs["new"]), restored.id, live.id])
        #expect(try fixture.readTags().count == 3 && restored.deletedAt == nil)
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 1)
        #expect(fixture.io.capture.authorizations == [570])
        #expect(facts.authorizationRequest == .returned && facts.authorizationResult == .unknown)
        #expect(fixture.count("reminderRefresh") == 1 && fixture.count("calendarRefresh") == 1)
        fixture.controller.requestOperationSubmit(old)
        try await host.key(36, "\r", flags: .command)
        #expect(fixture.count("save") == 1 && fixture.controller.settingExecution?.outputs.count == 1)
        try await host.revealSettingControlInsidePanel("unified.task.status")
        try host.snapshot("composition-native-saved-\(commandReturn)")
    }

    @Test(arguments: [CommandFieldOperation.add, .remove, .replaceAll, .clear, .unspecified])
    func nativeTagModesPreserveFinalOrder(mode: CommandFieldOperation) async throws {
        let fixture = try UnifiedSearchTaskCreateFixture(capability: .ordinaryComposition)
        defer { fixture.stop() }
        let first = try fixture.seedTag("first")
        let second = try fixture.seedTag("second")
        let restored = try fixture.seedTag("restore", deleted: true)
        try fixture.start(title: "Task #first #new #restore")
        let host = try await fixture.host()
        defer { host.close() }
        try await host.compositionMode(.tags, mode, fixture: fixture)
        if mode.requiresValue {
            try await host.clickCompositionControl("unified.tags.choose")
            let ids = mode == .remove ? [restored.id] : [second.id, first.id]
            for id in ids { try await host.clickCompositionControl("unified.tags.row." + id.uuidString) }
            try await host.clickCompositionControl("unified.tags.accept")
        }
        let accepted = try await host.prepareAndAcceptComposition(fixture)
        try await host.clickCompositionControl("unified.task.create")
        let task = try #require(fixture.io.capture.readTodos().first)
        let new = accepted.tagCreationIDs["new"]
        let expected: [UUID]
        switch mode {
        case .add: expected = [first.id, try #require(new), restored.id, second.id]
        case .remove: expected = [first.id, try #require(new)]
        case .replaceAll: expected = [second.id, first.id]
        case .clear: expected = []
        default: expected = [first.id, try #require(new), restored.id]
        }
        #expect(TagIDList.parse(task.tagIDs) == expected)
        #expect((restored.deletedAt == nil) == (mode == .add || mode == .unspecified))
        #expect(try fixture.readTags().count == (mode == .clear || mode == .replaceAll ? 3 : 4))
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 1)
    }

    @Test func nativeTagCancelQueryAndKeyboardSelection() async throws {
        let fixture = try UnifiedSearchTaskCreateFixture(capability: .ordinaryComposition)
        defer { fixture.stop() }
        let live = try fixture.seedTag("ordinary")
        _ = try fixture.seedTag("hidden", privateTag: true)
        try fixture.start()
        let host = try await fixture.host(width: 444)
        defer { host.close() }
        try await host.clickCompositionControl("unified.tags.choose")
        try await host.key(125, "\u{f701}")
        #expect(fixture.controller.tagSelection?.active == live.id)
        try await host.key(49, " ")
        #expect(fixture.controller.tagSelection?.selected == [live.id])
        try await host.key(53, "\u{1b}")
        #expect(fixture.controller.tagSelection == nil)
        #expect(fixture.controller.editingDraft?.arguments.contains { $0.parameter == .tags } == false)
        try host.assertCompositionTagFocus()
        try await host.clickCompositionControl("unified.tags.choose")
        try await host.key(125, "\u{f701}")
        try await host.key(49, " ")
        try await host.key(48, "\t")
        #expect(fixture.controller.tagSelection == nil)
        #expect(fixture.controller.editingDraft?.arguments.first { $0.parameter == .tags }?.value == .tags([live.id]))
        try host.assertCompositionTagFocus()
        try await host.clickCompositionControl("unified.tags.choose")
        let query = try #require(SettingsButtonTestSupport.elements(host.window.contentView).compactMap { $0 as? NSTextField }
            .first { $0.placeholderString == "Filter ordinary tags" })
        host.window.makeFirstResponder(query)
        try await host.settle()
        let editor = try #require(query.currentEditor() as? NSTextView)
        editor.insertText("ordin", replacementRange: editor.selectedRange())
        try await host.settle()
        let picker = try #require(fixture.controller.tagSelection)
        #expect(picker.query == "ordin" && picker.candidates.matching(picker.query).compactMap(\.id) == [live.id])
        try await host.key(53, "\u{1b}")
        #expect(fixture.controller.tagSelection == nil)
        #expect(fixture.controller.editingDraft?.arguments.first { $0.parameter == .tags }?.value == .tags([live.id]))
        try fixture.noCompositionWrites()
    }
}
