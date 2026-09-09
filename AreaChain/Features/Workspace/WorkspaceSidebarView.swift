import SwiftData
import SwiftUI

/// 现代工作台侧边导航栏组件
struct WorkspaceSidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var navigation: WorkspaceNavigation

    var projects: [ProjectItem]
    var tags: [TagItem]
    var todos: [TodoItem]

    var onAddProject: () -> Void
    var onAddTag: () -> Void

    @State private var pendingTrash: PendingTrash?

    var body: some View {
        List {
            Section("sidebar.focus") {
                tabRow(.today, badgeCount: todayUnfinishedCount)
                tabRow(.search)
            }

            Section("sidebar.boards") {
                tabRow(.quadrant)
                tabRow(.gantt)
                tabRow(.calendar)
            }

            Section("sidebar.records") {
                tabRow(.diary)
                tabRow(.attachments)
            }

            Section {
                let activeProjects = projects.filter { $0.deletedAt == nil }
                ForEach(activeProjects) { proj in
                    projectRow(proj)
                }
            } header: {
                HStack {
                    Text("sidebar.projects")
                    Spacer()
                    Button(action: onAddProject) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .help("sidebar.add.project")
                }
            }

            Section {
                let activeTags = tags.filter { $0.deletedAt == nil }
                ForEach(activeTags) { tag in
                    tagRow(tag)
                }
            } header: {
                HStack {
                    Text("sidebar.tags")
                    Spacer()
                    Button(action: onAddTag) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .help("sidebar.add.tag")
                }
            }

            Section("sidebar.system") {
                tabRow(.trash)
                tabRow(.settings)
            }
        }
        .listStyle(.sidebar)
        .confirmMoveToTrash($pendingTrash)
    }

    private var todayUnfinishedCount: Int? {
        let todayKey = DayClock.shared.todayKey
        let count = todos.filter { $0.dayKey == todayKey && $0.deletedAt == nil && !$0.isDone }.count
        return count > 0 ? count : nil
    }

    private func tabRow(_ tab: WorkspaceTab, badgeCount: Int? = nil) -> some View {
        let isSelected = navigation.selectedProjectID == nil && navigation.selectedTagID == nil && navigation.selectedTab == tab
        return Button {
            navigation.revealTab(tab)
        } label: {
            HStack {
                Label(tab.titleKey, systemImage: tab.iconName)
                Spacer()
                if let badgeCount {
                    Text("\(badgeCount)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? DaybookTheme.stamp : DaybookTheme.muted)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(
                            Capsule()
                                .fill(isSelected ? DaybookTheme.stamp.opacity(0.18) : DaybookTheme.hoverFill)
                        )
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .fill(isSelected ? DaybookTheme.stamp.opacity(0.12) : Color.clear)
        )
        .foregroundStyle(isSelected ? DaybookTheme.stamp : DaybookTheme.ink)
        .font(.system(size: 12.5))
    }

    private func projectRow(_ project: ProjectItem) -> some View {
        let isSelected = navigation.selectedProjectID == project.id
        let ids = ProjectTree.subtreeIDs(root: project.id, in: projects)
        let count = todos.filter {
            guard let projectID = $0.projectID else { return false }
            return ids.contains(projectID) && $0.deletedAt == nil && !$0.isDone
        }.count
        return Button {
            navigation.selectedProjectID = project.id
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.system(size: 11))
                Text(project.name)
                    .font(.system(size: 12))
                Spacer()
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(DaybookTheme.muted)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .fill(isSelected ? DaybookTheme.stamp.opacity(0.12) : Color.clear)
        )
        .foregroundStyle(isSelected ? DaybookTheme.stamp : DaybookTheme.ink)
        .contextMenu {
            Button("alert.trash.move", role: .destructive) {
                pendingTrash = PendingTrash(title: project.name) {
                    DayBoardMutations.persist { project.deletedAt = SoftDelete.stamp() }
                    if navigation.selectedProjectID == project.id {
                        navigation.selectedProjectID = nil
                    }
                }
            }
        }
    }

    private func tagRow(_ tag: TagItem) -> some View {
        let isSelected = navigation.selectedTagID == tag.id
        let count = todos.filter { TagIDList.contains($0.tagIDs, tag.id) && $0.deletedAt == nil && !$0.isDone }.count
        return Button {
            navigation.selectedTagID = tag.id
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "tag")
                    .font(.system(size: 11))
                Text(tag.name)
                    .font(.system(size: 12))
                Spacer()
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(DaybookTheme.muted)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .fill(isSelected ? DaybookTheme.stamp.opacity(0.12) : Color.clear)
        )
        .foregroundStyle(isSelected ? DaybookTheme.stamp : DaybookTheme.ink)
        .contextMenu {
            Button("alert.trash.move", role: .destructive) {
                pendingTrash = PendingTrash(title: tag.name) {
                    DayBoardMutations.persist { tag.deletedAt = SoftDelete.stamp() }
                    if navigation.selectedTagID == tag.id {
                        navigation.selectedTagID = nil
                    }
                }
            }
        }
    }
}
