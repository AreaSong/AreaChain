import SwiftUI

/// 输入外壳的三种用途；尺寸随 kind 变，颜色不变。
enum DaybookInputKind: Equatable {
    case composer
    case search
    case editor
}

/// 输入外壳的尺寸配置。只有尺寸可以在调用点重载；颜色、描边宽度不在这里，不可重载。
struct DaybookInputShellConfiguration {
    var height: CGFloat?
    var minHeight: CGFloat?
    var insets: EdgeInsets
    var spacing: CGFloat
    var radius: CGFloat

    static func standard(for kind: DaybookInputKind) -> DaybookInputShellConfiguration {
        switch kind {
        case .composer:
            DaybookInputShellConfiguration(
                height: DaybookMetrics.inputHeight, minHeight: nil,
                insets: DaybookMetrics.inputInsets(.composer), spacing: 8,
                radius: DaybookMetrics.Radius.inputComposer
            )
        case .search:
            DaybookInputShellConfiguration(
                height: DaybookMetrics.controlHeight, minHeight: nil,
                insets: DaybookMetrics.inputInsets(.search), spacing: 4,
                radius: DaybookMetrics.Radius.inputSearch
            )
        case .editor:
            DaybookInputShellConfiguration(
                height: nil, minHeight: nil,
                insets: DaybookMetrics.inputInsets(.editor), spacing: 0,
                radius: DaybookMetrics.Radius.inputEditor
            )
        }
    }
}

/// 全应用唯一的输入外壳（菜单栏、工作台、抽屉、手记小窗共用）。
/// 视觉基准 = 菜单栏浮层任务捕获框（用户决定）：未聚焦 ink 3% 底 + rule 40% 细边；聚焦 surface 底 + ink 35% 边；没有蓝色聚焦环。
/// composer / search 为固定高度单行；editor 多行不锁高。
/// 正文控件（DaybookTextField / SyntaxTextField / SyntaxTextEditor）放在 field 槽里，本壳不改变它们的任何按键行为。
struct DaybookInputShell<Leading: View, Field: View, Trailing: View>: View {
    var kind: DaybookInputKind
    var focused: Bool
    var configure: ((inout DaybookInputShellConfiguration) -> Void)? = nil
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var field: () -> Field
    @ViewBuilder var trailing: () -> Trailing

    private var configuration: DaybookInputShellConfiguration {
        var config = DaybookInputShellConfiguration.standard(for: kind)
        configure?(&config)
        return config
    }

    var body: some View {
        let config = configuration
        HStack(alignment: kind == .editor ? .top : .center, spacing: config.spacing) {
            leading()
            field()
            trailing()
        }
        .frame(maxWidth: .infinity)
        .padding(config.insets)
        .frame(height: config.height)
        .frame(minHeight: config.minHeight)
        .background(
            RoundedRectangle(cornerRadius: config.radius, style: .continuous)
                .fill(focused ? DaybookPalette.fill.surface : DaybookPalette.fill.subtle)
        )
        .overlay(
            RoundedRectangle(cornerRadius: config.radius, style: .continuous)
                .stroke(
                    focused ? DaybookPalette.border.focus : DaybookPalette.border.faint,
                    lineWidth: focused ? DaybookMetrics.Stroke.focus : DaybookMetrics.Stroke.regular
                )
        )
        .daybookHideInputChrome()
    }
}

extension DaybookInputShell where Leading == EmptyView, Trailing == EmptyView {
    init(
        kind: DaybookInputKind, focused: Bool,
        configure: ((inout DaybookInputShellConfiguration) -> Void)? = nil,
        @ViewBuilder field: @escaping () -> Field
    ) {
        self.init(kind: kind, focused: focused, configure: configure, leading: { EmptyView() }, field: field, trailing: { EmptyView() })
    }
}

extension DaybookInputShell where Trailing == EmptyView {
    init(
        kind: DaybookInputKind, focused: Bool,
        configure: ((inout DaybookInputShellConfiguration) -> Void)? = nil,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder field: @escaping () -> Field
    ) {
        self.init(kind: kind, focused: focused, configure: configure, leading: leading, field: field, trailing: { EmptyView() })
    }
}
