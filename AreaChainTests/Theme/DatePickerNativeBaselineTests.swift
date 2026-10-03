import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DatePickerNativeBaselineTests {
    @Test func originalGraphicalBehavior() async throws {
        let fixture = try SettingsButtonTestSupport()
        defer { fixture.cleanup() }
        var commits: [String] = []
        let window = fixture.window(OriginalDateSchedulePicker(initialKey: "2026-12-31") { commits.append($0) },
                                    size: NSSize(width: 300, height: 340))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let picker = try TimePickerNativeTestSupport.picker(in: window)
        #expect(DayKey.from(picker.dateValue) == "2026-12-31")
        record(picker, "initial")
        try SettingsButtonTestSupport.snapshot(window, name: "date-original")
        // 位置来自本机原生位图基线；NSDatePicker 的日历箭头没有独立 AX 子节点。
        let rect = picker.convert(picker.bounds, to: nil)
        for (x, stage) in [(rect.maxX - 8, "next-month"), (rect.maxX - 36, "previous-month")] {
            try await TimePickerNativeTestSupport.click(NSPoint(x: x, y: rect.maxY - 10), in: window)
            record(picker, stage)
            try SettingsButtonTestSupport.snapshot(window, name: "date-original-\(stage)")
            #expect(commits.isEmpty)
        }
        window.makeFirstResponder(picker)
        for (code, chars, label) in [(UInt16(124), "\u{F703}", "right"), (125, "\u{F701}", "down"),
                                    (126, "\u{F700}", "up"), (123, "\u{F702}", "left"),
                                    (36, "\r", "return"), (53, "\u{1B}", "escape")] {
            try await TimePickerNativeTestSupport.key(code, chars, in: window)
            record(picker, label)
            #expect(commits.isEmpty)
        }
        window.makeFirstResponder(nil)
        record(picker, "blur")
        #expect(commits.isEmpty)
        try await SettingsButtonTestSupport.click(SettingsButtonTestSupport.button("day.confirm", in: window), in: window)
        #expect(commits == [DayKey.from(picker.dateValue)])
    }

    private func record(_ picker: NSDatePicker, _ stage: String) {
        let nodes = SettingsButtonTestSupport.elements(picker).map { node in
            ["accessibilityRole", "accessibilityLabel", "accessibilityValue"].map {
                String(describing: SettingsButtonTestSupport.value(node, $0) ?? "nil")
            }.joined(separator: ":")
        }
        print("DATE_BASELINE \(stage) value=\(DayKey.from(picker.dateValue)) ax=\(nodes)")
    }
}

/// 冻结迁移前生产选择/确认实现，仅作合成日期原生对照。
private struct OriginalDateSchedulePicker: View {
    var initialKey: String
    var onPick: (String) -> Void
    @State private var pickedDate = Date()
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("day.pick.title").font(DaybookType.caption)
            DatePicker("day.date", selection: $pickedDate, displayedComponents: .date)
                .datePickerStyle(.graphical).labelsHidden()
            Button("day.confirm") { onPick(DayKey.from(pickedDate)) }
                .buttonStyle(DaybookButtonStyle(.prominent))
        }.padding(12)
            .onAppear { pickedDate = DayKey.date(from: initialKey) ?? .now }
    }
}
