import SwiftData
import SwiftUI

/// 现代工作台侧边导航栏组件
struct WorkspaceSidebarView: View {
    @Bindable var navigation: WorkspaceNavigation

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
            // 第一层：最外层窗口底板（全高通顶，呈现原生侧栏毛玻璃底色）
            WorkspaceSidebarVisualEffect(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea(.all, edges: .top)

            // 第二层：内嵌圆角内胆面板（macOS 系统设置同款：Squircle 连续圆角 + 微光内嵌描边 + 红绿灯自然包裹）
            ZStack(alignment: .top) {
                DaybookPalette.fill.page

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
                .daybookScroll(featherEdges: false)
                .environment(\.daybookScrollTopEdge, true)
                .scrollContentBackground(.hidden)
                .mask {
                    WorkspaceSidebarFadeMask()
                }

                WorkspaceSidebarHeaderLayer()
            }
            .clipShape(RoundedRectangle(cornerRadius: DaybookRadius.panel, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DaybookRadius.panel, style: .continuous)
                    .strokeBorder(DaybookPalette.border.subtle, lineWidth: 0.5)
            }
            .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1) // token-exempt: 侧栏内嵌面板微阴影
            .padding(.leading, 8)
            .padding(.top, 7)
            .padding(.bottom, 8)
            .padding(.trailing, 2)
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
        let isSelected = navigation.selectedTagID == nil
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
        let isSelected = navigation.selectedTagID == tag.id
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
