import AppKit
import SwiftData
import SwiftUI

/// 同一条底栏在工具与筛选之间切换；搜索状态由上层持有，不随控件移除而丢失。
struct FooterBar: View {
    var tab: BoardTab = .tasks
    @Bindable var toolbar: MenuBarToolbarState
    var filter: Binding<BoardFilter>? = nil
    var diaryFilterTagID: Binding<UUID?>? = nil
    var tags: [TagItem] = []
    var onShowSyntaxHelp: () -> Void = {}

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoverWorkItem: DispatchWorkItem?
    @State private var restoresTriggerFocus = false
    @FocusState private var filterFocused: Bool
    @FocusState private var triggerFocused: Bool

    private var activeTags: [TagItem] {
        tab == .tasks ? Catalog.liveTaskTags(tags) : Catalog.liveTags(tags)
    }

    private var selectedTagID: UUID? {
        tab == .tasks ? filter?.wrappedValue.tagID : diaryFilterTagID?.wrappedValue
    }

    private var highPriority: Bool {
        tab == .tasks && filter?.wrappedValue.isHighPriorityOnly == true
    }

    private var activeCount: Int {
        guard tab == .tasks else { return selectedTagID == nil ? 0 : 1 }
        let value = filter?.wrappedValue ?? BoardFilter()
        return [value.projectID != nil, value.tagID != nil, value.bundleID != nil, value.isHighPriorityOnly]
            .filter { $0 }.count
    }

    var body: some View {
        HStack(spacing: 0) {
            if toolbar.isFiltering {
                filterContents
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("menubar.toolbar.filters")
                    .transition(contentTransition)
            } else {
                toolsContents
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("menubar.toolbar.tools")
                    .transition(contentTransition)
            }
        }
        .frame(height: 30)
        .contentShape(Rectangle())
        .onHover(perform: trackFooterHover)
        .animation(DaybookMotion.interactive(reduceMotion), value: toolbar.isFiltering)
        .onChange(of: tab) { _, _ in closeFilters() }
        .onExitCommand(perform: closeFilters)
        .onDisappear { hoverWorkItem?.cancel() }
    }

    private var contentTransition: AnyTransition {
        // 原控件先退出，新的内容只淡入，不在原按钮上叠一层滑动面板。
        .asymmetric(insertion: reduceMotion ? .identity : .opacity, removal: .identity)
    }

    private var toolsContents: some View {
        HStack(spacing: 6) {
            filterTrigger
            MenuBarSearchField(
                toolbar: toolbar,
                availableTags: Catalog.liveTags(tags).map(\.name)
            )
            workspaceButton
            moreMenu
        }
    }

    private var filterTrigger: some View {
        HStack(spacing: 3) {
            Button { openFilters(focus: true) } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .accessibilityHidden(true)
                    Text(filterTitle).lineLimit(1).truncationMode(.tail)
                }
                .font(DaybookType.caption)
                .padding(.horizontal, 5)
                .frame(height: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .onHover { hovering in
                if hovering {
                    hoverWorkItem?.cancel()
                    toolbar.showFiltersFromHover()
                }
            }
            .focused($triggerFocused)
            .accessibilityLabel("filter.label")
            .accessibilityIdentifier("menubar.filter.open")
            .accessibilityValue(activeDescription)
            .help(activeCount == 0 ? L10n.string("filter.open.help", locale: locale) : activeDescription)

            if activeCount > 0 {
                Button(action: clearFilter) {
                    Image(systemName: "xmark").font(DaybookType.badge)
                        .frame(width: 14, height: 28)
                }
                .buttonStyle(.plain)
                .help("footer.filter.clear")
                .accessibilityLabel("footer.filter.clear")
            }
        }
        .foregroundStyle(activeCount > 0 ? DaybookTheme.stamp : DaybookTheme.muted)
        .frame(maxWidth: 88)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var filterTitle: String {
        if activeCount > 1 { return L10n.format("footer.filter.count", locale: locale, activeCount) }
        if highPriority { return L10n.string("filter.highPriority", locale: locale) }
        if let tag = activeTags.first(where: { $0.id == selectedTagID }) { return "#" + tag.name }
        return L10n.string("filter.label", locale: locale)
    }

    private var activeDescription: String {
        guard activeCount > 0 else { return L10n.string("filter.all", locale: locale) }
        return L10n.format("footer.filter.active", locale: locale, activeCount)
    }

    private var filterContents: some View {
        HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal.decrease")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookTheme.muted)
                .accessibilityHidden(true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    filterChip(L10n.string("filter.all", locale: locale), selected: activeCount == 0) {
                        clearFilter()
                        closeFilters()
                    }
                    .focused($filterFocused)
                    if tab == .tasks {
                        filterChip(L10n.string("filter.highPriority", locale: locale), selected: highPriority) {
                            filter?.wrappedValue = (filter?.wrappedValue ?? BoardFilter()).withHighPriority(!highPriority)
                            closeFilters()
                        }
                    }
                    ForEach(activeTags) { tag in
                        filterChip("#" + tag.name, selected: selectedTagID == tag.id) {
                            selectTag(tag.id)
                            closeFilters()
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            Button(action: closeFilters) {
                Image(systemName: "chevron.left")
                    .font(DaybookType.caption.weight(.semibold))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .foregroundStyle(DaybookTheme.muted)
            .help("filter.collapse")
            .accessibilityLabel("filter.collapse")
            .accessibilityIdentifier("menubar.filter.close")
        }
    }

    private func filterChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(DaybookType.caption)
                .fixedSize()
                .padding(.horizontal, 8)
                .frame(height: 26)
                .foregroundStyle(selected ? DaybookTheme.stamp : DaybookTheme.ink)
                .background(Capsule().fill(selected ? DaybookTheme.stamp.opacity(0.12) : DaybookTheme.hoverFill))
                .overlay(Capsule().strokeBorder(
                    selected ? DaybookTheme.stamp.opacity(0.45) : DaybookTheme.rule.opacity(0.6),
                    lineWidth: 0.7
                ))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityIdentifier("menubar.filter.option." + title)
        .help(title)
    }

    private var workspaceButton: some View {
        Button {
            AppWindows.openWorkspace(tab: tab == .diary ? .diary : .today)
        } label: {
            Label("footer.workspace", systemImage: "macwindow")
                .font(DaybookType.caption)
                .fixedSize()
                .frame(height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(DaybookTheme.muted)
        .help("window.workspace")
        .accessibilityLabel("window.workspace")
        .accessibilityIdentifier("menubar.workspace.open")
    }

    private var moreMenu: some View {
        Menu {
            Button(action: onShowSyntaxHelp) {
                Label("footer.syntax.help", systemImage: "questionmark.circle")
            }
            Button {
                AppWindows.openWorkspace(tab: .settings)
            } label: {
                Label("window.settings", systemImage: "gearshape")
            }
            Divider()
            Button(role: .destructive) { NSApplication.shared.terminate(nil) } label: {
                Label("footer.quit", systemImage: "power")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(DaybookType.caption.weight(.semibold))
                .frame(width: 24, height: 28)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .foregroundStyle(DaybookTheme.muted)
        .help("footer.more")
        .accessibilityLabel("footer.more")
        .accessibilityIdentifier("menubar.more")
    }

    private func openFilters(focus: Bool = false) {
        hoverWorkItem?.cancel()
        restoresTriggerFocus = focus
        toolbar.showFilters()
        if focus { DispatchQueue.main.async { filterFocused = true } }
    }

    private func closeFilters() {
        hoverWorkItem?.cancel()
        filterFocused = false
        toolbar.closeFilters()
        if restoresTriggerFocus {
            restoresTriggerFocus = false
            DispatchQueue.main.async { triggerFocused = true }
        }
    }

    private func trackFooterHover(_ hovering: Bool) {
        hoverWorkItem?.cancel()
        guard !hovering else { return }
        toolbar.pointerLeftToolbar()
        guard toolbar.isFiltering else { return }
        let work = DispatchWorkItem {
            closeFilters()
            toolbar.pointerLeftToolbar()
        }
        hoverWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: work)
    }

    private func selectTag(_ id: UUID) {
        let next = selectedTagID == id ? nil : id
        if tab == .tasks {
            filter?.wrappedValue = (filter?.wrappedValue ?? BoardFilter()).withTag(next)
        } else {
            diaryFilterTagID?.wrappedValue = next
        }
    }

    private func clearFilter() {
        if tab == .tasks { filter?.wrappedValue = BoardFilter() }
        else { diaryFilterTagID?.wrappedValue = nil }
    }
}
