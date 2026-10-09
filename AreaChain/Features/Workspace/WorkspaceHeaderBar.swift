import SwiftUI

/// 顶栏以主内容区为坐标；两侧等宽，操作数量不会挤走搜索中心。
struct WorkspaceHeaderBar: View {
    @Bindable var navigation: WorkspaceNavigation
    var tags: [TagItem]
    var content = WorkspaceHeaderContent()
    @State private var showsHelp = false

    var body: some View {
        WorkspaceHeaderRowLayout {
            title
            search
            ViewThatFits(in: .horizontal) {
                ForEach((0...content.actions.filter { !$0.overflowOnly }.count).reversed(), id: \.self) { count in
                    actions(limit: count)
                }
            }
        }
        .padding(.horizontal, DaybookSpacing.page)
        .frame(height: WorkspaceLayout.headerHeight)
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
                    .help(titleLabel)
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

    private var titleLabel: Text {
        if navigation.isSearching {
            return Text("workspace.search.title")
        } else if let tag = tags.first(where: { $0.id == navigation.selectedTagID && $0.deletedAt == nil }) {
            return Text("#\(tag.name)")
        } else {
            return Text(navigation.selectedTab == .today ? "workspace.today.title" : navigation.selectedTab.titleKey)
        }
    }

    private var helpKey: LocalizedStringKey? {
        navigation.isSearching || navigation.selectedTagID != nil ? nil : navigation.selectedTab.helpKey
    }

    private func actions(limit: Int) -> some View {
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
                    Image(systemName: "ellipsis")
                        .daybookMenuLabel(size: .regular)
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
                    else if navigation.canPresentInspector { navigation.isInspectorPresented = true }
                }
                .disabled(!navigation.canPresentInspector && !navigation.isInspectorPresented)
                .help(navigation.isInspectorSpaceAvailable ? "drawer.inspector.toggle" : "workspace.inspector.needsSpace")
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
    var height: CGFloat { WorkspaceLayout.headerHeight }

    func searchWidth(minimumActionsWidth: CGFloat) -> CGFloat {
        let available = width - 2 * DaybookSpacing.page
        let centeredMaximum = available - 2 * (minimumActionsWidth + DaybookSpacing.sm)
        return max(WorkspaceLayout.searchMinWidth,
                   min(WorkspaceLayout.searchMaxWidth, width * WorkspaceLayout.searchWidthRatio, centeredMaximum))
    }
}

/// 测量包含状态、原生菜单箭头和内边距的最小操作组；搜索只放置一次，缩放不切换输入身份。
private struct WorkspaceHeaderRowLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? WorkspaceLayout.maxContentWidth, height: WorkspaceLayout.headerHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        let minimumActions = subviews[2].sizeThatFits(ProposedViewSize(width: 0, height: bounds.height)).width
        let geometry = WorkspaceHeaderGeometry(width: bounds.width + 2 * DaybookSpacing.page)
        let searchWidth = geometry.searchWidth(minimumActionsWidth: minimumActions)
        let sideWidth = max(0, (bounds.width - searchWidth) / 2 - DaybookSpacing.sm)
        let sideProposal = ProposedViewSize(width: sideWidth, height: bounds.height)
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading, proposal: sideProposal)
        subviews[1].place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center,
                          proposal: ProposedViewSize(width: searchWidth, height: bounds.height))
        subviews[2].place(at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .trailing, proposal: sideProposal)
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
        .accessibilityLabel(Text(action.title))
        .accessibilityAddTraits(action.isActive ? .isSelected : [])
        .accessibilityIdentifier("workspace.header.action." + action.id)
    }
}

private struct WorkspaceHeaderMenuItem: View {
    let action: WorkspaceHeaderAction
    var body: some View {
        if action.children.isEmpty {
            Group {
                if action.isActive && action.role == nil {
                    Toggle(isOn: Binding(get: { action.isActive }, set: { _ in action.perform() })) {
                        Label(action.title, systemImage: action.systemImage)
                    }
                } else {
                    Button(role: action.role, action: action.perform) {
                        Label(action.title, systemImage: action.systemImage)
                    }
                }
            }
            .disabled(!action.isEnabled)
            .accessibilityAddTraits(action.isActive ? .isSelected : [])
        } else {
            Menu {
                ForEach(action.children) { child in WorkspaceHeaderMenuItem(action: child) }
            } label: { Label(action.title, systemImage: action.systemImage) }
            .disabled(!action.isEnabled)
            .accessibilityAddTraits(action.isActive ? .isSelected : [])
        }
    }
}
