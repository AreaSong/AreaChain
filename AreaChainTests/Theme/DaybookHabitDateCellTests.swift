import AppKit
import SwiftUI
import Testing
@testable import AreaChain

/// 原展示里的公共习惯日格：五态、各自选中和 today 的交叉呈现。
struct DaybookHabitDateCellSamples: View {
    var body: some View {
        VStack(spacing: DaybookSpacing.xs) {
            ForEach(0..<4) { row in
                HStack(spacing: DaybookMetrics.HabitMonthGrid.columnSpacing) {
                    ForEach(Array(DaybookHabitDateState.allCases.enumerated()), id: \.offset) { index, state in
                        DaybookDateCell(dayKey: "2026-09-0\(index + 1)", isToday: row > 1, isSelected: row % 2 == 1,
                                        presentation: .habit(state), statusDescription: status(state)) { }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("habit.samples.\(row)")
            }
        }
    }

    @Environment(\.locale) private var locale
    private func status(_ state: DaybookHabitDateState) -> String {
        let key: String = switch state {
        case .checked: "habit.month.checked"
        case .skipped: "habit.month.skipped"
        case .missed: "habit.month.missed"
        case .open, .outside: "habit.month.open"
        }
        return L10n.string(String.LocalizationValue(key), locale: locale)
    }
}

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
