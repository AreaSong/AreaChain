import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TimePickerNativeBaselineTests {
    typealias Native = SettingsButtonTestSupport
    typealias Time = TimePickerNativeTestSupport

    @Test(arguments: [false, true])
    func nativeMouseArrowsMatchOriginal(publicControl: Bool) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let probe = TimePickerProbe()
        probe.locale = Locale(identifier: "zh-Hans")
        let window = fixture.window(Group {
            if publicControl { TimePickerProbeView(probe: probe) }
            else { OriginalTimePickerProbe(probe: probe) }
        }, size: NSSize(width: 180, height: 100))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let picker = try Time.picker(in: window)
        let rect = picker.convert(picker.bounds, to: nil)
        try await Time.click(NSPoint(x: rect.minX + 10, y: rect.midY), in: window)
        let arrows = Native.elements(picker).filter {
            Native.value($0, "accessibilityRole") as? String == "AXButton"
        }.sorted { (try? Native.frame($0, in: window).midY) ?? 0 > (try? Native.frame($1, in: window).midY) ?? 0 }
        try #require(arrows.count == 2)
        for (index, value) in [780, 720].enumerated() {
            let frame = try Native.frame(arrows[index], in: window)
            try await Time.click(NSPoint(x: frame.midX, y: frame.midY), in: window)
            #expect(probe.minutes == value)
        }
        #expect(probe.writes == [780, 720])
    }

    @Test func originalIncompleteInvalidAndBoundaries() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let probe = TimePickerProbe()
        probe.locale = Locale(identifier: "zh-Hans")
        let window = fixture.window(OriginalTimePickerProbe(probe: probe), size: NSSize(width: 180, height: 100))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let picker = try Time.picker(in: window)
        for minute in [0, 719, 1439] {
            probe.minutes = minute
            try await SystemPageHost.settle(window)
            let rect = picker.convert(picker.bounds, to: nil)
            try await Time.click(NSPoint(x: rect.minX + 10, y: rect.midY), in: window)
            try await Time.key(124, "\u{F703}", in: window)
            try await Time.key(126, "\u{F700}", in: window)
            Time.record(picker, probe, "boundary-up-\(minute)")
            try await Time.key(125, "\u{F701}", in: window)
            Time.record(picker, probe, "boundary-down-\(minute)")
        }
        probe.minutes = 720
        try await SystemPageHost.settle(window)
        let rect = picker.convert(picker.bounds, to: nil)
        try await Time.click(NSPoint(x: rect.minX + 10, y: rect.midY), in: window)
        try await Time.key(21, "4", in: window)
        Time.record(picker, probe, "single-hour-4")
        try await Time.key(25, "9", in: window)
        Time.record(picker, probe, "invalid-hour-49")
        try await Time.key(124, "\u{F703}", in: window)
        try await Time.key(21, "4", in: window)
        Time.record(picker, probe, "partial-minute-4")
        window.makeFirstResponder(nil)
        try await SystemPageHost.settle(window)
        Time.record(picker, probe, "partial-blur")
        #expect(RemindMinutes.clamped(probe.minutes) != nil)
    }

    @Test(arguments: ["en", "zh-Hans", Locale.current.identifier])
    func originalProgrammaticAndKeyboardBaseline(locale: String) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let probe = TimePickerProbe()
        probe.locale = Locale(identifier: locale)
        let window = fixture.window(OriginalTimePickerProbe(probe: probe), size: NSSize(width: 180, height: 100))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let picker = try Time.picker(in: window)
        #expect(probe.writes.isEmpty)
        Time.record(picker, probe, "mount-\(locale)")
        for minute in [0, 720, 1439, -1, 1440] {
            probe.minutes = minute
            try await SystemPageHost.settle(window)
            Time.record(picker, probe, "external-\(minute)-\(locale)")
            #expect(probe.writes.isEmpty)
        }
        probe.minutes = nil
        try await SystemPageHost.settle(window)
        Time.record(picker, probe, "nil-\(locale)")
        #expect(probe.writes.isEmpty)
        probe.minutes = 720
        try await SystemPageHost.settle(window)
        picker.dateValue = try #require(RemindMinutes.date(minutes: 1439))
        try await SystemPageHost.settle(window)
        Time.record(picker, probe, "dateValue-only-\(locale)")
        #expect(probe.writes.isEmpty && probe.minutes == 720)
        picker.sendAction(picker.action, to: picker.target)
        try await SystemPageHost.settle(window)
        Time.record(picker, probe, "target-action-\(locale)")
        probe.minutes = 720
        try await SystemPageHost.settle(window)
        let rect = picker.convert(picker.bounds, to: nil)
        try await Time.click(NSPoint(x: rect.minX + 10, y: rect.midY), in: window)
        for (code, chars, stage) in [(UInt16(18), "1", "digit-1"), (19, "2", "digit-2"),
                                    (124, "\u{F703}", "right"), (21, "4", "minute-4"),
                                    (25, "9", "minute-9"), (126, "\u{F700}", "up"),
                                    (125, "\u{F701}", "down"), (53, "\u{1B}", "escape"),
                                    (48, "\t", "tab")] {
            try await Time.key(code, chars, in: window)
            Time.record(picker, probe, "\(stage)-\(locale)")
        }
        try Native.snapshot(window, name: "time-original-\(locale)")
        let writes = probe.writes
        window.makeFirstResponder(nil)
        try await SystemPageHost.settle(window)
        Time.record(picker, probe, "blur-\(locale)")
        SystemPageHost.release(window)
        #expect(probe.writes == writes)
    }
}
