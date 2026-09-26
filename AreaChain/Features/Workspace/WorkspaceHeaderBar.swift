import AppKit
import SwiftData
import SwiftUI

/// 工作台内容区置顶虚化顶栏（兼容组件与原生 Toolbar 两用）：
/// 左侧跟随当前视图标题，右侧常驻胶囊搜索框与抽屉切换按钮。
struct WorkspaceHeaderBar: View {
    @Environment(\.locale) private var locale
    @Bindable var navigation: WorkspaceNavigation
    var tags: [TagItem]

    var body: some View {
        HStack(spacing: 12) {
            WorkspaceHeaderLeadingTitle(navigation: navigation, tags: tags)

            Spacer(minLength: 16)

            WorkspaceHeaderSearchCapsule(navigation: navigation)

            WorkspaceHeaderInspectorToggle(navigation: navigation)
        }
        .padding(.horizontal, DaybookSpacing.page)
        .frame(height: WorkspaceLayout.headerHeight)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            DaybookDivider(opacity: 0.65)
        }
        .accessibilityIdentifier("workspace.header.bar")
    }
}

// MARK: - Subcomponents for Header & Native Toolbar

struct WorkspaceHeaderLeadingTitle: View {
    @Bindable var navigation: WorkspaceNavigation
    var tags: [TagItem]

    var body: some View {
        HStack(spacing: 8) {
            if let tid = navigation.selectedTagID, let tag = tags.first(where: { $0.id == tid && $0.deletedAt == nil }) {
                Image(systemName: "number")
                    .foregroundStyle(DaybookPalette.accent.base)
                Text("#\(tag.name)")
                    .font(DaybookType.body.weight(.medium))
                    .foregroundStyle(DaybookPalette.text.primary)
                    .lineLimit(1)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

struct WorkspaceHeaderSearchCapsule: View {
    @Environment(\.locale) private var locale
    @Bindable var navigation: WorkspaceNavigation
    @State private var hostWindow: NSWindow?

    var body: some View {
        DaybookInputShell(kind: .search, focused: navigation.isSearchFocused) {
            Image(systemName: "magnifyingglass")
                .font(DaybookType.caption.weight(.medium))
                .foregroundStyle(navigation.isSearchFocused ? DaybookPalette.text.primary : DaybookPalette.text.secondary)
        } field: {
            DaybookTextField(
                text: $navigation.searchQuery,
                placeholder: L10n.string("search.placeholder", locale: locale),
                fontSize: 12,
                focus: $navigation.isSearchFocused,
                onSubmit: {},
                allowsShiftNewline: false,
                onEscape: { escapeSearch() }
            )
            .accessibilityIdentifier("workspace.header.search")
        } trailing: {
            if !navigation.searchQuery.isEmpty {
                DaybookIconButton(systemName: "xmark.circle.fill", label: "footer.search.clear", size: .inline) {
                    navigation.clearSearch()
                    navigation.isSearchFocused = true
                }
            } else {
                Text("⌘F")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded)) // token-exempt: 快捷键提示用圆体
                    .foregroundStyle(DaybookPalette.text.secondary.opacity(0.6)) // token-exempt: 60% 次要色没有对应令牌
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: DaybookRadius.xxs)
                            .fill(DaybookPalette.border.default.opacity(0.18)) // token-exempt: 18% 分隔线没有对应令牌
                    )
            }
        }
        .frame(width: 260)
        .background(KeyWindowHost { hostWindow = $0 })
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

    private func escapeSearch() {
        if !BoardSearch.normalized(navigation.searchQuery).isEmpty {
            navigation.searchQuery = ""
            return
        }
        navigation.isSearchFocused = false
        if hostWindow?.firstResponder is NSTextView {
            hostWindow?.makeFirstResponder(nil)
        }
    }
}

struct WorkspaceHeaderInspectorToggle: View {
    @Environment(\.locale) private var locale
    @Bindable var navigation: WorkspaceNavigation

    var body: some View {
        DaybookIconButton(systemName: "sidebar.trailing",
            label: "drawer.inspector.toggle",
            size: .regular,
            isActive: navigation.isInspectorPresented
        ) {
            navigation.isInspectorPresented.toggle()
        }
        .accessibilityIdentifier("workspace.header.inspector.toggle")
    }
}

// MARK: - Native Toolbar Integration

struct WorkspaceToolbarModifier: ViewModifier {
    @Bindable var navigation: WorkspaceNavigation
    var tags: [TagItem]

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    WorkspaceHeaderLeadingTitle(
                        navigation: navigation,
                        tags: tags
                    )
                }

                ToolbarItem(placement: .principal) {
                    WorkspaceHeaderSearchCapsule(navigation: navigation)
                }

                ToolbarItem(placement: .primaryAction) {
                    WorkspaceHeaderInspectorToggle(navigation: navigation)
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .windowToolbar)
            .toolbarBackground(.visible, for: .windowToolbar)
    }
}

extension View {
    func workspaceToolbar(
        navigation: WorkspaceNavigation,
        tags: [TagItem]
    ) -> some View {
        modifier(WorkspaceToolbarModifier(
            navigation: navigation,
            tags: tags
        ))
    }
}
