import SwiftData
import SwiftUI

/// 现代工作台侧边导航栏组件
struct WorkspaceSidebarView: View {
    @Bindable var navigation: WorkspaceNavigation
    @Bindable private var shellPreviewSettings = WorkspaceShellPreviewSettings.shared

    var tags: [TagItem]
    var todos: [TodoItem]

    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query private var checks: [RoutineCheck]

    var body: some View {
        let badges = WorkspaceSidebarBadges.make(
            routines: routines,
            checks: checks,
            todos: todos,
            todayKey: DayClock.shared.todayKey
        )
        ZStack {
            // 第一层：最外层窗口底板（与右侧主画布共用同一原生灰底，消除分栏边界接缝）
            Color(nsColor: .windowBackgroundColor) // token-exempt: 侧栏外框与右侧主画布共用系统灰底以消除分界
                .ignoresSafeArea(.all, edges: .top)

            // 第二层：内嵌圆角内胆面板（macOS 系统设置同款：深邃内胆底色 + 四周闭合 1pt 玻璃高光圆角边线 + 均匀内缩边距）
            ZStack(alignment: .top) {
                DaybookPalette.sidebarFill

                List {
                    sidebarTopSpacer
                    overviewSection
                    itemsSection(todayUnfinished: badges.todayUnfinished, pending: badges.pending)
                    planningSection
                    contentSection
                    organizeSection
                    systemSection
                }
                .listStyle(.sidebar)
                .scrollIndicators(.hidden)
                .environment(\.daybookScrollTopEdge, true)
                .scrollContentBackground(.hidden)
            }
            .clipShape(RoundedRectangle(cornerRadius: DaybookRadius.panel, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DaybookRadius.panel, style: .continuous)
                    .strokeBorder(DaybookPalette.sidebarBorder, lineWidth: 1)
            }
            .daybookElevation(.panel)
            .padding(.leading, 9)
            .padding(.top, 9)
            .padding(.bottom, 9)
            .padding(.trailing, 8)
        }
        .background(SyntaxViewAnchor("syntax.workspace.sidebar.bounds"))
    }

    /// 顶部红绿灯避让区：确保未滚动时首项自然呈现在红绿灯下方，向上滚动时平滑穿透滑入毛玻璃层
    private var sidebarTopSpacer: some View {
        Color.clear
            .frame(height: 38)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .accessibilityHidden(true)
    }

    private var overviewSection: some View {
        Section {
            tabRow(.dashboard)
        } header: {
            Text("sidebar.overview")
        }
    }

    private func itemsSection(todayUnfinished: Int?, pending: Int?) -> some View {
        Section("sidebar.items") {
            tabRow(.today, badgeCount: todayUnfinished)
            if navigation === WorkspaceNavigation.shared && AppStartup.policy == .application && shellPreviewSettings.isEnabled {
                WorkspaceSidebarRow(
                    titleKey: "重构预览（今日）",
                    systemImage: "swatchpalette",
                    badgeCount: nil,
                    isSelected: navigation.isShowingShellPreview
                ) {
                    navigation.revealShellPreview()
                }
            }
            tabRow(.pending, badgeCount: pending)
            tabRow(.allItems)
        }
    }

    private var planningSection: some View {
        Section("sidebar.planning") {
            tabRow(.calendar)
            tabRow(.gantt)
            tabRow(.quadrant)
        }
    }

    private var contentSection: some View {
        Section("sidebar.content") {
            tabRow(.diary)
            tabRow(.clipboard)
            tabRow(.attachments)
        }
    }

    private var organizeSection: some View {
        Section("sidebar.organize") {
            tabRow(.tags)
            ForEach(Catalog.liveTaskTags(tags)) { tag in
                tagRow(tag)
            }
        }
    }

    private var systemSection: some View {
        Section("sidebar.system") {
            tabRow(.settings)
            tabRow(.shortcuts)
            tabRow(.privacy)
            tabRow(.dataBackup)
            tabRow(.trash)
        }
    }

    private func tabRow(_ tab: WorkspaceTab, badgeCount: Int? = nil) -> some View {
        let isSelected = !navigation.isShowingShellPreview
            && navigation.selectedTagID == nil
            && navigation.selectedTab == tab
        return WorkspaceSidebarRow(
            titleKey: tab.titleKey,
            systemImage: tab.iconName,
            badgeCount: badgeCount,
            isSelected: isSelected
        ) {
            navigation.revealTab(tab)
        }
    }

    private func tagRow(_ tag: TagItem) -> some View {
        let isSelected = !navigation.isShowingShellPreview && navigation.selectedTagID == tag.id
        return Button {
            navigation.selectedTagID = tag.id
        } label: {
            HStack(spacing: 8) {
                DaybookStatusDot(color: DaybookPalette.tagMark(name: tag.name, token: tag.colorToken), size: 8)

                Text(tag.name)
                    .font(DaybookType.body.weight(isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? DaybookPalette.accent.base : DaybookPalette.text.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.vertical, WorkspaceLayout.sidebarRowVerticalPadding)
            .padding(.horizontal, WorkspaceLayout.sidebarRowHorizontalPadding)
            .frame(minHeight: WorkspaceLayout.sidebarRowHeight)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.regular, style: .continuous)
                    .fill(isSelected ? DaybookPalette.fill.selection : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain) // control: 侧栏标签行，整行点击
        .accessibilityLabel(Text(tag.name))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
