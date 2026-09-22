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

/// 工作台侧边导航栏交互操作
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
    @Environment(\.modelContext) private var modelContext
    @Bindable var navigation: WorkspaceNavigation
    @Bindable private var prefs = AppPreferences.shared

    var projects: [ProjectItem]
    var tags: [TagItem]
    var todos: [TodoItem]
    var actions: WorkspaceSidebarActions

    private var onAddProject: () -> Void { actions.onAddProject }
    private var onAddChildProject: (UUID) -> Void { actions.onAddChildProject }
    private var onAddTag: () -> Void { actions.onAddTag }

    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query private var checks: [RoutineCheck]
    @State private var pendingTrash: PendingTrash?
    @State private var pendingRename: CatalogRename?
    @State private var renameDraft = ""
    @State private var renameError: LocalizedStringKey?

    var body: some View {
        List {
            focusSection
            boardsSection
            recordsSection
            projectsSection
            tagsSection
            systemSection
        }
        .listStyle(.sidebar)
        .daybookScroll(featherEdges: false)
        .confirmMoveToTrash($pendingTrash)
        .sheet(item: $pendingRename, onDismiss: { renameDraft = "" }) { _ in
            renameSheet
        }
    }

    private var focusSection: some View {
        Section {
            tabRow(.today, badgeCount: todayUnfinishedCount)
            tabRow(.residents)
        } header: {
            Text("sidebar.focus")
                .padding(.top, WorkspaceLayout.sidebarTopInset)
        }
    }

    private var boardsSection: some View {
        Section("sidebar.boards") {
            tabRow(.quadrant)
            tabRow(.gantt)
            tabRow(.calendar)
        }
    }

    private var recordsSection: some View {
        Section("sidebar.records") {
            tabRow(.diary)
            tabRow(.attachments)
        }
    }

    private var projectsSection: some View {
        Section(isExpanded: $prefs.isProjectsExpanded) {
            ForEach(ProjectTree.outline(projects)) { row in
                if let project = projects.first(where: { $0.id == row.id }) {
                    projectRow(project, depth: row.depth)
                }
            }
        } header: {
            HStack {
                Text("sidebar.projects")
                Spacer()
                DaybookIconButton(systemName: "plus", label: "sidebar.add.project", size: .compact, action: onAddProject)
            }
        }
    }

    private var tagsSection: some View {
        Section(isExpanded: $prefs.isTagsExpanded) {
            ForEach(Catalog.liveTaskTags(tags)) { tag in
                tagRow(tag)
            }
        } header: {
            HStack {
                Text("sidebar.tags")
                Spacer()
                DaybookIconButton(systemName: "plus", label: "sidebar.add.tag", size: .compact, action: onAddTag)
            }
        }
    }

    private var systemSection: some View {
        Section("sidebar.system") {
            tabRow(.trash)
            tabRow(.settings)
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
        return WorkspaceSidebarRow(
            title: project.name,
            systemImage: "folder",
            badgeCount: count,
            depth: depth,
            isSelected: isSelected
        ) {
            navigation.selectedProjectID = project.id
        }
        .contextMenu {
            projectContextMenu(project)
        }
    }

    @ViewBuilder
    private func projectContextMenu(_ project: ProjectItem) -> some View {
        Button("sidebar.rename") { beginRename(.project(project.id), name: project.name) }
        Button("sidebar.add.child") { onAddChildProject(project.id) }
        projectParentMenu(project)
        Button("alert.trash.move", role: .destructive) {
            pendingTrash = PendingTrash(title: project.name) {
                DayBoardMutations.trashProject(id: project.id, context: modelContext)
                if navigation.selectedProjectID == project.id {
                    navigation.selectedProjectID = nil
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
        return WorkspaceSidebarRow(
            title: tag.name,
            systemImage: "tag",
            badgeCount: count,
            isSelected: isSelected
        ) {
            navigation.selectedTagID = tag.id
        }
        .contextMenu {
            Button("sidebar.rename") { beginRename(.tag(tag.id), name: tag.name) }
            Button("alert.trash.move", role: .destructive) {
                pendingTrash = PendingTrash(title: tag.name) {
                    DayBoardMutations.trashTag(id: tag.id, context: modelContext)
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
                .font(DaybookType.body.weight(.semibold))
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
        let saved: Bool
        switch target {
        case .project(let id):
            saved = DayBoardMutations.renameProject(id: id, name: next, context: modelContext)
        case .tag(let id):
            saved = DayBoardMutations.renameTag(id: id, name: next, context: modelContext)
        }
        guard saved else { return }
        pendingRename = nil
        renameDraft = ""
        renameError = nil
    }

    private func setParent(_ id: UUID, _ parentID: UUID?) {
        guard projects.contains(where: { $0.id == id }) else { return }
        guard !ProjectTree.wouldCycle(moving: id, to: parentID, in: projects) else { return }
        DayBoardMutations.setProjectParent(id: id, parentID: parentID, context: modelContext)
    }
}
