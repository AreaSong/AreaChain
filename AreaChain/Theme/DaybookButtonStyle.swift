import SwiftUI

/// 按钮外观变体。基准 = 菜单栏浮层现状（用户决定）：悬停淡灰圆角底，没有蓝色悬停环。
enum DaybookButtonVariant: Equatable {
    /// 普通文字 / 图文按钮：主文字色。
    case quiet
    /// 次要文字 / 图文按钮：次要文字色，悬停变主文字色（例：未激活的"筛选"）。
    case subtle
    /// 强调动作（添加、今天、清除筛选）：强调色文字。
    case prominent
    /// 危险动作：危险色文字。
    case destructive
    /// 已选中 / 已激活的文字按钮：强调色文字 + 强调色 12% 底。
    case active
    /// 带描边的胶囊状按钮：指定色文字 + 12% 底 + 35% 描边（例：已激活的"筛选"）。
    case pill(tint: Color)
    /// 纯图标按钮：次要文字色，悬停主文字色 + 淡灰底；点击区为 size 决定的正方形。
    case icon
    /// 已激活的纯图标按钮：强调色 + 强调色 12% 底。
    case iconActive
    /// 危险的纯图标按钮：危险色，悬停危险色 12% 底。
    case iconDestructive

    var isIcon: Bool {
        switch self {
        case .icon, .iconActive, .iconDestructive: true
        default: false
        }
    }
}

/// 按钮尺寸：决定图标按钮的正方形点击区、文字按钮的内边距、圆角与图标字号。
enum DaybookButtonSize: Equatable {
    case regular
    case compact
    case inline

    var hit: CGFloat {
        switch self {
        case .regular: DaybookMetrics.Hit.regular
        case .compact: DaybookMetrics.Hit.compact
        case .inline: DaybookMetrics.Hit.inline
        }
    }

    var padding: EdgeInsets {
        switch self {
        case .regular: EdgeInsets(top: 3, leading: 6, bottom: 3, trailing: 6)
        case .compact: EdgeInsets(top: 2, leading: 5, bottom: 2, trailing: 5)
        case .inline: EdgeInsets(top: 1, leading: 3, bottom: 1, trailing: 3)
        }
    }

    var radius: CGFloat {
        self == .regular ? DaybookMetrics.Radius.control : DaybookMetrics.Radius.inline
    }

    var iconFont: Font {
        switch self {
        case .regular: .system(size: 12, weight: .semibold)
        case .compact: .system(size: 11, weight: .semibold)
        case .inline: .system(size: 9.5, weight: .bold)
        }
    }
}

/// 公共按钮的权威样式；动作、角色和快捷键仍由原生 Button 及宿主负责。
struct DaybookButtonStyle: ButtonStyle {
    var variant: DaybookButtonVariant
    var size: DaybookButtonSize
    /// 保留宿主显式焦点值；同时读取原生焦点环境，不额外注册焦点或快捷键。
    var isFocused: Bool

    init(_ variant: DaybookButtonVariant = .quiet, size: DaybookButtonSize = .regular, isFocused: Bool = false) {
        self.variant = variant
        self.size = size
        self.isFocused = isFocused
    }

    func makeBody(configuration: Configuration) -> some View {
        DaybookButtonBody(configuration: configuration, variant: variant, size: size, isFocused: isFocused)
    }
}

private struct DaybookButtonBody: View {
    let configuration: ButtonStyle.Configuration
    var variant: DaybookButtonVariant
    var size: DaybookButtonSize
    var isFocused: Bool

    var body: some View {
        configuration.label
            .modifier(DaybookButtonFrame(isIcon: variant.isIcon, size: size))
            .modifier(DaybookButtonChrome(
                variant: variant, size: size, isFocused: isFocused, isPressed: configuration.isPressed
            ))
    }
}

/// 菜单标签与按钮共享颜色、焦点和禁用反馈；菜单的按下/展开交互由 macOS 承载。
private struct DaybookButtonChrome: ViewModifier {
    var variant: DaybookButtonVariant
    var size: DaybookButtonSize
    var isFocused: Bool
    var isPressed = false
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var nativeFocused
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.daybookButtonReduceMotionPreview) private var previewReduceMotion

    private var reduceMotion: Bool {
        systemReduceMotion || previewReduceMotion
    }

    private var showsFocus: Bool { isEnabled && (isFocused || nativeFocused) }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: size.radius, style: .continuous)
        content
            .foregroundStyle(ink)
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(border, lineWidth: borderWidth))
            .contentShape(shape)
            .scaleEffect(isPressed && isEnabled && !reduceMotion ? 0.97 : 1.0)
            .onHover { hovering = $0 }
            .animation(DaybookMotion.interactive(reduceMotion), value: hovering)
            .animation(DaybookMotion.snappy(reduceMotion), value: isPressed)
            .opacity(isEnabled ? 1 : 0.45)
    }

    private var ink: Color {
        if !isEnabled { return DaybookPalette.text.disabled }
        switch variant {
        case .quiet: return DaybookPalette.text.primary
        case .subtle, .icon: return hovering ? DaybookPalette.text.primary : DaybookPalette.text.secondary
        case .prominent, .active, .iconActive: return DaybookPalette.accent.base
        case .destructive, .iconDestructive: return DaybookPalette.status.danger
        case .pill(let tint): return tint
        }
    }

    private var fill: Color {
        if isPressed && isEnabled { return DaybookPalette.fill.press }
        switch variant {
        case .active, .iconActive: return DaybookPalette.accent.fill
        case .pill(let tint): return tint.opacity(0.12)
        case .iconDestructive: return hovering && isEnabled ? DaybookPalette.status.danger.opacity(0.12) : .clear
        default: return hovering && isEnabled ? DaybookPalette.fill.hover : .clear
        }
    }

    private var border: Color {
        if showsFocus { return DaybookPalette.border.focus }
        if case .pill(let tint) = variant { return tint.opacity(0.35) }
        return .clear
    }

    private var borderWidth: CGFloat {
        if showsFocus { return 1.5 }
        if case .pill = variant { return DaybookMetrics.Stroke.regular }
        return 0
    }
}

/// 图标按钮是固定正方形点击区；文字按钮只加内边距。
private struct DaybookButtonFrame: ViewModifier {
    var isIcon: Bool
    var size: DaybookButtonSize

    func body(content: Content) -> some View {
        if isIcon {
            content.frame(width: size.hit, height: size.hit)
        } else {
            content.padding(size.padding)
        }
    }
}

/// 纯图标按钮的薄包装：统一点击区、图标字号、无障碍名与 help。
struct DaybookIconButton: View {
    var systemName: String
    var label: LocalizedStringKey
    var size: DaybookButtonSize = .regular
    var role: ButtonRole? = nil
    var isActive = false
    var enabled = true
    var action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .font(size.iconFont)
        }
        .buttonStyle(DaybookButtonStyle(variant, size: size))
        .disabled(!enabled)
        .accessibilityLabel(label)
        .help(label)
    }

    private var variant: DaybookButtonVariant {
        if role == .destructive { return .iconDestructive }
        return isActive ? .iconActive : .icon
    }
}

/// `Menu` 不接受 ButtonStyle；它的 label 用这个修饰符获得与图标按钮一致的外观。
private struct DaybookMenuLabelChrome: ViewModifier {
    var fitsLabel: Bool
    var size: DaybookButtonSize
    var isActive: Bool
    var isFocused: Bool
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, fitsLabel ? size.padding.leading : 0)
            .frame(width: fitsLabel ? nil : size.hit, height: size.hit)
            .modifier(DaybookButtonChrome(
                variant: isActive ? .iconActive : .icon, size: size, isFocused: isFocused
            ))
            .contentShape(Rectangle())
    }
}

extension View {
    func daybookMenuLabel(size: DaybookButtonSize = .compact, isActive: Bool = false, isFocused: Bool = false, fitsLabel: Bool = false) -> some View {
        modifier(DaybookMenuLabelChrome(fitsLabel: fitsLabel, size: size, isActive: isActive, isFocused: isFocused))
    }
}

// 系统辅助功能环境只读；控件预览只能加强减弱动态效果，不能关闭用户的系统设置。
private struct DaybookButtonReduceMotionPreviewKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var daybookButtonReduceMotionPreview: Bool {
        get { self[DaybookButtonReduceMotionPreviewKey.self] }
        set { self[DaybookButtonReduceMotionPreviewKey.self] = newValue }
    }
}
