import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct RoutineCreateLegacyNativeTests {
    @Test func originalQuickCaptureKeepsFailureDraftAndAllRowSort() async throws {
        let fixture = try WeekdayConsumerTestSupport()
        defer { fixture.cleanup() }
        let before = try fixture.context.fetch(FetchDescriptor<DailyRoutine>()).map(\.snapshot)
        let checks = fixture.base.checks.compactMap(\.snapshot)
        let window = fixture.window("management", locale: "zh-Hans")
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let placeholder = L10n.string("resident.add", locale: Locale(identifier: "zh-Hans"))
        let field = try #require(SettingsButtonTestSupport.elements(window.contentView).compactMap { $0 as? NSTextField }
            .first { $0.placeholderString == placeholder })
        #expect(window.makeFirstResponder(field))
        let editor = try #require(field.currentEditor() as? NSTextView)
        let raw = "Legacy !p3 @09:30 完成输入"
        editor.insertText(raw, replacementRange: editor.selectedRange())
        try await SystemPageHost.settle(window)
        fixture.repo.fail = true
        try await TimePickerNativeTestSupport.key(36, "\r", in: window)
        #expect(fixture.repo.creations == 1 && field.stringValue == raw)
        #expect(try fixture.context.fetchCount(FetchDescriptor<DailyRoutine>()) == before.count)
        fixture.repo.fail = false
        try await NativeSyntaxUI.prepareFocus(in: window)
        #expect(window.makeFirstResponder(field))
        try await TimePickerNativeTestSupport.key(36, "\r", in: window)
        try await SystemPageHost.settle(window)
        let rows = try fixture.context.fetch(FetchDescriptor<DailyRoutine>())
        let created = try #require(rows.first { row in !before.contains { $0.id == row.id } })
        #expect(fixture.repo.creations == 2 && field.stringValue.isEmpty)
        #expect(created.title == "Legacy 完成输入" && created.remindMinutes == 570 && !created.isImportant && created.isUrgent)
        #expect(created.sortOrder == (before.map(\.sortOrder).max() ?? -1) + 1)
        #expect(created.isEnabled && created.weekdayMask == WeekdayMask.all && created.checks.isEmpty)
        #expect(fixture.base.checks.compactMap(\.snapshot) == checks)
        try SettingsButtonTestSupport.snapshot(window, name: "rm2-legacy-quick-saved")
    }
}
