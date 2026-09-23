import SwiftData
import SwiftUI

struct GanttPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query(sort: \TodoItem.createdAt) private var todos: [TodoItem]

    var todayKey: String
    @State private var monthKey: String
    @State private var dropTarget: GanttDropTarget?
    @State private var selection = TaskSelection()
    @State private var drag: GanttDragState?

    private let dayWidth = GanttRowMetrics.dayWidth
    private let titleWidth = GanttRowMetrics.titleWidth

    init(todayKey: String) {
        self.todayKey = todayKey
        _monthKey = State(initialValue: todayKey)
    }

    var body: some View {
        DaybookPage(minWidth: 640, minHeight: 420, fullWidth: true) {
            DaybookPeriodBar(
                title: DayKey.monthTitle(monthKey, calendar: calendar, locale: locale),
                onPrev: { monthKey = DayKey.shiftedMonth(monthKey, by: -1, calendar: calendar) },
                onNext: { monthKey = DayKey.shiftedMonth(monthKey, by: 1, calendar: calendar) },
                onToday: String(monthKey.prefix(7)) == String(todayKey.prefix(7))
                    ? nil
                    : { monthKey = todayKey }
            )
            Text("gantt.hint")
                .font(DaybookType.subtitle)
                .foregroundStyle(DaybookPalette.text.secondary)
            if bars.isEmpty && marks.isEmpty {
                DaybookEmptyState(title: "gantt.empty", systemImage: "calendar")
            } else {
                timeline
            }
        }
        .onChange(of: monthKey) { _, _ in resetInteraction() }
        .onChange(of: bars) { _, current in
            selection.reconcile(with: current.map(\.id))
            if let drag, !drag.matches(current) { self.drag = nil }
        }
        .onDisappear { resetInteraction() }
    }

    private var timeline: some View {
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 4) {
                headerRow.padding(.bottom, 2)
                DaybookDivider(opacity: 0.5)
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(bars) { bar in todoRow(bar) }
                        ForEach(routineIDs, id: \.self) { id in routineRow(id) }
                    }
                    .padding(.bottom, 8)
                }
                .daybookScroll()
            }
        }
        .daybookScroll()
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
                    .font(DaybookType.micro.weight(key == todayKey ? .semibold : .regular))
                    .foregroundStyle(key == todayKey ? DaybookPalette.text.primary : DaybookPalette.text.secondary)
                    .frame(width: dayWidth)
                    .accessibilityLabel(DayKey.displayName(key, calendar: calendar, locale: locale))
            }
        }
    }

    private func todoRow(_ bar: GanttTodoBar) -> some View {
        let displayedDay = drag?.previewDay(for: bar.id) ?? bar.dayKey
        let isSelected = selection.ids.contains(bar.id)
        return HStack(spacing: 0) {
            Text(bar.title)
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.primary)
                .lineLimit(1)
                .help(bar.title)
                .frame(width: titleWidth, alignment: .leading)
                .accessibilityHidden(true)
            ForEach(days, id: \.self) { key in
                dayCell(key, rowID: bar.id, filled: key == displayedDay, selected: isSelected)
            }
        }
        .frame(height: GanttRowMetrics.height)
        .background(isSelected ? DaybookPalette.fill.selection : Color.clear, in: RoundedRectangle(cornerRadius: DaybookRadius.xs))
        .overlay {
            GanttRowPointerRegion(bar: bar, displayedDay: displayedDay, days: days, isSelected: isSelected) {
                handle($0, for: bar)
            }
        }
    }

    private func routineRow(_ id: UUID) -> some View {
        let title = marks.first { $0.routineID == id }?.title ?? ""
        let dots = Set(marks.filter { $0.routineID == id }.map(\.dayKey))
        return HStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "repeat")
                    .font(DaybookType.micro.weight(.bold))
                    .foregroundStyle(DaybookPalette.accent.base)
                    .accessibilityHidden(true)
                Text(title)
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .lineLimit(1)
                    .help(title)
            }
            .frame(width: titleWidth, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                resetInteraction()
                let inspectKey = dots.contains(todayKey)
                    ? todayKey
                    : (days.first { dots.contains($0) } ?? todayKey)
                BoardSelection.shared.inspectBoard(inspectKey)
                WorkspaceNavigation.shared.inspectTask(id)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(title)
            .accessibilityAddTraits(.isButton)
            ForEach(days, id: \.self) { key in
                Circle() // token-exempt: 习惯完成点，不是按钮
                    .fill(dots.contains(key) ? DaybookPalette.accent.base : Color.clear)
                    .frame(width: 6, height: 6)
                    .frame(width: dayWidth, height: 22)
            }
        }
    }

    private func dayCell(_ key: String, rowID: UUID, filled: Bool, selected: Bool) -> some View {
        let target = GanttDropTarget(rowID: rowID, dayKey: key)
        return RoundedRectangle(cornerRadius: DaybookRadius.xxs, style: .continuous) // token-exempt: 甘特色块是数据标记，不是卡片
            .fill(filled ? DaybookPalette.accent.base.opacity(0.85) : Color.clear) // token-exempt: 85% 印章色没有对应令牌
            .frame(width: dayWidth - 2, height: 14)
            .frame(width: dayWidth, height: 22)
            .overlay {
                RoundedRectangle(cornerRadius: DaybookRadius.xs) // token-exempt: 甘特色块是数据标记，不是卡片
                    .stroke((filled && selected) || dropTarget == target ? DaybookPalette.accent.base : Color.clear, lineWidth: 1.5)
            }
            .contentShape(Rectangle())
            .accessibilityHidden(true)
            .dropDestination(for: String.self) { items, _ in
                dropTodo(items, onto: key)
            } isTargeted: { hovering in
                dropTarget = hovering ? target : (dropTarget == target ? nil : dropTarget)
            }
    }

    private func handle(_ action: GanttPointerAction, for bar: GanttTodoBar) {
        switch action {
        case .select(let modifiers):
            selection.select(bar.id, in: bars.map(\.id), modifiers: modifiers)
        case .inspect:
            BoardSelection.shared.inspectBoard(bar.dayKey)
            WorkspaceNavigation.shared.inspectTask(bar.id)
        case .dragBegan:
            beginDrag(bar)
        case .dragChanged(let translation):
            drag?.update(dayOffset: Int((translation / dayWidth).rounded()))
        case .dragEnded:
            commitDrag()
        case .cancel:
            if drag != nil { drag = nil } else { selection.focus(nil) }
            dropTarget = nil
        case .moveByDays(let offset):
            beginDrag(bar)
            drag?.update(dayOffset: offset)
            commitDrag()
        }
    }

    private func beginDrag(_ bar: GanttTodoBar) {
        if !selection.ids.contains(bar.id) { selection.focus(bar.id) }
        dropTarget = nil
        drag = GanttDragState(sourceID: bar.id, selectedIDs: selection.ids, bars: bars, days: days)
    }

    private func commitDrag() {
        guard let drag else { return }
        self.drag = nil
        guard GanttRescheduling.commit(drag.moves, todos: todos, context: modelContext) else { return }
        if let id = WorkspaceNavigation.shared.selectedTaskID, let day = drag.previewDay(for: id) {
            BoardSelection.shared.inspectBoard(day)
        }
    }

    private func resetInteraction() {
        drag = nil
        dropTarget = nil
        selection.focus(nil)
    }

    private func dropTodo(_ items: [String], onto key: String) -> Bool {
        dropTarget = nil
        guard let id = items.compactMap(TodoDragToken.decode).first,
              let todo = todos.first(where: { $0.id == id && !$0.isDone && $0.deletedAt == nil })
        else { return false }
        return DayBoardMutations.moveTodo(todo, to: key)
    }
}

private struct GanttDropTarget: Equatable {
    let rowID: UUID
    let dayKey: String
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
