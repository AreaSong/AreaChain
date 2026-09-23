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
