import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct HabitMonthLayoutTests {
    typealias Native = SettingsButtonTestSupport

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func originalPixelsAndHitBounds(locale: String, scheme: ColorScheme) async throws {
        let f = try HabitMonthTestSupport()
        defer { f.cleanup() }
        for width in [CGFloat(280), 320] {
            for day in ["2026-09-07", "2026-09-08", "2026-09-04", "2026-09-09", "2026-09-01"] {
                let old = f.fixture.window(HabitMonthBaseline(routine: f.routine, inspectDayKey: day)
                    .padding(28).frame(maxHeight: .infinity, alignment: .top).background(DaybookPalette.fill.page),
                    locale: locale, scheme: scheme, size: NSSize(width: width, height: 260))
                defer { SystemPageHost.release(old) }
                try await SystemPageHost.settle(old)
                let before = try HabitMonthTestSupport.frames(old)
                let pixels = try bitmap(old)
                let window = f.fixture.window(HabitCheckMonthView(routine: f.routine, inspectDayKey: day)
                    .padding(28).frame(maxHeight: .infinity, alignment: .top).background(DaybookPalette.fill.page),
                    locale: locale, scheme: scheme, size: NSSize(width: width, height: 260))
                defer { SystemPageHost.release(window) }
                try await SystemPageHost.settle(window)
                #expect(before == (try HabitMonthTestSupport.frames(window)))
                #expect(pixels == (try bitmap(window)), "两位日号、状态/选中和今天无装饰应与原图逐像素一致")
                try assertAccessibility(f, day: day, locale: locale, window: window)
                if day == "2026-09-09" {
                    try Native.snapshot(window, name: "habitC-compare-\(Int(width))-\(locale)-\(scheme)")
                }
            }
        }
        try f.assertUnchanged()
    }

    @Test(arguments: [1, 2])
    func injectedCalendarAndCompleteIdentity(firstWeekday: Int) async throws {
        let f = try HabitMonthTestSupport()
        defer { f.cleanup() }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        calendar.firstWeekday = firstWeekday
        let cases = ["2026-02-15", "2026-09-09", "2026-08-18", "2026-12-31", "2027-01-01", "2024-02-29"]
        let counts = [28, 30, 31, 31, 31, 29]
        let rows = firstWeekday == 1 ? [4, 5, 6, 5, 6, 5] : [5, 5, 6, 5, 5, 5]
        for (index, day) in cases.enumerated() {
            let window = f.fixture.window(HabitCheckMonthView(routine: f.routine, inspectDayKey: day, calendar: calendar)
                .environment(\.calendar, Calendar(identifier: .buddhist)).padding(28),
                size: NSSize(width: 280, height: 260))
            defer { SystemPageHost.release(window) }
            try await SystemPageHost.settle(window)
            let days = DayKey.daysInMonth(containing: day, calendar: calendar)
            let nodes = Native.buttons(in: window)
            let ids = nodes.compactMap { Native.value($0, "accessibilityIdentifier") as? String }
            #expect(Set(ids) == Set(days.map { "daybook.date.\($0)" }))
            #expect(ids.count == counts[index])
            let expectedRows = rows[index]
            #expect(Set(try HabitMonthTestSupport.frames(window).map(\.midY)).count == expectedRows)
            #expect(!ids.contains { $0.contains("weekday") || $0.contains("padding") })
            let selected = try HabitMonthTestSupport.day(day, host: "habit.month.\(f.routine.id)", in: window)
            #expect(selected.value(forKey: "accessibilitySelected") as? Bool == true)
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.locale = Locale(identifier: "en")
            formatter.dateStyle = .full
            #expect(Native.value(selected, "accessibilityLabel") as? String
                    == formatter.string(from: try #require(DayKey.date(from: day, calendar: calendar))))
        }
        try f.assertUnchanged()
    }

    private func assertAccessibility(_ f: HabitMonthTestSupport, day: String, locale: String, window: NSWindow) throws {
        let states = ["01": "open", "04": "missed", "07": "checked", "08": "skipped", "09": "open", "10": "open", "12": "open"]
        for (suffix, state) in states {
            let key = "2026-09-" + suffix
            let node = try HabitMonthTestSupport.day(key, host: "habit.month.\(f.routine.id)", in: window)
            let statusKey = "habit.month.\(state)"
            #expect(Native.value(node, "accessibilityValue") as? String
                    == L10n.string(String.LocalizationValue(statusKey), locale: Locale(identifier: locale)))
            #expect(node.value(forKey: "accessibilitySelected") as? Bool == (key == day))
            let label = try #require(Native.value(node, "accessibilityLabel") as? String)
            #expect(label.contains("2026"))
            #expect(!label.contains(L10n.string(String.LocalizationValue(statusKey),
                                               locale: Locale(identifier: locale))))
        }
    }

    private func bitmap(_ window: NSWindow) throws -> Data {
        let view = try #require(window.contentView)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        return Data(bytes: try #require(bitmap.bitmapData), count: bitmap.bytesPerRow * bitmap.pixelsHigh)
    }
}
