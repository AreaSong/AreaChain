import AppKit
import SwiftUI
import Testing
@testable import AreaChain

/// 日期控件使用生产视图和合成日期；原生选择动作与最终确认分别取证。
@Suite(.serialized) @MainActor
struct DayScheduleButtonConsumerTests {
    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func selectionWaitsForConfirmation(locale: String, scheme: ColorScheme) async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        var picked: [String] = []
        let window = support.window(DaySchedulePicker(initialKey: "2026-10-01") { picked.append($0) },
                                    locale: locale, scheme: scheme, size: NSSize(width: 300, height: 340))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let picker = try datePicker(in: window)
        #expect(DayKey.from(picker.dateValue) == "2026-10-01" && picked.isEmpty)
        try await select("2026-10-18", picker: picker, in: window)
        #expect(picked.isEmpty)
        let button = try SettingsButtonTestSupport.button("day.confirm", locale: locale, in: window)
        try SettingsButtonTestSupport.assertBounds([button], in: window)
        try SettingsButtonTestSupport.snapshot(window, name: "date-confirm-\(locale)-\(scheme)")
        try await SettingsButtonTestSupport.click(button, in: window)
        #expect(picked == ["2026-10-18"])
    }

    @Test func customLongConfirmationTitleStillSubmitsOnce() async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        var picked: [String] = []
        let title = "Confirm the selected synthetic calendar date"
        let window = support.window(DaySchedulePicker(initialKey: "2026-12-31", confirmTitle: LocalizedStringKey(title)) {
            picked.append($0)
        }, size: NSSize(width: 300, height: 340))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let button = try SettingsButtonTestSupport.button(title, in: window)
        try SettingsButtonTestSupport.assertBounds([button], in: window)
        try SettingsButtonTestSupport.snapshot(window, name: "date-confirm-long")
        try await SettingsButtonTestSupport.click(button, in: window)
        #expect(picked == ["2026-12-31"])
    }

    @Test func taskConsumerCommitsAndClosesPopover() async throws {
        let support = try SettingsButtonTestSupport()
        defer { support.cleanup() }
        var picked: [String] = []
        let window = support.window(TaskDetailDateChips(dayKey: "2026-10-01") { picked.append($0) })
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try await SettingsButtonTestSupport.click(SettingsButtonTestSupport.button("day.pick", in: window), in: window)
        let popover = try #require(NSApp.windows.first { $0.isVisible && $0 !== window && hasDatePicker($0) })
        try await NativeSyntaxUI.prepareFocus(in: popover)
        let picker = try datePicker(in: popover)
        #expect(DayKey.from(picker.dateValue) == "2026-10-01")
        try await select("2026-10-18", picker: picker, in: popover)
        #expect(picked.isEmpty)
        try await SettingsButtonTestSupport.click(SettingsButtonTestSupport.button("day.confirm", in: popover), in: popover)
        #expect(picked == ["2026-10-18"])
        try await SystemPageHost.settle(window)
        #expect(!popover.isVisible)
    }

    @Test func diaryConsumerCommitsAndClosesPopover() async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        let note = try f.repository.addDiary(text: "Synthetic scheduled note", dayKey: "2026-10-01", tagIDs: [])
        // 从弹出层已打开的状态挂载真实卡片，保留其日期回调、事务和关闭绑定。
        let card = DiaryNoteCard(entry: note, activeTags: [], attachments: [], onDelete: {},
                                 vault: f.vault, pickingDay: true)
        let window = SystemPageHost.window(card, container: f.container, scheme: .light, locale: "en",
                                          size: NSSize(width: 380, height: 260))
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let popover = try #require(NSApp.windows.first { $0.isVisible && $0 !== window && hasDatePicker($0) })
        try await NativeSyntaxUI.prepareFocus(in: popover)
        let picker = try datePicker(in: popover)
        #expect(DayKey.from(picker.dateValue) == "2026-10-01")
        try await select("2026-10-18", picker: picker, in: popover)
        #expect(note.dayKey == "2026-10-01")
        try await SettingsButtonTestSupport.click(SettingsButtonTestSupport.button("day.confirm", in: popover), in: popover)
        #expect(note.dayKey == "2026-10-18" && !f.context.hasChanges)
        try await SystemPageHost.settle(window)
        #expect(!popover.isVisible)
    }

    private func datePicker(in window: NSWindow) throws -> NSDatePicker {
        try #require(SettingsButtonTestSupport.elements(window.contentView).compactMap { $0 as? NSDatePicker }.first)
    }

    private func hasDatePicker(_ window: NSWindow) -> Bool {
        SettingsButtonTestSupport.elements(window.contentView).contains { $0 is NSDatePicker }
    }

    private func select(_ key: String, picker: NSDatePicker, in window: NSWindow) async throws {
        picker.dateValue = try #require(DayKey.date(from: key))
        #expect(picker.sendAction(picker.action, to: picker.target))
        try await SystemPageHost.settle(window)
    }
}
