import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct CalendarMonthGridTests {
    typealias Native = SettingsButtonTestSupport
    typealias Grid = MonthGridTestSupport

    @Test(arguments: [false, true])
    func clicksReselectExternalRejectBlankAndDisabled(compact: Bool) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let probe = MonthGridProbe()
        probe.calendar.firstWeekday = 1
        let window = fixture.window(MonthGridProbeView(probe: probe, compact: compact), size: NSSize(width: 360, height: 500))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        for _ in 0..<2 { try await Native.click(Grid.day("2026-08-19", in: window), in: window) }
        #expect(probe.selections == ["2026-08-19", "2026-08-19"])
        let neighbor = try Native.frame(Grid.day("2026-08-20", in: window), in: window)
        try await Grid.click(NSPoint(x: neighbor.minX + 1, y: neighbor.midY), in: window)
        #expect(probe.selections.last == "2026-08-20")
        probe.reject = true
        try await Native.click(Grid.day("2026-08-18", in: window), in: window)
        #expect(probe.dates.selectedKey == "2026-08-20")
        #expect(try DatePickerTestSupport.selected("2026-08-20", in: window))
        #expect(try !DatePickerTestSupport.selected("2026-08-18", in: window))
        let before = probe.selections
        let first = try Native.frame(Grid.day("2026-08-01", in: window), in: window)
        let second = try Native.frame(Grid.day("2026-08-02", in: window), in: window)
        try await Grid.click(NSPoint(x: second.midX, y: first.midY), in: window)
        // 两格之间的 4pt 间隙不能命中邻格。
        try await Grid.click(NSPoint(x: neighbor.maxX + 2, y: neighbor.midY), in: window)
        probe.disabled = true
        try await SystemPageHost.settle(window)
        try await Native.click(Grid.day("2026-08-21", in: window), in: window)
        #expect(probe.selections == before && probe.drops.isEmpty)
        probe.dates = CalendarMonthGridDates(monthKey: "2028-02-29", todayKey: "2028-02-29", selectedKey: "2028-02-29")
        try await SystemPageHost.settle(window)
        #expect(try DatePickerTestSupport.selected("2028-02-29", in: window))
        #expect(!NativeSyntaxUI.identifiers(in: window).contains("daybook.date.2028-03-01"))
        #expect(probe.selections == before)
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func monthMatrixAndAccessibility(locale: String, scheme: ColorScheme) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let probe = MonthGridProbe()
        let window = fixture.window(MonthGridProbeView(probe: probe, compact: true), locale: locale, scheme: scheme,
                                    size: NSSize(width: 360, height: 500))
        defer { SystemPageHost.release(window) }
        for (key, first, count, rows) in [("2026-02-01", 1, 28, 4), ("2028-02-29", 2, 29, 5),
            ("2026-08-31", 1, 31, 6), ("2026-12-31", 2, 31, 5), ("2027-01-01", 2, 31, 5)] {
            probe.calendar.firstWeekday = first
            probe.dates = CalendarMonthGridDates(monthKey: key, todayKey: key, selectedKey: key)
            probe.counts = [key: 123456]
            try await SystemPageHost.settle(window)
            let days = Native.buttons(in: window).filter(Grid.belongsToGrid)
            #expect(days.count == count)
            try Native.assertBounds(days, in: window)
            #expect(Set(try days.map { Int(try Native.frame($0, in: window).midY.rounded()) }).count == rows)
            let day = try Grid.day(key, in: window)
            let formatter = DateFormatter()
            formatter.calendar = probe.calendar
            formatter.timeZone = probe.calendar.timeZone
            formatter.locale = Locale(identifier: locale)
            formatter.dateStyle = .full
            #expect(Native.value(day, "accessibilityLabel") as? String == formatter.string(from: try #require(DayKey.date(from: key))))
            #expect(Native.value(day, "accessibilityValue") as? String == L10n.string("calendar.today", locale: Locale(identifier: locale)))
            #expect((Native.value(day, "accessibilityHelp") as? String)?.contains("123") == true)
            let headers = Native.elements(window.contentView).filter {
                (Native.value($0, "accessibilityIdentifier") as? String)?.hasPrefix("daybook.date.weekday.") == true
                    && Grid.belongsToGrid($0)
            }.sorted { (try? Native.frame($0, in: window).minX) ?? 0 < (try? Native.frame($1, in: window).minX) ?? 0 }
            #expect(headers.count == 7)
            let order = WeekdayMask.orderedWeekdays(calendar: probe.calendar)
            for (node, weekday) in zip(headers, order) {
                #expect(Native.value(node, "accessibilityIdentifier") as? String == "daybook.date.weekday.\(weekday)")
                #expect((Native.value(node, "accessibilityLabel") ?? Native.value(node, "accessibilityTitle")
                    ?? Native.value(node, "accessibilityValue")) as? String
                    == WeekdayMask.accessibilityName(weekday, locale: Locale(identifier: locale), calendar: probe.calendar))
            }
            try Native.snapshot(window, name: "monthB-\(key)-\(locale)-\(scheme)")
        }
        #expect(probe.selections.isEmpty && probe.drops.isEmpty)
    }
}
