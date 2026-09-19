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
    @State var isCommandPressed = false
    @State private var flagsMonitor: Any? = nil
    @State var draft = ""
    @State var pickingDay = false
    @State var pickingTime = false
    @State private var isSubtasksExpanded = false
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

    private var shouldShowNoteBubble: Bool {
        !style.isWorkspace && !editing && !pickingDay && !pickingTime && isHovered && fullNoteText != nil
    }

    private var noteFloatingBubble: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer().frame(width: 6)
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(DaybookTheme.paper)
                    .offset(y: 1)
                Spacer()
            }
            .frame(height: 5)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(DaybookTheme.stamp)
                    Text(L10n.string("drawer.notes.title", locale: locale))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DaybookTheme.muted)
                    Spacer(minLength: 0)
                }

                Text(fullNoteText ?? "")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(DaybookTheme.ink)
                    .lineSpacing(2.5)
                    .lineLimit(8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .frame(width: 210, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(DaybookTheme.paper)
                    .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(DaybookTheme.rule.opacity(0.8), lineWidth: 0.8)
            )
        }
        .frame(width: 210, alignment: .leading)
        .fixedSize()
        .allowsHitTesting(false)
    }

    private var selectableContent: some View {
        titleContent
            .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
            .overlay(TaskRowPointerRegion(
                id: state.id,
                onSelect: { dispatch(.select($0)) },
                onEdit: beginEdit,
                onHover: { isPointerHovered = $0 }
            )
            .padding(.top, -6)
            .padding(.bottom, isSubtasksExpanded && !state.subtasks.isEmpty ? 0 : -6)
            .accessibilityHidden(true))
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
            .foregroundStyle(isHovered ? DaybookTheme.stamp : DaybookTheme.muted.opacity(0.65))
            .padding(.horizontal, 3.5)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(isHovered ? DaybookTheme.stamp.opacity(0.12) : DaybookTheme.ink.opacity(0.04))
            )
            .contentShape(Rectangle())
            .onHover { isNoteHovered = $0 }
            .overlay(alignment: .topLeading) {
                if shouldShowNoteBubble {
                    noteFloatingBubble
                        .offset(x: -8, y: 16)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .topLeading)),
                            removal: .opacity
                        ))
                }
            }
    }

    private var titleContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .center, spacing: 5) {
                ModernTaskTitle(text: state.title, isDone: state.isDone)
                    .lineLimit(style.isWorkspace ? 2 : 1)
                    .truncationMode(.tail)

                if !style.isWorkspace, fullNoteText != nil {
                    noteIndicator
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
        .contentShape(Rectangle())
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
