import AppKit
import SwiftData
import SwiftUI

struct GanttPage: View {
    @WorkspaceNavigationContext private var navigation
    @WorkspaceBoardContext private var boardSelection
    @Environment(\.workspaceEmbedded) private var embedded
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    @Environment(AppPreferences.self) private var preferences: AppPreferences?
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query(sort: \TodoItem.createdAt) private var todos: [TodoItem]
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]

    private var titleTruncation: Text.TruncationMode {
        (preferences ?? AppPreferences.shared).contentTruncation.textTruncation
    }

    var todayKey: String
    @State private var monthKey: String
    @State private var filter = BoardFilter()
    @State private var sortMode: GanttSortMode = .stable
    @State private var isSortExpanded = false
    @State private var customTitleWidth: CGFloat? = GanttSpanStore.loadTitleWidth()
    @State private var isDividerHovered = false
    @State private var spanDaysMap: [UUID: Int] = GanttSpanStore.load()
    @State private var reorderState: (id: UUID, offset: Int)?
    @State private var dropTarget: GanttDropTarget?
    @State private var selection = TaskSelection()
    @State private var drag: GanttDragState?
    @State private var hoveredRowID: UUID?
    @State private var hoveredTitleRowID: UUID?
    @State private var showRoutines = false

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
                onToday: String(monthKey.prefix(7)) == String(todayKey.prefix(7)) ? nil : { monthKey = todayKey },
                todayLabel: "gantt.currentMonth"
            )
            toolbarRow
            if !embedded {
                Text("gantt.hint")
                    .font(DaybookType.subtitle)
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
            if bars.isEmpty && marks.isEmpty {
                DaybookEmptyState(title: "gantt.empty", systemImage: "calendar")
            } else {
                timeline
            }
        }
        .workspaceInspectorTargets(bars.map(\.id) + routineIDs)
        .onChange(of: monthKey) { _, _ in resetInteraction() }
        .onChange(of: bars) { _, current in
            selection.reconcile(with: current.map(\.id))
            if let drag, !drag.matches(current) { self.drag = nil }
        }
        .onDisappear { resetInteraction() }
    }

    private var toolbarRow: some View {
        HStack(spacing: 8) {
            BoardFilterBar(filter: filter, tags: CatalogChoices.tags(tags), bundleIDs: [], showsPriority: true) { filter = $0 }
            Spacer(minLength: 8)
            BoardFilterDropdownButton(
                icon: "arrow.up.arrow.down", title: sortMode.label(locale: locale),
                active: sortMode != .stable, isExpanded: $isSortExpanded,
                reset: sortMode == .stable ? nil : { sortMode = .stable }, allOption: nil,
                items: GanttSortMode.allCases.map { mode in
                    FilterDropdownOption(id: mode.rawValue, title: mode.label(locale: locale),
                                         icon: "arrow.up.arrow.down", isSelected: sortMode == mode) { sortMode = mode }
                }
            )
            .font(DaybookType.caption)
        }
    }

    private var timeline: some View {
        GeometryReader { proxy in
            let metrics = GanttRowMetrics.resolve(availableWidth: proxy.size.width, dayCount: days.count, preferredTitleWidth: customTitleWidth)
            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 0) {
                    headerRow(metrics: metrics)
                    DaybookDivider(opacity: 0.6)
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(bars) { bar in
                                todoRow(bar, metrics: metrics)
                                    .offset(y: reorderOffset(for: bar.id, metrics: metrics))
                                    .zIndex(reorderState?.id == bar.id ? 200 : (hoveredTitleRowID == bar.id && drag == nil ? 120 : 1))
                            }
                            if !routineIDs.isEmpty {
                                routinesSection(metrics: metrics)
                            }
                        }
                        .padding(.bottom, 12)
                    }
                    .daybookScroll()
                }
            }
            .daybookScroll()
        }
    }

    private var days: [String] { DayKey.daysInMonth(containing: monthKey, calendar: calendar) }

    private var bars: [GanttTodoBar] {
        sortMode.sortedBars(todos: todos, monthDays: days, filter: filter)
    }

    private var marks: [GanttRoutineMark] {
        let filtered = routines.filter { Classification.matches($0.classifyBits, filter: filter) }
        return GanttLayout.routineMarks(routines: filtered.map(\.snapshot), monthKeys: days, calendar: calendar)
    }

    private var routineIDs: [UUID] {
        var seen: [UUID] = []
        for mark in marks where !seen.contains(mark.routineID) { seen.append(mark.routineID) }
        return seen
    }

    private func headerRow(metrics: GanttRowMetrics.Resolved) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("items.kind.oneOff")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
                DaybookCount(count: bars.count)
                Spacer(minLength: 0)
            }
            .padding(.leading, 4)
            .padding(.trailing, 8)
            .frame(width: metrics.titleWidth, height: 36, alignment: .leading)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(isDividerHovered ? DaybookPalette.accent.base : DaybookPalette.border.subtle)
                    .frame(width: isDividerHovered ? 2 : 1)
                    .overlay {
                        GanttColumnDividerRegion(
                            titleWidth: metrics.titleWidth,
                            onHover: { isDividerHovered = $0 },
                            onResize: { updateTitleWidth($0) }
                        )
                        .frame(width: 10, height: 36)
                    }
            }

            ForEach(days, id: \.self) { key in dayHeaderCell(key, metrics: metrics) }
        }
        .background(DaybookPalette.fill.subtle)
    }

    private func dayHeaderCell(_ key: String, metrics: GanttRowMetrics.Resolved) -> some View {
        let isToday = key == todayKey
        let isWeekend = !DayKey.isWeekday(key, calendar: calendar)
        return VStack(spacing: 1) {
            Text(weekdaySymbol(for: key))
                .font(DaybookType.micro.weight(isToday ? .semibold : .regular))
                .foregroundStyle(isToday ? DaybookPalette.accent.base : DaybookPalette.text.tertiary)
            Text(DayKey.dayNumber(key, calendar: calendar))
                .font(DaybookType.micro.weight(isToday ? .bold : .medium))
                .foregroundStyle(isToday ? DaybookPalette.text.onAccent : (isWeekend ? DaybookPalette.text.secondary : DaybookPalette.text.primary))
                .frame(width: 18, height: 18)
                .background { if isToday { Circle().fill(DaybookPalette.accent.base) } } // token-exempt: 今日日期圆标
        }
        .frame(width: metrics.dayWidth, height: 36)
        .background(columnTint(for: key))
        .overlay(alignment: .trailing) { Rectangle().fill(DaybookPalette.border.faint).frame(width: 0.5) }
        .accessibilityLabel(DayKey.displayName(key, calendar: calendar, locale: locale))
    }

    private func todoRow(_ bar: GanttTodoBar, metrics: GanttRowMetrics.Resolved) -> some View {
        let displayedDay = drag?.previewDay(for: bar.id) ?? bar.dayKey
        let span = max(spanDaysMap[bar.id] ?? 1, 1)
        let isSelected = selection.ids.contains(bar.id)
        let isRowHovered = hoveredRowID == bar.id
        let slot = quadrantSlot(for: bar.id)
        let showBubble = drag == nil && reorderState == nil && hoveredTitleRowID == bar.id
            && isTitleTruncated(bar.title, titleWidth: metrics.titleWidth, hasPriority: slot != .rest)
        return HStack(spacing: 0) {
            todoTitleCell(bar, slot: slot, isSelected: isSelected, isRowHovered: isRowHovered, showBubble: showBubble, metrics: metrics)
            ForEach(days, id: \.self) { key in dayCell(key, rowID: bar.id, metrics: metrics) }
        }
        .frame(height: metrics.height)
        .background(rowBackground(isSelected: isSelected, isHovered: isRowHovered))
        .overlay(alignment: .leading) {
            todoBarOverlay(displayedDay: displayedDay, span: span, isSelected: isSelected, isHovered: isRowHovered, metrics: metrics)
        }
        .overlay(alignment: .bottom) { Rectangle().fill(DaybookPalette.border.faint).frame(height: 0.5) }
        .overlay {
            GanttRowPointerRegion(
                bar: bar, displayedDay: displayedDay, spanDays: span, days: days,
                isSelected: isSelected, titleWidth: metrics.titleWidth, dayWidth: metrics.dayWidth,
                onHover: { rowHover, titleHover in
                    guard drag == nil && reorderState == nil else { return }
                    if rowHover {
                        hoveredRowID = bar.id
                        hoveredTitleRowID = titleHover ? bar.id : nil
                    } else {
                        if hoveredRowID == bar.id { hoveredRowID = nil }
                        if hoveredTitleRowID == bar.id { hoveredTitleRowID = nil }
                    }
                },
                dispatch: { handle($0, for: bar, dayWidth: metrics.dayWidth) }
            )
        }
    }

    @ViewBuilder
    private func todoBarOverlay(
        displayedDay: String, span: Int, isSelected: Bool, isHovered: Bool, metrics: GanttRowMetrics.Resolved
    ) -> some View {
        if let startIndex = days.firstIndex(of: displayedDay) {
            let clampedSpan = min(max(span, 1), max(1, days.count - startIndex))
            let width = max(14, CGFloat(clampedSpan) * metrics.dayWidth - 4)
            RoundedRectangle(cornerRadius: DaybookRadius.xxs, style: .continuous) // token-exempt: 甘特色块是数据标记，不是卡片
                .fill(DaybookPalette.accent.base.opacity(0.85)) // token-exempt: 85% 印章色没有对应令牌
                .frame(width: width, height: 16)
                .overlay(alignment: .trailing) {
                    if isSelected || isHovered {
                        Capsule() // token-exempt: 色块右侧拉伸把手标识
                            .fill(DaybookPalette.text.onAccent.opacity(0.75)) // token-exempt: 色块右侧拉伸把手标识
                            .frame(width: 2, height: 8)
                            .padding(.trailing, 3)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: DaybookRadius.xs) // token-exempt: 甘特色块是数据标记，不是卡片
                        .stroke(isSelected ? DaybookPalette.accent.base : Color.clear, lineWidth: 1.5)
                }
                .offset(x: metrics.titleWidth + CGFloat(startIndex) * metrics.dayWidth + 2)
                .allowsHitTesting(false)
        }
    }

    private func todoTitleCell(
        _ bar: GanttTodoBar, slot: QuadrantSlot, isSelected: Bool,
        isRowHovered: Bool, showBubble: Bool, metrics: GanttRowMetrics.Resolved
    ) -> some View {
        HStack(spacing: 5) {
            ModernCheckbox(isDone: false) {}.allowsHitTesting(false)
            if slot != .rest { QuadrantBadge(slot: slot, isHighlighted: isSelected || isRowHovered) }
            Text(bar.title)
                .font(DaybookType.caption).foregroundStyle(DaybookPalette.text.primary)
                .lineLimit(1).truncationMode(titleTruncation)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 2).padding(.trailing, 6)
        .frame(width: metrics.titleWidth, height: metrics.height, alignment: .leading)
        .overlay(alignment: .trailing) {
            Rectangle().fill(isDividerHovered ? DaybookPalette.accent.base : DaybookPalette.border.subtle).frame(width: isDividerHovered ? 2 : 1)
        }
        .overlay(alignment: .topLeading) {
            if showBubble {
                TaskTitleBubble(title: bar.title, growsUpward: false, onCopy: { copyTitle(bar.title) }, onHover: { _ in })
                    .frame(width: min(420, max(200, metrics.titleWidth + 20)), alignment: .leading).fixedSize()
                    .offset(x: GanttRowMetrics.checkboxWidth, y: metrics.height + 2).allowsHitTesting(false)
            }
        }
        .accessibilityHidden(true)
    }

    private func routinesSection(metrics: GanttRowMetrics.Resolved) -> some View {
        let isExpanded = showRoutines || bars.isEmpty
        let totalWidth = metrics.titleWidth + CGFloat(days.count) * metrics.dayWidth
        return VStack(alignment: .leading, spacing: 0) {
            Button { showRoutines.toggle() } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(DaybookType.micro.weight(.bold)).foregroundStyle(DaybookPalette.text.tertiary).frame(width: 12)
                    Image(systemName: "repeat")
                        .font(DaybookType.micro.weight(.bold)).foregroundStyle(DaybookPalette.accent.base)
                    Text("items.kind.recurring")
                        .font(DaybookType.caption).foregroundStyle(DaybookPalette.text.secondary)
                    DaybookCount(count: routineIDs.count)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 6)
                .frame(width: totalWidth, height: 26, alignment: .leading)
                .background(DaybookPalette.fill.subtle)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain) // token-exempt: 表格分区头整行可点击，不使用按钮边框样式
            .overlay(alignment: .bottom) { Rectangle().fill(DaybookPalette.border.faint).frame(height: 0.5) }
            if isExpanded {
                ForEach(routineIDs, id: \.self) { id in routineRow(id, metrics: metrics) }
            }
        }
    }

    private func routineRow(_ id: UUID, metrics: GanttRowMetrics.Resolved) -> some View {
        let title = marks.first { $0.routineID == id }?.title ?? ""
        let dots = Set(marks.filter { $0.routineID == id }.map(\.dayKey))
        let isHovered = hoveredRowID == id
        return HStack(spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: "repeat")
                    .font(DaybookType.micro.weight(.bold)).foregroundStyle(DaybookPalette.accent.base).frame(width: 16)
                    .accessibilityHidden(true)
                Text(title)
                    .font(DaybookType.caption).foregroundStyle(DaybookPalette.text.secondary)
                    .lineLimit(1).truncationMode(titleTruncation).help(title)
            }
            .padding(.leading, 4).padding(.trailing, 6)
            .frame(width: metrics.titleWidth, height: metrics.height, alignment: .leading)
            .overlay(alignment: .trailing) {
                Rectangle().fill(isDividerHovered ? DaybookPalette.accent.base : DaybookPalette.border.subtle).frame(width: isDividerHovered ? 2 : 1)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                resetInteraction()
                let inspectKey = dots.contains(todayKey) ? todayKey : (days.first { dots.contains($0) } ?? todayKey)
                boardSelection.inspectBoard(inspectKey)
                navigation.inspectTask(id)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(title)
            .accessibilityAddTraits(.isButton)

            ForEach(days, id: \.self) { key in
                Circle() // token-exempt: 习惯完成点，不是按钮
                    .fill(dots.contains(key) ? DaybookPalette.accent.base : Color.clear)
                    .frame(width: 6, height: 6)
                    .frame(width: metrics.dayWidth, height: metrics.height)
                    .background(columnTint(for: key))
                    .overlay(alignment: .trailing) { Rectangle().fill(DaybookPalette.border.faint).frame(width: 0.5) }
            }
        }
        .background(isHovered ? DaybookPalette.fill.hover : Color.clear)
        .overlay(alignment: .bottom) { Rectangle().fill(DaybookPalette.border.faint).frame(height: 0.5) }
        .onHover { hovering in
            if hovering { hoveredRowID = id } else if hoveredRowID == id { hoveredRowID = nil }
        }
    }

    private func dayCell(_ key: String, rowID: UUID, metrics: GanttRowMetrics.Resolved) -> some View {
        let target = GanttDropTarget(rowID: rowID, dayKey: key)
        return Color.clear
            .frame(width: metrics.dayWidth, height: metrics.height)
            .background(columnTint(for: key))
            .overlay(alignment: .trailing) { Rectangle().fill(DaybookPalette.border.faint).frame(width: 0.5) }
            .overlay {
                RoundedRectangle(cornerRadius: DaybookRadius.xs) // token-exempt: 甘特色块是数据标记，不是卡片
                    .stroke(dropTarget == target ? DaybookPalette.accent.base : Color.clear, lineWidth: 1.5)
            }
            .contentShape(Rectangle())
            .accessibilityHidden(true)
            .dropDestination(for: String.self) { items, _ in
                dropTodo(items, onto: key)
            } isTargeted: { hovering in
                dropTarget = hovering ? target : (dropTarget == target ? nil : dropTarget)
            }
    }

    private func columnTint(for key: String) -> Color {
        if key == todayKey { return DaybookPalette.accent.fill }
        if !DayKey.isWeekday(key, calendar: calendar) { return DaybookPalette.fill.subtle }
        return Color.clear
    }

    private func rowBackground(isSelected: Bool, isHovered: Bool) -> Color {
        if isSelected { return DaybookPalette.fill.selection }
        if isHovered { return DaybookPalette.fill.hover }
        return Color.clear
    }

    private func weekdaySymbol(for key: String) -> String {
        guard let date = DayKey.date(from: key, calendar: calendar) else { return "" }
        let weekday = calendar.component(.weekday, from: date)
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard (1...symbols.count).contains(weekday) else { return "" }
        return symbols[weekday - 1]
    }

    private func quadrantSlot(for id: UUID) -> QuadrantSlot {
        guard let todo = todos.first(where: { $0.id == id }) else { return .rest }
        return QuadrantSlot.of(important: todo.isImportant, urgent: todo.isUrgent)
    }

    private func isTitleTruncated(_ title: String, titleWidth: CGFloat, hasPriority: Bool) -> Bool {
        let font = NSFont.systemFont(ofSize: DaybookType.captionSize, weight: .medium)
        let textWidth = ceil((title as NSString).size(withAttributes: [.font: font]).width)
        let reservedWidth: CGFloat = GanttRowMetrics.checkboxWidth + (hasPriority ? 26 : 0) + 14
        return textWidth > max(40, titleWidth - reservedWidth)
    }

    private func copyTitle(_ title: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(title, forType: .string)
    }

    private func updateTitleWidth(_ width: CGFloat) {
        let clamped = min(max(width, 120), 480)
        customTitleWidth = clamped
        GanttSpanStore.saveTitleWidth(clamped)
    }

    private func reorderOffset(for id: UUID, metrics: GanttRowMetrics.Resolved) -> CGFloat {
        guard let state = reorderState, let sourceIndex = bars.firstIndex(where: { $0.id == state.id }),
              let rowIndex = bars.firstIndex(where: { $0.id == id }) else { return 0 }
        let targetIndex = min(max(sourceIndex + state.offset, 0), max(bars.count - 1, 0))
        if rowIndex == sourceIndex { return CGFloat(targetIndex - sourceIndex) * metrics.height }
        if targetIndex > sourceIndex && (sourceIndex + 1 ... targetIndex).contains(rowIndex) { return -metrics.height }
        if targetIndex < sourceIndex && (targetIndex ..< sourceIndex).contains(rowIndex) { return metrics.height }
        return 0
    }

    private func commitReorder(bar: GanttTodoBar, offset: Int) {
        reorderState = nil
        var ordered = bars
        guard let sourceIndex = ordered.firstIndex(where: { $0.id == bar.id }) else { return }
        let targetIndex = min(max(sourceIndex + offset, 0), max(ordered.count - 1, 0))
        guard sourceIndex != targetIndex else { return }
        let item = ordered.remove(at: sourceIndex)
        ordered.insert(item, at: targetIndex)
        if sortMode != .stable { sortMode = .stable }
        _ = ModelChanges.perform(in: modelContext) {
            for (index, entry) in ordered.enumerated() {
                if let todo = todos.first(where: { $0.id == entry.id }) {
                    todo.sortOrder = index
                }
            }
        }
    }

    private func handle(_ action: GanttPointerAction, for bar: GanttTodoBar, dayWidth: CGFloat) {
        switch action {
        case .select(let modifiers): selection.select(bar.id, in: bars.map(\.id), modifiers: modifiers)
        case .inspect: boardSelection.inspectBoard(bar.dayKey); navigation.inspectTask(bar.id)
        case .dragBegan: beginDrag(bar)
        case .dragChanged(let translation): drag?.update(dayOffset: Int((translation / dayWidth).rounded()))
        case .dragEnded: commitDrag()
        case .resizeSpan(let newSpan):
            if newSpan <= 1 { spanDaysMap.removeValue(forKey: bar.id) } else { spanDaysMap[bar.id] = newSpan }
            GanttSpanStore.save(spanDaysMap)
        case .resizeTitleColumn(let width): updateTitleWidth(width)
        case .reorderRow(let offset): reorderState = (id: bar.id, offset: offset)
        case .commitReorder(let offset): commitReorder(bar: bar, offset: offset)
        case .hoverDivider(let hovering): if isDividerHovered != hovering { isDividerHovered = hovering }
        case .cancel:
            if drag != nil { drag = nil } else if reorderState != nil { reorderState = nil } else { selection.focus(nil) }
            dropTarget = nil
        case .moveByDays(let offset): beginDrag(bar); drag?.update(dayOffset: offset); commitDrag()
        case .complete: completeSelected(including: bar.id)
        }
    }

    private func completeSelected(including id: UUID) {
        let ids = selection.ids.isEmpty ? [id] : selection.ids
        for todo in todos where ids.contains(todo.id) && todo.deletedAt == nil && !todo.isDone {
            _ = DayBoardMutations.toggleTodo(todo)
        }
    }

    private func beginDrag(_ bar: GanttTodoBar) {
        if !selection.ids.contains(bar.id) { selection.focus(bar.id) }
        dropTarget = nil; hoveredTitleRowID = nil
        drag = GanttDragState(sourceID: bar.id, selectedIDs: selection.ids, bars: bars, days: days)
    }

    private func commitDrag() {
        guard let drag else { return }
        self.drag = nil
        guard GanttRescheduling.commit(drag.moves, todos: todos, context: modelContext) else { return }
        if let id = navigation.selectedTaskID, let day = drag.previewDay(for: id) { boardSelection.inspectBoard(day) }
    }

    private func resetInteraction() {
        drag = nil; reorderState = nil; dropTarget = nil
        hoveredRowID = nil; hoveredTitleRowID = nil; isDividerHovered = false
        selection.focus(nil)
    }

    private func dropTodo(_ items: [String], onto key: String) -> Bool {
        dropTarget = nil
        guard let id = items.compactMap(TodoDragToken.decode).first,
              let todo = todos.first(where: { $0.id == id && !$0.isDone && $0.deletedAt == nil }) else { return false }
        return DayBoardMutations.moveTodo(todo, to: key)
    }
}
