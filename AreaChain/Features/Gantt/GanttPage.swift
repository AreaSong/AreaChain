import SwiftData
import SwiftUI

struct GanttPage: View {
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query(sort: \TodoItem.createdAt) private var todos: [TodoItem]

    var todayKey: String
    @State private var monthKey: String
    @State private var dropKey: String?

    private let dayWidth: CGFloat = 22
    private let titleWidth: CGFloat = 108

    init(todayKey: String) {
        self.todayKey = todayKey
        _monthKey = State(initialValue: todayKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DaybookPeriodBar(
                title: DayKey.monthTitle(monthKey, calendar: calendar, locale: locale),
                onPrev: { monthKey = DayKey.shiftedMonth(monthKey, by: -1, calendar: calendar) },
                onNext: { monthKey = DayKey.shiftedMonth(monthKey, by: 1, calendar: calendar) },
                onToday: String(monthKey.prefix(7)) == String(todayKey.prefix(7))
                    ? nil
                    : { monthKey = todayKey }
            )
            Text("gantt.hint")
                .font(.system(size: 11))
                .foregroundStyle(DaybookTheme.muted)
            if bars.isEmpty && marks.isEmpty {
                DaybookEmptyState(title: "gantt.empty", systemImage: "calendar")
            } else {
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: 4) {
                        headerRow
                            .padding(.bottom, 2)
                        Divider()
                            .overlay(DaybookTheme.rule.opacity(0.5))
                        ScrollView(.vertical) {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(bars) { bar in
                                    todoRow(bar)
                                }
                                ForEach(routineIDs, id: \.self) { id in
                                    routineRow(id)
                                }
                            }
                            .padding(.bottom, 8)
                        }
                        .daybookScroll()
                    }
                }
                .daybookScroll()
            }
        }
        .daybookPanel(minWidth: 640, minHeight: 420)
    }

    private var days: [String] {
        DayKey.daysInMonth(containing: monthKey, calendar: calendar)
    }

    private var bars: [GanttTodoBar] {
        GanttLayout.todoBars(todos: todos.map(\.snapshot), monthKeys: Set(days))
    }

    private var marks: [GanttRoutineMark] {
        GanttLayout.routineMarks(routines: routines.map(\.snapshot), monthKeys: days, calendar: calendar)
    }

    private var routineIDs: [UUID] {
        var seen: [UUID] = []
        for mark in marks where !seen.contains(mark.routineID) {
            seen.append(mark.routineID)
        }
        return seen
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: titleWidth, height: 18)
            ForEach(days, id: \.self) { key in
                Text(DayKey.dayNumber(key, calendar: calendar))
                    .font(.system(size: 9, weight: key == todayKey ? .semibold : .regular))
                    .foregroundStyle(key == todayKey ? DaybookTheme.ink : DaybookTheme.muted)
                    .frame(width: dayWidth)
                    .accessibilityLabel(DayKey.displayName(key, calendar: calendar, locale: locale))
            }
        }
    }

    private func todoRow(_ bar: GanttTodoBar) -> some View {
        HStack(spacing: 0) {
            Text(bar.title)
                .font(.system(size: 11))
                .foregroundStyle(DaybookTheme.ink)
                .lineLimit(1)
                .help(bar.title)
                .frame(width: titleWidth, alignment: .leading)
                .accessibilityLabel(bar.title)
                .accessibilityValue(DayKey.displayName(bar.dayKey, calendar: calendar, locale: locale))
            ForEach(days, id: \.self) { key in
                dayCell(key, filled: key == bar.dayKey, payload: TodoDragToken.encode(bar.id))
            }
        }
    }

    private func routineRow(_ id: UUID) -> some View {
        let title = marks.first { $0.routineID == id }?.title ?? ""
        let dots = Set(marks.filter { $0.routineID == id }.map(\.dayKey))
        return HStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "repeat")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DaybookTheme.stamp)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(DaybookTheme.muted)
                    .lineLimit(1)
                    .help(title)
            }
            .frame(width: titleWidth, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(title)
            .accessibilityAddTraits(.isStaticText)
            ForEach(days, id: \.self) { key in
                Circle()
                    .fill(dots.contains(key) ? DaybookTheme.stamp : Color.clear)
                    .frame(width: 6, height: 6)
                    .frame(width: dayWidth, height: 22)
            }
        }
    }

    private func dayCell(_ key: String, filled: Bool, payload: String) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(filled ? DaybookTheme.stamp.opacity(0.85) : Color.clear)
            .frame(width: dayWidth - 2, height: 14)
            .frame(width: dayWidth, height: 22)
            .overlay(
                Rectangle()
                    .stroke(dropKey == key ? DaybookTheme.stamp : Color.clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
            .help(filled ? barHelp(key) : "")
            .accessibilityHidden(!filled)
            .accessibilityLabel(filled ? barHelp(key) : "")
            .modifier(TodoDragIfNeeded(payload: filled ? payload : nil))
            .dropDestination(for: String.self) { items, _ in
                dropTodo(items, onto: key)
            } isTargeted: { hovering in
                dropKey = hovering ? key : (dropKey == key ? nil : dropKey)
            }
    }

    private func barHelp(_ key: String) -> String {
        DayKey.displayName(key, calendar: calendar, locale: locale)
    }

    private func dropTodo(_ items: [String], onto key: String) -> Bool {
        guard let id = items.compactMap(TodoDragToken.decode).first,
              let todo = todos.first(where: { $0.id == id })
        else { return false }
        DayBoardMutations.moveTodo(todo, to: key)
        return true
    }
}

struct GanttStandaloneView: View {
    private var dayClock: DayClock { DayClock.shared }
    @State private var dayTick = Date()

    var body: some View {
        let todayKey: String = {
            _ = dayTick
            return dayClock.todayKey
        }()
        GanttPage(todayKey: todayKey)
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                DayClock.shared.refresh()
                dayTick = Date()
            }
    }
}
