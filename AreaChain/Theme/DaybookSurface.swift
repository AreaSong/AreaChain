import SwiftUI

/// 列表行、卡片、浮层面板、提示条的唯一外壳。颜色不可在调用点重载；圆角、内边距、最小高度可以。
enum DaybookSurfaceVariant: Equatable {
    case row
    case card
    case panel
    case banner
}

struct DaybookSurfaceConfiguration: Equatable {
    var radius: CGFloat
    var minHeight: CGFloat?
    var padding: EdgeInsets

    static func standard(for variant: DaybookSurfaceVariant) -> DaybookSurfaceConfiguration {
        switch variant {
        case .row:
            DaybookSurfaceConfiguration(radius: DaybookRadius.small, minHeight: nil, padding: EdgeInsets())
        case .card:
            DaybookSurfaceConfiguration(radius: DaybookRadius.medium, minHeight: nil, padding: EdgeInsets())
        case .panel:
            DaybookSurfaceConfiguration(radius: DaybookMetrics.Radius.panel, minHeight: nil, padding: EdgeInsets())
        case .banner:
            DaybookSurfaceConfiguration(
                radius: DaybookMetrics.Radius.inputComposer,
                minHeight: nil,
                padding: EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
            )
        }
    }
}

private struct DaybookSurfaceModifier: ViewModifier {
    var variant: DaybookSurfaceVariant
    var isHovered: Bool
    var isSelected: Bool
    var configure: ((inout DaybookSurfaceConfiguration) -> Void)?
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let config = configuration
        let shape = RoundedRectangle(cornerRadius: config.radius, style: .continuous)
        content
            .padding(config.padding)
            .frame(minHeight: config.minHeight)
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(border, lineWidth: borderWidth))
            .daybookElevation(elevation)
            .onHover { hovering = $0 }
            .animation(DaybookMotion.interactive(reduceMotion), value: hovering)
            .animation(DaybookMotion.interactive(reduceMotion), value: isHovered)
            .animation(DaybookMotion.interactive(reduceMotion), value: isSelected)
    }

    private var configuration: DaybookSurfaceConfiguration {
        var config = DaybookSurfaceConfiguration.standard(for: variant)
        configure?(&config)
        return config
    }

    private var highlighted: Bool { isHovered || hovering }

    private var fill: Color {
        switch variant {
        case .row:
            if isSelected { return DaybookPalette.fill.selection }
            if highlighted { return DaybookPalette.fill.hover }
            return .clear
        case .card:
            if isSelected { return DaybookPalette.fill.selection }
            if highlighted { return DaybookPalette.cardSurfaceHover }
            return DaybookPalette.cardSurface
        case .panel:
            return DaybookPalette.fill.page
        case .banner:
            return DaybookPalette.fill.subtle
        }
    }

    private var border: Color {
        switch variant {
        case .row:
            if isSelected { return DaybookPalette.border.selection }
            return .clear
        case .card:
            if isSelected { return DaybookPalette.accent.base.opacity(0.85) }
            if highlighted { return DaybookPalette.cardBorderHover }
            return DaybookPalette.border.subtle
        case .panel:
            return DaybookPalette.border.default
        case .banner:
            return DaybookPalette.border.faint
        }
    }

    private var borderWidth: CGFloat {
        switch variant {
        case .row:
            return isSelected ? DaybookMetrics.Stroke.emphasis : 0
        case .card:
            return isSelected ? DaybookMetrics.Stroke.emphasis : 0.8
        case .panel:
            return 0.7
        case .banner:
            return DaybookMetrics.Stroke.regular
        }
    }

    private var elevation: DaybookElevation {
        variant == .panel ? .floating : .flat
    }
}

extension View {
    /// 静态卡片只绘制装饰；不进入交互表面的悬停状态、选中、布局或动画链。
    /// 装饰不参与命中，内容按钮和行继续拥有各自的真实点击边界。
    func daybookStaticCardSurface() -> some View {
        let shape = RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
        return background(shape.fill(DaybookPalette.cardSurface).allowsHitTesting(false))
            .overlay(shape.strokeBorder(DaybookPalette.border.subtle, lineWidth: 0.8).allowsHitTesting(false))
    }

    func daybookSurface(
        _ variant: DaybookSurfaceVariant,
        isHovered: Bool = false,
        isSelected: Bool = false,
        configure: ((inout DaybookSurfaceConfiguration) -> Void)? = nil
    ) -> some View {
        modifier(DaybookSurfaceModifier(
            variant: variant,
            isHovered: isHovered,
            isSelected: isSelected,
            configure: configure
        ))
    }
}

/// 浮层仅有呈现差异；不复用 panel 的内描边、悬停状态或布局 modifier。
enum DaybookFloatingSurface: Equatable {
    case suggestions
    case readOnly
    /// 小圆角且阴影只绘制在背景上，不把正文或越界气泡投影到整卡阴影中。
    case smallBackground
    case tagDetail
    case syntaxHelp
    /// 状态只来自气泡；复制反馈不是系统剪贴板成功的证明。
    case rowBubble(isHovered: Bool, isCopied: Bool)

    var radius: CGFloat {
        switch self {
        case .suggestions, .tagDetail: DaybookRadius.regular
        case .readOnly, .smallBackground, .rowBubble: DaybookRadius.small
        case .syntaxHelp: DaybookRadius.medium
        }
    }

    // 标签详情和帮助卡沿用原 60% / 0.8pt，不能借接入改变旧三预设的描边。
    private var usesDetailBorder: Bool { self == .tagDetail || self == .syntaxHelp }
    var borderOpacity: Double {
        if case .rowBubble(_, let copied) = self { return copied ? 0.7 : 0.9 }
        return usesDetailBorder ? 0.6 : 0.7
    }

    var borderWidth: CGFloat {
        if case .rowBubble = self { return 0.8 }
        return usesDetailBorder ? 0.8 : 0.7
    }

    var borderColor: Color {
        if case .rowBubble(let hovered, let copied) = self {
            if copied { return DaybookPalette.accent.base.opacity(0.7) }
            if hovered { return DaybookPalette.cardBorderHover }
        }
        return DaybookPalette.border.default.opacity(borderOpacity)
    }

    var shape: RoundedRectangle {
        switch self {
        case .suggestions, .smallBackground, .tagDetail, .syntaxHelp, .rowBubble:
            RoundedRectangle(cornerRadius: radius, style: .continuous)
        // 保留原默认构造；默认值由 SDK 决定，不能假设是 circular。
        case .readOnly: RoundedRectangle(cornerRadius: radius)
        }
    }
}

private struct DaybookFloatingSurfaceModifier: ViewModifier {
    let presentation: DaybookFloatingSurface
    let isPresented: Bool

    func body(content: Content) -> some View {
        switch presentation {
        case .suggestions, .smallBackground, .tagDetail, .syntaxHelp, .rowBubble:
            content.background {
                if isPresented { background.daybookElevation(.floating) }
            }.overlay { border }
        case .readOnly:
            content.background {
                if isPresented { background }
            }.overlay { border }
                .daybookElevation(isPresented ? .floating : .flat)
        }
    }

    private var shape: RoundedRectangle {
        presentation.shape
    }

    private var background: some View { shape.fill(DaybookPalette.fill.page) }

    @ViewBuilder private var border: some View {
        if isPresented {
            // 描边在形状边缘居中；strokeBorder 会内缩，不能互换。
            shape.stroke(presentation.borderColor, lineWidth: presentation.borderWidth)
                .allowsHitTesting(false)
        }
    }
}

extension View {
    /// 浮层装饰性描边不参与命中，内容与宿主继续负责交互；不增加布局、裁切或命中形状。
    /// 可关闭候选装饰而保持内容身份，让独立预览继续拥有自己的外壳。
    func daybookSurface(floating presentation: DaybookFloatingSurface, isPresented: Bool = true) -> some View {
        modifier(DaybookFloatingSurfaceModifier(presentation: presentation, isPresented: isPresented))
    }
}
