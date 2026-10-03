import AppKit
import SwiftData
import Testing
@testable import AreaChain

extension TimePickerConsumerTests {
    @Test(arguments: [false, true])
    func realNativeInputExternalUpdateAndPendingEscape(resident: Bool) async throws {
        let fixture = try TimePickerConsumerFixture(minutes: 720)
        defer { fixture.cleanup() }
        let window = fixture.window(resident: resident, locale: "zh-Hans")
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let picker = try await fixture.open(resident: resident, locale: "zh-Hans", in: window)
        let popup = try #require(picker.window)
        try await NativeSyntaxUI.prepareFocus(in: popup)
        let rect = picker.convert(picker.bounds, to: nil)
        try await TimePickerNativeTestSupport.click(NSPoint(x: rect.minX + 10, y: rect.midY), in: popup)
        try await TimePickerNativeTestSupport.key(124, "\u{F703}", in: popup)
        try await TimePickerNativeTestSupport.key(21, "4", in: popup)
        #expect((resident ? fixture.repository.reminderWrites : fixture.taskMinutesWrites).isEmpty)
        try await TimePickerNativeTestSupport.key(25, "9", in: popup)
        #expect((resident ? fixture.routine.remindMinutes : fixture.todo.remindMinutes) == 769)
        #expect((resident ? fixture.repository.reminderWrites : fixture.taskMinutesWrites) == [769])
        if resident { fixture.routine.remindMinutes = 0 }
        else { fixture.todo.remindMinutes = 0 }
        try fixture.native.container.mainContext.save()
        try await SystemPageHost.settle(popup)
        #expect(displayed(picker) == 0)
        try await TimePickerNativeTestSupport.click(NSPoint(x: rect.minX + 10, y: rect.midY), in: popup)
        try await TimePickerNativeTestSupport.key(124, "\u{F703}", in: popup)
        try await TimePickerNativeTestSupport.key(21, "4", in: popup)
        try await fixture.close(picker)
        #expect((resident ? fixture.repository.reminderWrites : fixture.taskMinutesWrites) == [769])
        #expect((resident ? fixture.routine.remindMinutes : fixture.todo.remindMinutes) == 0)
    }

    @Test(arguments: [false, true])
    func failedDefaultInitializationAndClearKeepAuthority(resident: Bool) async throws {
        let fixture = try TimePickerConsumerFixture(minutes: nil)
        defer { fixture.cleanup() }
        fixture.fail = true
        fixture.repository.fail = true
        let window = fixture.window(resident: resident)
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let picker = try await fixture.open(resident: resident, in: window)
        #expect((resident ? fixture.routine.remindMinutes : fixture.todo.remindMinutes) == nil)
        #expect((resident ? fixture.repository.reminderWrites : fixture.taskMinutesWrites).count == 1)
        #expect(picker.accessibilityHelp() == "Not set")
        try await fixture.close(picker)
        if resident { fixture.routine.remindMinutes = 720 }
        else { fixture.todo.remindMinutes = 720 }
        try fixture.native.container.mainContext.save()
        try await SystemPageHost.settle(window)
        try await fixture.clear(resident: resident, in: window)
        #expect((resident ? fixture.routine.remindMinutes : fixture.todo.remindMinutes) == 720)
        let reopened = try await fixture.open(resident: resident, in: window)
        #expect(displayed(reopened) == 720)
        #expect((resident ? fixture.repository.reminderWrites : fixture.taskMinutesWrites).count == 2)
        try await fixture.close(reopened)
    }

    @Test func reminderOpeningKeepsOriginalResidentTitleCommitTiming() async throws {
        let fixture = try TimePickerConsumerFixture(minutes: 720)
        defer { fixture.cleanup() }
        let window = fixture.window(resident: true)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let field = try #require(Native.elements(window.contentView).compactMap { $0 as? NSTextField }
            .first { $0.stringValue == fixture.routine.title })
        window.makeFirstResponder(field)
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.selectAll(nil)
        editor.insertText("Synthetic renamed draft", replacementRange: editor.selectedRange())
        try await SystemPageHost.settle(window)
        #expect(fixture.routine.title == "Synthetic time routine")
        let picker = try await fixture.open(resident: true, in: window)
        print("TIME_TITLE afterOpen=\(fixture.routine.title == "Synthetic renamed draft") focused=\(window.firstResponder === editor)")
        #expect(fixture.routine.title == "Synthetic renamed draft", "原弹出层获得焦点后，标题沿原失焦规则保存")
        #expect(fixture.repository.reminderWrites.isEmpty)
        try fixture.assign(815, to: picker)
        try await fixture.close(picker)
        #expect(field.stringValue == "Synthetic renamed draft" && fixture.routine.title == "Synthetic renamed draft")
        #expect(fixture.routine.isEnabled && fixture.routine.checks.isEmpty)
    }
}
