import SwiftUI

/// 顶栏以主内容区为坐标；两侧等宽，操作数量不会挤走搜索中心。
struct WorkspaceHeaderBar: View {
    @Bindable var navigation: WorkspaceNavigation
    var tags: [TagItem]
    var content = WorkspaceHeaderContent()
    @State private var showsHelp = false

    var body: some View {
        GeometryReader { geometry in
            let layout = WorkspaceHeaderGeometry(width: geometry.size.width)
            VStack(spacing: DaybookSpacing.xs) {
                HStack(spacing: DaybookSpacing.sm) {
                    title
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !layout.stacked {
                        search.frame(width: layout.searchWidth)
                    }
                    actions(limit: layout.directActionCount, compact: layout.stacked)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                if layout.stacked {
                    search.frame(width: layout.searchWidth)
                }
            }
            .padding(.horizontal, DaybookSpacing.page)
            .frame(width: geometry.size.width, height: layout.height)
        }
        .background(.ultraThinMaterial)
        .background(SyntaxViewAnchor("syntax.workspace.header.bounds"))
        .overlay(alignment: .bottom) { DaybookDivider(opacity: 0.65) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workspace.header.bar")
        .onChange(of: navigation.contentIdentity) { _, _ in showsHelp = false }
    }

    private var search: some View {
        WorkspaceHeaderSearchCapsule(
            navigation: navigation,
            tagNames: tags.filter { $0.deletedAt == nil }.map(\.name)
        )
        .background(SyntaxViewAnchor("syntax.workspace.search.bounds"))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workspace.header.search.shell")
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xxs) {
            HStack(spacing: DaybookSpacing.xs) {
                titleLabel
                    .font(DaybookType.body.weight(.semibold))
                    .foregroundStyle(DaybookPalette.text.primary)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                if let helpKey {
                    DaybookIconButton(systemName: "info.circle", label: "workspace.page.info", size: .inline) {
                        showsHelp.toggle()
                    }
                    .help(Text(helpKey))
                    .popover(isPresented: $showsHelp, arrowEdge: .bottom) {
                        Text(helpKey)
                            .font(DaybookType.body)
                            .padding(DaybookSpacing.md)
                            .frame(idealWidth: 280, maxWidth: 320, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .onExitCommand { showsHelp = false }
                    }
                    .accessibilityIdentifier("workspace.header.help")
                }
            }
            if !navigation.isSearching && navigation.selectedTagID == nil && navigation.selectedTab == .today {
                TimelineView(.periodic(from: .now, by: 60)) { _ in
                    WorkspaceHeaderDate()
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workspace.header.title")
    }

    @ViewBuilder private var titleLabel: some View {
        if navigation.isSearching {
            Text("workspace.search.title")
        } else if let tag = tags.first(where: { $0.id == navigation.selectedTagID && $0.deletedAt == nil }) {
            Text("#\(tag.name)")
                .help(tag.name)
        } else {
            Text(navigation.selectedTab == .today ? "workspace.today.title" : navigation.selectedTab.titleKey)
        }
    }

    private var helpKey: LocalizedStringKey? {
        navigation.isSearching || navigation.selectedTagID != nil ? nil : navigation.selectedTab.helpKey
    }

    private func actions(limit: Int, compact: Bool) -> some View {
        let direct = Array(content.actions.filter { !$0.overflowOnly }.prefix(limit))
        let overflow = content.actions.filter { action in !direct.contains { $0.id == action.id } }
        return HStack(spacing: DaybookSpacing.xs) {
            ForEach(direct) { action in
                WorkspaceHeaderActionView(action: action)
            }
            if !overflow.isEmpty {
                Menu {
                    ForEach(overflow) { action in WorkspaceHeaderMenuItem(action: action) }
                } label: {
                    Label("workspace.toolbar.more", systemImage: "ellipsis")
                        .labelStyle(WorkspaceToolbarLabelStyle(iconOnly: compact))
                        .daybookMenuLabel(size: .regular, fitsLabel: true)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .accessibilityLabel(Text("workspace.toolbar.more"))
                .accessibilityIdentifier("workspace.header.more")
            }
            content.status
            if navigation.supportsTaskInspector {
                if !content.actions.isEmpty || content.status != nil {
                    Divider().frame(height: DaybookMetrics.Hit.inline)
                }
                DaybookIconButton(systemName: "sidebar.trailing", label: "drawer.inspector.toggle",
                                  isActive: navigation.isInspectorPresented) {
                    if navigation.isInspectorPresented { navigation.closeInspector() }
                    else if navigation.canInspectSelectedTask { navigation.isInspectorPresented = true }
                }
                .disabled(!navigation.canInspectSelectedTask)
                .accessibilityAddTraits(navigation.isInspectorPresented ? .isSelected : [])
                .accessibilityIdentifier("workspace.header.inspector.toggle")
            }
        }
        .font(DaybookType.caption)
        .fixedSize()
        .background(SyntaxViewAnchor("syntax.workspace.actions.bounds"))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workspace.header.actions")
    }
}

private struct WorkspaceHeaderDate: View {
    @Environment(\.locale) private var locale
    var body: some View {
        Text(DayKey.displayName(DayKey.today(), locale: locale))
            .font(DaybookType.micro)
            .foregroundStyle(DaybookPalette.text.secondary)
            .lineLimit(1)
    }
}

struct WorkspaceHeaderGeometry {
    let width: CGFloat
    var stacked: Bool { width < WorkspaceLayout.headerSingleRowWidth }
    var height: CGFloat { stacked ? WorkspaceLayout.headerStackedHeight : WorkspaceLayout.headerHeight }
    var searchWidth: CGFloat { min(300, max(160, stacked ? width - 2 * DaybookSpacing.page : width * 0.34)) }
    var directActionCount: Int { width >= 1080 ? 3 : (width >= 920 ? 2 : (width >= 520 ? 1 : 0)) }
}

private struct WorkspaceToolbarLabelStyle: LabelStyle {
    var iconOnly: Bool
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: DaybookSpacing.xs) {
            configuration.icon
            if !iconOnly { configuration.title.lineLimit(1) }
        }
    }
}

private struct WorkspaceHeaderActionView: View {
    let action: WorkspaceHeaderAction
    var body: some View {
        Group {
            if action.children.isEmpty {
                Button(role: action.role, action: action.perform) {
                    Label(action.title, systemImage: action.systemImage)
                }
                .buttonStyle(DaybookButtonStyle(action.isActive ? .prominent : .quiet))
            } else {
                Menu {
                    ForEach(action.children) { child in WorkspaceHeaderMenuItem(action: child) }
                } label: {
                    Label(action.title, systemImage: action.systemImage).daybookMenuLabel(size: .regular, fitsLabel: true)
                }
                .menuStyle(.borderlessButton)
            }
        }
        .disabled(!action.isEnabled)
        .fixedSize()
        .accessibilityIdentifier("workspace.header.action." + action.id)
    }
}

private struct WorkspaceHeaderMenuItem: View {
    let action: WorkspaceHeaderAction
    var body: some View {
        if action.children.isEmpty {
            Button(role: action.role, action: action.perform) {
                Label(action.title, systemImage: action.isActive ? "checkmark" : action.systemImage)
            }
            .disabled(!action.isEnabled)
        } else {
            Menu {
                ForEach(action.children) { child in
                    Button(role: child.role, action: child.perform) {
                        Label(child.title, systemImage: child.isActive ? "checkmark" : child.systemImage)
                    }.disabled(!child.isEnabled)
                }
            } label: { Label(action.title, systemImage: action.systemImage) }
            .disabled(!action.isEnabled)
        }
    }
}
