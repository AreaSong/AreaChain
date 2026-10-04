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

    var radius: CGFloat { self == .suggestions ? DaybookRadius.regular : DaybookRadius.small }
    var shape: RoundedRectangle {
        switch self {
        case .suggestions, .smallBackground: RoundedRectangle(cornerRadius: radius, style: .continuous)
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
        case .suggestions, .smallBackground:
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
            // 原描边跨形状边缘各 0.35pt；strokeBorder 会内缩，不能互换。
            shape.stroke(DaybookPalette.border.default.opacity(0.7), lineWidth: 0.7)
        }
    }
}

extension View {
    /// 不增加布局、裁切或命中形状。可关闭候选装饰而保持内容身份，让独立预览继续拥有自己的外壳。
    func daybookSurface(floating presentation: DaybookFloatingSurface, isPresented: Bool = true) -> some View {
        modifier(DaybookFloatingSurfaceModifier(presentation: presentation, isPresented: isPresented))
    }
}
