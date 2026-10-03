import SwiftData
import SwiftUI
@testable import AreaChain

/// 第六阶段 C 修改前冻结的绘制；仅供与真实生产组件做几何和像素对照。
struct HabitMonthBaseline: View {
    var routine: DailyRoutine
    var inspectDayKey: String
    @Query private var checks: [RoutineCheck]
    @Environment(\.locale) private var locale

    var body: some View {
        let today = DayClock.shared.todayKey
        let cells = DayKey.monthGrid(containing: inspectDayKey)
        VStack(alignment: .leading, spacing: 6) {
            Text(DayKey.displayName(inspectDayKey, locale: locale))
                .font(DaybookType.label)
                .foregroundStyle(DaybookPalette.text.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                    dayCell(day, today: today)
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: String?, today: String) -> some View {
        let mark = HabitMonth.mark(
            dayKey: day,
            routine: routine.snapshot,
            checks: checks.compactMap(\.snapshot),
            todayKey: today
        )
        if let day, mark != .padding {
            Button {
                WorkspaceNavigation.shared.inspectTask(routine.id, dayKey: day)
            } label: {
                Text(daySuffix(day))
                    .font(DaybookType.micro)
                    .frame(maxWidth: .infinity, minHeight: 22)
                    .foregroundStyle(foreground(mark, selected: day == inspectDayKey))
                    .background(
                        RoundedRectangle(cornerRadius: DaybookRadius.xxs, style: .continuous)
                            .fill(fill(mark, selected: day == inspectDayKey))
                    )
            }
            .buttonStyle(.plain) // control: 习惯月历单日
            .accessibilityLabel(accessibility(day, mark: mark))
        } else {
            Color.clear.frame(height: 22)
        }
    }

    private func daySuffix(_ day: String) -> String {
        String(day.suffix(2))
    }

    private func foreground(_ mark: HabitDayMark, selected: Bool) -> Color {
        if selected { return DaybookPalette.text.onAccent }
        switch mark {
        case .checked, .skipped: return DaybookPalette.accent.base
        case .missed: return DaybookPalette.text.primary
        case .outside, .padding: return DaybookPalette.text.tertiary
        case .open: return DaybookPalette.text.primary
        }
    }

    private func fill(_ mark: HabitDayMark, selected: Bool) -> Color {
        if selected { return DaybookPalette.accent.base }
        switch mark {
        case .checked: return DaybookPalette.accent.fill
        case .skipped: return DaybookPalette.fill.subtle
        case .missed: return DaybookPalette.fill.hover
        default: return .clear
        }
    }

    private func accessibility(_ day: String, mark: HabitDayMark) -> String {
        let name = DayKey.displayName(day, locale: locale)
        let key: String
        switch mark {
        case .checked: key = "habit.month.checked"
        case .skipped: key = "habit.month.skipped"
        case .missed: key = "habit.month.missed"
        default: key = "habit.month.open"
        }
        return name + " " + L10n.string(String.LocalizationValue(key), locale: locale)
    }
}
