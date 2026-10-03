import SwiftUI

/// 月历网格日期坐标配置
struct CalendarMonthGridDates {
    var monthKey: String
    var todayKey: String
    var selectedKey: String

    init(monthKey: String, todayKey: String, selectedKey: String) {
        self.monthKey = monthKey
        self.todayKey = todayKey
        self.selectedKey = selectedKey
    }
}

struct CalendarMonthGrid: View {
    @Environment(\.calendar) private var calendar

    var dates: CalendarMonthGridDates
    var counts: [String: Int]
    var isCompact: Bool = false
    var onSelect: (String) -> Void
    var onDropTodo: ((UUID, String) -> Void)? = nil

    var monthKey: String { dates.monthKey }
    var todayKey: String { dates.todayKey }
    var selectedKey: String { dates.selectedKey }

    init(
        dates: CalendarMonthGridDates,
        counts: [String: Int],
        isCompact: Bool = false,
        onSelect: @escaping (String) -> Void,
        onDropTodo: ((UUID, String) -> Void)? = nil
    ) {
        self.dates = dates
        self.counts = counts
        self.isCompact = isCompact
        self.onSelect = onSelect
        self.onDropTodo = onDropTodo
    }

    @State private var dropKey: String?

    private var density: DaybookMonthGridDensity { isCompact ? .compact : .regular }

    var body: some View {
        let cells = DaybookMonthGridDay.month(containing: monthKey, calendar: calendar)
        VStack(spacing: DaybookSpacing.xs) {
            DaybookWeekdayHeader()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DaybookSpacing.xs), count: 7), spacing: DaybookSpacing.xs) {
                ForEach(cells) { day in
                    if let key = day.key {
                        cell(key)
                    } else {
                        Color.clear
                            .frame(maxWidth: .infinity, minHeight: density.minimumContentHeight)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("calendar.month.grid")
    }

    private func cell(_ key: String) -> some View {
        let count = counts[key] ?? 0
        return DaybookDateCell(
            dayKey: key, isToday: key == todayKey, isSelected: key == selectedKey,
            presentation: .monthGrid(density), annotation: count > 0 ? Text("\(count)") : nil,
            isDropTarget: dropKey == key
        ) {
            onSelect(key)
        }
        .dropDestination(for: String.self) { items, _ in
            guard let onDropTodo, let id = items.compactMap(TodoDragToken.decode).first else {
                return false
            }
            onDropTodo(id, key)
            return true
        } isTargeted: { hovering in
            withAnimation(DaybookMotion.snappy) {
                dropKey = hovering ? key : (dropKey == key ? nil : dropKey)
            }
        }
        .accessibilityHint(count > 0 ? Text("a11y.calendar.remaining \(count)") : Text(""))
    }

}
