import SwiftUI

// MARK: - TaskRow ⌘ 平铺极速快捷操作条（与「···」更多菜单 1:1 完全对齐）

extension TaskRow {
    @ViewBuilder
    var commandActionStrip: some View {
        BoardCommandStrip(
            hoveredTip: hoveredQuickActionTip,
            destructiveTitle: L10n.string("row.quick.delete", locale: locale)
        ) {
            editAndScheduleButtons
            classificationButtons
            attachmentAndHabitButtons
        } destructive: {
            destructiveButton
        }
    }

    @ViewBuilder
    private var editAndScheduleButtons: some View {
        commandStripButton(
            icon: "pencil",
            key: "row.quick.edit"
        ) {
            beginEdit()
        }

        // 2. 排程日期 📅 (移至明天 + 自定义日期)
        if state.todayKey != nil {
            commandStripMenu(
                icon: "calendar",
                key: "row.quick.schedule",
                isActive: state.todayKey != nil
            ) {
                scheduleSection
            }
        }

        // 3. 提醒时间 ⏰ (设置时刻 + 清除时刻)
        if state.canSetRemind {
            commandStripMenu(
                icon: "clock",
                key: "row.quick.remind",
                isActive: state.remindMinutes != nil
            ) {
                timeMenus
            }
        }
    }

    @ViewBuilder
    private var classificationButtons: some View {
        // 4. 四象限优先级 ⚡️ (P1~P4 + 清除)
        if state.classify != nil {
            commandStripMenu(
                icon: "exclamationmark.circle",
                key: "row.quick.priority",
                isActive: hasActivePriority
            ) {
                priorityMenuItems
            }
        }

        // 标签
        if let classify = state.classify, !classify.tags.isEmpty {
            commandStripMenu(
                icon: "tag",
                key: "row.quick.tags",
                isActive: !attachedTagNames.isEmpty
            ) {
                tagsMenuItems(classify)
            }
        }
    }

    @ViewBuilder
    private var attachmentAndHabitButtons: some View {
        // 7. 附件与采集 📎 (添加文件 + 粘贴 + 截图标注)
        if state.attachments != nil {
            commandStripMenu(
                icon: "paperclip",
                key: "row.quick.attach",
                isActive: (state.attachments?.items.count ?? 0) > 0
            ) {
                attachmentMenus
            }
        }

        // 8. 习惯常驻规则 🔄 (工作日/每天 + 启用/停用)
        if state.isResident {
            commandStripMenu(
                icon: "repeat",
                key: "row.quick.resident",
                isActive: state.isEnabled == true
            ) {
                standingMenus
            }
        }

        // 9. 习惯跳过 ⏭ (跳过今天)
        if state.canSkip {
            commandStripButton(
                icon: "forward.frame",
                key: "row.quick.skip"
            ) {
                dispatch(.skip)
            }
        }
    }

    private var destructiveButton: some View {
        commandStripButton(
            icon: "trash",
            key: "row.quick.delete",
            isDestructive: true
        ) {
            dispatch(.delete)
        }
        .fixedSize()
    }

    private func commandStripButton(
        icon: String,
        key: String,
        isActive: Bool = false,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        BoardCommandStripButton(
            icon: icon,
            labelKey: key,
            isActive: isActive,
            isDestructive: isDestructive,
            hoveredTip: $hoveredQuickActionTip,
            action: action
        )
    }

    private func commandStripMenu<Content: View>(
        icon: String,
        key: String,
        isActive: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        BoardCommandStripMenu(icon: icon, labelKey: key, isActive: isActive, hoveredTip: $hoveredQuickActionTip, content: content)
    }
}
