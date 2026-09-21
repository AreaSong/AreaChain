import SwiftData
import SwiftUI

/// 工作台内容区置顶虚化顶栏（兼容组件与原生 Toolbar 两用）：
/// 左侧跟随当前视图标题，右侧常驻胶囊搜索框与抽屉切换按钮。
struct WorkspaceHeaderBar: View {
    @Environment(\.locale) private var locale
    @Bindable var navigation: WorkspaceNavigation
    var projects: [ProjectItem]
    var tags: [TagItem]

    var body: some View {
        HStack(spacing: 12) {
            WorkspaceHeaderLeadingTitle(navigation: navigation, projects: projects, tags: tags)

            Spacer(minLength: 16)

            WorkspaceHeaderSearchCapsule(navigation: navigation)

            WorkspaceHeaderInspectorToggle(navigation: navigation)
        }
        .padding(.horizontal, DaybookSpacing.page)
        .frame(height: WorkspaceStyle.headerHeight)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider()
                .background(DaybookTheme.rule.opacity(0.65))
        }
        .accessibilityIdentifier("workspace.header.bar")
    }
}

// MARK: - Subcomponents for Header & Native Toolbar

struct WorkspaceHeaderLeadingTitle: View {
    @Bindable var navigation: WorkspaceNavigation
    var projects: [ProjectItem]
    var tags: [TagItem]

    var body: some View {
        HStack(spacing: 8) {
            if let pid = navigation.selectedProjectID, let project = projects.first(where: { $0.id == pid && $0.deletedAt == nil }) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(DaybookTheme.stamp)
                Text(project.name)
                    .font(DaybookType.subtitle.weight(.semibold))
                    .foregroundStyle(DaybookTheme.ink)
                    .lineLimit(1)
            } else if let tid = navigation.selectedTagID, let tag = tags.first(where: { $0.id == tid && $0.deletedAt == nil }) {
                Image(systemName: "number")
                    .foregroundStyle(DaybookTheme.stamp)
                Text("#\(tag.name)")
                    .font(DaybookType.subtitle.weight(.semibold))
                    .foregroundStyle(DaybookTheme.ink)
                    .lineLimit(1)
            } else {
                Image(systemName: navigation.selectedTab.iconName)
                    .foregroundStyle(DaybookTheme.stamp)
                Text(navigation.selectedTab.titleKey)
                    .font(DaybookType.subtitle.weight(.semibold))
                    .foregroundStyle(DaybookTheme.ink)
                    .lineLimit(1)
            }
        }
        .accessibilityAddTraits(.isHeader)
        .opacity(navigation.isInlineTitleVisible ? 1.0 : 0.0)
        .offset(y: navigation.isInlineTitleVisible ? 0 : 4)
        .animation(DaybookMotion.interactive, value: navigation.isInlineTitleVisible)
    }
}

struct WorkspaceHeaderSearchCapsule: View {
    @Environment(\.locale) private var locale
    @Bindable var navigation: WorkspaceNavigation

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(navigation.isSearchFocused ? DaybookTheme.ink : DaybookTheme.muted)

            DaybookTextField(
                text: $navigation.searchQuery,
                placeholder: L10n.string("search.placeholder", locale: locale),
                fontSize: 12,
                focus: $navigation.isSearchFocused,
                onSubmit: {},
                allowsShiftNewline: false,
                onEscape: {
                    navigation.clearSearch()
                    NSApp.keyWindow?.makeFirstResponder(nil)
                }
            )
            .accessibilityIdentifier("workspace.header.search")

            if !navigation.searchQuery.isEmpty {
                Button {
                    navigation.clearSearch()
                    navigation.isSearchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(DaybookTheme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("footer.search.clear")
            }
        }
        .padding(.horizontal, 10)
        .frame(width: 240, height: 28)
        .background(
            Capsule()
                .fill(navigation.isSearchFocused ? DaybookTheme.surface : WorkspaceStyle.input.opacity(0.85))
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    navigation.isSearchFocused ? DaybookTheme.stamp.opacity(0.65) : DaybookTheme.rule.opacity(0.65),
                    lineWidth: 0.8
                )
        )
        // ⌘F 全局快捷键聚焦
        .background {
            Button("") {
                navigation.isSearchFocused = true
            }
            .keyboardShortcut("f", modifiers: .command)
            .opacity(0)
            .accessibilityHidden(true)
        }
    }
}

struct WorkspaceHeaderInspectorToggle: View {
    @Environment(\.locale) private var locale
    @Bindable var navigation: WorkspaceNavigation

    var body: some View {
        Button {
            navigation.isInspectorPresented.toggle()
        } label: {
            Image(systemName: "sidebar.trailing")
                .font(.system(size: 14))
                .foregroundStyle(navigation.isInspectorPresented ? DaybookTheme.stamp : DaybookTheme.ink)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(navigation.isInspectorPresented ? DaybookTheme.hoverFill : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(L10n.string("drawer.inspector.toggle", locale: locale))
        .accessibilityIdentifier("workspace.header.inspector.toggle")
    }
}

// MARK: - Native Toolbar Integration

struct WorkspaceToolbarModifier: ViewModifier {
    @Bindable var navigation: WorkspaceNavigation
    var projects: [ProjectItem]
    var tags: [TagItem]

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    WorkspaceHeaderLeadingTitle(
                        navigation: navigation,
                        projects: projects,
                        tags: tags
                    )
                }

                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 8) {
                        WorkspaceHeaderSearchCapsule(navigation: navigation)
                        WorkspaceHeaderInspectorToggle(navigation: navigation)
                    }
                }
            }
    }
}

extension View {
    func workspaceToolbar(
        navigation: WorkspaceNavigation,
        projects: [ProjectItem],
        tags: [TagItem]
    ) -> some View {
        modifier(WorkspaceToolbarModifier(
            navigation: navigation,
            projects: projects,
            tags: tags
        ))
    }
}

