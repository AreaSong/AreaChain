import AppKit
import SwiftUI
import Testing
@testable import AreaChain

/// 原 ControlsPreview 的同一日格样例，也可单独挂载以核对全部状态。
struct DaybookDateCellSamples: View {
    var onSelect: (String) -> Void = { _ in }

    var body: some View {
        VStack(spacing: DaybookSpacing.sm) {
            ForEach([false, true], id: \.self) { compact in
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4)) {
                    ForEach(0..<8) { state in
                        let key = "2026-09-\(String(format: "%02d", state + (compact ? 11 : 1)))"
                        DaybookDateCell(dayKey: key, isToday: state & 1 != 0, isSelected: state & 2 != 0,
                                        presentation: .monthGrid(compact ? .compact : .regular),
                                        annotation: state == 0 ? nil : Text(verbatim: "123456"), isDropTarget: state & 4 != 0) {
                            onSelect(key)
                        }
                    }
                }
            }
        }
    }
}

@Suite(.serialized) @MainActor
struct DaybookDateCellTests {
    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func stateMatrixAndAction(locale: String, scheme: ColorScheme) async throws {
        let fixture = try SettingsButtonTestSupport()
        defer { fixture.cleanup() }
        var actions: [String] = []
        let window = fixture.window(DaybookDateCellSamples { actions.append($0) }.padding(12)
            .background(DaybookPalette.fill.page), locale: locale, scheme: scheme, size: NSSize(width: 360, height: 300))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let native = SettingsButtonTestSupport.self
        #expect(native.buttons(in: window).count == 16)
        try native.assertBounds(native.buttons(in: window), in: window)
        try await native.click(DatePickerTestSupport.day("2026-09-08", in: window), in: window)
        #expect(actions == ["2026-09-08"])
        // 公共动作不生成乐观选中；此处选择仍由传入的 state 决定。
        #expect(try DatePickerTestSupport.selected("2026-09-08", in: window))
        #expect(try !DatePickerTestSupport.selected("2026-09-01", in: window))
        try native.snapshot(window, name: "monthB-states-\(locale)-\(scheme)")
    }
}
