import SwiftUI

// MARK: - Modern Checkbox

/// 现代物理微弹性复选框：支持弹性回弹、微缩放触感与无障碍特性
struct ModernCheckbox: View {
    var isDone: Bool
    var action: () -> Void

    @State private var hovering = false
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(strokeColor, lineWidth: 1.5)
                .background(
                    Circle()
                        .fill(isDone ? DaybookTheme.stamp : Color.clear)
                )
                .frame(width: 17, height: 17)

            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(DaybookTheme.checkmark)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 20, height: 20)
        .offset(y: 0.5)
        .scaleEffect(isAnimating ? 0.85 : (hovering ? 1.05 : 1.0))
        .contentShape(Rectangle())
        .onTapGesture {
            handleTap()
        }
        .onHover { hovering = $0 }
        .animation(DaybookMotion.snappy(reduceMotion), value: isDone)
        .animation(DaybookMotion.interactive(reduceMotion), value: hovering)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isDone ? Text("checkbox.done") : Text("checkbox.open"))
        .accessibilityAddTraits(isDone ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { handleTap() }
    }

    private var strokeColor: Color {
        if isDone {
            return DaybookTheme.stamp
        }
        if hovering {
            return DaybookTheme.stamp.opacity(0.8)
        }
        return DaybookTheme.ink.opacity(0.24)
    }

    private func handleTap() {
        if !reduceMotion {
            withAnimation(DaybookMotion.snappy) {
                isAnimating = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(DaybookMotion.snappy) {
                    isAnimating = false
                }
            }
        }
        action()
    }
}

// MARK: - Pill Badge

/// 现代胶囊标签组件：用于项目、标签与日期徽章
struct PillBadge: View {
    var title: String
    var icon: String? = nil
    var color: Color = DaybookTheme.stamp
    var isSelected: Bool = false
    var action: (() -> Void)? = nil

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    badgeContent
                }
                .buttonStyle(.plain)
            } else {
                badgeContent
            }
        }
    }

    private var badgeContent: some View {
        HStack(spacing: 3.5) {
            if let icon {
                Image(systemName: icon)
                    .font(DaybookType.badge)
            }
            Text(title)
                .font(DaybookType.badge)
                .lineLimit(1)
        }
        .foregroundStyle(isSelected ? color : DaybookTheme.muted)
        .padding(.horizontal, 7)
        .padding(.vertical, 2.5)
        .background(
            Capsule()
                .fill(backgroundFill)
        )
        .overlay(
            Capsule()
                .strokeBorder(borderStroke, lineWidth: 0.8)
        )
        .onHover { hovering = $0 }
        .animation(DaybookMotion.interactive(reduceMotion), value: hovering)
    }

    private var backgroundFill: Color {
        if isSelected {
            return color.opacity(0.14)
        }
        if hovering {
            return DaybookTheme.hoverFill
        }
        return Color.clear
    }

    private var borderStroke: Color {
        if isSelected {
            return color.opacity(0.35)
        }
        if hovering {
            return DaybookTheme.rule.opacity(0.8)
        }
        return DaybookTheme.rule.opacity(0.4)
    }
}

// MARK: - Modern Card Modifier

struct ModernCardModifier: ViewModifier {
    var cornerRadius: CGFloat = DaybookRadius.card
    var isHovered: Bool = false
    var isSelected: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderStroke, lineWidth: isSelected ? 1.5 : 0.8)
            )
            .shadow(
                color: shadowColor,
                radius: isSelected ? 4 : (isHovered ? 4 : 2),
                x: 0,
                y: isSelected ? 1 : (isHovered ? 2 : 1)
            )
    }

    private var shadowColor: Color {
        if isSelected {
            return DaybookTheme.stamp.opacity(0.18)
        }
        if isHovered {
            return DaybookShadow.cardHover
        }
        return DaybookShadow.cardSubtle
    }

    private var backgroundFill: Color {
        if isSelected {
            return DaybookTheme.cardSelectionFill
        }
        if isHovered {
            return DaybookTheme.cardSurfaceHover
        }
        return DaybookTheme.cardSurface
    }

    private var borderStroke: Color {
        if isSelected {
            return DaybookTheme.stamp.opacity(0.85)
        }
        if isHovered {
            return DaybookTheme.cardBorderHover
        }
        return DaybookTheme.cardBorder
    }
}

extension View {
    func modernCard(
        cornerRadius: CGFloat = DaybookRadius.card,
        isHovered: Bool = false,
        isSelected: Bool = false
    ) -> some View {
        modifier(ModernCardModifier(
            cornerRadius: cornerRadius,
            isHovered: isHovered,
            isSelected: isSelected
        ))
    }

    /// 现代极简通透行修饰符：无硬阴影与厚边框，仅保留悬停/选中柔和底色高亮
    func modernRow(
        cornerRadius: CGFloat = DaybookRadius.small,
        isHovered: Bool = false,
        isSelected: Bool = false
    ) -> some View {
        modifier(ModernRowModifier(
            cornerRadius: cornerRadius,
            isHovered: isHovered,
            isSelected: isSelected
        ))
    }

    /// 现代柔光焦点环
    func modernFocusRing(isFocused: Bool) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .stroke(DaybookTheme.focusRing, lineWidth: isFocused ? 1.5 : 0)
                .padding(-1.5)
                .opacity(isFocused ? 0.9 : 0)
        )
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

// MARK: - Modern Row Modifier

struct ModernRowModifier: ViewModifier {
    var cornerRadius: CGFloat = DaybookRadius.small
    var isHovered: Bool = false
    var isSelected: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderStroke, lineWidth: isSelected ? 1.0 : 0.7)
            )
    }

    private var backgroundFill: Color {
        if isSelected {
            return DaybookTheme.cardSelectionFill
        }
        if isHovered {
            return DaybookTheme.hoverFill
        }
        return DaybookTheme.ink.opacity(0.035)
    }

    private var borderStroke: Color {
        if isSelected {
            return DaybookTheme.cardSelectionStroke
        }
        if isHovered {
            return DaybookTheme.rule.opacity(0.4)
        }
        return DaybookTheme.rule.opacity(0.20)
    }
}

// MARK: - Strikethrough Text

/// 待办完成时的删除线平滑划过与文字渐隐组件
struct ModernTaskTitle: View {
    var text: String
    var isDone: Bool
    var font: Font = DaybookType.body

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(text)
            .font(font)
            .strikethrough(isDone, color: DaybookTheme.muted.opacity(0.8))
            .foregroundStyle(isDone ? DaybookTheme.done : DaybookTheme.ink)
            .animation(DaybookMotion.interactive(reduceMotion), value: isDone)
    }
}
