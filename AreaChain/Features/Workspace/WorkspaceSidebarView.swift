import SwiftData
import SwiftUI

private enum CatalogRename: Identifiable {
    case project(UUID)
    case tag(UUID)

    var id: UUID {
        switch self {
        case .project(let id), .tag(let id):
            return id
        }
    }
}

/// 现代工作台侧边导航栏组件
struct WorkspaceSidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var navigation: WorkspaceNavigation

    var projects: [ProjectItem]
    var tags: [TagItem]
    var todos: [TodoItem]

    var onAddProject: () -> Void
    var onAddChildProject: (UUID) -> Void
    var onAddTag: () -> Void

    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query private var checks: [RoutineCheck]
    @State private var pendingTrash: PendingTrash?
    @State private var pendingRename: CatalogRename?
    @State private var renameDraft = ""
    @State private var renameError: LocalizedStringKey?

    var body: some View {
        List {
            Section("sidebar.focus") {
                tabRow(.today, badgeCount: todayUnfinishedCount)
                tabRow(.residents)
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
                ForEach(ProjectTree.outline(projects)) { row in
                    if let project = projects.first(where: { $0.id == row.id }) {
                        projectRow(project, depth: row.depth)
                    }
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
                ForEach(Catalog.liveTaskTags(tags)) { tag in
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
        .sheet(item: $pendingRename, onDismiss: { renameDraft = "" }) { _ in
            renameSheet
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

    private func projectRow(_ project: ProjectItem, depth: Int) -> some View {
        let isSelected = navigation.selectedProjectID == project.id
        let count = Catalog.openCount(
            todos: todos,
            routines: routines,
            checks: checks,
            project: project,
            tag: nil,
            projects: projects,
            dayKey: DayClock.shared.todayKey
        )
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
        .padding(.leading, 6 + CGFloat(depth) * 12)
        .padding(.trailing, 6)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .fill(isSelected ? DaybookTheme.stamp.opacity(0.12) : Color.clear)
        )
        .foregroundStyle(isSelected ? DaybookTheme.stamp : DaybookTheme.ink)
        .contextMenu {
            Button("sidebar.rename") { beginRename(.project(project.id), name: project.name) }
            Button("sidebar.add.child") { onAddChildProject(project.id) }
            projectParentMenu(project)
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

    private func projectParentMenu(_ project: ProjectItem) -> some View {
        Menu("sidebar.parent") {
            Button("sidebar.parent.none") {
                setParent(project.id, nil)
            }
            ForEach(ProjectTree.allowedParents(for: project.id, in: projects)) { parent in
                Button(ProjectTree.pathLabel(parent.id, in: projects)) {
                    setParent(project.id, parent.id)
                }
            }
        }
    }

    private func tagRow(_ tag: TagItem) -> some View {
        let isSelected = navigation.selectedTagID == tag.id
        let count = Catalog.openCount(
            todos: todos,
            routines: routines,
            checks: checks,
            project: nil,
            tag: tag,
            projects: projects,
            dayKey: DayClock.shared.todayKey
        )
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
            Button("sidebar.rename") { beginRename(.tag(tag.id), name: tag.name) }
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

    private var renameSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("sidebar.rename")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DaybookTheme.ink)
            TextField("sidebar.rename.name", text: $renameDraft)
                .textFieldStyle(.roundedBorder)
                .onSubmit(commitRename)
                .onChange(of: renameDraft) { _, _ in renameError = nil }
            if let renameError {
                Text(renameError)
                    .font(.system(size: 11))
                    .foregroundStyle(DaybookTheme.destructive)
            }
            HStack {
                Spacer()
                Button("alert.cancel") {
                    pendingRename = nil
                    renameDraft = ""
                    renameError = nil
                }
                Button("sidebar.rename") { commitRename() }
                    .buttonStyle(.borderedProminent)
                    .disabled(renameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 260)
    }

    private func beginRename(_ target: CatalogRename, name: String) {
        renameDraft = name
        renameError = nil
        pendingRename = target
    }

    private func commitRename() {
        let next = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !next.isEmpty, let target = pendingRename else {
            pendingRename = nil
            return
        }
        if case .tag = target, DiaryMemoTags.isPresetName(next) {
            renameError = "tag.preset.reserved"
            return
        }
        DayBoardMutations.persist {
            switch target {
            case .project(let id):
                projects.first { $0.id == id }?.name = next
            case .tag(let id):
                tags.first { $0.id == id }?.name = next
            }
        }
        pendingRename = nil
        renameDraft = ""
        renameError = nil
    }

    private func setParent(_ id: UUID, _ parentID: UUID?) {
        guard let item = projects.first(where: { $0.id == id }) else { return }
        guard !ProjectTree.wouldCycle(moving: id, to: parentID, in: projects) else { return }
        DayBoardMutations.persist { item.parentID = parentID }
    }
}
