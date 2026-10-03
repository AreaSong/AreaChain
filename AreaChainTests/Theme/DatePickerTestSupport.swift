import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@MainActor
enum DatePickerTestSupport {
    typealias Native = SettingsButtonTestSupport

    static func key(_ code: UInt16, _ characters: String, in window: NSWindow) async throws {
        try #require(window.isKeyWindow)
        // 经过应用事件队列，系统弹出层和既有窗口监视器也必须参与派发。
        NSApp.postEvent(try PickerNativeTestSupport.key(code: code, chars: characters, in: window), atStart: false)
        try await SystemPageHost.settle(window)
    }

    static func day(_ key: String, in window: NSWindow) throws -> NSObject {
        try Native.button("daybook.date.\(key)", in: window)
    }

    static func selected(_ key: String, in window: NSWindow) throws -> Bool {
        let node = try day(key, in: window)
        return (node.value(forKey: "accessibilitySelected") as? NSNumber)?.boolValue == true
    }

    static func select(_ key: String, in window: NSWindow) async throws {
        try await Native.click(day(key, in: window), in: window)
    }

    static func hasPicker(_ window: NSWindow) -> Bool {
        NativeSyntaxUI.identifiers(in: window).contains("daybook.datePicker")
    }

    static func popup(excluding window: NSWindow) throws -> NSWindow {
        let windows = NSApp.windows.filter { $0 !== window && $0.isVisible && hasPicker($0) }
        try #require(windows.count == 1)
        return windows[0]
    }
}

@MainActor @Observable
final class DatePickerProbe {
    var selection = "2026-12-31"
    var writes: [String] = []
    var reject = false
    var disabled = false
    var visible = true
    var calendar = Calendar.current
    var binding: Binding<String> {
        Binding(get: { self.selection }, set: { self.writes.append($0); if !self.reject { self.selection = $0 } })
    }
}

struct DatePickerProbeView: View {
    var probe: DatePickerProbe
    var body: some View {
        if probe.visible {
            DaybookDatePicker(selection: probe.binding, todayKey: "2026-12-31")
                .disabled(probe.disabled)
                .environment(\.calendar, probe.calendar)
                .padding(8)
                .background(DaybookPalette.fill.page)
        }
    }
}
