import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchTaskTitleInteractionTests {
    @Test(arguments: [false, true]) func nativeSelectionToActualModification(commandReturn: Bool) async throws {
        let fixture = try UnifiedSearchTaskTitleFixture()
        defer { fixture.stop() }
        let host = try await fixture.host()
        defer { host.close() }
        let editor = try host.editor
        editor.insertText("/tasks/title", replacementRange: .init(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        try await host.key(48, "\t")
        try #require(fixture.controller.editingDraft?.commandID.rawValue == "todo.title")
        try await host.selectTitleTarget(fixture, keyboard: commandReturn)
        #expect(fixture.controller.editingDraft?.baseline == CommandDraftBaseline())
        let input = try await host.focusParameter(.title)
        input.insertText("Native 标题 #新建 #恢复 !p1 @09:30", replacementRange: input.selectedRange())
        try await host.settle()
        try await host.key(36, "\r")
        #expect(fixture.controller.editingDraft?.arguments.first?.value == .shortText("Native 标题 #新建 #恢复 !p1 @09:30"))
        let accepted = try await host.prepareAndAcceptTitle(fixture)
        #expect(accepted.preview.impact.tags.original.count == 1 && accepted.preview.impact.tags.final.count == 3)
        #expect(accepted.preview.impact.tags.associations.map(\.effect) == [.createAndAssociate, .restoreAndAssociate])
        try await host.revealSettingControlInsidePanel("unified.title.tagSummary")
        try host.snapshot("title-native-prepared-\(commandReturn)")
        let old = fixture.controller.buffer
        if commandReturn {
            host.window.makeFirstResponder(try host.field)
            try await host.settle()
            try await host.key(53, "\u{1b}")
            try await host.key(36, "\r", flags: .command)
        } else { try await host.clickCompositionControl("unified.title.save") }
        let facts = try fixture.facts
        let task = try fixture.stored
        #expect(facts.state == .saved && facts.targetID == fixture.base.todo.id)
        #expect(task.title == "Native 标题" && task.isImportant && task.isUrgent && task.remindMinutes == 570)
        #expect(TagIDList.parse(task.tagIDs) == [fixture.base.live.id, try #require(accepted.tagCreationIDs["新建"]), fixture.base.deleted.id])
        #expect(fixture.base.deleted.deletedAt == nil && task.dayKey == "2026-10-05" && task.isDone)
        #expect(task.dueMinutes == 600 && task.sortOrder == 7 && task.calendarEventID == "qa.calendar")
        #expect(try fixture.base.io.context.fetchCount(FetchDescriptor<TodoItem>()) == 1)
        #expect(try fixture.base.io.context.fetchCount(FetchDescriptor<TagItem>()) == 3)
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 1 && fixture.base.io.authorizations == [570])
        #expect(fixture.controller.settingExecution?.outputs.isEmpty == true)
        fixture.controller.requestOperationSubmit(old)
        fixture.controller.acceptTaskTitle(accepted.preview, source: old)
        try await host.key(36, "\r", flags: .command)
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 1)
        try await host.revealSettingControlInsidePanel("unified.title.status")
        try host.snapshot("title-native-saved-\(commandReturn)")
    }

    @Test(arguments: ["原标题", "原标题 #恢复", "原标题 #新建", "原标题 !p1", "原标题 @09:30"])
    func nativeSameTitleDistinguishesAllEffects(text: String) async throws {
        let fixture = try UnifiedSearchTaskTitleFixture()
        defer { fixture.stop() }
        try await fixture.start(text)
        let host = try await fixture.host()
        defer { host.close() }
        _ = try await host.prepareAndAcceptTitle(fixture)
        try await host.clickCompositionControl("unified.title.save")
        let unchanged = text == "原标题"
        #expect(try fixture.facts.state == (unchanged ? .noChange : .saved))
        #expect(fixture.count("save") == (unchanged ? 0 : 1) && fixture.count("ui") == (unchanged ? 0 : 1))
        #expect(try fixture.stored.title == "原标题")
        if text.contains("#恢复") { #expect(fixture.base.deleted.deletedAt == nil) }
        if text.contains("!p1") { #expect(try fixture.stored.isUrgent) }
        if text.contains("@09:30") { #expect(try fixture.stored.remindMinutes == 570) }
        try await host.revealSettingControlInsidePanel("unified.title.status")
        try host.snapshot(unchanged ? "title-noChange" : "title-sameTitle-effects")
    }

    @Test func nativeMarkedTextReturnTabAndEscapeNeverSubmit() async throws {
        let fixture = try UnifiedSearchTaskTitleFixture()
        defer { fixture.stop() }
        try await fixture.start()
        let host = try await fixture.host()
        defer { host.close() }
        let editor = try await host.focusParameter(.title)
        let original = fixture.controller.editingDraft?.arguments
        editor.setMarkedText("组合输入", selectedRange: .init(location: 4, length: 0), replacementRange: editor.selectedRange())
        fixture.controller.prepareTaskTitle(fixture.controller.buffer)
        try await host.key(36, "\r", flags: .command)
        #expect(fixture.controller.taskTitlePreview == nil && fixture.controller.editingDraft?.arguments == original)
        editor.unmarkText()
        editor.insertText("新标题", replacementRange: .init(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        try await host.key(36, "\r")
        try await host.key(48, "\t")
        try await host.key(53, "\u{1b}")
        try fixture.noWrites()
        #expect(fixture.controller.settingExecution == nil)
        #expect(fixture.controller.editingDraft?.arguments.first?.value == .shortText("新标题"))
    }

    @Test func nativeRestorationWithoutTaskFieldChangesStillSaves() async throws {
        let fixture = try UnifiedSearchTaskTitleFixture()
        defer { fixture.stop() }
        fixture.base.todo.tagIDs = TagIDList.encode([fixture.base.live.id, fixture.base.deleted.id])
        try fixture.base.io.context.save()
        try await fixture.start("原标题 #恢复")
        let host = try await fixture.host()
        defer { host.close() }
        let accepted = try await host.prepareAndAcceptTitle(fixture)
        #expect(accepted.preview.impact.changedFields.isEmpty)
        #expect(accepted.preview.impact.tags.sideEffects.map(\.effect) == [.restoreAndAssociate])
        try await host.clickCompositionControl("unified.title.save")
        #expect(try fixture.facts.state == .saved && fixture.stored.title == "原标题")
        #expect(fixture.base.deleted.deletedAt == nil && fixture.count("save") == 1 && fixture.count("ui") == 1)
    }
}
