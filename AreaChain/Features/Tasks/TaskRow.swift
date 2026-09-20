import SwiftUI

/// 任务行：只读状态快照加动作派发。
struct TaskRow: View {
    let state: TaskRowState
    let dispatch: (TaskRowAction) -> Void
    var onSaveTitle: ((String) -> Bool)? = nil

    @Environment(\.locale) var locale
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.daybookViewStyle) var style

    @State var editing = false
    @State var hovering = false
    @State private var isPointerHovered = false
    @State private var isNoteHovered = false
    @State private var isTitleTextHovered = false
    @State var isCommandPressed = false
    @State private var flagsMonitor: Any? = nil
    @State var draft = ""
    @State var pickingDay = false
    @State var pickingTime = false
    @State private var isSubtasksExpanded = false
    @State private var growsUpward = false
    @State private var bubbleShiftX: CGFloat = 0
    // 输入由 NSTextField 承载，焦点请求使用原生绑定，避免 SwiftUI 焦点树将其复位。
    @State var editorFocused = false
    @State var hoveredQuickActionTip: String? = nil

    var isHovered: Bool {
        hovering || isPointerHovered || isNoteHovered
    }

    // MARK: - 现代标准构造器 (State + Action)

    init(state: TaskRowState, onSaveTitle: ((String) -> Bool)? = nil, dispatch: @escaping (TaskRowAction) -> Void) {
        self.state = state
        self.onSaveTitle = onSaveTitle
        self.dispatch = dispatch
    }

    var body: some View {
        rowContent
            .onHover { hovering = $0 }
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
            .onAppear {
                draft = state.title
                startObservingModifiers()
            }
            .onDisappear {
                stopObservingModifiers()
            }
            .onChange(of: state.title) { _, value in
                if !editing { draft = value }
            }
            .onChange(of: state.isExternalEditing) { _, value in
                if value && !editing { beginEdit() }
            }
    }

    private func startObservingModifiers() {
        guard flagsMonitor == nil else { return }
        isCommandPressed = NSEvent.modifierFlags.contains(.command)
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            isCommandPressed = event.modifierFlags.contains(.command)
            return event
        }
    }

    private func stopObservingModifiers() {
        if let flagsMonitor {
            NSEvent.removeMonitor(flagsMonitor)
            self.flagsMonitor = nil
        }
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

                metadataCluster

                actionCluster
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(minHeight: style.isWorkspace ? WorkspaceStyle.rowHeight : 34)
        .modernRow(
            cornerRadius: DaybookRadius.small,
            isHovered: isHovered,
            isSelected: state.isSelected
        )
        .contentShape(RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous))
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { updateVerticalPlacement(proxy) }
                    .onChange(of: proxy.frame(in: .global).minY) { _, _ in updateVerticalPlacement(proxy) }
            }
        )
        .zIndex(isHovered ? 60 : 1)
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
        if style.isWorkspace {
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

    private var fullNoteText: String? {
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
        !style.isWorkspace && !editing && !pickingDay && !pickingTime
            && (isTitleTextHovered || isPointerHovered) && !isNoteHovered && isTitleTruncated
    }

    private var shouldShowNoteBubble: Bool {
        !style.isWorkspace && !editing && !pickingDay && !pickingTime && isNoteHovered && fullNoteText != nil
    }

    private var selectableContent: some View {
        HStack(alignment: .center, spacing: 5) {
            titleContent
                .overlay(TaskRowPointerRegion(
                    id: state.id,
                    onSelect: { dispatch(.select($0)) },
                    onEdit: beginEdit,
                    onHover: { isPointerHovered = $0 }
                )
                .padding(.top, -6)
                .padding(.bottom, isSubtasksExpanded && !state.subtasks.isEmpty ? 0 : -6)
                .accessibilityHidden(true))

            if !style.isWorkspace, fullNoteText != nil {
                noteIndicator
            }

            Color.clear
                .frame(minWidth: 10, maxWidth: .infinity, minHeight: 20)
                .contentShape(Rectangle())
                .overlay(TaskRowPointerRegion(
                    id: state.id,
                    onSelect: { dispatch(.select($0)) },
                    onEdit: beginEdit
                )
                .padding(.top, -6)
                .padding(.bottom, isSubtasksExpanded && !state.subtasks.isEmpty ? 0 : -6)
                .accessibilityHidden(true))
        }
        .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
        .modifier(TodoDragIfNeeded(payload: state.dragPayload))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(state.isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { dispatch(.select()) }
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
        Image(systemName: "text.alignleft")
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(isNoteHovered ? DaybookTheme.stamp : DaybookTheme.muted.opacity(0.65))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(isNoteHovered ? DaybookTheme.stamp.opacity(0.12) : DaybookTheme.ink.opacity(0.04))
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
            .onHover { hovering in
                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                    isNoteHovered = hovering
                }
            }
            .overlay(alignment: growsUpward ? .bottomLeading : .topLeading) {
                if shouldShowNoteBubble, let noteText = fullNoteText {
                    let arrowPadding = max(8, min(186, 8 - bubbleShiftX))
                    let transformAnchor = UnitPoint(
                        x: max(0.06, min(0.94, (arrowPadding + 3.5) / 210.0)),
                        y: growsUpward ? 1.0 : 0.0
                    )
                    TaskNoteBubble(note: noteText, growsUpward: growsUpward, bubbleShiftX: bubbleShiftX)
                        .offset(x: -8 + bubbleShiftX, y: growsUpward ? -18 : 16)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: transformAnchor)),
                            removal: .opacity
                        ))
                }
            }
    }

    private func updateVerticalPlacement(_ proxy: GeometryProxy) {
        growsUpward = proxy.frame(in: .global).minY > 260
    }

    private func updateBubblePlacement(_ proxy: GeometryProxy) {
        let frame = proxy.frame(in: .global)
        let globalY = frame.minY
        let globalX = frame.minX

        // 纵向：菜单栏高度约为 460pt，底部分割线与搜索栏位于 400~410pt 附近。
        // 气泡高约 70~120pt。当图标全局 Y > 260pt（即下半部分）时，下方空间受限，自动向上翻转展开。
        growsUpward = globalY > 260

        // 横向：气泡宽 210pt。默认 offset(x: -8)，气泡右边界 = globalX - 8 + 210 = globalX + 202。
        // 菜单栏弹窗宽约 380pt，安全右边界设为 356pt（保留右侧呼吸感与视口边距）。
        // 当长标题将 [≡] 靠右推时，自动向左平移夹紧，同时小三角动态跟随指示器居中。
        let safeMaxX: CGFloat = style.isWorkspace ? 700 : 356
        let safeMinX: CGFloat = 12
        let bubbleRight = globalX + 202
        if bubbleRight > safeMaxX {
            let overflow = bubbleRight - safeMaxX
            let maxShift = max(0, (globalX - 8) - safeMinX)
            bubbleShiftX = -min(overflow, maxShift)
        } else {
            bubbleShiftX = 0
        }
    }

    private var titleContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            ModernTaskTitle(text: state.title, isDone: state.isDone)
                .lineLimit(style.isWorkspace ? 2 : 1)
                .truncationMode(.tail)
                .contentShape(Rectangle())
                .onHover { hovering in
                    withAnimation(DaybookMotion.interactive(reduceMotion)) {
                        isTitleTextHovered = hovering
                    }
                }
                .overlay(alignment: growsUpward ? .bottomLeading : .topLeading) {
                    if shouldShowTitleBubble {
                        TaskTitleBubble(title: state.title, growsUpward: growsUpward)
                            .offset(y: growsUpward ? -6 : 22)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: growsUpward ? .bottomLeading : .topLeading)),
                                removal: .opacity
                            ))
                    }
                }

            if style.isWorkspace {
                if let noteSnippet = formattedNoteSnippet {
                    Text(noteSnippet)
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookTheme.muted.opacity(0.85))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                if let note = state.note {
                    Text(note)
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookTheme.stamp.opacity(0.85))
                }

                if let source = state.classify?.sourceLabel, !source.isEmpty {
                    Text(source)
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookTheme.muted.opacity(0.75))
                }
            }
        }
    }

    @ViewBuilder
    private var metadataCluster: some View {
        HStack(spacing: 5) {
            quadrantBadge

            tagChips

            if state.isResident, let streak = state.streak, streak >= 1 {
                streakBadge(streak)
            }

            if let remindMinutes = state.remindMinutes {
                remindBadge(remindMinutes)
            }

            if !state.subtasks.isEmpty {
                TaskRowSubtaskChip(
                    subtasks: state.subtasks,
                    isExpanded: $isSubtasksExpanded,
                    reduceMotion: reduceMotion
                )
            }

            if let items = state.attachments?.items, !items.isEmpty {
                AttachmentThumbnails(items: items)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .opacity(style.isWorkspace || hovering || state.isSelected ? 1.0 : 0.65)
        .animation(DaybookMotion.interactive(reduceMotion), value: hovering)
    }

    var attachedTagNames: [String] {
        guard let classify = state.classify else { return [] }
        let selectedIDs = Set(TagIDList.parse(classify.tagIDs))
        guard !selectedIDs.isEmpty else { return [] }
        return classify.tags.filter { selectedIDs.contains($0.id) }.map(\.name)
    }

    private var editor: some View {
        SyntaxTextField(
            text: $draft, placeholder: L10n.string("row.edit.field", locale: locale),
            focused: $editorFocused, allowsShiftNewline: true, onSubmit: saveEdit, onEscape: cancelEdit
        )
        .onAppear { DispatchQueue.main.async { editorFocused = true } }
    }

    private var timePicker: some View {
        DatePicker(
            "row.time",
            selection: Binding(
                get: {
                    RemindMinutes.date(minutes: state.remindMinutes ?? RemindMinutes.from(date: .now)) ?? .now
                },
                set: { dispatch(.setRemindMinutes(RemindMinutes.from(date: $0))) }
            ),
            displayedComponents: .hourAndMinute
        )
        .labelsHidden()
        .padding(12)
        .frame(minWidth: 180)
    }

    func beginEdit() {
        draft = state.title
        editorFocused = false
        editing = true
    }

    func cancelEdit() {
        draft = state.title
        editing = false
        editorFocused = false
        dispatch(.endEditing)
    }

    func saveEdit() {
        let next = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !next.isEmpty {
            if let onSaveTitle {
                guard onSaveTitle(next) else { return }
            } else {
                dispatch(.editTitle(next))
            }
        } else {
            draft = state.title
        }
        editing = false
        editorFocused = false
        dispatch(.endEditing)
    }
}
