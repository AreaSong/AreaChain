import SwiftUI

struct CalendarMonthGrid: View {
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    var monthKey: String
    var todayKey: String
    var selectedKey: String
    var counts: [String: Int]
    var onSelect: (String) -> Void

    var body: some View {
        let cells = DayKey.monthGrid(containing: monthKey, calendar: calendar)
        VStack(spacing: 4) {
            weekdayHeaders
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, key in
                    if let key {
                        cell(key)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
    }

    private var weekdayHeaders: some View {
        HStack(spacing: 4) {
            ForEach(WeekdayMask.orderedWeekdays(calendar: calendar), id: \.self) { weekday in
                Text(WeekdayMask.veryShortSymbol(weekday, locale: locale, calendar: calendar))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DaybookTheme.muted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func cell(_ key: String) -> some View {
        let selected = key == selectedKey
        let today = key == todayKey
        let count = counts[key] ?? 0
        return Button {
            onSelect(key)
        } label: {
            VStack(spacing: 1) {
                Text(DayKey.dayNumber(key, calendar: calendar))
                    .font(.system(size: 12, weight: selected ? .semibold : .regular))
                Text(count > 0 ? "\(count)" : " ")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(count > 0 ? DaybookTheme.stamp : Color.clear)
            }
            .foregroundStyle(selected ? DaybookTheme.ink : DaybookTheme.muted)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(selected ? DaybookTheme.stamp.opacity(0.28) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(today ? DaybookTheme.stamp : Color.clear, lineWidth: 1.2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(DayKey.displayName(key, calendar: calendar, locale: locale))
    }
}
