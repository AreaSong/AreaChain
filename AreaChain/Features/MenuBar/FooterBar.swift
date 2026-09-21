import AppKit
import SwiftData
import SwiftUI

/// 菜单栏底栏：左侧筛选气泡入口、中间常驻搜索框、右侧工作台与更多入口，结构稳定无抖动。
struct FooterBar: View {
    var tab: BoardTab = .tasks
    @Bindable var toolbar: MenuBarToolbarState
    var filter: Binding<BoardFilter>? = nil
    var diaryFilterTagID: Binding<UUID?>? = nil
    var projects: [ProjectItem] = []
    var projectCounts: [UUID: Int] = [:]
    var unclassifiedCount: Int? = nil
    var tags: [TagItem] = []
    var tagCounts: [UUID: Int] = [:]
    var onShowSyntaxHelp: () -> Void = {}

    @Environment(\.locale) private var locale
    @State private var isFilterPopoverPresented = false
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
        HStack(spacing: 6) {
            // 1. 左侧筛选入口区
            filterTrigger

            // 2. 中间常驻搜索框
            MenuBarSearchField(
                tab: tab,
                toolbar: toolbar,
                availableTags: activeTags.map(\.name)
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("menubar.toolbar.tools")

            // 3. 右侧稳定动作区
            HStack(spacing: 6) {
                workspaceButton
                moreMenu
            }
            .frame(width: 54, alignment: .trailing)
        }
        .frame(height: 30)
        .onChange(of: tab) { _, _ in isFilterPopoverPresented = false }
        .onChange(of: isFilterPopoverPresented) { _, presented in
            if presented {
                toolbar.showFilters()
            } else {
                toolbar.closeFilters()
            }
        }
        .onChange(of: toolbar.isFiltering) { _, filtering in
            if filtering != isFilterPopoverPresented {
                isFilterPopoverPresented = filtering
            }
        }
    }

    // MARK: - 左侧筛选入口与触发器

    private var filterTrigger: some View {
        Group {
            if activeCount > 0 {
                activeFilterCapsule
            } else {
                inactiveFilterButton
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .popover(isPresented: $isFilterPopoverPresented, arrowEdge: .top) {
            MenuBarFilterPopover(
                tab: tab,
                filter: filter,
                diaryFilterTagID: diaryFilterTagID,
                projects: projects,
                projectCounts: projectCounts,
                unclassifiedCount: unclassifiedCount,
                tags: activeTags,
                tagCounts: tagCounts,
                onDismiss: { isFilterPopoverPresented = false }
            )
        }
    }

    private var inactiveFilterButton: some View {
        Button {
            isFilterPopoverPresented.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease")
                    .accessibilityHidden(true)
                Text(filterTitle).lineLimit(1)
            }
            .font(DaybookType.caption)
            .padding(.horizontal, 5)
            .frame(height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut("f", modifiers: [.command, .shift])
        .focused($triggerFocused)
        .foregroundStyle(DaybookTheme.muted)
        .accessibilityLabel("filter.label")
        .accessibilityIdentifier("menubar.filter.open")
        .help(L10n.string("filter.open.help", locale: locale))
    }

    private var activeFilterCapsule: some View {
        HStack(spacing: 2) {
            Button {
                isFilterPopoverPresented.toggle()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 9.5, weight: .semibold))
                        .accessibilityHidden(true)
                    Text(filterTitle)
                        .font(DaybookType.caption.weight(.medium))
                        .lineLimit(1)
                }
                .padding(.leading, 7)
                .padding(.vertical, 3)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .focused($triggerFocused)

            Button(action: clearFilter) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("footer.filter.clear")
            .accessibilityLabel("footer.filter.clear")
        }
        .frame(height: 24)
        .foregroundStyle(DaybookTheme.stamp)
        .background(Capsule().fill(DaybookTheme.stamp.opacity(0.12)))
        .overlay(Capsule().strokeBorder(DaybookTheme.stamp.opacity(0.40), lineWidth: 0.8))
        .accessibilityLabel("filter.label")
        .accessibilityIdentifier("menubar.filter.open")
        .accessibilityValue(activeDescription)
        .help(activeDescription)
    }

    private var filterTitle: String {
        if activeCount > 1 { return L10n.format("footer.filter.count", locale: locale, activeCount) }
        if highPriority { return L10n.string("filter.highPriority", locale: locale) }
        if let projectID = filter?.wrappedValue.projectID {
            if projectID == BoardFilter.noneID {
                return L10n.string("filter.project.none", locale: locale)
            }
            if let name = projects.first(where: { $0.id == projectID })?.name {
                return name
            }
        }
        if let tag = activeTags.first(where: { $0.id == selectedTagID }) { return "#" + tag.name }
        return L10n.string("filter.label", locale: locale)
    }

    private var activeDescription: String {
        guard activeCount > 0 else { return L10n.string("filter.all", locale: locale) }
        return L10n.format("footer.filter.active", locale: locale, activeCount)
    }

    private func clearFilter() {
        if tab == .tasks {
            filter?.wrappedValue = BoardFilter()
        } else {
            diaryFilterTagID?.wrappedValue = nil
        }
    }

    // MARK: - 右侧稳定动作区

    private var workspaceButton: some View {
        Button {
            AppWindows.openWorkspace(tab: tab == .diary ? .diary : .today)
        } label: {
            Image(systemName: "macwindow")
                .font(DaybookType.caption)
                .frame(width: 24, height: 28)
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
                Label("footer.syntax.guide", systemImage: "questionmark.circle")
            }
            Button {
                AppWindows.openWorkspace(tab: .settings)
            } label: {
                Label("footer.preferences", systemImage: "gearshape")
            }
            Divider()
            Button {
                NSApp.terminate(nil)
            } label: {
                Label("footer.quit", systemImage: "power")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(DaybookType.caption)
                .frame(width: 24, height: 28)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .foregroundStyle(DaybookTheme.muted)
        .help("footer.more")
        .accessibilityLabel("footer.more")
        .accessibilityIdentifier("menubar.more")
    }
}
