import AppKit
import SwiftUI
import Testing
@testable import AreaChain

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
