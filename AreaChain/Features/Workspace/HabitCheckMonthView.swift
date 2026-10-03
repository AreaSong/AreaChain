import SwiftData
import SwiftUI

/// 检查器里的单月打卡。点某一天只切换检查日，不改打卡。
struct HabitCheckMonthView: View {
    var routine: DailyRoutine
    var inspectDayKey: String
    // 生产沿原 Calendar.current；局部注入只用于合成日历，三处日期语义使用同一份值。
    var calendar: Calendar = .current
    @Query private var checks: [RoutineCheck]
    @Environment(\.locale) private var locale

    var body: some View {
        let today = DayClock.shared.todayKey
        let cells = DaybookMonthGridDay.month(containing: inspectDayKey, calendar: calendar)
        VStack(alignment: .leading, spacing: DaybookMetrics.HabitMonthGrid.headingSpacing) {
            Text(DayKey.displayName(inspectDayKey, calendar: calendar, locale: locale))
                .font(DaybookType.label)
                .foregroundStyle(DaybookPalette.text.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DaybookMetrics.HabitMonthGrid.columnSpacing), count: 7),
                      spacing: DaybookMetrics.HabitMonthGrid.rowSpacing) {
                ForEach(cells) { day in
                    dayCell(day.key, today: today)
                }
            }
        }
        .environment(\.calendar, calendar)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("habit.month.\(routine.id)")
    }

    @ViewBuilder
    private func dayCell(_ day: String?, today: String) -> some View {
        let mark = HabitMonth.mark(
            dayKey: day,
            routine: routine.snapshot,
            checks: checks.compactMap(\.snapshot),
            todayKey: today,
            calendar: calendar
        )
        if let day, mark != .padding {
            DaybookDateCell(dayKey: day, isToday: day == today, isSelected: day == inspectDayKey,
                            presentation: .habit(presentation(mark)), statusDescription: accessibility(mark)) {
                WorkspaceNavigation.shared.inspectTask(routine.id, dayKey: day)
            }
        } else {
            Color.clear.frame(height: DaybookMetrics.HabitMonthGrid.minimumContentHeight)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func presentation(_ mark: HabitDayMark) -> DaybookHabitDateState {
        switch mark {
        case .checked: .checked
        case .skipped: .skipped
        case .missed: .missed
        case .open: .open
        case .outside, .padding: .outside
        }
    }

    private func accessibility(_ mark: HabitDayMark) -> String {
        let key: String
        switch mark {
        case .checked: key = "habit.month.checked"
        case .skipped: key = "habit.month.skipped"
        case .missed: key = "habit.month.missed"
        default: key = "habit.month.open"
        }
        return L10n.string(String.LocalizationValue(key), locale: locale)
    }
}
