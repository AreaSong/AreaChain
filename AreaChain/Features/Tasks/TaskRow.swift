import SwiftUI

/// 任务行：只读状态快照加动作派发。
struct TaskRow: View {
    let state: TaskRowState
    let dispatch: (TaskRowAction) -> Void
    var onSaveTitle: ((String) -> Bool)? = nil

    @Environment(\.locale) var locale
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.workspaceEmbedded) var embedded

    @State var editing = false
    @State private var chrome = BoardRowChrome()
    @State var hasCopied = false
    @State var hasNoteCopied = false
    @State var draft = ""
    @State var pickingDay = false
    @State var pickingTime = false
    @State var isSubtasksExpanded = false
    @State private var growsUpward = false
    @State private var bubbleShiftX: CGFloat = 0
    // 输入由 NSTextField 承载，焦点请求使用原生绑定，避免 SwiftUI 焦点树将其复位。
    @State var editorFocused = false
    @State var hoveredQuickActionTip: String? = nil

    private var isRowHovered: Bool {
        get { chrome.isRowHovered }
        nonmutating set { chrome.isRowHovered = newValue }
    }

    private var isNoteHovered: Bool {
        get { chrome.isNoteHovered }
        nonmutating set { chrome.isNoteHovered = newValue }
    }

    private var isNoteBubbleHovered: Bool {
        get { chrome.isNoteBubbleHovered }
        nonmutating set { chrome.isNoteBubbleHovered = newValue }
    }

    private var isTitleTextHovered: Bool {
        get { chrome.isTitleTextHovered }
        nonmutating set { chrome.isTitleTextHovered = newValue }
    }

    private var isTitleBubbleHovered: Bool {
        get { chrome.isTitleBubbleHovered }
        nonmutating set { chrome.isTitleBubbleHovered = newValue }
    }

    var isCommandPressed: Bool {
        get { chrome.isCommandPressed }
        nonmutating set { chrome.isCommandPressed = newValue }
    }

    var isHovered: Bool {
        isRowHovered || isNoteBubbleHovered || isTitleBubbleHovered
    }

    // MARK: - 现代标准构造器 (State + Action)

    init(state: TaskRowState, onSaveTitle: ((String) -> Bool)? = nil, dispatch: @escaping (TaskRowAction) -> Void) {
        self.state = state
        self.onSaveTitle = onSaveTitle
        self.dispatch = dispatch
    }

    var body: some View {
        rowContent
            .onHover { chrome.handleRowHover($0, reduceMotion: reduceMotion) }
            .animation(DaybookMotion.interactive(reduceMotion), value: isHovered)
            .animation(DaybookMotion.interactive(reduceMotion), value: isCommandPressed)
            .animation(DaybookMotion.interactive(reduceMotion), value: state.isSelected)
            .contextMenu { menus }
            .popover(isPresented: $pickingDay) {
                daySchedulePopover
            }
            .popover(isPresented: $pickingTime) {
                timePicker
            }
            .task(id: hasCopied) {
                guard hasCopied else { return }
                try? await Task.sleep(for: .milliseconds(1200))
                if !Task.isCancelled {
                    withAnimation(DaybookMotion.interactive(reduceMotion)) {
                        hasCopied = false
                    }
                }
            }
            .task(id: hasNoteCopied) {
                guard hasNoteCopied else { return }
                try? await Task.sleep(for: .milliseconds(1200))
                if !Task.isCancelled {
                    withAnimation(DaybookMotion.interactive(reduceMotion)) {
                        hasNoteCopied = false
                    }
                }
            }
            .onAppear {
                draft = state.title
                chrome.startCommandMonitor(reduceMotion: reduceMotion)
            }
            .onDisappear {
                chrome.stop()
            }
            .onChange(of: state.title) { _, value in
                if !editing { draft = value }
            }
            .onChange(of: state.isExternalEditing) { _, value in
                if value && !editing { beginEdit() }
            }
            .zIndex((shouldShowTitleBubble || shouldShowNoteBubble) ? 120 : (isHovered ? 100 : 1))
    }

    private var rowContent: some View {
        HStack(alignment: shouldAlignTop ? .top : .center, spacing: 8) {
            ModernCheckbox(isDone: state.isDone) {
                PendingCompletionManager.shared.toggle(
                    id: state.id,
                    currentlyDone: state.isDone,
                    reduceMotion: reduceMotion
                ) {
                    dispatch(.toggleDone)
                }
            }

            if editing {
                editor
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if isHovered && isCommandPressed {
                commandActionStrip
                    .transition(.opacity)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    selectableContent
                    if isSubtasksExpanded && !state.subtasks.isEmpty {
                        TaskRowSubtaskInlineList(subtasks: state.subtasks) { subtaskID in
                            dispatch(.toggleSubtask(subtaskID))
                        }
                        .padding(.top, 2)
                    }
                }

                if hasVisibleMetadata {
                    metadataCluster
                }

                actionCluster
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(minHeight: DaybookMetrics.rowHeight)
        .daybookSurface(.row, isHovered: isHovered, isSelected: state.isSelected)
        .contentShape(RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous))
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { updateVerticalPlacement(proxy) }
                    .onChange(of: proxy.frame(in: .global).minY) { _, _ in updateVerticalPlacement(proxy) }
            }
        )
    }

    @ViewBuilder
    private var daySchedulePopover: some View {
        if let todayKey = state.todayKey {
            DaySchedulePicker(initialKey: state.currentDayKey ?? todayKey) { key in
                dispatch(.moveToDay(key))
                pickingDay = false
            }
        }
    }

    private var shouldAlignTop: Bool {
        hasVisibleNote || (isSubtasksExpanded && !state.subtasks.isEmpty) || editing
    }

    private var hasVisibleNote: Bool {
        if embedded {
            if let note = state.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return true
            }
            if let source = state.classify?.sourceLabel, !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return true
            }
            return formattedNoteSnippet != nil
        }
        return false
    }

    // MARK: - Subviews

    var fullNoteText: String? {
        if let notes = state.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return notes.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let note = state.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return note.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private var isTitleTruncated: Bool {
        TaskTitleTruncation.isTruncated(state.title)
    }

    private var shouldShowTitleBubble: Bool {
        !embedded && !editing && !pickingDay && !pickingTime && !isCommandPressed
            && (isTitleTextHovered || isTitleBubbleHovered) && !isNoteHovered && !isNoteBubbleHovered && isTitleTruncated
    }

    private var shouldShowNoteBubble: Bool {
        !embedded && !editing && !pickingDay && !pickingTime && !isCommandPressed
            && (isNoteHovered || isNoteBubbleHovered) && fullNoteText != nil
    }

    private func selectImmediately(_ modifiers: TaskSelectionModifiers = []) {
        chrome.revealRow(reduceMotion: reduceMotion)
        dispatch(.select(modifiers))
    }

    private func selection(shift: Bool, command: Bool) -> TaskSelectionModifiers {
        var modifiers = TaskSelectionModifiers()
        if shift { modifiers.insert(.shift) }
        if command { modifiers.insert(.command) }
        return modifiers
    }

    private var selectableContent: some View {
        HStack(alignment: .center, spacing: 5) {
            titleContent
                .layoutPriority(1)
                .overlay(
                    BoardRowPointerRegion(
                        id: state.id,
                        plainDoubleClick: true,
                        onSelect: { selectImmediately(selection(shift: $0, command: $1)) },
                        onDoubleClick: beginEdit,
                        onHover: { chrome.handleTitleHover($0, reduceMotion: reduceMotion) }
                    )
                    .padding(.top, -6)
                    .padding(.bottom, isSubtasksExpanded && !state.subtasks.isEmpty ? 0 : -6)
                    .accessibilityHidden(true)
                )

            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 20)
                .contentShape(Rectangle())
                .overlay(
                    BoardRowPointerRegion(
                        id: state.id,
                        plainDoubleClick: true,
                        onSelect: { selectImmediately(selection(shift: $0, command: $1)) },
                        onDoubleClick: beginEdit
                    )
                    .padding(.top, -6)
                    .padding(.bottom, isSubtasksExpanded && !state.subtasks.isEmpty ? 0 : -6)
                    .accessibilityHidden(true)
                )

            if !embedded, fullNoteText != nil {
                noteIndicator
                    .fixedSize()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(TodoDragIfNeeded(payload: state.dragPayload))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(state.isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { selectImmediately() }
        .accessibilityAction(named: Text("row.edit"), beginEdit)
    }

    private var residentMark: some View {
        Image(systemName: "repeat")
            .font(DaybookType.badge.weight(.bold))
            .foregroundStyle(DaybookTheme.stamp)
            .accessibilityLabel("row.resident")
            .help("row.resident")
    }

    private var noteIndicator: some View {
        Image(systemName: hasNoteCopied ? "checkmark" : "text.alignleft")
            .font(DaybookType.micro.weight(.medium))
            .foregroundStyle(hasNoteCopied ? DaybookTheme.stamp : (isNoteHovered ? DaybookTheme.stamp : DaybookTheme.muted.opacity(0.65))) // token-exempt: 65% 次要色没有对应令牌
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.xxs, style: .continuous)
                    .fill(hasNoteCopied ? DaybookTheme.stamp.opacity(0.16) : (isNoteHovered ? DaybookPalette.accent.fill : DaybookTheme.ink.opacity(0.04))) // token-exempt: 16% 与 4% 没有对应令牌
            )
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            updateBubblePlacement(proxy)
                        }
                        .onChange(of: proxy.frame(in: .global).minY) { _, _ in
                            updateBubblePlacement(proxy)
                        }
                        .onChange(of: proxy.frame(in: .global).minX) { _, _ in
                            updateBubblePlacement(proxy)
                        }
                }
            )
            .contentShape(Rectangle())
            .onHover { chrome.handleNoteHover($0, reduceMotion: reduceMotion) }
            .onTapGesture {
                if let note = fullNoteText {
                    copyToClipboard(note)
                    withAnimation(DaybookMotion.interactive(reduceMotion)) {
                        hasNoteCopied = true
                    }
                }
            }
            .overlay(alignment: growsUpward ? .bottomLeading : .topLeading) {
                if shouldShowNoteBubble, let noteText = fullNoteText {
                    let arrowPadding = max(8, min(186, 8 - bubbleShiftX))
                    let transformAnchor = UnitPoint(
                        x: max(0.06, min(0.94, (arrowPadding + 3.5) / 210.0)),
                        y: growsUpward ? 1.0 : 0.0
                    )
                    TaskNoteBubble(
                        note: noteText,
                        growsUpward: growsUpward,
                        bubbleShiftX: bubbleShiftX,
                        onCopy: { copyToClipboard(noteText) },
                        onHover: { hovering in
                            isNoteBubbleHovered = hovering
                            if !hovering && !isNoteHovered {
                                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                                    isNoteHovered = false
                                }
                            }
                        }
                    )
                    .offset(x: -8 + bubbleShiftX, y: growsUpward ? -18 : 16)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: transformAnchor)),
                        removal: .opacity
                    ))
                }
            }
    }

    private func updateVerticalPlacement(_ proxy: GeometryProxy) {
        growsUpward = bubblePlacement(proxy).growsUpward
    }

    private func updateBubblePlacement(_ proxy: GeometryProxy) {
        let placement = bubblePlacement(proxy)
        growsUpward = placement.growsUpward
        bubbleShiftX = placement.bubbleShiftX
    }

    private func bubblePlacement(_ proxy: GeometryProxy) -> (growsUpward: Bool, bubbleShiftX: CGFloat) {
        let frame = proxy.frame(in: .global)
        return RowBubblePlacement.calculate(
            globalPoint: CGPoint(x: frame.minX, y: frame.minY),
            wideHost: embedded
        )
    }

    private var titleContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            ModernTaskTitle(text: state.title, isDone: state.isDone)
                .lineLimit(embedded ? 2 : 1)
                .truncationMode(.tail)
                .layoutPriority(1)
                .contentShape(Rectangle())
                .onHover { chrome.handleTitleHover($0, reduceMotion: reduceMotion) }
                .overlay(alignment: growsUpward ? .bottomLeading : .topLeading) {
                    if shouldShowTitleBubble {
                        TaskTitleBubble(
                            title: state.title,
                            growsUpward: growsUpward,
                            onCopy: { copyToClipboard(state.title) },
                            onHover: { hovering in
                                isTitleBubbleHovered = hovering
                                if !hovering && !isTitleTextHovered {
                                    withAnimation(DaybookMotion.interactive(reduceMotion)) {
                                        isTitleTextHovered = false
                                    }
                                }
                            }
                        )
                        .offset(y: growsUpward ? -6 : 22)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: growsUpward ? .bottomLeading : .topLeading)),
                            removal: .opacity
                        ))
                    }
                }

            if embedded {
                if let noteSnippet = formattedNoteSnippet {
                    Text(noteSnippet)
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookTheme.muted.opacity(0.85)) // token-exempt: 85% 次要色没有对应令牌
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                if let note = state.note {
                    Text(note)
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookTheme.stamp.opacity(0.85)) // token-exempt: 85% 印章色没有对应令牌
                }

                if let source = state.classify?.sourceLabel, !source.isEmpty {
                    Text(source)
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookPalette.text.tertiary)
                }
            }
        }
    }
}

