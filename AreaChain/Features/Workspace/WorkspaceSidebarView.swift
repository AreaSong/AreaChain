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
        List {
            overviewSection
            itemsSection
            planningSection
            contentSection
            organizeSection
            systemSection
        }
        .listStyle(.sidebar)
        .daybookScroll(featherEdges: false)
    }

    private var overviewSection: some View {
        Section {
            tabRow(.dashboard)
        } header: {
            Text("sidebar.overview")
                .padding(.top, WorkspaceLayout.sidebarTopInset)
        }
    }

    private var itemsSection: some View {
        Section("sidebar.items") {
            tabRow(.today, badgeCount: todayUnfinishedCount)
            tabRow(.pending, badgeCount: pendingCount)
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
            tabRow(.privacy)
            tabRow(.dataBackup)
            tabRow(.trash)
        }
    }

    private var todayUnfinishedCount: Int? {
        let count = DayBoardLogic.todayBadgeCount(
            routines: routines.map(\.snapshot),
            checks: checks.compactMap(\.snapshot),
            todos: todos.map(\.snapshot),
            dayKey: DayClock.shared.todayKey
        )
        return count > 0 ? count : nil
    }

    private var pendingCount: Int? {
        let projection = AgendaProjection.pending(
            routines: routines.map(\.snapshot),
            checks: checks.compactMap(\.snapshot),
            todos: todos.map(\.snapshot),
            todayKey: DayClock.shared.todayKey
        )
        let count = projection.overdueCount + projection.upcomingCount
        return count > 0 ? count : nil
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
                Circle() // token-exempt: 标签色点，不是按钮
                    .fill(DaybookPalette.tagMark(name: tag.name, token: tag.colorToken))
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text(tag.name)
                    .font(DaybookType.body)
                    .foregroundStyle(DaybookPalette.text.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain) // control: 侧栏标签行，整行点击
        .listRowBackground(isSelected ? DaybookPalette.fill.selection : Color.clear)
        .accessibilityLabel(Text(tag.name))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
