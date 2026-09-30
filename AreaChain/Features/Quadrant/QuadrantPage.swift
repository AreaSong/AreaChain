import AppKit
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
    @State private var floatingPreview: QuadrantFloatingPreview?
    @State private var previewHoverID: UUID?

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
        .coordinateSpace(name: QuadrantPageSpace.name)
        .overlay(alignment: .topLeading) { floatingPreviewLayer }
    }

    @ViewBuilder
    private var floatingPreviewLayer: some View {
        if let floatingPreview {
            QuadrantPreviewOverlay(
                preview: floatingPreview,
                onCopy: copyPreview,
                onHover: hoverPreview
            )
        }
    }

    private func copyPreview(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func hoverPreview(_ hovering: Bool) {
        previewHoverID = hovering ? floatingPreview?.id : nil
    }

    private var previewLink: QuadrantPreviewLink {
        QuadrantPreviewLink(
            spaceName: QuadrantPageSpace.name,
            preview: $floatingPreview,
            hoverID: $previewHoverID
        )
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
                                previewLink: previewLink,
                                onToggle: { toggle(row) },
                                onInspect: {
                                    focusedID = row.id
                                    inspect(row)
                                }
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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
    var previewLink: QuadrantPreviewLink
    var onToggle: () -> Void
    var onInspect: () -> Void

    @State private var chrome = BoardRowChrome()
    @State private var titleOverflows = false
    @State private var growsUpward = false
    @State private var bubbleShiftX: CGFloat = 0
    @State private var anchorFrame: CGRect = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            ModernCheckbox(isDone: false, action: onToggle)
            titleButton
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .daybookSurface(.card, isSelected: isFocused, configure: { $0.radius = DaybookRadius.small })
        .accessibilityIdentifier("quadrant.task.\(row.id)")
        .draggable(payload)
        .onChange(of: showsTitleBubble) { _, show in syncPreview(show) }
        .onChange(of: anchorFrame) { _, _ in if showsTitleBubble { syncPreview(true) } }
        .onChange(of: previewHeld) { _, held in holdBubble(held) }
        .onDisappear {
            if previewLink.preview.wrappedValue?.id == row.id {
                previewLink.preview.wrappedValue = nil
            }
            chrome.stop()
        }
    }

    private var showsTitleBubble: Bool {
        titleOverflows && (chrome.isTitleTextHovered || chrome.isTitleBubbleHovered)
    }

    private var titleButton: some View {
        Button(action: onInspect) {
            HStack(spacing: 6) {
                if isResident {
                    Image(systemName: "repeat")
                        .font(DaybookType.micro.weight(.bold))
                        .foregroundStyle(DaybookPalette.accent.base)
                        .accessibilityLabel("row.resident")
                }
                QuadrantSingleLineTitle(
                    text: title,
                    truncation: AppPreferences.shared.quadrantTitleTruncation.textTruncation,
                    overflows: $titleOverflows
                )
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain) // control: 象限任务卡整行点击
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .onHover { chrome.handleTitleHover($0, reduceMotion: reduceMotion) }
        .background(placementReader)
    }

    private var previewHeld: Bool { previewLink.hoverID.wrappedValue == row.id }

    private var placementReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { updateAnchor(proxy) }
                .onChange(of: proxy.frame(in: .named(previewLink.spaceName))) { _, _ in updateAnchor(proxy) }
        }
    }

    private func updateAnchor(_ proxy: GeometryProxy) {
        let frame = proxy.frame(in: .named(previewLink.spaceName))
        if anchorFrame != frame { anchorFrame = frame }
        applyPlacement(proxy)
    }

    private func syncPreview(_ show: Bool) {
        guard show, anchorFrame.width > 1 else {
            if previewLink.preview.wrappedValue?.id == row.id {
                previewLink.preview.wrappedValue = nil
            }
            return
        }
        let preview = QuadrantTitleOverflow.preview(title)
        let next = QuadrantFloatingPreview(
            id: row.id,
            title: title,
            excerpt: preview.excerpt,
            showsHint: preview.isPartial,
            anchor: anchorFrame,
            growsUpward: growsUpward,
            shiftX: bubbleShiftX
        )
        if previewLink.preview.wrappedValue != next {
            previewLink.preview.wrappedValue = next
        }
    }

    private func applyPlacement(_ proxy: GeometryProxy) {
        let frame = proxy.frame(in: .global)
        let placement = RowBubblePlacement.calculate(
            globalPoint: CGPoint(x: frame.minX, y: frame.minY),
            wideHost: true
        )
        if growsUpward != placement.growsUpward { growsUpward = placement.growsUpward }
        if abs(bubbleShiftX - placement.bubbleShiftX) > 0.5 { bubbleShiftX = placement.bubbleShiftX }
    }

    private func holdBubble(_ hovering: Bool) {
        chrome.isTitleBubbleHovered = hovering
        guard !hovering, !chrome.isTitleTextHovered else { return }
        withAnimation(DaybookMotion.interactive(reduceMotion)) {
            chrome.isTitleTextHovered = false
        }
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

private struct QuadrantSingleLineTitle: View {
    var text: String
    var truncation: Text.TruncationMode
    @Binding var overflows: Bool
    @State private var visibleWidth: CGFloat = 0

    var body: some View {
        Text(text)
            .font(DaybookType.subtitle)
            .foregroundStyle(DaybookPalette.text.primary)
            .lineLimit(1)
            .truncationMode(truncation)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: QuadrantVisibleWidthKey.self, value: proxy.size.width)
                }
            }
            .onPreferenceChange(QuadrantVisibleWidthKey.self, perform: updateVisibleWidth)
            .onChange(of: text) { _, _ in publishOverflow() }
            .onChange(of: truncation) { _, _ in publishOverflow() }
    }

    private func updateVisibleWidth(_ width: CGFloat) {
        guard abs(visibleWidth - width) > 0.5 else { return }
        visibleWidth = width
        publishOverflow()
    }

    private func publishOverflow() {
        let next = QuadrantTitleOverflow.overflowsProbe(text, visibleWidth: visibleWidth)
        if overflows != next { overflows = next }
    }
}

private struct QuadrantVisibleWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
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
