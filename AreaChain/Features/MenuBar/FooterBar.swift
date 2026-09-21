import AppKit
import SwiftData
import SwiftUI

/// 菜单栏底栏：左侧筛选抽屉入口、中间常驻搜索框、右侧工作台与更多入口，结构稳定无抖动。
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
    var isFilterDrawerPresented: Binding<Bool> = .constant(false)
    var onTriggerHover: ((Bool) -> Void)? = nil
    var onTriggerClick: (() -> Void)? = nil

    @Environment(\.locale) private var locale
    @FocusState private var triggerFocused: Bool
    @FocusState private var workspaceFocused: Bool
    @FocusState private var moreFocused: Bool

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
                isFilterDrawerPresented.wrappedValue = filtering
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
    }

    private var inactiveFilterButton: some View {
        Button {
            onTriggerClick?() ?? isFilterDrawerPresented.wrappedValue.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease")
                    .accessibilityHidden(true)
                Text(filterTitle).lineLimit(1)
            }
            .font(DaybookType.caption)
            .padding(.horizontal, 5)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isFilterDrawerPresented.wrappedValue ? DaybookTheme.stamp.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isFilterDrawerPresented.wrappedValue ? DaybookTheme.stamp.opacity(0.5) : Color.clear, lineWidth: 0.6)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut("f", modifiers: [.command, .shift])
        .focused($triggerFocused)
        .foregroundStyle(isFilterDrawerPresented.wrappedValue ? DaybookTheme.stamp : DaybookTheme.muted)
        .onHover { hovering in
            onTriggerHover?(hovering)
        }
        .accessibilityLabel("filter.label")
        .accessibilityIdentifier("menubar.filter.open")
        .help(L10n.string("filter.open.help", locale: locale))
    }

    private var activeFilterCapsule: some View {
        HStack(spacing: 2) {
            Button {
                onTriggerClick?() ?? isFilterDrawerPresented.wrappedValue.toggle()
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
        .onHover { hovering in
            onTriggerHover?(hovering)
        }
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
                .modifier(FooterActionItemModifier(isFocused: workspaceFocused))
        }
        .buttonStyle(.plain)
        .focused($workspaceFocused)
        .keyboardShortcut("0", modifiers: .command)
        .help(L10n.string("window.workspace", locale: locale))
        .accessibilityLabel(L10n.string("window.workspace", locale: locale))
        .accessibilityIdentifier("menubar.workspace.open")
    }

    private var moreMenu: some View {
        Menu {
            // 第一段：主工作台直接入口
            Button {
                AppWindows.openWorkspace(tab: tab == .diary ? .diary : .today)
            } label: {
                Label("window.workspace", systemImage: "macwindow")
            }
            .keyboardShortcut("0", modifiers: .command)

            Divider()

            // 第二段：辅助指南、偏好设置与系统回收站
            Button(action: onShowSyntaxHelp) {
                Label("footer.syntax.guide", systemImage: "questionmark.circle")
            }
            .keyboardShortcut("/", modifiers: .command)

            Button {
                AppWindows.openWorkspace(tab: .settings)
            } label: {
                Label("window.settings", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)

            Button {
                AppWindows.openWorkspace(tab: .trash)
            } label: {
                Label("window.trash", systemImage: "trash")
            }

            Divider()

            // 第三段：退出应用
            Button(role: .destructive) {
                NSApp.terminate(nil)
            } label: {
                Label("footer.quit", systemImage: "power")
            }
            .keyboardShortcut("q", modifiers: .command)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .semibold))
                .modifier(FooterActionItemModifier(isFocused: moreFocused))
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

// MARK: - 底栏动作按钮微交互修饰符

private struct FooterActionItemModifier: ViewModifier {
    @State private var isHovered = false
    var isFocused: Bool = false

    func body(content: Content) -> some View {
        content
            .frame(width: 26, height: 26)
            .foregroundStyle(isHovered || isFocused ? DaybookTheme.ink : DaybookTheme.muted)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .fill(isHovered ? DaybookTheme.hoverFill : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .strokeBorder(DaybookTheme.focusRing, lineWidth: isFocused ? 1.5 : 0)
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.12)) {
                    isHovered = hovering
                }
            }
    }
}
