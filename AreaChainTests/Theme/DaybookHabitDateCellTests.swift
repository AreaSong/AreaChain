import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DaybookHabitDateCellTests {
    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func publicSamples(locale: String, scheme: ColorScheme) async throws {
        let f = try SettingsButtonTestSupport()
        defer { f.cleanup() }
        let window = f.window(DaybookHabitDateCellSamples().padding(20).background(DaybookPalette.fill.page),
                              locale: locale, scheme: scheme, size: NSSize(width: 280, height: 160))
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        #expect(SettingsButtonTestSupport.buttons(in: window).count == 20)
        for row in 0..<4 {
            for index in 1...5 {
                let node = try HabitMonthTestSupport.day("2026-09-0\(index)", host: "habit.samples.\(row)", in: window)
                #expect(node.value(forKey: "accessibilitySelected") as? Bool == (row % 2 == 1))
            }
        }
        try SettingsButtonTestSupport.snapshot(window, name: "habitC-public-\(locale)-\(scheme)")
    }
}
