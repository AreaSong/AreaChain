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

    // MARK: - ⌘ 平铺极速快捷操作条（纯图标 + 悬浮聚焦信息提示）

    @ViewBuilder
    var commandActionStrip: some View {
        HStack(spacing: 4) {
            // 1. 编辑标题 ✏️
            commandStripButton(
                icon: "pencil",
                key: "row.quick.edit"
            ) {
                beginEdit()
            }

            // 2. 提醒时间 ⏰
            if state.canSetRemind {
                commandStripButton(
                    icon: "clock",
                    key: "row.quick.remind",
                    isActive: state.remindMinutes != nil
                ) {
                    if state.remindMinutes == nil {
                        dispatch(.setRemindMinutes(RemindMinutes.from(date: .now)))
                    }
                    pickingTime = true
                }
            }

            // 3. 四象限优先级 ⚡️
            if state.classify != nil {
                Menu {
                    priorityMenuItems
                } label: {
                    commandStripIcon(
                        icon: "exclamationmark.circle",
                        key: "row.quick.priority",
                        isActive: hasActivePriority
                    )
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
            }

            // 4. 移至明天 📅
            if state.todayKey != nil {
                commandStripButton(
                    icon: "arrow.right.circle",
                    key: "row.quick.tomorrow",
                    isActive: false
                ) {
                    let tomorrow = DayKey.tomorrow(from: .now)
                    dispatch(.moveToDay(tomorrow))
                }
            }

            // 5. 归属项目 📁
            if let classify = state.classify, !classify.projects.isEmpty {
                Menu {
                    projectMenuItems(classify)
                } label: {
                    commandStripIcon(
                        icon: "folder",
                        key: "row.quick.project",
                        isActive: classify.projectID != nil
                    )
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
            }

            // 6. 标签 🏷
            if let classify = state.classify, !classify.tags.isEmpty {
                Menu {
                    tagsMenuItems(classify)
                } label: {
                    commandStripIcon(
                        icon: "tag",
                        key: "row.quick.tags",
                        isActive: !attachedTagNames.isEmpty
                    )
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
            }

            // 7. 习惯跳过 ⏭
            if state.canSkip {
                commandStripButton(
                    icon: "forward.frame",
                    key: "row.quick.skip"
                ) {
                    dispatch(.skip)
                }
            }

            // 悬浮聚焦文字提示区（新用户悬浮出信息，老用户凭图标盲操）
            if let tip = hoveredQuickActionTip {
                Text(tip)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(tip == L10n.string("row.quick.delete", locale: locale) ? Color.red : DaybookTheme.ink.opacity(0.85))
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .fill(tip == L10n.string("row.quick.delete", locale: locale) ? Color.red.opacity(0.08) : DaybookTheme.ink.opacity(0.06))
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.92, anchor: .leading)),
                        removal: .opacity
                    ))
            }

            Spacer(minLength: 4)

            // 8. 移入废纸篓 🗑（靠最右侧，危险操作）
            commandStripButton(
                icon: "trash",
                key: "row.quick.delete",
                isDestructive: true
            ) {
                dispatch(.delete)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
    }

    private var hasActivePriority: Bool {
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

    private func commandStripButton(
        icon: String,
        key: String,
        isActive: Bool = false,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            commandStripIcon(icon: icon, key: key, isActive: isActive, isDestructive: isDestructive)
        }
        .buttonStyle(.plain)
    }

    private func commandStripIcon(
        icon: String,
        key: String,
        isActive: Bool = false,
        isDestructive: Bool = false
    ) -> some View {
        let localizedText = L10n.string(String.LocalizationValue(stringLiteral: key), locale: locale)
        let isButtonHovered = hoveredQuickActionTip == localizedText

        return Image(systemName: icon)
            .font(.system(size: 10.5, weight: .medium))
            .frame(width: 22, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                    .fill(
                        isDestructive
                            ? (isButtonHovered ? Color.red.opacity(0.18) : Color.red.opacity(0.08))
                            : (isActive
                                ? DaybookTheme.stamp.opacity(isButtonHovered ? 0.22 : 0.14)
                                : (isButtonHovered ? DaybookTheme.ink.opacity(0.12) : DaybookTheme.ink.opacity(0.05)))
                    )
            )
            .foregroundStyle(
                isDestructive
                    ? Color.red
                    : (isActive ? DaybookTheme.stamp : DaybookTheme.ink.opacity(isButtonHovered ? 0.95 : 0.72))
            )
            .contentShape(Rectangle())
            .help(LocalizedStringKey(key))
            .onHover { hovering in
                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                    if hovering {
                        hoveredQuickActionTip = localizedText
                    } else if hoveredQuickActionTip == localizedText {
                        hoveredQuickActionTip = nil
                    }
                }
            }
    }

    // MARK: - 子菜单辅助

    @ViewBuilder
    private var scheduleSection: some View {
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
    private var priorityMenuItems: some View {
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
    private func projectMenuItems(_ classify: TaskClassifyContext) -> some View {
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
    private func tagsMenuItems(_ classify: TaskClassifyContext) -> some View {
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
