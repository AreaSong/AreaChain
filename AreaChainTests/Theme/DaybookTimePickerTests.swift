import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DaybookTimePickerTests {
    typealias Native = SettingsButtonTestSupport
    typealias Time = TimePickerNativeTestSupport

    @Test func allMinutesAndCalendarDisplayAreLossless() throws {
        for zone in ["America/Los_Angeles", "Asia/Shanghai", "Pacific/Apia"] {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = try #require(TimeZone(identifier: zone))
            let display = DaybookTimePresentation(calendar: calendar)
            for minute in RemindMinutes.range {
                #expect(display.minutes(try #require(display.date(minute))) == minute)
            }
            #expect(display.date(-1) == nil && display.date(1440) == nil)
        }
    }

    @Test func mountExternalNilRejectionDisableAndTeardown() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let probe = TimePickerProbe()
        probe.minutes = nil
        let window = fixture.window(TimePickerProbeView(probe: probe), size: NSSize(width: 180, height: 100))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let picker = try Time.picker(in: window)
        #expect(probe.writes.isEmpty && probe.minutes == nil)
        #expect(picker.accessibilityHelp() == "Not set")
        for value in [0, 720, 1439, -1, 1440] {
            probe.minutes = value
            try await SystemPageHost.settle(window)
            if RemindMinutes.range.contains(value) { #expect(displayed(picker) == value) }
            else { #expect(picker.accessibilityHelp() == "Invalid time") }
            #expect(probe.writes.isEmpty && probe.minutes == value)
        }
        probe.minutes = 720
        try await SystemPageHost.settle(window)
        for locale in ["en_US", "zh-Hans", "en_GB"] {
            probe.locale = Locale(identifier: locale)
            try await SystemPageHost.settle(window)
            #expect(displayed(picker) == 720 && probe.writes.isEmpty)
        }
        try assign(815, to: picker)
        #expect(probe.minutes == 815 && probe.writes == [815])
        probe.reject = true
        try await SystemPageHost.settle(window)
        try assign(900, to: picker)
        #expect(probe.minutes == 815 && displayed(picker) == 815)
        probe.disabled = true
        try await SystemPageHost.settle(window)
        #expect(!picker.isEnabled)
        try assign(1000, to: picker)
        #expect(probe.writes == [815, 900])
        probe.disabled = false
        try await SystemPageHost.settle(window)
        SystemPageHost.release(window)
        try assign(1000, to: picker)
        #expect(probe.writes == [815, 900])
    }

    @Test func nativeDigitsIntermediateValidationAndCarryMatchBaseline() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let probe = TimePickerProbe()
        probe.locale = Locale(identifier: "zh-Hans")
        let window = fixture.window(TimePickerProbeView(probe: probe), size: NSSize(width: 180, height: 100))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let picker = try Time.picker(in: window)
        for minute in [0, 719, 1439] {
            probe.minutes = minute
            try await SystemPageHost.settle(window)
            try await selectHour(picker, in: window)
            try await Time.key(124, "\u{F703}", in: window)
            try await Time.key(126, "\u{F700}", in: window)
            #expect(probe.minutes == (minute + 1) % 1440)
            try await Time.key(125, "\u{F701}", in: window)
            #expect(probe.minutes == minute)
        }
        probe.minutes = 720
        try await SystemPageHost.settle(window)
        try await selectHour(picker, in: window)
        try await Time.key(21, "4", in: window)
        #expect(probe.minutes == 240, "4 已构成完整小时，沿原生规则立即提交")
        let writes = probe.writes
        try await Time.key(25, "9", in: window)
        #expect(probe.writes == writes, "49 不是合法小时")
        try await Time.key(124, "\u{F703}", in: window)
        try await Time.key(21, "4", in: window)
        #expect(probe.writes == writes, "分钟 4 尚处于可继续输入第二位的暂存态")
        // 无关环境刷新不冲掉暂存；失焦由 AppKit 将合法单数字分钟完成为 04。
        probe.disabled = false
        try await SystemPageHost.settle(window)
        window.makeFirstResponder(nil)
        try await SystemPageHost.settle(window)
        #expect(probe.minutes == 244)
        try await selectHour(picker, in: window)
        try await Time.key(124, "\u{F703}", in: window)
        try await Time.key(21, "4", in: window)
        try await Time.key(25, "9", in: window)
        #expect(probe.minutes == 289)
        let committed = probe.writes
        try await Time.key(53, "\u{1B}", in: window)
        #expect(probe.writes == committed)
    }

    @Test(arguments: ["en", "zh-Hans"], [false, true])
    func nativeAppearanceAndLongName(locale: String, dark: Bool) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let probe = TimePickerProbe()
        probe.locale = Locale(identifier: locale)
        let window = fixture.window(TimePickerProbeView(probe: probe, title: "dev.controls.time.long"),
            locale: locale, scheme: dark ? .dark : .light, size: NSSize(width: 180, height: 100))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let picker = try Time.picker(in: window)
        #expect(picker.font?.pointSize == DaybookType.bodySize)
        #expect(picker.datePickerElements == .hourMinute && picker.datePickerStyle == .textFieldAndStepper)
        #expect(picker.accessibilityLabel() == L10n.string("dev.controls.time.long", locale: probe.locale))
        #expect(picker.convert(picker.bounds, to: window.contentView).maxX <= 180)
        try Native.snapshot(window, name: "time-public-\(locale)-\(dark)")
    }

    private func displayed(_ picker: NSDatePicker) -> Int {
        RemindMinutes.from(date: picker.dateValue, calendar: picker.calendar ?? .current)
    }

    private func assign(_ value: Int, to picker: NSDatePicker) throws {
        picker.dateValue = try #require(RemindMinutes.date(minutes: value, calendar: picker.calendar ?? .current))
        picker.sendAction(picker.action, to: picker.target)
    }

    private func selectHour(_ picker: NSDatePicker, in window: NSWindow) async throws {
        let rect = picker.convert(picker.bounds, to: nil)
        try await Time.click(NSPoint(x: rect.minX + 10, y: rect.midY), in: window)
    }
}

struct TimePickerProbeView: View {
    @Bindable var probe: TimePickerProbe
    var title: String.LocalizationValue = "row.time"
    var body: some View {
        DaybookTimePicker(title, minutes: probe.binding)
            .disabled(probe.disabled)
            .environment(\.locale, probe.locale)
            .padding(12)
            .background(DaybookPalette.fill.page)
    }
}
