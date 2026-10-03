import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct RecurringEditorTimeTests {
    typealias Native = SettingsButtonTestSupport
    typealias Detail = DetailTimeSupport

    @Test(arguments: ["en", "zh-Hans"], [false, true])
    func formLayoutAndEmptyTime(locale: String, dark: Bool) async throws {
        let fixture = try TimePickerConsumerFixture(minutes: nil)
        defer { fixture.cleanup() }
        let window = fixture.native.window(RecurringItemEditor(), locale: locale,
            scheme: dark ? .dark : .light, size: NSSize(width: 440, height: 640))
        defer { SystemPageHost.release(window) }
        let picker = try await Detail.open(locale: locale, in: window)
        #expect(picker.locale?.identifier == locale)
        try Native.snapshot(window, name: "recurring-time-form-\(locale)-\(dark)")
        try await fixture.close(picker)
        #expect(fixture.repository.creations == 0 && fixture.repository.reminderWrites.isEmpty)
    }

    @Test(arguments: [false, true])
    func draftTimeCancelSaveAndFailure(save: Bool) async throws {
        let fixture = try TimePickerConsumerFixture(minutes: nil)
        defer { fixture.cleanup() }
        let window = fixture.native.window(RecurringItemEditor(), locale: "zh-Hans",
            size: NSSize(width: 440, height: 640))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let field = try #require(Native.elements(window.contentView).compactMap { $0 as? NSTextField }
            .first { $0.placeholderString == "标题" })
        window.makeFirstResponder(field)
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.insertText("Synthetic long recurring title 保留草稿与备注", replacementRange: editor.selectedRange())
        let picker = try await Detail.open(locale: "zh-Hans", in: window)
        #expect(picker.accessibilityHelp() == "未设置")
        try await fixture.close(picker)
        #expect(fixture.repository.creations == 0)
        let reopened = try await Detail.open(locale: "zh-Hans", in: window)
        try fixture.assign(720, to: reopened)
        try await SystemPageHost.settle(window)
        try await Detail.partial(reopened)
        let popup = try #require(reopened.window)
        try await TimePickerNativeTestSupport.key(25, "9", in: popup)
        #expect(Detail.displayed(reopened) == 769)
        try await TimePickerNativeTestSupport.key(36, "\r", in: popup)
        #expect(fixture.repository.creations == 0, "时间字段 Return 不能提前保存表单")
        try await fixture.close(reopened)
        #expect(try fixture.native.container.mainContext.fetchCount(FetchDescriptor<DailyRoutine>()) == 1)
        #expect(fixture.repository.reminderWrites.isEmpty)
        try await NativeSyntaxUI.prepareFocus(in: window)
        if !save {
            try await Native.click(Native.button("recurring.create.cancel", locale: "zh-Hans", in: window), in: window)
            #expect(fixture.repository.creations == 0)
            #expect(try fixture.native.container.mainContext.fetchCount(FetchDescriptor<DailyRoutine>()) == 1)
            return
        }
        fixture.repository.fail = true
        try await Native.click(Native.button("common.save", locale: "zh-Hans", in: window), in: window)
        #expect(fixture.repository.creations == 1)
        #expect(try fixture.native.container.mainContext.fetchCount(FetchDescriptor<DailyRoutine>()) == 1)
        #expect(field.stringValue == "Synthetic long recurring title 保留草稿与备注")
        let retained = try await Detail.open(locale: "zh-Hans", in: window)
        #expect(Detail.displayed(retained) == 769)
        try await fixture.close(retained)
        fixture.repository.fail = false
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await Native.click(Native.button("common.save", locale: "zh-Hans", in: window), in: window)
        let saved = try #require(ModelContext(fixture.native.container).fetch(FetchDescriptor<DailyRoutine>())
            .first { $0.id != fixture.routine.id })
        #expect(saved.remindMinutes == 769)
        #expect(saved.title == "Synthetic long recurring title 保留草稿与备注")
        #expect(fixture.repository.creations == 2)
    }
}
