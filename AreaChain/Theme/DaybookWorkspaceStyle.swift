import AppKit
import SwiftUI

/// 工作台通过环境启用新外观；菜单栏和独立手记窗口保留原来的尺寸与材质。
enum DaybookViewStyle: Equatable {
    case standard
    case workspace

    var isWorkspace: Bool { self == .workspace }
    var pageBackground: Color { isWorkspace ? WorkspaceStyle.paper : DaybookTheme.paper.opacity(0.94) }
    var cardSurface: Color { isWorkspace ? WorkspaceStyle.surface : DaybookTheme.cardSurface }
    var cardBorder: Color { isWorkspace ? WorkspaceStyle.border : DaybookTheme.cardBorder }
    var hoverFill: Color { isWorkspace ? WorkspaceStyle.hover : DaybookTheme.hoverFill }
    var selectionFill: Color { isWorkspace ? WorkspaceStyle.selection : DaybookTheme.cardSelectionFill }
    var doneText: Color { isWorkspace ? DaybookTheme.muted : DaybookTheme.done }

    func inputBorderWidth(focused: Bool, kind: DaybookInputKind) -> CGFloat {
        if !isWorkspace && kind == .search { return focused ? 1.6 : 1 }
        return focused ? 1.4 : 0.8
    }
}

private struct DaybookViewStyleKey: EnvironmentKey {
    static let defaultValue = DaybookViewStyle.standard
}

extension EnvironmentValues {
    var daybookViewStyle: DaybookViewStyle {
        get { self[DaybookViewStyleKey.self] }
        set { self[DaybookViewStyleKey.self] = newValue }
    }
}

enum WorkspaceSwatch {
    static let paperLight = (247.0 / 255, 247.0 / 255, 248.0 / 255)
    static let paperDark = (30.0 / 255, 30.0 / 255, 32.0 / 255)
    static let surfaceLight = (1.0, 1.0, 1.0)
    static let surfaceDark = (38.0 / 255, 38.0 / 255, 41.0 / 255)
    static let inputLight = (240.0 / 255, 240.0 / 255, 243.0 / 255)
    static let inputDark = (42.0 / 255, 42.0 / 255, 46.0 / 255)
    static let controlLight = (0.50, 0.50, 0.54)
    static let controlDark = (0.52, 0.52, 0.56)
    static let hoverLight = (0.91, 0.91, 0.93)
    static let hoverDark = (0.20, 0.20, 0.22)
    static let selectionLight = (0.88, 0.92, 0.98)
    static let selectionDark = (0.12, 0.20, 0.32)
}

enum WorkspaceStyle {
    static let paper = Color.daybook(name: "workspace.paper", swatch: WorkspaceSwatch.paperLight, dark: WorkspaceSwatch.paperDark)
    static let surface = Color.daybook(name: "workspace.surface", swatch: WorkspaceSwatch.surfaceLight, dark: WorkspaceSwatch.surfaceDark)
    static let input = Color.daybook(name: "workspace.input", swatch: WorkspaceSwatch.inputLight, dark: WorkspaceSwatch.inputDark)
    static let control = Color.daybook(name: "workspace.control", swatch: WorkspaceSwatch.controlLight, dark: WorkspaceSwatch.controlDark)
    static let border = Color.daybook(name: "workspace.border", swatch: (0.86, 0.86, 0.88), dark: (0.24, 0.24, 0.27))
    static let hover = Color.daybook(name: "workspace.hover", swatch: WorkspaceSwatch.hoverLight, dark: WorkspaceSwatch.hoverDark)
    static let selection = Color.daybook(name: "workspace.selection", swatch: WorkspaceSwatch.selectionLight, dark: WorkspaceSwatch.selectionDark)

    static let headerHeight: CGFloat = 50
    static let controlHeight: CGFloat = 28
    static let composerHeight: CGFloat = 38
    static let rowHeight: CGFloat = 38
    static let cardRadius: CGFloat = 8
    static let maxContentWidth: CGFloat = 880
    static let sectionFont = Font.system(size: DaybookType.subtitleSize, weight: .semibold)
    static let countFont = DaybookType.caption.monospacedDigit()
    static let progressFont = DaybookType.badge.weight(.semibold).monospacedDigit()
    static let sidebarRowHeight: CGFloat = 28
    static let sidebarRowVerticalPadding: CGFloat = 4.5
    static let sidebarRowHorizontalPadding: CGFloat = 8
    static let sidebarTopInset: CGFloat = 28
}

struct DaybookPageHeader<Title: View, Subtitle: View, Trailing: View>: View {
    @Environment(\.daybookViewStyle) private var style
    private let title: Title
    private let subtitle: Subtitle
    private let trailing: Trailing

    init(
        @ViewBuilder title: () -> Title,
        @ViewBuilder subtitle: () -> Subtitle,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title()
        self.subtitle = subtitle()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: style.isWorkspace ? .center : .bottom, spacing: style.isWorkspace ? DaybookSpacing.md : DaybookSpacing.sm) {
            VStack(alignment: .leading, spacing: 3) {
                title.accessibilityAddTraits(.isHeader)
                subtitle
            }
            .frame(minHeight: style.isWorkspace ? WorkspaceStyle.headerHeight : nil, alignment: .topLeading)
            Spacer(minLength: 0)
            trailing
        }
        .accessibilityIdentifier("workspace.page.header")
    }
}

enum DaybookInputKind: Equatable {
    case composer
    case search
    case editor
}

private struct DaybookInputChrome: ViewModifier {
    @Environment(\.daybookViewStyle) private var style
    var focused: Bool
    var kind: DaybookInputKind

    func body(content: Content) -> some View {
        content
            .padding(insets)
            .frame(minHeight: minimumHeight)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(focused ? DaybookTheme.focusRing : border, lineWidth: style.inputBorderWidth(focused: focused, kind: kind))
            )
    }

    private var insets: EdgeInsets {
        switch kind {
        case .composer: EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        case .search:
            style.isWorkspace
                ? EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
                : EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
        case .editor: EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
        }
    }

    private var minimumHeight: CGFloat? {
        guard style.isWorkspace else { return nil }
        switch kind {
        case .composer: return WorkspaceStyle.composerHeight
        case .search: return WorkspaceStyle.controlHeight
        case .editor: return nil
        }
    }

    private var radius: CGFloat {
        !style.isWorkspace && kind == .search ? DaybookRadius.medium : DaybookRadius.small
    }

    private var fill: Color {
        if style.isWorkspace { return WorkspaceStyle.input }
        if kind == .composer && !focused { return DaybookTheme.hoverFill.opacity(0.75) }
        return DaybookTheme.surface
    }

    private var border: Color {
        if style.isWorkspace { return WorkspaceStyle.border }
        return kind == .search ? DaybookTheme.rule : DaybookTheme.cardBorder
    }
}

/// 筛选菜单和直接切换的标签共享外观，但继续由原来的 Menu / Button 处理交互。
struct WorkspaceFilterLabel<Content: View>: View {
    var isSelected: Bool
    var tint: Color
    private let content: Content

    init(isSelected: Bool, tint: Color = DaybookTheme.stamp, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content.workspaceFilterChrome(isSelected: isSelected, tint: tint)
    }
}

private struct WorkspaceFilterChrome: ViewModifier {
    var isSelected: Bool
    var tint: Color
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .font(.system(size: DaybookType.captionSize, weight: isSelected ? .medium : .regular))
            .foregroundStyle(DaybookTheme.ink)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .frame(minHeight: WorkspaceStyle.controlHeight)
            .background(Capsule().fill(isSelected ? tint.opacity(0.12) : (hovering ? WorkspaceStyle.hover : WorkspaceStyle.surface)))
            .overlay(Capsule().strokeBorder(isSelected ? tint.opacity(0.35) : WorkspaceStyle.border, lineWidth: 0.8))
            .contentShape(Capsule())
            .onHover { hovering = $0 }
            .animation(DaybookMotion.interactive(reduceMotion), value: hovering)
    }
}

extension View {
    func daybookInputChrome(focused: Bool, kind: DaybookInputKind) -> some View {
        modifier(DaybookInputChrome(focused: focused, kind: kind))
    }

    func workspaceFilterChrome(isSelected: Bool, tint: Color = DaybookTheme.stamp) -> some View {
        modifier(WorkspaceFilterChrome(isSelected: isSelected, tint: tint))
    }
}

// MARK: - 工作台侧边栏公用组件

/// 侧边栏分组标题操作微按钮
struct WorkspaceSidebarHeaderAction: View {
    var icon: String = "plus"
    var labelKey: LocalizedStringKey
    var action: () -> Void

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isHovered ? DaybookTheme.stamp : DaybookTheme.muted)
                .frame(width: 20, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                        .fill(isHovered ? WorkspaceStyle.hover : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(labelKey)
        .onHover { isHovered = $0 }
        .animation(DaybookMotion.interactive(reduceMotion), value: isHovered)
    }
}

/// 侧边栏统一导航行组件
struct WorkspaceSidebarRow: View {
    var titleKey: LocalizedStringKey?
    var title: String?
    var systemImage: String
    var badgeCount: Int?
    var depth: Int
    var isSelected: Bool
    var action: () -> Void

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        titleKey: LocalizedStringKey,
        systemImage: String,
        badgeCount: Int? = nil,
        depth: Int = 0,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.titleKey = titleKey
        self.title = nil
        self.systemImage = systemImage
        self.badgeCount = badgeCount
        self.depth = depth
        self.isSelected = isSelected
        self.action = action
    }

    init(
        title: String,
        systemImage: String,
        badgeCount: Int? = nil,
        depth: Int = 0,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.titleKey = nil
        self.title = title
        self.systemImage = systemImage
        self.badgeCount = badgeCount
        self.depth = depth
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(DaybookType.body)
                    .frame(width: 16, alignment: .center)
                if let titleKey {
                    Text(titleKey)
                } else if let title {
                    Text(title)
                }
                Spacer(minLength: 0)
                if let badgeCount, badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(WorkspaceStyle.countFont)
                        .foregroundStyle(isSelected ? DaybookTheme.stamp : DaybookTheme.muted)
                }
            }
            .font(DaybookType.body.weight(isSelected ? .medium : .regular))
            .foregroundStyle(isSelected ? DaybookTheme.stamp : DaybookTheme.ink)
            .padding(.vertical, WorkspaceStyle.sidebarRowVerticalPadding)
            .padding(.leading, WorkspaceStyle.sidebarRowHorizontalPadding + CGFloat(depth) * 12)
            .padding(.trailing, WorkspaceStyle.sidebarRowHorizontalPadding)
            .frame(minHeight: WorkspaceStyle.sidebarRowHeight)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .fill(backgroundFill)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(DaybookMotion.interactive(reduceMotion), value: isHovered)
    }

    private var backgroundFill: Color {
        if isSelected {
            return WorkspaceStyle.selection
        }
        if isHovered {
            return WorkspaceStyle.hover
        }
        return .clear
    }
}

