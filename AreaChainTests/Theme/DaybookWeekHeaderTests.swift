import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DaybookWeekHeaderTests {
    typealias Native = SettingsButtonTestSupport

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func originalPixelsGeometryAndSemantics(locale: String, scheme: ColorScheme) async throws {
        let f = try Native()
        defer { f.cleanup() }
        for width in [CGFloat(106), 180] {
            let old = f.window(CalendarWeekHeaderBaseline(day: "2026-09-30")
                .padding(20).background(DaybookPalette.fill.page), locale: locale, scheme: scheme,
                size: NSSize(width: width, height: 100))
            defer { SystemPageHost.release(old) }
            try await SystemPageHost.settle(old)
            let before = try WeekdayPickerTestSupport.bitmap(old)
            let frame = try Native.frame(#require(Native.buttons(in: old).first), in: old)
            #expect(frame.height == 41 && frame.width == width - 40)
            for state in 0..<4 {
                let cell = DaybookDateCell(dayKey: "2026-09-30", isToday: state & 1 != 0, isSelected: state & 2 != 0,
                    presentation: .weekHeader(shortStamp: DayKey.shortStamp("2026-09-30", locale: Locale(identifier: locale)))) {}
                let window = f.window(cell.padding(20).background(DaybookPalette.fill.page), locale: locale,
                                      scheme: scheme, size: NSSize(width: width, height: 100))
                defer { SystemPageHost.release(window) }
                try await SystemPageHost.settle(window)
                let node = try DatePickerTestSupport.day("2026-09-30", in: window)
                #expect(Native.buttons(in: window).count == 1)
                #expect(try Native.frame(node, in: window) == frame)
                #expect(try WeekdayPickerTestSupport.bitmap(window) == before)
                #expect(node.value(forKey: "accessibilitySelected") as? Bool == (state & 2 != 0))
                #expect(Native.value(node, "accessibilityLabel") as? String == fullDate("2026-09-30", locale: locale))
                #expect(Native.value(node, "accessibilityValue") as? String
                    == (state & 1 != 0 ? MenuButtonTestSupport.localized("calendar.today", locale) : ""))
            }
        }
        let window = f.window(DaybookWeekHeaderSamples().padding(20).background(DaybookPalette.fill.page),
            locale: locale, scheme: scheme, size: NSSize(width: 500, height: 100))
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        try Native.snapshot(window, name: "weekE-public-\(locale)-\(scheme)")
    }

    @Test func formatSourcesRemainIndependent() async throws {
        let f = try Native()
        defer { f.cleanup() }
        for identifier in [Calendar.Identifier.gregorian, .buddhist, .hebrew] {
            var calendar = Calendar(identifier: identifier)
            calendar.timeZone = try #require(TimeZone(identifier: "Pacific/Auckland"))
            let day = "2024-02-29"
            let old = f.window(CalendarWeekHeaderBaseline(day: day).environment(\.calendar, calendar)
                .padding(20), size: NSSize(width: 180, height: 100))
            defer { SystemPageHost.release(old) }
            try await SystemPageHost.settle(old)
            let pixels = try WeekdayPickerTestSupport.bitmap(old)
            let cell = DaybookDateCell(dayKey: day, isToday: false, isSelected: false,
                presentation: .weekHeader(shortStamp: DayKey.shortStamp(day, locale: Locale(identifier: "en")))) {}
            let window = f.window(cell.environment(\.calendar, calendar).padding(20),
                                  size: NSSize(width: 180, height: 100))
            defer { SystemPageHost.release(window) }
            try await SystemPageHost.settle(window)
            #expect(try WeekdayPickerTestSupport.bitmap(window) == pixels)
            let node = try DatePickerTestSupport.day(day, in: window)
            #expect(Native.value(node, "accessibilityLabel") as? String == fullDate(day, locale: "en", calendar: calendar))
        }
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func controlsPreviewShowsWeekHeaders(locale: String, scheme: ColorScheme) async throws {
        let f = try Native()
        defer { f.cleanup() }
        let window = f.window(DaybookControlsPreview(localeID: locale, dark: scheme == .dark),
            locale: locale, scheme: scheme, size: NSSize(width: 760, height: 640))
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let nodes = Native.buttons(in: window).filter {
            HabitMonthTestSupport.belongs($0, to: "preview.weekHeader")
        }
        #expect(nodes.count == 4)
        try await Native.reveal(#require(nodes.first), in: window)
        try Native.assertBounds(nodes, in: window)
        try Native.snapshot(window, name: "weekE-gallery-\(locale)-\(scheme)")
    }

    private func fullDate(_ day: String, locale: String, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: locale)
        formatter.dateStyle = .full
        return DayKey.date(from: day, calendar: calendar).map(formatter.string) ?? day
    }
}
