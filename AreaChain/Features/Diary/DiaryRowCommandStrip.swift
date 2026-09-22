import SwiftUI

/// 手记卡片按住 ⌘ 时的平铺快捷操作条
struct DiaryRowCommandStrip: View {
    var isSensitive: Bool
    var isPinned: Bool
    var hasConvertedToTask: Bool = false
    var allTags: [TagItem] = []
    var assignedTagIDs: Set<UUID> = []
    var currentDayKey: String = ""
    var onOpen: () -> Void
    var onConvertToTask: () -> Void
    var onCopy: () -> Void
    var onToggleTag: (UUID) -> Void
    var onMoveToDay: (String) -> Void
    var onPickCustomDate: () -> Void
    var onTogglePin: () -> Void
    var onAttach: () -> Void
    var onTogglePrivate: () -> Void
    var onInspect: () -> Void
    var onDelete: () -> Void

    @Environment(\.locale) private var locale
    @State private var hoveredQuickActionTip: String? = nil

    var body: some View {
        BoardCommandStrip(
            hoveredTip: hoveredQuickActionTip,
            destructiveTitle: L10n.string("diary.quick.delete", locale: locale)
        ) {
                commandStripButton(
                    icon: "arrow.up.forward",
                    key: "diary.quick.open",
                    action: onOpen
                )

                // 2. 转为今日待办 􀆅
                commandStripButton(
                    icon: hasConvertedToTask ? "checkmark" : "checklist",
                    key: hasConvertedToTask ? "diary.quick.converted_task" : "diary.quick.convert_task",
                    isActive: hasConvertedToTask,
                    action: onConvertToTask
                )

                // 3. 复制手记 📋
                commandStripButton(
                    icon: "square.on.square",
                    key: "diary.quick.copy",
                    action: onCopy
                )

                // 4. 标签选择 🏷
                if !allTags.isEmpty {
                    commandStripMenu(
                        icon: "tag",
                        key: "diary.quick.tags",
                        isActive: !assignedTagIDs.isEmpty
                    ) {
                        DiaryTagToggleButtons(tags: allTags, assignedIDs: assignedTagIDs, onToggle: onToggleTag)
                    }
                }

                // 5. 调整归属日期 📅
                commandStripMenu(
                    icon: "calendar",
                    key: "diary.quick.schedule",
                    isActive: currentDayKey == DayKey.today()
                ) {
                    DiaryDayMoveButtons(onMove: onMoveToDay, onPickCustom: onPickCustomDate)
                }

                // 6. 置顶 / 取消置顶 📌
                commandStripButton(
                    icon: isPinned ? "pin.slash" : "pin",
                    key: isPinned ? "diary.quick.unpin" : "diary.quick.pin",
                    isActive: isPinned,
                    action: onTogglePin
                )

                // 7. 添加附件 📎
                commandStripButton(
                    icon: "paperclip",
                    key: "diary.quick.attach",
                    action: onAttach
                )
                .disabled(isSensitive)

                // 8. 私密加锁 🔒
                commandStripButton(
                    icon: isSensitive ? "lock.fill" : "lock",
                    key: isSensitive ? "diary.quick.privacy.unlock" : "diary.quick.privacy.lock",
                    isActive: isSensitive,
                    action: onTogglePrivate
                )

                // 9. 工作台查看 🖥
                commandStripButton(
                    icon: "sidebar.left",
                    key: "diary.quick.workspace",
                    action: onInspect
                )
        } destructive: {
            commandStripButton(
                icon: "trash",
                key: "diary.quick.delete",
                isDestructive: true,
                action: onDelete
            )
        }
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
