import SwiftUI

/// 任务行：只读状态快照加动作派发。
struct TaskRow: View {
    let state: TaskRowState
    let dispatch: (TaskRowAction) -> Void

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var editing = false
    @State private var hovering = false
    @State private var draft = ""
    @State private var pickingDay = false
    @State private var pickingTime = false
    @State private var isSubtasksExpanded = false
    @FocusState private var editorFocused: Bool

    // MARK: - 现代标准构造器 (State + Action)

    init(state: TaskRowState, dispatch: @escaping (TaskRowAction) -> Void) {
        self.state = state
        self.dispatch = dispatch
    }

    var body: some View {
        rowContent
            .onTapGesture(count: 2) {
                beginEdit()
            }
            .onTapGesture(count: 1) {
                dispatch(.select)
            }
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
            .modifier(TodoDragIfNeeded(payload: state.dragPayload))
    }

    private var rowContent: some View {
        HStack(alignment: shouldAlignTop ? .top : .center, spacing: 8) {
            ModernCheckbox(isDone: state.isDone) {
                dispatch(.toggleDone)
            }

            if state.isResident {
                residentMark
            }

            QuadrantDots(
                isImportant: state.classify?.isImportant == true || state.isImportant,
                isUrgent: state.classify?.isUrgent == true || state.isUrgent
            )

            if editing {
                editor
            } else {
                titleContent
            }

            Spacer(minLength: 8)

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
        state.note != nil || state.notes != nil || !state.subtasks.isEmpty || editing
    }

    // MARK: - Subviews

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

            if isSubtasksExpanded && !state.subtasks.isEmpty {
                TaskRowSubtaskInlineList(subtasks: state.subtasks) { subtaskID in
                    dispatch(.toggleSubtask(subtaskID))
                }
                .padding(.top, 2)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var metadataCluster: some View {
        HStack(spacing: 6) {
            if state.isResident, let streak = state.streak, streak >= 1 {
                PillBadge(
                    title: "\(streak)",
                    icon: "flame.fill",
                    color: .orange,
                    isSelected: true
                )
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
    }

    private var formattedNoteSnippet: String? {
        guard let notes = state.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let firstLine = notes.components(separatedBy: .newlines).first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        return firstLine?.trimmingCharacters(in: .whitespaces)
    }

    @ViewBuilder
    private func remindBadge(_ minutes: Int) -> some View {
        let badge = PillBadge(
            title: RemindMinutes.label(minutes, locale: locale),
            icon: "clock.fill",
            color: DaybookTheme.stamp,
            isSelected: true
        )
        if state.canSetRemind {
            Button {
                pickingTime = true
            } label: {
                badge
            }
            .buttonStyle(.plain)
        } else {
            badge
        }
    }

    private var editor: some View {
        TextField("row.edit.field", text: $draft)
            .textFieldStyle(.plain)
            .font(DaybookType.body)
            .foregroundStyle(DaybookTheme.ink)
            .focused($editorFocused)
            .onSubmit(saveEdit)
            .onExitCommand(perform: cancelEdit)
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

    private func beginEdit() {
        draft = state.title
        editing = true
        DispatchQueue.main.async {
            editorFocused = true
        }
    }

    private func cancelEdit() {
        draft = state.title
        editing = false
        editorFocused = false
        dispatch(.endEditing)
    }

    private func saveEdit() {
        let next = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !next.isEmpty {
            dispatch(.editTitle(next))
        } else {
            draft = state.title
        }
        editing = false
        editorFocused = false
        dispatch(.endEditing)
    }
}

// MARK: - Menus & Actions

extension TaskRow {
    @ViewBuilder
    private var actionCluster: some View {
        HStack(spacing: 2) {
            if editing {
                RowIconButton(systemName: "checkmark", label: "row.save", action: saveEdit)
                RowIconButton(systemName: "xmark", label: "row.cancel", action: cancelEdit)
            } else if hovering || state.isSelected {
                RowIconButton(systemName: "pencil", label: "row.edit", action: beginEdit)
                RowIconButton(systemName: "trash", label: "row.delete", role: .destructive) {
                    dispatch(.delete)
                }
                moreMenu
            }
        }
        .animation(DaybookMotion.interactive(reduceMotion), value: hovering)
    }

    private var moreMenu: some View {
        Menu {
            overflowMenus
            Button("row.delete", role: .destructive) {
                dispatch(.delete)
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(DaybookType.subtitle.weight(.semibold))
                .frame(width: DaybookTheme.hit, height: DaybookTheme.hit)
                .contentShape(Rectangle())
        }
        .buttonStyle(DaybookQuietButtonStyle())
        .menuIndicator(.hidden)
        .help("row.more")
        .accessibilityLabel("row.more")
    }

    @ViewBuilder
    var menus: some View {
        Button("row.edit", action: beginEdit)
        overflowMenus
        Button("row.delete", role: .destructive) {
            dispatch(.delete)
        }
    }

    @ViewBuilder
    private var overflowMenus: some View {
        timeMenus
        classifyMenus
        attachmentMenus
        if state.todayKey != nil {
            DayScheduleMenu(
                todayKey: state.todayKey ?? "",
                currentDayKey: state.currentDayKey,
                onMove: { dispatch(.moveToDay($0)) },
                pickingDay: $pickingDay
            )
        }
        standingMenus
        if state.canSkip {
            Button("row.skip") {
                dispatch(.skip)
            }
        }
    }

    @ViewBuilder
    private var timeMenus: some View {
        if state.canSetRemind {
            Button("row.time.set") {
                if state.remindMinutes == nil {
                    dispatch(.setRemindMinutes(RemindMinutes.from(date: .now)))
                }
                pickingTime = true
            }
            if state.remindMinutes != nil {
                Button("row.time.clear") {
                    dispatch(.setRemindMinutes(nil))
                }
            }
        }
    }

    @ViewBuilder
    private var standingMenus: some View {
        if state.isResident {
            if let weekdaysOnly = state.weekdaysOnly {
                Button(weekdaysOnly ? "row.everyday" : "row.weekdays") {
                    dispatch(.setWeekdaysOnly(!weekdaysOnly))
                }
            }
            if let isEnabled = state.isEnabled {
                if isEnabled {
                    Button("row.disable") {
                        dispatch(.setEnabled(false))
                    }
                } else {
                    Button("row.enable") {
                        dispatch(.setEnabled(true))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var classifyMenus: some View {
        if let classify = state.classify {
            Button(classify.isImportant ? "classify.important.on" : "classify.important") {
                classify.onImportant(!classify.isImportant)
            }
            Button(classify.isUrgent ? "classify.urgent.on" : "classify.urgent") {
                classify.onUrgent(!classify.isUrgent)
            }
            if !classify.projects.isEmpty {
                Menu("classify.project") {
                    Button("classify.project.none") { classify.onProject(nil) }
                    ForEach(classify.projects) { project in
                        Button {
                            classify.onProject(project.id)
                        } label: {
                            if classify.projectID == project.id {
                                Label(project.name, systemImage: "checkmark")
                            } else {
                                Text(project.name)
                            }
                        }
                    }
                }
            }
            if !classify.tags.isEmpty {
                Menu("classify.tags") {
                    ForEach(classify.tags) { tag in
                        let on = TagIDList.contains(classify.tagIDs, tag.id)
                        Button {
                            classify.onToggleTag(tag.id)
                        } label: {
                            if on {
                                Label(tag.name, systemImage: "checkmark")
                            } else {
                                Text(tag.name)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var attachmentMenus: some View {
        if let attachments = state.attachments {
            Button("row.attach", action: attachments.onPickFile)
            Button("row.attach.paste", action: attachments.onPaste)
            if let onCapture = attachments.onCaptureScreen {
                Button("row.attach.screen", action: onCapture)
            }
        }
    }
}
