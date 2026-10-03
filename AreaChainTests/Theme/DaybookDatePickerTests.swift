import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DaybookDatePickerTests {
    typealias Native = SettingsButtonTestSupport
    typealias DateUI = DatePickerTestSupport

    @Test func navigationExternalRejectDisabledAndUnmount() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let probe = DatePickerProbe()
        let window = fixture.window(DatePickerProbeView(probe: probe), size: NSSize(width: 280, height: 280))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        #expect(probe.writes.isEmpty)
        #expect(try DateUI.selected("2026-12-31", in: window))
        try await Native.click(Native.button("calendar.next", in: window), in: window)
        #expect(probe.selection == "2026-12-31" && probe.writes.isEmpty)
        #expect(NativeSyntaxUI.identifiers(in: window).contains("daybook.date.2027-01-01"))
        try await DateUI.select("2027-01-18", in: window)
        #expect(probe.writes == ["2027-01-18"])
        probe.selection = "2028-02-29"
        try await SystemPageHost.settle(window)
        #expect(try DateUI.selected("2028-02-29", in: window))
        probe.reject = true
        try await DateUI.select("2028-02-18", in: window)
        #expect(probe.selection == "2028-02-29" && probe.writes.count == 2)
        #expect(try DateUI.selected("2028-02-29", in: window))
        #expect(try !DateUI.selected("2028-02-18", in: window))
        probe.disabled = true
        try await SystemPageHost.settle(window)
        try await DateUI.select("2028-02-17", in: window)
        #expect(probe.writes.count == 2)
        probe.disabled = false
        try await SystemPageHost.settle(window)
        let retained = try DateUI.day("2028-02-17", in: window)
        probe.visible = false
        try await SystemPageHost.settle(window)
        _ = retained.perform(NSSelectorFromString("accessibilityPerformPress"))
        #expect(probe.writes.count == 2)
    }

    @Test func mouseAndArrowKeysUseCivilDaysWithoutConfirmation() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let probe = DatePickerProbe()
        let window = fixture.window(DatePickerProbeView(probe: probe), size: NSSize(width: 280, height: 280))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try await DateUI.select("2026-12-31", in: window)
        for (code, chars, expected) in [(UInt16(124), "\u{F703}", "2027-01-01"),
            (125, "\u{F701}", "2027-01-08"), (126, "\u{F700}", "2027-01-01"), (123, "\u{F702}", "2026-12-31")] {
            try await DatePickerTestSupport.key(code, chars, in: window)
            #expect(probe.selection == expected)
        }
        let writes = probe.writes
        try await DatePickerTestSupport.key(36, "\r", in: window)
        window.makeFirstResponder(nil)
        #expect(probe.writes == writes)
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func monthLayoutsAndLocalization(locale: String, scheme: ColorScheme) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let probe = DatePickerProbe()
        probe.calendar = Calendar(identifier: .gregorian)
        probe.calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let window = fixture.window(DatePickerProbeView(probe: probe), locale: locale, scheme: scheme,
                                    size: NSSize(width: 280, height: 280))
        defer { SystemPageHost.release(window) }
        for (key, first, count, last, rows) in [("2026-02-01", 1, 28, "2026-02-28", 4),
            ("2028-02-29", 2, 29, "2028-02-29", 5), ("2026-08-31", 1, 31, "2026-08-31", 6),
            ("2026-09-18", 2, 30, "2026-09-30", 5)] {
            probe.selection = key
            probe.calendar.firstWeekday = first
            try await SystemPageHost.settle(window)
            let days = Native.buttons(in: window).filter {
                (Native.value($0, "accessibilityIdentifier") as? String)?.hasPrefix("daybook.date.20") == true
            }
            #expect(days.count == count)
            #expect(try DateUI.selected(key, in: window))
            _ = try DateUI.day(last, in: window)
            try Native.assertBounds(days, in: window)
            let yPositions = try days.map { Int(try Native.frame($0, in: window).midY.rounded()) }
            #expect(Set(yPositions).count == rows)
            let headers = Native.elements(window.contentView).filter {
                (Native.value($0, "accessibilityIdentifier") as? String)?.hasPrefix("daybook.date.weekday.") == true
            }.sorted { (try? Native.frame($0, in: window).minX) ?? 0 < (try? Native.frame($1, in: window).minX) ?? 0 }
            #expect(headers.count == 7)
            #expect(Native.value(try #require(headers.first), "accessibilityIdentifier") as? String == "daybook.date.weekday.\(first)")
            let labels = MenuButtonTestSupport.labels(in: window)
            #expect(labels.contains(DayKey.monthTitle(key, calendar: probe.calendar, locale: Locale(identifier: locale))))
            try Native.snapshot(window, name: "date-\(key)-\(first)-\(locale)-\(scheme)")
        }
        #expect(probe.writes.isEmpty)
    }
    @Test func todaySemanticsAndInvalidValueDoNotWriteOnMount() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let probe = DatePickerProbe()
        let window = fixture.window(DatePickerProbeView(probe: probe), size: NSSize(width: 280, height: 280))
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let today = try DateUI.day("2026-12-31", in: window)
        #expect(Native.value(today, "accessibilityValue") as? String == L10n.string("calendar.today", locale: Locale(identifier: "en")))
        #expect((Native.value(today, "accessibilityLabel") as? String)?.contains("2026") == true)
        probe.selection = "invalid"
        try await SystemPageHost.settle(window)
        #expect(probe.selection == "invalid" && probe.writes.isEmpty)
        #expect(try !DateUI.selected("2026-12-31", in: window))
    }

}
