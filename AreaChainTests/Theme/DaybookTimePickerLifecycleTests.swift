import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DaybookTimePickerLifecycleTests {
    typealias Native = SettingsButtonTestSupport
    typealias Time = TimePickerNativeTestSupport

    @Test func mountingAndExternalChangesLeaveAdjacentEditorAlone() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let state = TimeFocusProbe()
        let window = fixture.window(TimeFocusView(state: state), size: NSSize(width: 320, height: 160))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let field = try #require(Native.elements(window.contentView).compactMap { $0 as? NSTextField }.first { $0.isEditable })
        window.makeFirstResponder(field)
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.insertText("Synthetic unsaved draft", replacementRange: editor.selectedRange())
        state.show = true
        try await SystemPageHost.settle(window)
        let picker = try Time.picker(in: window)
        state.time.minutes = 1439
        state.time.locale = Locale(identifier: "zh-Hans")
        try await SystemPageHost.settle(window)
        #expect(window.firstResponder === editor && state.submits == 0)
        #expect(state.draft == "Synthetic unsaved draft" && state.time.writes.isEmpty)
        #expect(RemindMinutes.from(date: picker.dateValue, calendar: picker.calendar ?? .current) == 1439)
        state.show = false
        try await SystemPageHost.settle(window)
        #expect(window.firstResponder === editor && state.submits == 0)
    }

    @Test func partialInputEscapeDisableAndDetachDoNotFlushLateValues() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let probe = TimePickerProbe()
        probe.locale = Locale(identifier: "zh-Hans")
        let window = fixture.window(TimePickerProbeView(probe: probe), size: NSSize(width: 180, height: 100))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let picker = try Time.picker(in: window)
        let rect = picker.convert(picker.bounds, to: nil)
        try await Time.click(NSPoint(x: rect.minX + 10, y: rect.midY), in: window)
        try await Time.key(124, "\u{F703}", in: window)
        try await Time.key(21, "4", in: window)
        #expect(probe.writes.isEmpty)
        try await Time.key(53, "\u{1B}", in: window)
        #expect(probe.writes.isEmpty)
        probe.disabled = true
        try await SystemPageHost.settle(window)
        try await Time.click(NSPoint(x: rect.maxX - 6, y: rect.midY), in: window)
        try await Time.key(126, "\u{F700}", in: window)
        #expect(probe.writes.isEmpty && probe.minutes == 720)
        SystemPageHost.release(window)
        picker.sendAction(picker.action, to: picker.target)
        #expect(probe.writes.isEmpty)
    }

    @Test(arguments: ["en", "zh-Hans"], [false, true])
    func galleryUsesProductionInputsAndExternalUpdate(locale: String, dark: Bool) async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let window = fixture.window(DaybookControlsPreview(localeID: locale, dark: dark, longLabels: true),
            locale: locale, scheme: dark ? .dark : .light, size: NSSize(width: 760, height: 640))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let pickers = Native.elements(window.contentView).compactMap { $0 as? DaybookTimeField }
        #expect(pickers.count == 3 && pickers.filter { !$0.isEnabled }.count == 1)
        let first = try #require(pickers.first { $0.accessibilityLabel() ==
            L10n.string("dev.controls.time.long", locale: Locale(identifier: locale)) })
        let old = first.dateValue
        let update = try Native.button("preview.time.external", locale: locale, in: window)
        try await Native.reveal(update, in: window)
        try await Native.click(update, in: window)
        #expect(first.dateValue != old)
        try Native.snapshot(window, name: "time-gallery-\(locale)-\(dark)")
    }

    @Test func windowCloseAndDisableDuringPendingInputDoNotSubmit() async throws {
        let fixture = try Native()
        defer { fixture.cleanup() }
        let probe = TimePickerProbe()
        probe.locale = Locale(identifier: "zh-Hans")
        let window = fixture.window(TimePickerProbeView(probe: probe), size: NSSize(width: 180, height: 100))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let picker = try Time.picker(in: window)
        let rect = picker.convert(picker.bounds, to: nil)
        try await Time.click(NSPoint(x: rect.minX + 10, y: rect.midY), in: window)
        try await Time.key(124, "\u{F703}", in: window)
        try await Time.key(21, "4", in: window)
        probe.disabled = true
        try await SystemPageHost.settle(window)
        #expect(probe.writes.isEmpty && probe.minutes == 720)
        probe.disabled = false
        probe.minutes = 0
        try await SystemPageHost.settle(window)
        #expect(RemindMinutes.from(date: picker.dateValue, calendar: picker.calendar ?? .current) == 0)
        try await Time.click(NSPoint(x: rect.minX + 10, y: rect.midY), in: window)
        try await Time.key(124, "\u{F703}", in: window)
        try await Time.key(21, "4", in: window)
        window.close()
        try await SystemPageHost.settle(window)
        picker.sendAction(picker.action, to: picker.target)
        #expect(probe.writes.isEmpty && probe.minutes == 0)
    }
}

@MainActor @Observable
private final class TimeFocusProbe {
    var show = false
    var draft = ""
    var submits = 0
    let time = TimePickerProbe()
}

private struct TimeFocusView: View {
    @Bindable var state: TimeFocusProbe
    @State private var focused = false
    var body: some View {
        VStack {
            SyntaxTextField(text: $state.draft, placeholder: "Synthetic draft", focused: $focused,
                onSubmit: { state.submits += 1 })
            if state.show { TimePickerProbeView(probe: state.time) }
        }.padding(12)
    }
}
