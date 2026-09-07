import SwiftUI

struct CalendarMonthGrid: View {
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    var monthKey: String
    var todayKey: String
    var selectedKey: String
    var counts: [String: Int]
    var onSelect: (String) -> Void
    var onDropTodo: ((UUID, String) -> Void)? = nil

    @State private var dropKey: String?

    var body: some View {
        let cells = DayKey.monthGrid(containing: monthKey, calendar: calendar)
        VStack(spacing: 4) {
            weekdayHeaders
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, key in
                    if let key {
                        cell(key)
                    } else {
                        Color.clear
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .allowsHitTesting(false)
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
            VStack(spacing: 2) {
                Text(DayKey.dayNumber(key, calendar: calendar))
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                Text(count > 0 ? "\(count)" : " ")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(count > 0 ? DaybookTheme.stamp : .clear)
            }
            .foregroundStyle(selected ? DaybookTheme.ink : DaybookTheme.muted)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(selected ? DaybookTheme.stamp.opacity(0.28) : DaybookTheme.ink.opacity(0.001))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(today ? DaybookTheme.stamp : Color.clear, lineWidth: 1.2)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: 52)
        .contentShape(Rectangle())
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(dropKey == key ? DaybookTheme.stamp : Color.clear, lineWidth: 2)
        )
        .dropDestination(for: String.self) { items, _ in
            guard let onDropTodo, let id = items.compactMap(TodoDragToken.decode).first else {
                return false
            }
            onDropTodo(id, key)
            return true
        } isTargeted: { hovering in
            dropKey = hovering ? key : (dropKey == key ? nil : dropKey)
        }
        .accessibilityLabel(DayKey.displayName(key, calendar: calendar, locale: locale))
    }
}
