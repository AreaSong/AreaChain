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

    // MARK: - 「···」 4 逻辑分区更多菜单

    private var moreMenu: some View {
        Menu {
            // 分区 1: 编辑与排程
            Button("row.edit", action: beginEdit)
            scheduleSection
            timeMenus

            Divider()

            // 分区 2: 四象限与分类
            prioritySubMenu
            projectSubMenu
            tagsSubMenu

            Divider()

            // 分区 3: 附件与习惯上下文
            attachmentMenus
            standingMenus
            if state.canSkip {
                Button("row.skip") {
                    dispatch(.skip)
                }
            }

            Divider()

            // 分区 4: 危险区（移入废纸篓）
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
        scheduleSection
        timeMenus
        Divider()
        prioritySubMenu
        projectSubMenu
        tagsSubMenu
        Divider()
        attachmentMenus
        standingMenus
        if state.canSkip {
            Button("row.skip") {
                dispatch(.skip)
            }
        }
        Divider()
        Button("row.delete", role: .destructive) {
            dispatch(.delete)
        }
    }
    var hasActivePriority: Bool {
        state.classify?.isImportant == true || state.isImportant || state.classify?.isUrgent == true || state.isUrgent
    }

    func setQuadrant(_ slot: QuadrantSlot?) {
        guard let classify = state.classify else { return }
        switch slot {
        case .importantUrgent:
            classify.onImportant(true)
            classify.onUrgent(true)
        case .important:
            classify.onImportant(true)
            classify.onUrgent(false)
        case .urgent:
            classify.onImportant(false)
            classify.onUrgent(true)
        case .rest, .none:
            classify.onImportant(false)
            classify.onUrgent(false)
        }
    }

    // MARK: - 子菜单辅助

    @ViewBuilder
    var scheduleSection: some View {
        if state.todayKey != nil {
            Button {
                let tomorrow = DayKey.tomorrow(from: .now)
                dispatch(.moveToDay(tomorrow))
            } label: {
                Label("row.tomorrow", systemImage: "arrow.right.circle")
            }
            DayScheduleMenu(
                todayKey: state.todayKey ?? "",
                currentDayKey: state.currentDayKey,
                onMove: { dispatch(.moveToDay($0)) },
                pickingDay: $pickingDay
            )
        }
    }

    @ViewBuilder
    var timeMenus: some View {
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
    private var prioritySubMenu: some View {
        if state.classify != nil {
            Menu {
                priorityMenuItems
            } label: {
                Label("classify.priority", systemImage: "exclamationmark.circle")
            }
        }
    }

    @ViewBuilder
    var priorityMenuItems: some View {
        let currentImportant = state.classify?.isImportant == true || state.isImportant
        let currentUrgent = state.classify?.isUrgent == true || state.isUrgent
        let currentSlot = QuadrantSlot.of(important: currentImportant, urgent: currentUrgent)
        let hasPriority = currentImportant || currentUrgent

        Button {
            setQuadrant(.importantUrgent)
        } label: {
            if currentSlot == .importantUrgent && hasPriority {
                Label("P1 · \(L10n.string("quadrant.iu", locale: locale))", systemImage: "checkmark")
            } else {
                Text("P1 · \(L10n.string("quadrant.iu", locale: locale))")
            }
        }
        Button {
            setQuadrant(.important)
        } label: {
            if currentSlot == .important && hasPriority {
                Label("P2 · \(L10n.string("quadrant.i", locale: locale))", systemImage: "checkmark")
            } else {
                Text("P2 · \(L10n.string("quadrant.i", locale: locale))")
            }
        }
        Button {
            setQuadrant(.urgent)
        } label: {
            if currentSlot == .urgent && hasPriority {
                Label("P3 · \(L10n.string("quadrant.u", locale: locale))", systemImage: "checkmark")
            } else {
                Text("P3 · \(L10n.string("quadrant.u", locale: locale))")
            }
        }
        Button {
            setQuadrant(.rest)
        } label: {
            if currentSlot == .rest && hasPriority {
                Label("P4 · \(L10n.string("quadrant.rest", locale: locale))", systemImage: "checkmark")
            } else {
                Text("P4 · \(L10n.string("quadrant.rest", locale: locale))")
            }
        }
        if hasPriority {
            Divider()
            Button("classify.priority.clear") {
                setQuadrant(nil)
            }
        }
    }

    @ViewBuilder
    private var projectSubMenu: some View {
        if let classify = state.classify, !classify.projects.isEmpty {
            Menu {
                projectMenuItems(classify)
            } label: {
                Label("classify.project", systemImage: "folder")
            }
        }
    }

    @ViewBuilder
    func projectMenuItems(_ classify: TaskClassifyContext) -> some View {
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

    @ViewBuilder
    private var tagsSubMenu: some View {
        if let classify = state.classify, !classify.tags.isEmpty {
            Menu {
                tagsMenuItems(classify)
            } label: {
                Label("classify.tags", systemImage: "tag")
            }
        }
    }

    @ViewBuilder
    func tagsMenuItems(_ classify: TaskClassifyContext) -> some View {
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

    @ViewBuilder
    var standingMenus: some View {
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
    var attachmentMenus: some View {
        if let attachments = state.attachments {
            Button("row.attach", action: attachments.onPickFile)
            Button("row.attach.paste", action: attachments.onPaste)
            if let onCapture = attachments.onCaptureScreen {
                Button("row.attach.screen", action: onCapture)
            }
        }
    }
}
