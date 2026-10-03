import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DateScheduleCalendarIsolationTests {
    @Test func popupKeysDoNotReachProductionCalendarOrList() async throws {
        let fixture = try CalendarSpanTestSupport(day: "2026-10-02")
        defer { fixture.close() }
        try await fixture.prepare()
        try await fixture.key(36, chars: "\r")
        let native = SettingsButtonTestSupport.self
        let menus = MenuButtonTestSupport.menus(in: fixture.window).filter {
            MenuButtonTestSupport.title($0) == fixture.text("row.more") && fixture.visible($0)
        }
        let menu = try await MenuButtonTestSupport.openAndEscape(try #require(menus.first), in: fixture.window)
        try MenuButtonTestSupport.dispatch(fixture.text("day.pick"), in: menu)
        try await SystemPageHost.settle(fixture.window)
        let popup = try DatePickerTestSupport.popup(excluding: fixture.window)
        try await NativeSyntaxUI.prepareFocus(in: popup)
        let focusedTask = WorkspaceNavigation.shared.selectedTaskID
        let selected = fixture.selectedKey
        try await DatePickerTestSupport.select("2026-10-18", in: popup)
        for (code, chars) in [(UInt16(124), "\u{F703}"), (125, "\u{F701}"), (36, "\r")] {
            try await DatePickerTestSupport.key(code, chars, in: popup)
            #expect(fixture.selectedKey == selected)
            #expect(WorkspaceNavigation.shared.selectedTaskID == focusedTask)
            try fixture.assertUnchanged()
        }
        #expect(try DatePickerTestSupport.selected("2026-10-26", in: popup))
        try native.snapshot(popup, name: "date-calendar-isolation")
        try await DatePickerTestSupport.key(53, "\u{1B}", in: popup)
        #expect(!popup.isVisible)
        #expect(fixture.selectedKey == selected)
        try fixture.assertUnchanged()
    }
}
