import SwiftData
import SwiftUI

struct QuadrantPage: View {
    @Environment(\.workspaceEmbedded) private var embedded
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query(sort: \TodoItem.createdAt) private var todos: [TodoItem]
    @Query private var checks: [RoutineCheck]

    var todayKey: String
    @Bindable private var selection = BoardSelection.shared
    @Environment(\.modelContext) private var modelContext
    @State private var dropSlot: QuadrantSlot?
    @State private var drafts: [QuadrantSlot: String] = [:]
    @State private var fieldFocus: [QuadrantSlot: Bool] = [:]
    @State private var focusedID: UUID?

    init(todayKey: String) {
        self.todayKey = todayKey
    }

    private var selectedKey: String {
        get { selection.inspectingDayKey }
        nonmutating set { selection.inspectingDayKey = newValue }
    }

    var body: some View {
        DaybookPage(minWidth: 560, minHeight: 480, fullWidth: true) {
            DaybookPeriodBar(
                title: DayKey.displayName(selectedKey, calendar: calendar, locale: locale),
                onPrev: { selectedKey = DayKey.shifted(selectedKey, by: -1, calendar: calendar) },
                onNext: { selectedKey = DayKey.shifted(selectedKey, by: 1, calendar: calendar) },
                onToday: selectedKey == todayKey ? nil : { selectedKey = todayKey }
            )
            Text("quadrant.hint")
                .font(DaybookType.subtitle)
                .foregroundStyle(DaybookPalette.text.secondary)
                .accessibilityIdentifier("quadrant.hint")
            if embedded {
                GeometryReader { geometry in
                    quadrantGrid(cellHeight: max(0, (geometry.size.height - DaybookSpacing.sm) / 2))
                }
            } else {
                quadrantGrid(cellHeight: 180)
            }
        }
        .quadrantKeys(
            ids: focusOrder,
            focusedID: $focusedID,
            onToggle: toggleFocused,
            onInspect: inspectFocused
        )
    }

    private func quadrantGrid(cellHeight: CGFloat) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: DaybookSpacing.sm), count: 2)
        return LazyVGrid(columns: columns, spacing: DaybookSpacing.sm) {
            ForEach(QuadrantSlot.allCases) { slot in
                cell(slot, height: cellHeight)
            }
        }
    }

    private func cell(_ slot: QuadrantSlot, height: CGFloat) -> some View {
        let rows = rows(in: slot)
        let isTargeted = dropSlot == slot
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                QuadrantMiniMark(slot: slot)

                Text(LocalizedStringKey(slot.titleKeyName))
                    .font(DaybookType.section)
                    .foregroundStyle(DaybookPalette.text.primary)
            }
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("quadrant.header.\(slot.rawValue)")
            if rows.isEmpty {
                DaybookEmptyState(title: "quadrant.empty", compact: true)
            } else {
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(rows) { row in
                            QuadrantChip(
                                row: row,
                                isFocused: focusedID == row.id,
                                onToggle: { toggle(row) },
                                onInspect: {
                                    focusedID = row.id
                                    inspect(row)
                                }
                            )
                        }
                    }
                }
                .daybookScroll()
            }
            DaybookTextField(
                text: draftBinding(slot),
                placeholder: L10n.string("quadrant.add", locale: locale),
                focus: focusBinding(slot),
                onSubmit: { addTodo(in: slot) },
                allowsShiftNewline: false
            )
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        // 固定视口让长清单只在宫格内部滚动，空宫格也占据同样的空间。
        .frame(height: height, alignment: .topLeading)
        .daybookSurface(.card, isHovered: isTargeted, isSelected: isTargeted)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("quadrant.cell.\(slot.rawValue)")
        .dropDestination(for: String.self) { items, _ in
            apply(items, to: slot)
        } isTargeted: { hovering in
            withAnimation(DaybookMotion.snappy) {
                dropSlot = hovering ? slot : (dropSlot == slot ? nil : dropSlot)
            }
        }
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

    private var focusOrder: [UUID] {
        QuadrantSlot.allCases.flatMap { rows(in: $0).map(\.id) }
    }

    private func draftBinding(_ slot: QuadrantSlot) -> Binding<String> {
        Binding(
            get: { drafts[slot] ?? "" },
            set: { drafts[slot] = $0 }
        )
    }

    private func focusBinding(_ slot: QuadrantSlot) -> Binding<Bool> {
        Binding(
            get: { fieldFocus[slot] ?? false },
            set: { fieldFocus[slot] = $0 }
        )
    }

    private func addTodo(in slot: QuadrantSlot) {
        let text = drafts[slot] ?? ""
        guard DayBoardMutations.addCapturedTodo(
            text: text, dayKey: selectedKey, context: modelContext, fallbackQuadrant: slot
        ) else { return }
        drafts[slot] = ""
    }

    private func toggle(_ row: BoardRow) {
        switch row {
        case .todo(let todo):
            _ = DayBoardMutations.toggleTodo(todo)
        case .resident(let routine):
            _ = DayBoardMutations.toggleRoutine(routine, on: selectedKey, checks: checks, context: modelContext)
        }
    }

    private func inspect(_ row: BoardRow) {
        BoardSelection.shared.inspectBoard(selectedKey)
        WorkspaceNavigation.shared.inspectTask(row.id)
    }

    private func toggleFocused() {
        guard let id = focusedID, let row = find(id) else { return }
        toggle(row)
    }

    private func inspectFocused() {
        guard let id = focusedID, let row = find(id) else { return }
        inspect(row)
    }

    private func find(_ id: UUID) -> BoardRow? {
        QuadrantSlot.allCases.lazy.compactMap { slot in rows(in: slot).first { $0.id == id } }.first
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

private struct QuadrantChip: View {
    var row: BoardRow
    var isFocused: Bool
    var onToggle: () -> Void
    var onInspect: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            ModernCheckbox(isDone: false, action: onToggle)
            Button(action: onInspect) {
                HStack(spacing: 6) {
                    if isResident {
                        Image(systemName: "repeat")
                            .font(DaybookType.micro.weight(.bold))
                            .foregroundStyle(DaybookPalette.accent.base)
                            .accessibilityLabel("row.resident")
                    }
                    Text(title)
                        .font(DaybookType.subtitle)
                        .foregroundStyle(DaybookPalette.text.primary)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain) // control: 象限任务卡整行点击
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .daybookSurface(.card, isSelected: isFocused, configure: { $0.radius = DaybookRadius.small })
        .accessibilityIdentifier("quadrant.task.\(row.id)")
        .draggable(payload)
    }

    private var title: String {
        switch row {
        case .resident(let item): item.title
        case .todo(let item): item.title
        }
    }

    private var isResident: Bool {
        if case .resident = row { return true }
        return false
    }

    private var payload: String {
        switch row {
        case .resident(let item): TodoDragToken.encodeRoutine(item.id)
        case .todo(let item): TodoDragToken.encode(item.id)
        }
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
