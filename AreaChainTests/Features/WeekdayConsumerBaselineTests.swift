import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct WeekdayConsumerBaselineTests {
    typealias Native = SettingsButtonTestSupport
    typealias Support = WeekdayPickerTestSupport

    @Test(arguments: ["editor", "management", "detail"], ["en", "zh-Hans"])
    func productionLayouts(host: String, locale: String) async throws {
        let f = try WeekdayConsumerTestSupport()
        defer { f.cleanup() }
        // 只含合成文案；用真实消费者检查长标题和相邻时间按钮。
        f.routine.title = "Synthetic long recurring title for weekday layout / 合成重复事项长标题"
        try f.context.save()
        for narrow in [true, false] {
            let window = f.window(host, locale: locale, dark: !narrow, narrow: narrow)
            defer { SystemPageHost.release(window) }
            try await NativeSyntaxUI.prepareFocus(in: window)
            try await SystemPageHost.settle(window)
            let days = try Support.days(locale: locale, in: window)
            try Native.assertBounds(days, in: window)
            let frames = try days.map { try Native.frame($0, in: window) }
            #expect(Set(frames.map(\.midY)).count == 1)
            #expect(Set(frames.map(\.width)) == [25])
            if host == "management" {
                try Native.assertBounds(days + [Native.button("row.time.set", locale: locale, in: window)], in: window)
            }
            #expect(f.repo.weekdayWrites.isEmpty && f.repo.creations == 0)
            try Native.snapshot(window, name: "weekdayD-\(host)-\(locale)-\(narrow)")
            print("WeekdayD consumer=\(host) locale=\(locale) narrow=\(narrow) frames=\(frames)")
        }
        try f.assertUnrelatedUnchanged()
    }

    @Test(arguments: ["editor", "management", "detail"])
    func titleFocusAndCommit(host: String) async throws {
        let f = try WeekdayConsumerTestSupport()
        defer { f.cleanup() }
        let window = f.window(host, narrow: false)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let editor: NSTextView
        if host == "detail" {
            let title = try #require(Native.elements(window.contentView).first {
                Native.value($0, "accessibilityValue") as? String == "Synthetic habit"
            })
            try await Native.click(title, in: window)
            editor = try #require(window.firstResponder as? NSTextView)
            editor.insertText("Synthetic title draft", replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
            try await SystemPageHost.settle(window)
        } else {
            editor = try await Support.replaceTitle("Synthetic title draft", in: window)
        }
        try await Native.click(Support.day(2, in: window), in: window)
        #expect(window.firstResponder === editor)
        #expect(editor.string == "Synthetic title draft")
        #expect(f.routine.title == "Synthetic habit")
        #expect(f.repo.creations == 0)
        #expect(f.repo.weekdayWrites.count == (host == "editor" ? 0 : 1))
        #expect(window.makeFirstResponder(nil))
        try await SystemPageHost.settle(window)
        #expect(f.routine.title == (host == "editor" ? "Synthetic habit" : "Synthetic title draft"))
        try f.assertUnrelatedUnchanged()
    }

    @Test(arguments: ["editor", "detail"])
    func notesFocusAndCommit(host: String) async throws {
        let f = try WeekdayConsumerTestSupport()
        defer { f.cleanup() }
        let window = f.window(host, narrow: false)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let editor = try #require(Native.elements(window.contentView).compactMap { $0 as? NSTextView }
            .first { $0.isEditable && !$0.isFieldEditor })
        #expect(window.makeFirstResponder(editor))
        editor.insertText("Synthetic notes draft", replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
        try await SystemPageHost.settle(window)
        try await Native.click(Support.day(2, in: window), in: window)
        #expect(window.firstResponder === editor)
        #expect(editor.string == "Synthetic notes draft")
        #expect(f.routine.notes == "Synthetic notes")
        #expect(window.makeFirstResponder(nil))
        try await SystemPageHost.settle(window)
        #expect(f.routine.notes == (host == "editor" ? "Synthetic notes" : "Synthetic notes draft"))
        #expect(f.repo.creations == 0)
        try f.assertUnrelatedUnchanged()
    }

    @Test(arguments: ["management", "detail"])
    func immediateSaveAndFailureInSameHost(host: String) async throws {
        let f = try WeekdayConsumerTestSupport()
        defer { f.cleanup() }
        let window = f.window(host, narrow: false)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try await Native.click(Support.day(1, in: window), in: window)
        let saved = WeekdayMask.toggling(WeekdayMask.workdays, weekday: 1)
        #expect(f.routine.resolvedWeekdayMask == saved && f.repo.weekdayWrites == [saved])
        try Support.expectMask(saved, in: window)
        f.repo.fail = true
        try await Native.click(Support.day(7, in: window), in: window)
        #expect(f.repo.weekdayWrites == [saved, WeekdayMask.all])
        #expect(f.routine.resolvedWeekdayMask == saved)
        try Support.expectMask(saved, in: window)
        f.repo.fail = false
        try await Native.click(Support.day(7, in: window), in: window)
        #expect(f.routine.resolvedWeekdayMask == WeekdayMask.all)
        #expect(f.repo.weekdayWrites == [saved, WeekdayMask.all, WeekdayMask.all])
        try Support.expectMask(WeekdayMask.all, in: window)
        #expect(!f.context.hasChanges)
        try f.assertUnrelatedUnchanged()
    }
}
