import SwiftData
import SwiftUI

/// 工作台内容区置顶虚化顶栏：
/// 左侧跟随当前视图标题，右侧常驻胶囊搜索框与抽屉切换按钮。
/// 背景采用 macOS 原生半透明磨砂材质（.ultraThinMaterial），下部内容滚动时自然在其下方虚化透出。
struct WorkspaceHeaderBar: View {
    @Environment(\.locale) private var locale
    @Bindable var navigation: WorkspaceNavigation
    var projects: [ProjectItem]
    var tags: [TagItem]

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            leadingTitleSection

            Spacer(minLength: 16)

            searchCapsuleField

            inspectorToggleButton
        }
        .padding(.horizontal, DaybookSpacing.page)
        .frame(height: 48)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider()
                .background(DaybookTheme.rule.opacity(0.55))
        }
        .accessibilityIdentifier("workspace.header.bar")
        .onChange(of: navigation.isSearchFocused) { _, focused in
            if focused {
                isFieldFocused = true
            }
        }
        .onChange(of: isFieldFocused) { _, focused in
            navigation.isSearchFocused = focused
        }
    }

    // MARK: - Leading Title Section

    @ViewBuilder
    private var leadingTitleSection: some View {
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
    }

    // MARK: - Search Capsule Field

    private var searchCapsuleField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isFieldFocused ? DaybookTheme.ink : DaybookTheme.muted)

            TextField(
                L10n.string("search.placeholder", locale: locale),
                text: $navigation.searchQuery
            )
            .textFieldStyle(.plain)
            .font(DaybookType.caption)
            .focused($isFieldFocused)
            .accessibilityIdentifier("workspace.header.search")

            if !navigation.searchQuery.isEmpty {
                Button {
                    navigation.clearSearch()
                    isFieldFocused = true
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
        .padding(.vertical, 5)
        .frame(width: 220, height: 28)
        .background(
            Capsule()
                .fill(isFieldFocused ? DaybookTheme.surface : WorkspaceStyle.input.opacity(0.85))
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    isFieldFocused ? DaybookTheme.stamp.opacity(0.65) : DaybookTheme.rule.opacity(0.65),
                    lineWidth: isFieldFocused ? 1.2 : 0.8
                )
        )
        // ⌘F 全局快捷键聚焦
        .background {
            Button("") {
                isFieldFocused = true
            }
            .keyboardShortcut("f", modifiers: .command)
            .opacity(0)
            .accessibilityHidden(true)
        }
    }

    // MARK: - Inspector Toggle Button

    private var inspectorToggleButton: some View {
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
