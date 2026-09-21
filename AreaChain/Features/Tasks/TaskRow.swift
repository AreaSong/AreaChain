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
    @State private var isNoteBubbleHovered = false
    @State private var isTitleTextHovered = false
    @State private var isTitleBubbleHovered = false
    @State private var titleHoverTask: Task<Void, Never>? = nil
    @State private var noteHoverTask: Task<Void, Never>? = nil
    @State var hasCopied = false
    @State var hasNoteCopied = false
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
        hovering || isPointerHovered || isNoteHovered || isNoteBubbleHovered || isTitleBubbleHovered
    }

    // MARK: - 现代标准构造器 (State + Action)

    init(state: TaskRowState, onSaveTitle: ((String) -> Bool)? = nil, dispatch: @escaping (TaskRowAction) -> Void) {
        self.state = state
        self.onSaveTitle = onSaveTitle
        self.dispatch = dispatch
    }

    var body: some View {
        rowContent
            .onHover { isHovering in
                hovering = isHovering
                if !isHovering {
                    titleHoverTask?.cancel()
                    titleHoverTask = nil
                    noteHoverTask?.cancel()
                    noteHoverTask = nil
                    if !isTitleBubbleHovered {
                        withAnimation(DaybookMotion.interactive(reduceMotion)) {
                            isTitleTextHovered = false
                        }
                    }
                    if !isNoteBubbleHovered {
                        withAnimation(DaybookMotion.interactive(reduceMotion)) {
                            isNoteHovered = false
                        }
                    }
                }
            }
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
                startObservingModifiers()
            }
            .onDisappear {
                stopObservingModifiers()
                titleHoverTask?.cancel()
                titleHoverTask = nil
                noteHoverTask?.cancel()
                noteHoverTask = nil
            }
            .onChange(of: state.title) { _, value in
                if !editing { draft = value }
            }
            .onChange(of: state.isExternalEditing) { _, value in
                if value && !editing { beginEdit() }
            }
            .zIndex((shouldShowTitleBubble || shouldShowNoteBubble) ? 120 : (isHovered ? 100 : 1))
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

                if hasVisibleMetadata {
                    metadataCluster
                }

                actionCluster
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(minHeight: style.isWorkspace ? WorkspaceStyle.rowHeight : 36)
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
            && (isTitleTextHovered || isPointerHovered || isTitleBubbleHovered) && !isNoteHovered && !isNoteBubbleHovered && isTitleTruncated
    }

    private var shouldShowNoteBubble: Bool {
        !style.isWorkspace && !editing && !pickingDay && !pickingTime && (isNoteHovered || isNoteBubbleHovered) && fullNoteText != nil
    }

    private var selectableContent: some View {
        HStack(alignment: .center, spacing: 5) {
            titleContent
                .layoutPriority(1)
                .overlay(TaskRowPointerRegion(
                    id: state.id,
                    onSelect: { dispatch(.select($0)) },
                    onEdit: beginEdit,
                    onHover: { isPointerHovered = $0 }
                )
                .padding(.top, -6)
                .padding(.bottom, isSubtasksExpanded && !state.subtasks.isEmpty ? 0 : -6)
                .accessibilityHidden(true))

            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 20)
                .contentShape(Rectangle())
                .overlay(TaskRowPointerRegion(
                    id: state.id,
                    onSelect: { dispatch(.select($0)) },
                    onEdit: beginEdit
                )
                .padding(.top, -6)
                .padding(.bottom, isSubtasksExpanded && !state.subtasks.isEmpty ? 0 : -6)
                .accessibilityHidden(true))

            if !style.isWorkspace, fullNoteText != nil {
                noteIndicator
                    .fixedSize()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        Image(systemName: hasNoteCopied ? "checkmark" : "text.alignleft")
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(hasNoteCopied ? DaybookTheme.stamp : (isNoteHovered ? DaybookTheme.stamp : DaybookTheme.muted.opacity(0.65)))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(hasNoteCopied ? DaybookTheme.stamp.opacity(0.16) : (isNoteHovered ? DaybookTheme.stamp.opacity(0.12) : DaybookTheme.ink.opacity(0.04)))
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
            .onHover { isHovering in
                noteHoverTask?.cancel()
                if isHovering {
                    noteHoverTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(300))
                        guard !Task.isCancelled else { return }
                        withAnimation(DaybookMotion.interactive(reduceMotion)) {
                            isNoteHovered = true
                        }
                    }
                } else {
                    noteHoverTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(100))
                        guard !Task.isCancelled else { return }
                        if !isNoteBubbleHovered {
                            withAnimation(DaybookMotion.interactive(reduceMotion)) {
                                isNoteHovered = false
                            }
                        }
                    }
                }
            }
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
                .layoutPriority(1)
                .contentShape(Rectangle())
                .onHover { isHovering in
                    titleHoverTask?.cancel()
                    if isHovering {
                        titleHoverTask = Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(300))
                            guard !Task.isCancelled else { return }
                            withAnimation(DaybookMotion.interactive(reduceMotion)) {
                                isTitleTextHovered = true
                            }
                        }
                    } else {
                        titleHoverTask = Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(100))
                            guard !Task.isCancelled else { return }
                            if !isTitleBubbleHovered {
                                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                                    isTitleTextHovered = false
                                }
                            }
                        }
                    }
                }
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

    private var hasVisibleMetadata: Bool {
        state.isImportant || state.classify?.isImportant == true
            || state.isUrgent || state.classify?.isUrgent == true
            || !attachedTagNames.isEmpty
            || (state.isResident && (state.streak ?? 0) >= 1)
            || state.remindMinutes != nil
            || !state.subtasks.isEmpty
            || !(state.attachments?.items.isEmpty ?? true)
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

    func copyTask() {
        var content = state.title
        if let note = fullNoteText, !note.isEmpty {
            content += "\n" + note
        }
        copyToClipboard(content)
        withAnimation(DaybookMotion.interactive(reduceMotion)) {
            hasCopied = true
        }
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
