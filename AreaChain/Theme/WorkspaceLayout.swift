import SwiftUI

/// 工作台布局尺寸。用户决定：控件尺寸两宿主统一，只有"有侧栏、有页头、内容更宽"这类布局差异保留在这里。
/// 只允许 MainSplitWorkspaceView.swift、WorkspaceSidebarView.swift、WorkspaceHeaderBar.swift、DaybookPage.swift 与本文件引用。
enum WorkspaceLayout {
    static let headerHeight: CGFloat = 50
    static let maxContentWidth: CGFloat = 880
    static let sidebarRowHeight: CGFloat = 28
    static let sidebarRowVerticalPadding: CGFloat = 4.5
    static let sidebarRowHorizontalPadding: CGFloat = 8
    static let sidebarTopInset: CGFloat = 28
}

// MARK: - 以下三个组件从 DaybookWorkspaceStyle.swift 原样搬入，布局尺寸改为 WorkspaceLayout

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
            .frame(minHeight: style.isWorkspace ? WorkspaceLayout.headerHeight : nil, alignment: .topLeading)
            Spacer(minLength: 0)
            trailing
        }
        .accessibilityIdentifier("workspace.page.header")
    }
}

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
            .padding(.vertical, WorkspaceLayout.sidebarRowVerticalPadding)
            .padding(.leading, WorkspaceLayout.sidebarRowHorizontalPadding + CGFloat(depth) * 12)
            .padding(.trailing, WorkspaceLayout.sidebarRowHorizontalPadding)
            .frame(minHeight: WorkspaceLayout.sidebarRowHeight)
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
