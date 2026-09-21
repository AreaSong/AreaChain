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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoveredQuickActionTip: String? = nil

    var body: some View {
        HStack(spacing: 3) {
            HStack(spacing: 2.5) {
                // 1. 打开独立大窗口 ↗
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
                        ForEach(allTags) { tag in
                            Button {
                                onToggleTag(tag.id)
                            } label: {
                                HStack {
                                    Text("#" + tag.name)
                                    if assignedTagIDs.contains(tag.id) {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }

                // 5. 调整归属日期 📅
                commandStripMenu(
                    icon: "calendar",
                    key: "diary.quick.schedule",
                    isActive: currentDayKey == DayKey.today()
                ) {
                    Button(L10n.string("diary.schedule.today", locale: locale)) {
                        onMoveToDay(DayKey.today())
                    }
                    Button(L10n.string("diary.schedule.yesterday", locale: locale)) {
                        onMoveToDay(DayKey.yesterday())
                    }
                    Button(L10n.string("diary.schedule.tomorrow", locale: locale)) {
                        onMoveToDay(DayKey.tomorrow())
                    }
                    Divider()
                    Button(L10n.string("diary.schedule.custom", locale: locale)) {
                        onPickCustomDate()
                    }
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
            }
            .fixedSize(horizontal: true, vertical: true)

            if let tip = hoveredQuickActionTip {
                Text(tip)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(tip == L10n.string("diary.quick.delete", locale: locale) ? Color.red : DaybookTheme.ink.opacity(0.85))
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .frame(height: 18)
                    .background(
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .fill(tip == L10n.string("diary.quick.delete", locale: locale) ? Color.red.opacity(0.08) : DaybookTheme.ink.opacity(0.06))
                    )
                    .fixedSize(horizontal: true, vertical: true)
                    .transition(.opacity)
            }

            Spacer(minLength: 2)

            // 10. 删除手记 🗑（靠最右侧，危险操作）
            commandStripButton(
                icon: "trash",
                key: "diary.quick.delete",
                isDestructive: true,
                action: onDelete
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 24)
        .animation(.easeInOut(duration: 0.12), value: hoveredQuickActionTip)
    }

    private func commandStripButton(
        icon: String,
        key: String,
        isActive: Bool = false,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let localizedText = L10n.string(String.LocalizationValue(stringLiteral: key), locale: locale)
        return Button(action: action) {
            commandStripIcon(
                icon: icon,
                isButtonHovered: hoveredQuickActionTip == localizedText,
                isActive: isActive,
                isDestructive: isDestructive
            )
        }
        .buttonStyle(.plain)
        .frame(width: 22, height: 22)
        .fixedSize()
        .accessibilityLabel(LocalizedStringKey(key))
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

    private func commandStripMenu<Content: View>(
        icon: String,
        key: String,
        isActive: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let localizedText = L10n.string(String.LocalizationValue(stringLiteral: key), locale: locale)
        let isButtonHovered = hoveredQuickActionTip == localizedText

        return Menu {
            content()
        } label: {
            commandStripIcon(icon: icon, isButtonHovered: isButtonHovered, isActive: isActive)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 22, height: 22)
        .fixedSize()
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

    private func commandStripIcon(
        icon: String,
        isButtonHovered: Bool,
        isActive: Bool = false,
        isDestructive: Bool = false
    ) -> some View {
        Image(systemName: icon)
            .font(.system(size: 11.5, weight: .medium))
            .frame(width: 22, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 4.0, style: .continuous)
                    .fill(
                        isDestructive
                            ? (isButtonHovered ? Color.red.opacity(0.18) : Color.red.opacity(0.08))
                            : (isActive
                                ? DaybookTheme.stamp.opacity(isButtonHovered ? 0.22 : 0.14)
                                : (isButtonHovered ? DaybookTheme.ink.opacity(0.12) : Color.clear))
                    )
            )
            .foregroundStyle(
                isDestructive
                    ? Color.red
                    : (isActive ? DaybookTheme.stamp : DaybookTheme.ink.opacity(isButtonHovered ? 0.95 : 0.72))
            )
            .contentShape(Rectangle())
    }
}
