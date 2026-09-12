import SwiftUI

/// 任务行：只读状态快照加动作派发。
struct TaskRow: View {
    let state: TaskRowState
    let dispatch: (TaskRowAction) -> Void
    var onSaveTitle: ((String) -> Bool)? = nil

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @State var editing = false
    @State var hovering = false
    @State var draft = ""
    @State var pickingDay = false
    @State var pickingTime = false
    @State private var isSubtasksExpanded = false
    @State private var autocomplete = SyntaxAutocompleteState()
    // 输入由 NSTextField 承载，焦点请求使用原生绑定，避免 SwiftUI 焦点树将其复位。
    @State var editorFocused = false

    // MARK: - 现代标准构造器 (State + Action)

    init(state: TaskRowState, onSaveTitle: ((String) -> Bool)? = nil, dispatch: @escaping (TaskRowAction) -> Void) {
        self.state = state
        self.onSaveTitle = onSaveTitle
        self.dispatch = dispatch
    }

    var body: some View {
        rowContent
            .onHover { hovering = $0 }
            .animation(DaybookMotion.interactive(reduceMotion), value: hovering)
            .animation(DaybookMotion.interactive(reduceMotion), value: state.isSelected)
            .contextMenu { menus }
            .popover(isPresented: $pickingDay) {
                daySchedulePopover
            }
            .popover(isPresented: $pickingTime) {
                timePicker
            }
            .onAppear { draft = state.title }
            .onChange(of: state.title) { _, value in
                if !editing { draft = value }
            }
            .onChange(of: state.isExternalEditing) { _, value in
                if value && !editing { beginEdit() }
            }
    }

    private var rowContent: some View {
        HStack(alignment: shouldAlignTop ? .top : .center, spacing: 8) {
            ModernCheckbox(isDone: state.isDone) {
                dispatch(.toggleDone)
            }

            QuadrantDots(
                isImportant: state.classify?.isImportant == true || state.isImportant,
                isUrgent: state.classify?.isUrgent == true || state.isUrgent
            )

            if editing {
                editor
                    .frame(maxWidth: .infinity, alignment: .leading)
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
            }

            metadataCluster

            actionCluster
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .modernRow(
            cornerRadius: DaybookRadius.small,
            isHovered: hovering,
            isSelected: state.isSelected
        )
        .contentShape(RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous))
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
        if let note = state.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        if let source = state.classify?.sourceLabel, !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        return formattedNoteSnippet != nil
    }

    // MARK: - Subviews

    private var selectableContent: some View {
        titleContent
            .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
            .overlay(TaskRowPointerRegion(
                id: state.id,
                onSelect: { dispatch(.select($0)) },
                onEdit: beginEdit
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

    private var titleContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            ModernTaskTitle(text: state.title, isDone: state.isDone)
                .lineLimit(2)

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
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookTheme.muted.opacity(0.75))
            }

        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var metadataCluster: some View {
        HStack(spacing: 5) {
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
        .opacity(hovering || state.isSelected ? 1.0 : 0.65)
        .animation(DaybookMotion.interactive(reduceMotion), value: hovering)
    }

    private var formattedNoteSnippet: String? {
        guard let notes = state.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let firstLine = notes.components(separatedBy: .newlines).first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        return firstLine?.trimmingCharacters(in: .whitespaces)
    }

    private func streakBadge(_ streak: Int) -> some View {
        let isHighlighted = hovering || state.isSelected
        return HStack(spacing: 2.5) {
            Image(systemName: "flame.fill")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(isHighlighted ? Color.orange : DaybookTheme.muted.opacity(0.75))
            Text("\(streak)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(isHighlighted ? DaybookTheme.ink : DaybookTheme.muted.opacity(0.75))
                .lineLimit(1)
                .offset(y: -0.6)
        }
        .fixedSize()
        .padding(.horizontal, 4.5)
        .frame(height: 18)
        .background(
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .fill(isHighlighted ? Color.orange.opacity(0.12) : Color.clear)
        )
    }

    @ViewBuilder
    private func remindBadge(_ minutes: Int) -> some View {
        let isHighlighted = hovering || state.isSelected
        let content = HStack(spacing: 2.5) {
            Image(systemName: "clock")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(isHighlighted ? DaybookTheme.stamp : DaybookTheme.muted.opacity(0.75))
            Text(RemindMinutes.label(minutes, locale: locale))
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(isHighlighted ? DaybookTheme.ink : DaybookTheme.muted.opacity(0.75))
                .lineLimit(1)
                .offset(y: -0.6)
        }
        .fixedSize()
        .padding(.horizontal, 4.5)
        .frame(height: 18)
        .background(
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .fill(isHighlighted ? DaybookTheme.stamp.opacity(0.10) : Color.clear)
        )

        if state.canSetRemind {
            Button {
                pickingTime = true
            } label: {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            DaybookTextField(
                text: $draft,
                placeholder: L10n.string("row.edit.field", locale: locale),
                fontSize: 13,
                focus: $editorFocused,
                autocomplete: autocomplete,
                availableTags: state.classify?.tags.map(\.name) ?? [],
                onSubmit: saveEdit,
                onEscape: cancelEdit
            )
            .onExitCommand(perform: cancelEdit)
            .onAppear {
                DispatchQueue.main.async { editorFocused = true }
            }

            if autocomplete.isActive {
                SyntaxAutocompletePopup(state: autocomplete) { candidate in
                    if let trigger = autocomplete.trigger {
                        let (newText, _) = SyntaxAutocompleteEngine.applyCandidate(
                            candidate,
                            to: draft,
                            range: trigger.range
                        )
                        draft = newText
                        autocomplete.dismiss()
                    }
                }
                .padding(.top, 24)
                .zIndex(100)
            }
        }
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
        autocomplete.dismiss()
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
        autocomplete.dismiss()
        dispatch(.endEditing)
    }
}
