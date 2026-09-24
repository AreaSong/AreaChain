import SwiftData
import SwiftUI

/// 工作台侧边导航栏交互操作。项目与标签新建仍保留给调用方，本阶段侧栏不展示这些入口。
struct WorkspaceSidebarActions {
    var onAddProject: () -> Void
    var onAddChildProject: (UUID) -> Void
    var onAddTag: () -> Void

    init(
        onAddProject: @escaping () -> Void,
        onAddChildProject: @escaping (UUID) -> Void,
        onAddTag: @escaping () -> Void
    ) {
        self.onAddProject = onAddProject
        self.onAddChildProject = onAddChildProject
        self.onAddTag = onAddTag
    }
}

/// 现代工作台侧边导航栏组件
struct WorkspaceSidebarView: View {
    @Bindable var navigation: WorkspaceNavigation

    var projects: [ProjectItem]
    var tags: [TagItem]
    var todos: [TodoItem]
    var actions: WorkspaceSidebarActions

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
            tabRow(.pending)
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

    private func tabRow(_ tab: WorkspaceTab, badgeCount: Int? = nil) -> some View {
        let isSelected = navigation.selectedProjectID == nil
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
}
