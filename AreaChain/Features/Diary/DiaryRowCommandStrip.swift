import SwiftUI

/// 手记卡片按住 ⌘ 时的平铺快捷操作条
struct DiaryRowCommandStrip: View {
    var isSensitive: Bool
    var isPinned: Bool
    var onOpen: () -> Void
    var onCopy: () -> Void
    var onTogglePin: () -> Void
    var onAttach: () -> Void
    var onInspect: () -> Void
    var onDelete: () -> Void

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoveredQuickActionTip: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            HStack(spacing: 3) {
                // 1. 打开小窗 ↗
                commandStripButton(
                    icon: "arrow.up.forward.square",
                    key: "diary.quick.open",
                    action: onOpen
                )
                // 2. 复制手记 📋
                commandStripButton(
                    icon: "doc.on.doc",
                    key: "diary.quick.copy",
                    action: onCopy
                )
                // 3. 置顶 / 取消置顶 📌
                commandStripButton(
                    icon: isPinned ? "pin.slash" : "pin",
                    key: isPinned ? "diary.quick.unpin" : "diary.quick.pin",
                    isActive: isPinned,
                    action: onTogglePin
                )
                // 4. 添加附件 📎
                commandStripButton(
                    icon: "paperclip",
                    key: "diary.quick.attach",
                    action: onAttach
                )
                .disabled(isSensitive)
                // 5. 工作台查看 🖥
                commandStripButton(
                    icon: "macwindow",
                    key: "diary.quick.workspace",
                    action: onInspect
                )
                // 6. 删除手记 🗑
                commandStripButton(
                    icon: "trash",
                    key: "diary.quick.delete",
                    isDestructive: true,
                    action: onDelete
                )
            }
            .fixedSize(horizontal: true, vertical: true)

            if let tip = hoveredQuickActionTip {
                Text(tip)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(DaybookTheme.ink.opacity(0.85))
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .frame(height: 16)
                    .background(
                        Capsule()
                            .fill(DaybookTheme.surface)
                            .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(DaybookTheme.rule.opacity(0.4), lineWidth: 0.5)
                    )
                    .transition(.opacity)
            }

            Spacer(minLength: 0)
        }
        .frame(height: 18)
        .clipped()
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
        .accessibilityLabel(LocalizedStringKey(key))
        .help(LocalizedStringKey(key))
        .background(
            QuickActionHoverArea { hovering in
                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                    if hovering {
                        hoveredQuickActionTip = localizedText
                    } else if hoveredQuickActionTip == localizedText {
                        hoveredQuickActionTip = nil
                    }
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
            .font(.system(size: 9.5, weight: .medium))
            .frame(width: 18, height: 18)
            .background(
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
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
