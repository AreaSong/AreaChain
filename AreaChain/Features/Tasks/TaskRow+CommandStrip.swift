import AppKit
import SwiftUI

// MARK: - TaskRow ⌘ 平铺极速快捷操作条（与「···」更多菜单 1:1 完全对齐）

extension TaskRow {
    @ViewBuilder
    var commandActionStrip: some View {
        HStack(spacing: 4) {
            // 左侧高频操作图标组：强制固定尺寸，彻底杜绝任何水平挤压或位移
            HStack(spacing: 3) {
                // 1. 编辑标题 ✏️
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

                // 5. 归属项目 📁 (无 + 各项目)
                if let classify = state.classify, !classify.projects.isEmpty {
                    commandStripMenu(
                        icon: "folder",
                        key: "row.quick.project",
                        isActive: classify.projectID != nil
                    ) {
                        projectMenuItems(classify)
                    }
                }

                // 6. 标签 🏷 (各标签勾选)
                if let classify = state.classify, !classify.tags.isEmpty {
                    commandStripMenu(
                        icon: "tag",
                        key: "row.quick.tags",
                        isActive: !attachedTagNames.isEmpty
                    ) {
                        tagsMenuItems(classify)
                    }
                }

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
            .fixedSize(horizontal: true, vertical: true)

            // 悬浮聚焦文字提示区（固定高度 18pt，纯透明度渐变，绝不撑大行高，绝不引起晃动）
            if let tip = hoveredQuickActionTip {
                Text(tip)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(tip == L10n.string("row.quick.delete", locale: locale) ? Color.red : DaybookTheme.ink.opacity(0.85))
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .frame(height: 18)
                    .background(
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .fill(tip == L10n.string("row.quick.delete", locale: locale) ? Color.red.opacity(0.08) : DaybookTheme.ink.opacity(0.06))
                    )
                    .transition(.opacity)
            }

            Spacer(minLength: 4)

            // 10. 移入废纸篓 🗑（靠最右侧，危险操作）
            commandStripButton(
                icon: "trash",
                key: "row.quick.delete",
                isDestructive: true
            ) {
                dispatch(.delete)
            }
            .fixedSize()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 24)
        .clipped()
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
        let isButtonHovered = hoveredQuickActionTip == localizedText

        return Button(action: action) {
            commandStripIcon(icon: icon, isButtonHovered: isButtonHovered, isActive: isActive, isDestructive: isDestructive)
        }
        .buttonStyle(.plain)
        .frame(width: 24, height: 24)
        .fixedSize()
        .help(LocalizedStringKey(key))
        .background(
            QuickActionHoverArea { hovering in
                if hovering {
                    hoveredQuickActionTip = localizedText
                } else if hoveredQuickActionTip == localizedText {
                    hoveredQuickActionTip = nil
                }
            }
        )
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
        .frame(width: 24, height: 24)
        .fixedSize()
        .help(LocalizedStringKey(key))
        .background(
            QuickActionHoverArea { hovering in
                if hovering {
                    hoveredQuickActionTip = localizedText
                } else if hoveredQuickActionTip == localizedText {
                    hoveredQuickActionTip = nil
                }
            }
        )
    }

    private func commandStripIcon(
        icon: String,
        isButtonHovered: Bool,
        isActive: Bool = false,
        isDestructive: Bool = false
    ) -> some View {
        Image(systemName: icon)
            .font(.system(size: 12, weight: .medium))
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
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
    }
}

// MARK: - 原生 AppKit 悬浮跟踪，无视 Menu 事件拦截，100% 稳定响应

struct QuickActionHoverArea: NSViewRepresentable {
    var onHover: (Bool) -> Void

    func makeNSView(context: Context) -> HoverTrackingNSView {
        let view = HoverTrackingNSView()
        view.onHover = onHover
        return view
    }

    func updateNSView(_ nsView: HoverTrackingNSView, context: Context) {
        nsView.onHover = onHover
    }
}

final class HoverTrackingNSView: NSView {
    var onHover: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        self.trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onHover?(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onHover?(false)
    }
}
