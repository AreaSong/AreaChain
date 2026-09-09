import SwiftData
import SwiftUI

struct QuadrantPage: View {
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query(sort: \TodoItem.createdAt) private var todos: [TodoItem]
    @Query private var checks: [RoutineCheck]

    var todayKey: String
    @Bindable private var selection = BoardSelection.shared
    @State private var dropSlot: QuadrantSlot?

    init(todayKey: String) {
        self.todayKey = todayKey
    }

    private var selectedKey: String {
        get { selection.inspectingDayKey }
        nonmutating set { selection.inspectingDayKey = newValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DaybookPeriodBar(
                title: DayKey.displayName(selectedKey, calendar: calendar, locale: locale),
                onPrev: { selectedKey = DayKey.shifted(selectedKey, by: -1, calendar: calendar) },
                onNext: { selectedKey = DayKey.shifted(selectedKey, by: 1, calendar: calendar) },
                onToday: selectedKey == todayKey ? nil : { selectedKey = todayKey }
            )
            Text("quadrant.hint")
                .font(.system(size: 11))
                .foregroundStyle(DaybookTheme.muted)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(QuadrantSlot.allCases) { slot in
                    cell(slot)
                }
            }
        }
        .daybookPanel(minWidth: 560, minHeight: 480)
    }

    private func cell(_ slot: QuadrantSlot) -> some View {
        let rows = rows(in: slot)
        let isTargeted = dropSlot == slot
        return VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(slot.titleKeyName))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DaybookTheme.stamp)
            if rows.isEmpty {
                DaybookEmptyState(title: "quadrant.empty", compact: true)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(rows) { row in
                            chip(row)
                        }
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
        .modernCard(cornerRadius: DaybookRadius.medium, isHovered: isTargeted, isSelected: isTargeted)
        .dropDestination(for: String.self) { items, _ in
            apply(items, to: slot)
        } isTargeted: { hovering in
            withAnimation(ModernMotion.snappy) {
                dropSlot = hovering ? slot : (dropSlot == slot ? nil : dropSlot)
            }
        }
    }

    private func chip(_ row: BoardRow) -> some View {
        HStack(spacing: 6) {
            if isResident(row) {
                Image(systemName: "repeat")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DaybookTheme.stamp)
                    .accessibilityLabel("row.resident")
            }
            Text(title(row))
                .font(.system(size: 12))
                .foregroundStyle(DaybookTheme.ink)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .modernCard(cornerRadius: DaybookRadius.small)
        .contentShape(Rectangle())
        .onTapGesture {
            WorkspaceNavigation.shared.inspectTask(row.id)
        }
        .draggable(payload(row))
    }

    private func rows(in slot: QuadrantSlot) -> [BoardRow] {
        let snapshots = (routines.map(\.snapshot), checks.compactMap(\.snapshot), todos.map(\.snapshot))
        let openRoutines = DayBoardLogic.openRoutines(
            routines: snapshots.0,
            checks: snapshots.1,
            dayKey: selectedKey
        )
        let openTodos = DayBoardLogic.openTodos(todos: snapshots.2, dayKey: selectedKey)
        let mixed: [BoardRow] =
            routines.filter { item in openRoutines.contains { $0.id == item.id } }.map(BoardRow.resident)
            + todos.filter { item in openTodos.contains { $0.id == item.id } }.map(BoardRow.todo)
        return mixed
            .filter { QuadrantSlot.of(important: bits($0).0, urgent: bits($0).1) == slot }
            .sorted { Classification.precedes($0.boardSortKey, $1.boardSortKey) }
    }

    private func bits(_ row: BoardRow) -> (Bool, Bool) {
        switch row {
        case .resident(let item): (item.isImportant, item.isUrgent)
        case .todo(let item): (item.isImportant, item.isUrgent)
        }
    }

    private func title(_ row: BoardRow) -> String {
        switch row {
        case .resident(let item): item.title
        case .todo(let item): item.title
        }
    }

    private func isResident(_ row: BoardRow) -> Bool {
        if case .resident = row { return true }
        return false
    }

    private func payload(_ row: BoardRow) -> String {
        switch row {
        case .resident(let item): TodoDragToken.encodeRoutine(item.id)
        case .todo(let item): TodoDragToken.encode(item.id)
        }
    }

    private func apply(_ items: [String], to slot: QuadrantSlot) -> Bool {
        guard let raw = items.first else { return false }
        if let id = TodoDragToken.decode(raw), let todo = todos.first(where: { $0.id == id }) {
            DayBoardMutations.applyQuadrant(slot, to: todo)
            return true
        }
        if let id = TodoDragToken.decodeRoutine(raw), let routine = routines.first(where: { $0.id == id }) {
            DayBoardMutations.applyQuadrant(slot, to: routine)
            return true
        }
        return false
    }
}

struct QuadrantStandaloneView: View {
    private var dayClock: DayClock { DayClock.shared }
    @State private var dayTick = Date()

    var body: some View {
        let todayKey: String = {
            _ = dayTick
            return dayClock.todayKey
        }()
        QuadrantPage(todayKey: todayKey)
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                DayClock.shared.refresh()
                dayTick = Date()
            }
    }
}
