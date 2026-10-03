import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct CalendarMonthGridLayoutTests {
    typealias Native = SettingsButtonTestSupport

    @Test(arguments: [false, true], ["en", "zh-Hans"])
    func baselineGeometry(compact: Bool, locale: String) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        let dates = CalendarMonthGridDates(monthKey: "2026-08-01", todayKey: "2026-08-18", selectedKey: "2026-08-19")
        let counts = ["2026-08-18": 3, "2026-08-19": 999999]
        let old = fixture.window(CalendarMonthGridBaseline(dates: dates, counts: counts, isCompact: compact, onSelect: { _ in })
            .environment(\.calendar, calendar).padding(20).frame(maxHeight: .infinity, alignment: .top),
            locale: locale, size: NSSize(width: 360, height: 500))
        defer { SystemPageHost.release(old) }
        try await SystemPageHost.settle(old)
        let before = try frames(old)
        try Native.snapshot(old, name: "monthB-before-\(compact)-\(locale)")
        let window = fixture.window(CalendarMonthGrid(dates: dates, counts: counts, isCompact: compact, onSelect: { _ in })
            .environment(\.calendar, calendar).padding(20).frame(maxHeight: .infinity, alignment: .top),
            locale: locale, size: NSSize(width: 360, height: 500))
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let after = try frames(window)
        #expect(before.count == 31 && after.count == 31)
        #expect(before == after)
        // 实测 13pt 日期＋9pt 计数撑到 29pt，六位数换行另增 11pt；regular 按钮再加 6pt。
        #expect(Set(after.map(\.height)) == (compact ? [35, 46] : [58]))
        #expect(Set(after.map(\.midY)).count == 6)
        print("MonthB baseline compact=\(compact) locale=\(locale) first=\(after[0]) last=\(after[30])")
        try Native.snapshot(window, name: "monthB-after-\(compact)-\(locale)")
    }

    private func frames(_ window: NSWindow) throws -> [CGRect] {
        let buttons = Native.buttons(in: window)
        try Native.assertBounds(buttons, in: window)
        return try buttons.map { try Native.frame($0, in: window) }.sorted {
            $0.midY == $1.midY ? $0.minX < $1.minX : $0.midY > $1.midY
        }
    }
}
