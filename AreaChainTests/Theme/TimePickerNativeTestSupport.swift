import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@MainActor
enum TimePickerNativeTestSupport {
    typealias Native = SettingsButtonTestSupport

    static func picker(in window: NSWindow) throws -> NSDatePicker {
        try #require(Native.elements(window.contentView).compactMap { $0 as? NSDatePicker }.first)
    }

    static func key(_ code: UInt16, _ characters: String, in window: NSWindow) async throws {
        try #require(window.isKeyWindow)
        NSApp.sendEvent(try PickerNativeTestSupport.key(code: code, chars: characters, in: window))
        try await SystemPageHost.settle(window)
    }

    static func click(_ point: NSPoint, in window: NSWindow) async throws {
        try #require(window.isKeyWindow)
        // 日期单元的鼠标追踪要从事件队列取得 mouseUp，不能在同步 mouseDown 返回后才发送。
        NSApp.postEvent(try MenuButtonTestSupport.mouse(.leftMouseUp, at: point, in: window), atStart: false)
        NSApp.sendEvent(try MenuButtonTestSupport.mouse(.leftMouseDown, at: point, in: window))
        try await SystemPageHost.settle(window)
    }

    static func record(_ picker: NSDatePicker, _ probe: TimePickerProbe, _ stage: String) {
        let values = Native.elements(picker).map { node in
            ["accessibilityRole", "accessibilityLabel", "accessibilityValue"].map {
                String(describing: Native.value(node, $0) ?? "nil")
            }.joined(separator: ":")
        }
        print("TIME_BASELINE \(stage) model=\(String(describing: probe.minutes)) writes=\(probe.writes) " +
              "native=\(RemindMinutes.from(date: picker.dateValue, calendar: picker.calendar ?? .current)) " +
              "style=\(picker.datePickerStyle.rawValue) continuous=\(picker.isContinuous) ax=\(values)")
    }
}

@MainActor @Observable
final class TimePickerProbe {
    var minutes: Int? = 720
    var writes: [Int?] = []
    var reject = false
    var disabled = false
    var locale = Locale.current
    var binding: Binding<Int?> {
        Binding(get: { self.minutes }, set: { self.writes.append($0); if !self.reject { self.minutes = $0 } })
    }
}

/// 保留迁移前转换作为原生对照；只有合成分钟，不能作为生产持久化适配。
struct OriginalTimePickerProbe: View {
    @Bindable var probe: TimePickerProbe
    var body: some View {
        VStack {
            DatePicker("row.time", selection: Binding(
                get: { RemindMinutes.date(minutes: probe.minutes ?? RemindMinutes.from(date: .now)) ?? .now },
                set: { probe.binding.wrappedValue = RemindMinutes.from(date: $0) }
            ), displayedComponents: .hourAndMinute)
            .labelsHidden()
            .padding(12)
            .frame(minWidth: 180)
            TextField("Synthetic adjacent title", text: .constant("Unsubmitted title"))
        }
        .environment(\.locale, probe.locale)
    }
}
