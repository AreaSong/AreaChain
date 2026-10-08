import SwiftUI

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
