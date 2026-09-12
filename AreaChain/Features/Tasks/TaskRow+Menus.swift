import SwiftUI

// MARK: - TaskRow Menus & Overflow Actions

extension TaskRow {
    @ViewBuilder
    var actionCluster: some View {
        HStack(spacing: 2) {
            if editing {
                RowIconButton(systemName: "checkmark", label: "row.save", action: saveEdit)
                RowIconButton(systemName: "xmark", label: "row.cancel", action: cancelEdit)
            } else if hovering || state.isSelected {
                moreMenu
            }
        }
        .frame(minWidth: 22)
        .animation(DaybookMotion.interactive(reduceMotion), value: hovering)
    }

    private var moreMenu: some View {
        Menu {
            Button("row.edit", action: beginEdit)
            Divider()
            overflowMenus
            Divider()
            Button("row.delete", role: .destructive) {
                dispatch(.delete)
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DaybookTheme.muted)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(DaybookTheme.ink.opacity(0.06))
                )
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
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
