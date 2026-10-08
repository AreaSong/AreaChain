import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchTM2InteractionTests {
    @Test(arguments: [false, true]) func completionAndReopeningUseRealControls(reopen: Bool) async throws {
        let fixture = try UnifiedSearchTM2Fixture(done: reopen)
        defer { fixture.results.stop() }
        let host = try await fixture.host(reopen ? 1 : 2)
        defer { host.close() }
        let before = fixture.service.base.todo.snapshot
        try await fixture.selectCommand("/tasks/completion", host: host)
        for _ in 0..<(reopen ? 2 : 1) {
            let picker = try await host.compositionPicker("unified.parameter.boolean.enabled")
            try await PickerNativeTestSupport.keyboardSelection(picker, moveDown: true, in: host.window)
        }
        #expect(fixture.controller.editingDraft?.arguments.first?.value == .boolean(!reopen))
        let name = reopen ? "reopen" : "complete"
        let accepted = try await fixture.prepare(host, name: name)
        #expect(accepted.preview.completion?.affected.count == (reopen ? 0 : 1))
        let facts = try await fixture.submit(host, name: name, chord: reopen)
        let todo = try fixture.service.todo()
        #expect(todo.isDone == !reopen && todo.subtasks.filter { $0.deletedAt == nil && $0.isDone }.count == (reopen ? 1 : 2))
        #expect(todo.subtasks.first { $0.deletedAt != nil }?.isDone == false)
        #expect(facts.completedSubtaskIDs?.count == (reopen ? 0 : 1))
        try fixture.service.assertUnchanged(before, except: "completion")
    }

    @Test(arguments: [CommandFieldOperation.add, .remove, .replaceAll, .clear])
    func tagSetModesUseConfirmedTemporarySelection(mode: CommandFieldOperation) async throws {
        let fixture = try UnifiedSearchTM2Fixture()
        defer { fixture.results.stop() }
        let host = try await fixture.host(mode == .add ? 3 : 0)
        defer { host.close() }
        let before = fixture.service.base.todo.snapshot
        try await fixture.selectCommand("/tasks/tags", host: host)
        try await fixture.mode(.tags, mode, host: host)
        if mode.requiresValue {
            let previous = fixture.controller.editingDraft?.arguments
            try await host.clickCompositionControl("unified.tags.choose")
            let id = mode == .remove ? fixture.service.base.live.id : fixture.service.base.deleted.id
            try await host.clickCompositionControl("unified.tags.row." + id.uuidString)
            #expect(fixture.controller.editingDraft?.arguments == previous)
            try await host.clickCompositionControl("unified.tags.accept")
            #expect(fixture.controller.editingDraft?.arguments.first?.value == .tags([id]))
        }
        let name = "tags-" + mode.rawValue
        _ = try await fixture.prepare(host, name: name)
        _ = try await fixture.submit(host, name: name, chord: mode == .replaceAll)
        let expected = mode == .add ? [fixture.service.base.live.id, fixture.service.base.deleted.id]
            : mode == .replaceAll ? [fixture.service.base.deleted.id] : []
        #expect(try fixture.service.todo().tagIDs == TagIDList.encode(expected))
        #expect(try fixture.service.tags().count == 2)
        try fixture.service.assertUnchanged(before, except: "tags")
    }

    @Test(arguments: [false, true]) func createAndRestoreAreExplicitlyAccepted(restore: Bool) async throws {
        let fixture = try UnifiedSearchTM2Fixture()
        defer { fixture.results.stop() }
        let host = try await fixture.host(restore ? 2 : 1)
        defer { host.close() }
        let before = fixture.service.base.todo.snapshot
        try await fixture.selectCommand("/tasks/create-tag", host: host)
        let editor = try await host.focusParameter(.name)
        editor.insertText(restore ? "恢复" : "Synthetic new tag", replacementRange: editor.selectedRange())
        try await host.settle()
        try await host.key(36, "\r")
        let name = restore ? "restore-tag" : "create-tag"
        let accepted = try await fixture.prepare(host, name: name)
        #expect(accepted.preview.tags?.actions.final.map(\.effect) == [restore ? .restoreAndAssociate : .createAndAssociate])
        let facts = try await fixture.submit(host, name: name, chord: !restore)
        #expect(facts.savedTagEffects == [restore ? .restoreAndAssociate : .createAndAssociate])
        let tags = try fixture.service.tags()
        #expect(tags.count == (restore ? 2 : 3))
        let id: UUID
        if restore { id = fixture.service.base.deleted.id }
        else { id = try #require(accepted.tagCreationIDs["synthetic new tag"]) }
        #expect(tags.first { $0.id == id }?.deletedAt == nil)
        #expect(try fixture.service.todo().tagIDs == TagIDList.encode([fixture.service.base.live.id, id]))
        try fixture.service.assertUnchanged(before, except: "tags")
    }

    @Test(arguments: [false, true]) func dueAssignAndClearUseTimeControl(clear: Bool) async throws {
        let fixture = try UnifiedSearchTM2Fixture()
        defer { fixture.results.stop() }
        let host = try await fixture.host(clear ? 3 : 0)
        defer { host.close() }
        let before = fixture.service.base.todo.snapshot
        try await fixture.selectCommand("/tasks/due", host: host)
        if clear { try await fixture.mode(.time, .clear, host: host) }
        else {
            let time = try TimePickerNativeTestSupport.picker(in: host.window)
            try await SettingsButtonTestSupport.reveal(time, in: host.window)
            let frame = time.convert(time.bounds, to: nil)
            try await TimePickerNativeTestSupport.click(.init(x: frame.minX + 10, y: frame.midY), in: host.window)
            try await TimePickerNativeTestSupport.key(25, "9", in: host.window)
            try await TimePickerNativeTestSupport.key(124, "\u{F703}", in: host.window)
            try await TimePickerNativeTestSupport.key(20, "3", in: host.window)
            try await TimePickerNativeTestSupport.key(29, "0", in: host.window)
            // 英文 12 小时制还需明确 AM，不能沿用控件初始化时的 PM。
            try await TimePickerNativeTestSupport.key(124, "\u{F703}", in: host.window)
            try await TimePickerNativeTestSupport.key(0, "a", in: host.window)
            try await host.settle()
            #expect(RemindMinutes.from(date: time.dateValue, calendar: time.calendar ?? .current) == 570)
        }
        let name = clear ? "clear-due" : "assign-due"
        _ = try await fixture.prepare(host, name: name)
        _ = try await fixture.submit(host, name: name, chord: clear)
        #expect(try fixture.service.todo().dueMinutes == (clear ? nil : 570))
        try fixture.service.assertUnchanged(before, except: "due")
    }
}
