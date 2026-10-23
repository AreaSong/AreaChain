import AppKit
import SwiftData
import SwiftUI

/// 菜单栏底栏：左侧筛选抽屉入口、中间统一搜索框、右侧工作台与收起入口，结构稳定无抖动。
struct FooterBar: View {
    var tab: BoardTab = .tasks
    @Bindable var toolbar: MenuBarToolbarState
    var filters: Binding<BoardFilters>
    var unclassifiedCount: Int? = nil
    var tags: [TagItem] = []
    var tagCounts: [UUID: Int] = [:]
    var onShowSyntaxHelp: () -> Void = {}
    var isFilterDrawerPresented: Binding<Bool> = .constant(false)
    var onTriggerClick: (() -> Void)? = nil
    var activeCategory: Binding<FilterCategory>? = nil
    /// 统一搜索的菜单栏控制器；nil 表示装配失败，中间显示不可用说明。
    var unified: UnifiedSearchController? = nil

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var triggerFocused: Bool
    @FocusState private var workspaceFocused: Bool
    @FocusState private var moreFocused: Bool

    private var activeCount: Int {
        filters.wrappedValue.activeCount(for: tab)
    }

    @State private var hoverTask: Task<Void, Never>? = nil

    var body: some View {
        HStack(spacing: 6) {
            // 1. 左侧筛选入口区
            filterTrigger

            // 2. 中间全宽统一搜索框；装配失败时换成不阻塞的不可用说明
            Group {
                if let unified {
                    MenuBarUnifiedSearchField(controller: unified)
                } else {
                    UnifiedSearchUnavailableField(compact: true)
                        .frame(minWidth: DaybookMetrics.Window.popoverFooterSearchMinWidth)
                        .accessibilityIdentifier("menubar.search.unavailable")
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("menubar.toolbar.tools")
            .frame(maxWidth: .infinity)

            // 3. 右侧稳定动作区
            HStack(spacing: 4) {
                workspaceButton
                moreMenu
            }
            .frame(width: 56, alignment: .trailing)
        }
        .frame(height: 30)
        .onChange(of: tab) { _, _ in isFilterDrawerPresented.wrappedValue = false }
        .onChange(of: isFilterDrawerPresented.wrappedValue) { _, presented in
            if presented {
                toolbar.showFilters()
            } else {
                toolbar.closeFilters()
            }
        }
        .onChange(of: toolbar.isFiltering) { _, filtering in
            if filtering != isFilterDrawerPresented.wrappedValue {
                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                    isFilterDrawerPresented.wrappedValue = filtering
                }
            }
        }
    }

    // MARK: - 左侧筛选入口与触发器

    private var filterIsActive: Bool {
        isFilterDrawerPresented.wrappedValue || activeCount > 0
    }

    private var filterTrigger: some View {
        filterButton
            .fixedSize(horizontal: true, vertical: false)
            .frame(minHeight: DaybookMetrics.Hit.compact)
            .contentShape(Rectangle())
            .background(SyntaxViewAnchor("menubar.filter.open"))
            .onHover(perform: handleFilterHover)
    }

    private var filterButton: some View {
        Button(action: triggerAction) {
            HStack(spacing: filterIsActive ? 3.5 : 4) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(filterIsActive ? DaybookType.micro.weight(.bold) : DaybookType.caption)
                    .accessibilityHidden(true)
                Text(L10n.string("filter.label", locale: locale))
                    .font(filterIsActive ? DaybookType.caption.weight(.semibold) : DaybookType.caption)
                    .lineLimit(1)
                if filterIsActive, activeCount > 0 {
                    DaybookCount(count: activeCount, emphasis: true)
                }
            }
        }
        .buttonStyle(DaybookButtonStyle(
            filterIsActive ? .pill(tint: DaybookPalette.accent.base) : .subtle,
            size: .compact,
            isFocused: triggerFocused
        ))
        .contentShape(Rectangle())
        .appShortcut(.openFilter)
        .focused($triggerFocused)
        .accessibilityLabel("filter.label")
        .accessibilityIdentifier("menubar.filter.open")
        .help(filterIsActive ? activeDescription : L10n.string("filter.open.help", locale: locale))
    }

    /// 开关会改按钮尺寸。离开若立刻重新允许悬停，同一次点击里的跟踪重建会把刚关掉的筛选又打开。
    private func handleFilterHover(_ isHovered: Bool) {
        hoverTask?.cancel()
        hoverTask = Task {
            try? await Task.sleep(for: .milliseconds(isHovered ? 120 : 160))
            guard !Task.isCancelled else { return }
            if isHovered {
                toolbar.showFiltersFromHover()
            } else {
                toolbar.pointerLeftToolbar()
            }
        }
    }

    private func triggerAction() {
        hoverTask?.cancel()
        hoverTask = nil
        onTriggerClick?() ?? isFilterDrawerPresented.wrappedValue.toggle()
    }

    // MARK: - 辅助计算

    private var activeDescription: String {
        guard activeCount > 0 else { return L10n.string("filter.all", locale: locale) }
        return L10n.format("footer.filter.active", locale: locale, activeCount)
    }

    private func clearFilter() {
        filters.wrappedValue.clear(tab)
    }

    // MARK: - 右侧稳定动作区

    private var dismissDrawerButton: some View {
        DaybookIconButton(systemName: "xmark", label: "common.close", size: .regular) {
            isFilterDrawerPresented.wrappedValue = false
        }
    }

    private var workspaceButton: some View {
        Button {
            AppWindows.openWorkspace(tab: tab == .diary ? .diary : .today)
        } label: {
            Image(systemName: "macwindow")
                .font(DaybookType.caption)
        }
        .buttonStyle(DaybookButtonStyle(.icon, size: .regular, isFocused: workspaceFocused))
        .focused($workspaceFocused)
        .appShortcut(.openWorkspace)
        .help(L10n.string("window.workspace", locale: locale))
        .accessibilityLabel(L10n.string("window.workspace", locale: locale))
        .accessibilityIdentifier("menubar.workspace.open")
    }

    private var moreMenu: some View {
        Menu {
            Button {
                AppWindows.openWorkspace(tab: tab == .diary ? .diary : .today)
            } label: {
                Label("window.workspace", systemImage: "macwindow")
            }
            .appShortcut(.openWorkspace)

            Divider()

            Button(action: onShowSyntaxHelp) {
                Label("footer.syntax.guide", systemImage: "questionmark.circle")
            }
            .appShortcut(.syntaxHelp)

            Button {
                AppWindows.openSettings()
            } label: {
                Label("window.settings", systemImage: "gearshape")
            }
            .appShortcut(.openSettings)

            Button {
                AppWindows.openWorkspace(tab: .trash)
            } label: {
                Label("window.trash", systemImage: "trash")
            }

            Divider()

            Button(role: .destructive) {
                NSApp.terminate(nil)
            } label: {
                Label("footer.quit", systemImage: "power")
            }
            .appShortcut(.quit)
        } label: {
            Image(systemName: "ellipsis")
                .font(DaybookType.subtitle.weight(.semibold))
                .daybookMenuLabel(size: .regular, isFocused: moreFocused)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .focused($moreFocused)
        .help(L10n.string("footer.more", locale: locale))
        .accessibilityLabel(L10n.string("footer.more", locale: locale))
        .accessibilityIdentifier("menubar.more")
    }
}
