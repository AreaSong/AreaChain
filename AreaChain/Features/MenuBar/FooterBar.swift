import AppKit
import SwiftData
import SwiftUI

/// 菜单栏底栏：左侧筛选抽屉入口、中间动态切换搜索框/已选胶囊流、右侧工作台与更多入口，结构稳定无抖动。
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
    var onTriggerClick: (() -> Void)? = nil
    var activeCategory: Binding<FilterCategory>? = nil

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var triggerFocused: Bool
    @FocusState private var workspaceFocused: Bool
    @FocusState private var moreFocused: Bool

    private var activeTags: [TagItem] {
        tab == .tasks ? Catalog.liveTaskTags(tags) : Catalog.liveTags(tags)
    }

    private var currentFilter: BoardFilter {
        filter?.wrappedValue ?? BoardFilter()
    }

    private var selectedTagID: UUID? {
        tab == .tasks ? currentFilter.tagID : diaryFilterTagID?.wrappedValue
    }

    private var activeCount: Int {
        guard tab == .tasks else { return selectedTagID == nil ? 0 : 1 }
        let value = currentFilter
        let isPriorityActive = value.isHighPriorityOnly || value.priorityScope != .all
        return [value.projectID != nil, value.tagID != nil, value.bundleID != nil, isPriorityActive, value.dateScope != .all]
            .filter { $0 }.count
    }

    private var isFilterActiveOrDrawerOpen: Bool {
        isFilterDrawerPresented.wrappedValue || (activeCount > 0 && !toolbar.isSearching && !toolbar.searchIsFocused)
    }

    var body: some View {
        HStack(spacing: 6) {
            // 1. 左侧筛选入口区
            filterTrigger

            // 2. 中间就地联动区：筛选激活或抽屉打开时展示已选胶囊条，否则展示通用搜索框
            Group {
                if isFilterActiveOrDrawerOpen {
                    activeFilterChipsBar
                } else {
                    MenuBarSearchField(
                        tab: tab,
                        toolbar: toolbar,
                        availableTags: activeTags.map(\.name)
                    )
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("menubar.toolbar.tools")
                }
            }
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
                isFilterDrawerPresented.wrappedValue = filtering
            }
        }
    }

    // MARK: - 左侧筛选入口与触发器

    private var filterTrigger: some View {
        Group {
            if isFilterDrawerPresented.wrappedValue || activeCount > 0 {
                activeFilterButton
            } else {
                inactiveFilterButton
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var inactiveFilterButton: some View {
        Button {
            triggerAction()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease")
                    .accessibilityHidden(true)
                Text(L10n.string("filter.label", locale: locale))
                    .lineLimit(1)
            }
            .font(DaybookType.caption)
            .padding(.horizontal, 6)
            .frame(height: 26)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.clear, lineWidth: 0.6)
            )
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

    private var activeFilterButton: some View {
        Button {
            triggerAction()
        } label: {
            HStack(spacing: 3.5) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 9, weight: .bold))
                    .accessibilityHidden(true)

                Text(L10n.string("filter.label", locale: locale))
                    .font(DaybookType.caption.weight(.semibold))
                    .lineLimit(1)

                if activeCount > 0 {
                    Text("\(activeCount)")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .padding(.horizontal, 3.5)
                        .padding(.vertical, 0.5)
                        .background(DaybookTheme.stamp.opacity(0.18))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 6)
            .frame(height: 26)
            .foregroundStyle(DaybookTheme.stamp)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(DaybookTheme.stamp.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(DaybookTheme.stamp.opacity(0.40), lineWidth: 0.8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut("f", modifiers: [.command, .shift])
        .focused($triggerFocused)
        .accessibilityLabel("filter.label")
        .accessibilityIdentifier("menubar.filter.open")
        .help(activeDescription)
    }

    private func triggerAction() {
        onTriggerClick?() ?? isFilterDrawerPresented.wrappedValue.toggle()
    }

    // MARK: - 中间已选胶囊横向流

    private var activeFilterChipsBar: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    if tab == .tasks {
                        // 时间范围胶囊
                        if currentFilter.dateScope != .all {
                            chipItem(
                                title: dateScopeTitle(currentFilter.dateScope),
                                icon: "calendar",
                                onSelect: { navigateToCategory(.date) },
                                onRemove: { filter?.wrappedValue = currentFilter.withDateScope(.all) }
                            )
                        }

                        // 优先级胶囊
                        if currentFilter.priorityScope != .all || currentFilter.isHighPriorityOnly {
                            chipItem(
                                title: priorityTitle(currentFilter),
                                icon: "exclamationmark.3",
                                onSelect: { navigateToCategory(.priority) },
                                onRemove: {
                                    var next = currentFilter.withPriorityScope(.all)
                                    next.isHighPriorityOnly = false
                                    filter?.wrappedValue = next
                                }
                            )
                        }

                        // 项目胶囊
                        if let pid = currentFilter.projectID {
                            let name = pid == BoardFilter.noneID
                                ? L10n.string("filter.project.none", locale: locale)
                                : (projects.first(where: { $0.id == pid })?.name ?? L10n.string("filter.project", locale: locale))
                            chipItem(
                                title: name,
                                icon: "folder",
                                onSelect: { navigateToCategory(.project) },
                                onRemove: { filter?.wrappedValue = currentFilter.withProject(nil) }
                            )
                        }
                    }

                    // 标签胶囊
                    if let tid = selectedTagID {
                        if let tag = tags.first(where: { $0.id == tid }) {
                            chipItem(
                                title: "#" + tag.name,
                                dotColor: DiaryTagChrome.color(for: tag.name),
                                onSelect: { navigateToCategory(.tag) },
                                onRemove: { clearTag() }
                            )
                        }
                    }

                    // 若没有任何已选胶囊且抽屉开启，提示用户点选
                    if activeCount == 0 {
                        Text(L10n.string("filter.label", locale: locale) + "...")
                            .font(DaybookType.caption)
                            .foregroundStyle(DaybookTheme.muted.opacity(0.7))
                            .padding(.leading, 4)
                    }
                }
                .padding(.vertical, 2)
            }

            // 清空全部小按钮
            if activeCount > 0 {
                Button(action: clearFilter) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(DaybookTheme.stamp.opacity(0.8))
                        .padding(4)
                        .background(Circle().fill(DaybookTheme.stamp.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help(L10n.string("filter.clear", locale: locale))
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 26)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(DaybookTheme.hoverFill.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(DaybookTheme.rule.opacity(0.35), lineWidth: 0.6)
        )
    }

    private func chipItem(
        title: String,
        icon: String? = nil,
        dotColor: Color? = nil,
        onSelect: @escaping () -> Void,
        onRemove: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 3) {
            Button(action: onSelect) {
                HStack(spacing: 2.5) {
                    if let dotColor {
                        Circle().fill(dotColor).frame(width: 4.5, height: 4.5)
                    } else if let icon {
                        Image(systemName: icon).font(.system(size: 8, weight: .medium))
                    }
                    Text(title)
                        .font(.system(size: 9.5, weight: .medium))
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .frame(width: 10, height: 10)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 5)
        .padding(.trailing, 3.5)
        .padding(.vertical, 2)
        .background(Capsule().fill(DaybookTheme.stamp.opacity(0.12)))
        .overlay(Capsule().strokeBorder(DaybookTheme.stamp.opacity(0.4), lineWidth: 0.6))
        .foregroundStyle(DaybookTheme.stamp)
    }

    private func navigateToCategory(_ cat: FilterCategory) {
        if !isFilterDrawerPresented.wrappedValue {
            isFilterDrawerPresented.wrappedValue = true
        }
        activeCategory?.wrappedValue = cat
    }

    private func clearTag() {
        if tab == .tasks {
            filter?.wrappedValue = currentFilter.withTag(nil)
        } else {
            diaryFilterTagID?.wrappedValue = nil
        }
    }

    private func dateScopeTitle(_ scope: DateFilterScope) -> String {
        switch scope {
        case .all: return L10n.string("filter.all", locale: locale)
        case .today: return L10n.string("filter.date.today", locale: locale)
        case .recent: return L10n.string("filter.date.recent", locale: locale)
        case .overdue: return L10n.string("filter.date.overdue", locale: locale)
        }
    }

    private func priorityTitle(_ filter: BoardFilter) -> String {
        switch filter.priorityScope {
        case .all:
            return filter.isHighPriorityOnly ? L10n.string("filter.priority.high", locale: locale) : ""
        case .highPriorityOnly:
            return L10n.string("filter.priority.high", locale: locale)
        case .p1:
            return L10n.string("filter.priority.p1", locale: locale)
        case .p2:
            return L10n.string("filter.priority.p2", locale: locale)
        case .p3:
            return L10n.string("filter.priority.p3", locale: locale)
        case .p4:
            return L10n.string("filter.priority.p4", locale: locale)
        }
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
            Button {
                AppWindows.openWorkspace(tab: tab == .diary ? .diary : .today)
            } label: {
                Label("window.workspace", systemImage: "macwindow")
            }
            .keyboardShortcut("0", modifiers: .command)

            Divider()

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
