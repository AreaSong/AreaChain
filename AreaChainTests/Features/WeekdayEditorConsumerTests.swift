import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct WeekdayEditorConsumerTests {
    typealias Native = SettingsButtonTestSupport
    typealias Support = WeekdayPickerTestSupport

    @Test(arguments: ["en", "zh-Hans"], [false, true])
    func emptyDraftCancelFailureAndRetry(locale: String, save: Bool) async throws {
        let f = try WeekdayConsumerTestSupport()
        defer { f.cleanup() }
        let window = f.window("editor", locale: locale)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let title = try await Support.replaceTitle("Synthetic weekday draft", in: window)
        for weekday in 1...7 { try await Native.click(Support.day(weekday, locale: locale, in: window), in: window) }
        #expect(window.firstResponder === title && title.string == "Synthetic weekday draft")
        try Support.expectMask(0, allowsEmpty: true, locale: locale, in: window)
        let required = L10n.string("recurring.create.weekdays.required", locale: Locale(identifier: locale))
        #expect(Support.copyContains(required, in: window))
        let saveButton = try Native.button("common.save", locale: locale, in: window)
        #expect(saveButton.value(forKey: "accessibilityEnabled") as? Bool == false)
        // 真实标题 Return 仍走原保存校验，不能只依赖禁用按钮。
        try await TimePickerNativeTestSupport.key(36, "\r", in: window)
        #expect(f.repo.creations == 0 && f.repo.weekdayWrites.isEmpty)
        try await Native.click(Support.day(5, locale: locale, in: window), in: window)
        #expect(try Native.button("common.save", locale: locale, in: window).value(forKey: "accessibilityEnabled") as? Bool == true)
        #expect(!Support.copyContains(required, in: window))
        if !save {
            try await Native.click(Native.button("recurring.create.cancel", locale: locale, in: window), in: window)
            #expect(f.repo.creations == 0)
            #expect(try f.context.fetchCount(FetchDescriptor<DailyRoutine>()) == 2)
            return
        }
        try await finishFailedDraftAndRetry(f, locale: locale, window: window)
    }

    private func finishFailedDraftAndRetry(_ f: WeekdayConsumerTestSupport, locale: String,
                                           window: NSWindow) async throws {
        let notes = try #require(Native.elements(window.contentView).compactMap { $0 as? NSTextView }
            .first { $0.isEditable && !$0.isFieldEditor })
        #expect(window.makeFirstResponder(notes))
        notes.insertText("Synthetic notes retained", replacementRange: NSRange(location: 0, length: notes.string.utf16.count))
        try await SystemPageHost.settle(window)
        let toggle = try #require(Native.elements(window.contentView).first {
            Native.value($0, "accessibilityRole") as? String == "AXCheckBox"
        })
        try await Native.click(toggle, in: window)
        try await Native.click(Native.button("09:00", locale: locale, in: window), in: window)
        f.repo.fail = true
        try await Native.click(Native.button("common.save", locale: locale, in: window), in: window)
        #expect(f.repo.creations == 1 && f.repo.weekdayWrites.isEmpty && f.repo.reminderWrites.isEmpty)
        #expect(try f.context.fetchCount(FetchDescriptor<DailyRoutine>()) == 2)
        try Support.expectMask(WeekdayMask.only(weekday: 5), allowsEmpty: true, locale: locale, in: window)
        #expect(Support.copyContains("Synthetic weekday draft", in: window))
        #expect(notes.string == "Synthetic notes retained")
        let failure = L10n.string("recurring.create.failed", locale: Locale(identifier: locale))
        #expect(Support.copyContains(failure, in: window))
        f.repo.fail = false
        try await Native.click(Native.button("common.save", locale: locale, in: window), in: window)
        let saved = try #require(ModelContext(f.base.fixture.container).fetch(FetchDescriptor<DailyRoutine>())
            .first { $0.id != f.routine.id && $0.id != f.base.other.id })
        #expect(saved.title == "Synthetic weekday draft" && saved.notes == "Synthetic notes retained")
        #expect(saved.resolvedWeekdayMask == WeekdayMask.only(weekday: 5))
        #expect(saved.remindMinutes == 540 && !saved.isEnabled)
        #expect(f.repo.creations == 2)
        try f.assertUnrelatedUnchanged()
    }

    @Test(arguments: ["management", "detail"])
    func lastDayStillSavesUnchangedValue(host: String) async throws {
        let f = try WeekdayConsumerTestSupport()
        defer { f.cleanup() }
        f.routine.setWeekdayMask(WeekdayMask.only(weekday: 2))
        try f.context.save()
        let window = f.window(host, narrow: false)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        for _ in 0..<2 { try await Native.click(Support.day(2, in: window), in: window) }
        #expect(f.repo.weekdayWrites == [2, 2])
        #expect(f.routine.resolvedWeekdayMask == 2)
        try Support.expectMask(2, in: window)
        try f.assertUnrelatedUnchanged()
    }

    @Test(arguments: [false, true])
    func actualSheetDismissal(save: Bool) async throws {
        let f = try WeekdayConsumerTestSupport()
        defer { f.cleanup() }
        let presentation = WeekdayEditorPresentation()
        let parent = f.base.fixture.window(WeekdayEditorSheetHost(presentation: presentation))
        defer { SystemPageHost.release(parent) }
        try await NativeSyntaxUI.prepareFocus(in: parent)
        presentation.presented = true
        try await SystemPageHost.settle(parent)
        let sheet = try #require(parent.attachedSheet)
        try await NativeSyntaxUI.prepareFocus(in: sheet)
        _ = try await Support.replaceTitle("Synthetic sheet draft", in: sheet)
        try await Native.click(Support.day(1, in: sheet), in: sheet)
        #expect(presentation.presented && f.repo.creations == 0)
        if save {
            f.repo.fail = true
            try await Native.click(Native.button("common.save", in: sheet), in: sheet)
            #expect(presentation.presented && parent.attachedSheet === sheet)
            try Support.expectMask(126, allowsEmpty: true, in: sheet)
            f.repo.fail = false
        }
        try await Native.click(Native.button(save ? "common.save" : "recurring.create.cancel", in: sheet), in: sheet)
        try await SystemPageHost.settle(parent)
        #expect(!presentation.presented && parent.attachedSheet == nil)
        #expect(f.repo.creations == (save ? 2 : 0))
        #expect(try f.context.fetchCount(FetchDescriptor<DailyRoutine>()) == (save ? 3 : 2))
    }
}

@MainActor @Observable
final class WeekdayEditorPresentation {
    var presented = false
}

struct WeekdayEditorSheetHost: View {
    @Bindable var presentation: WeekdayEditorPresentation
    var body: some View {
        Color.clear.sheet(isPresented: $presentation.presented) {
            RecurringItemEditor().frame(width: 440, height: 640)
        }
    }
}
