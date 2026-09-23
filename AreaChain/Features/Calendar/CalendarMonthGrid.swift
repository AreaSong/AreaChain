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
    @Environment(\.locale) private var locale
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

    private var cellHeight: CGFloat { isCompact ? 28 : 52 }

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
                            .frame(maxWidth: .infinity, minHeight: cellHeight)
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
                    .font(DaybookType.label)
                    .foregroundStyle(DaybookPalette.text.secondary)
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
                    .font(DaybookType.body.weight(selected ? .semibold : .regular))
                Text(count > 0 ? "\(count)" : " ")
                    .font(.system(size: 9, weight: .semibold, design: .rounded)) // token-exempt: 日期计数用圆体
                    .foregroundStyle(count > 0 ? DaybookPalette.accent.base : .clear)
            }
            .foregroundStyle(selected ? DaybookPalette.text.primary : DaybookPalette.text.secondary)
            .frame(maxWidth: .infinity, minHeight: cellHeight)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous) // token-exempt: 今日环、选中与投放三态
                    .fill(selected ? DaybookPalette.accent.base.opacity(0.18) : DaybookPalette.cardSurface) // token-exempt: 18% 印章底没有对应令牌
            )
            .overlay(
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous) // token-exempt: 今日环、选中与投放三态
                    .stroke(today ? DaybookPalette.accent.base : (selected ? DaybookPalette.accent.base.opacity(0.4) : DaybookPalette.border.default.opacity(0.3)), lineWidth: today ? 1.4 : 0.8) // token-exempt: 40% 印章色和 30% 分隔线没有对应令牌
            )
            .contentShape(RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous))
        }
        .buttonStyle(DaybookButtonStyle(.quiet))
        .frame(maxWidth: .infinity, minHeight: cellHeight)
        .contentShape(Rectangle())
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous) // token-exempt: 今日环、选中与投放三态
                .stroke(dropKey == key ? DaybookPalette.accent.base : Color.clear, lineWidth: 2)
        )
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
        .accessibilityLabel(cellLabel(key: key, count: count, today: today))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityHint(count > 0 ? Text("a11y.calendar.remaining \(count)") : Text(""))
    }

    private func cellLabel(key: String, count: Int, today: Bool) -> String {
        let day = DayKey.displayName(key, calendar: calendar, locale: locale)
        if today {
            return L10n.string("a11y.calendar.today \(day)", locale: locale)
        }
        return day
    }
}
