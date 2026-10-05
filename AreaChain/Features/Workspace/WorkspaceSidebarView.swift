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
        List {
            overviewSection
            itemsSection(todayUnfinished: badges.todayUnfinished, pending: badges.pending)
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
