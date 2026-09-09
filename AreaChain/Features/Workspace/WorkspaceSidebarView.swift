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

    var body: some View {
        List {
            Section("视图") {
                tabRow(.today)
                tabRow(.search)
                tabRow(.calendar)
                tabRow(.quadrant)
                tabRow(.gantt)
                tabRow(.diary)
                tabRow(.attachments)
                tabRow(.trash)
                tabRow(.settings)
            }

            Section {
                let activeProjects = projects.filter { $0.deletedAt == nil }
                ForEach(activeProjects) { proj in
                    projectRow(proj)
                }
            } header: {
                HStack {
                    Text("项目")
                    Spacer()
                    Button(action: onAddProject) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .help("新建项目")
                }
            }

            Section {
                let activeTags = tags.filter { $0.deletedAt == nil }
                ForEach(activeTags) { tag in
                    tagRow(tag)
                }
            } header: {
                HStack {
                    Text("标签")
                    Spacer()
                    Button(action: onAddTag) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .help("新建标签")
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func tabRow(_ tab: WorkspaceTab) -> some View {
        let isSelected = navigation.selectedProjectID == nil && navigation.selectedTagID == nil && navigation.selectedTab == tab
        return Button {
            navigation.selectedTab = tab
        } label: {
            HStack {
                Label(tab.titleKey, systemImage: tab.iconName)
                Spacer()
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
        let count = todos.filter { $0.projectID == project.id && $0.deletedAt == nil && !$0.isDone }.count
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
            Button("移入废纸篓", role: .destructive) {
                DayBoardMutations.persist { project.deletedAt = .now }
                if navigation.selectedProjectID == project.id {
                    navigation.selectedProjectID = nil
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
            Button("移入废纸篓", role: .destructive) {
                DayBoardMutations.persist { tag.deletedAt = .now }
                if navigation.selectedTagID == tag.id {
                    navigation.selectedTagID = nil
                }
            }
        }
    }
}
