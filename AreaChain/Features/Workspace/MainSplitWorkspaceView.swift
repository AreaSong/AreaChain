import SwiftData
import SwiftUI
import AppKit

/// 三栏工作台：侧栏、详情页与检查器抽屉。
struct MainSplitWorkspaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable private var navigation = WorkspaceNavigation.shared

    @Query(sort: \ProjectItem.sortOrder) private var projects: [ProjectItem]
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    @Query private var todos: [TodoItem]
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query private var checks: [RoutineCheck]

    @State private var isAddingProject = false
    @State private var newProjectName = ""
    @State private var newProjectParentID: UUID?
    @State private var isAddingTag = false
    @State private var newTagName = ""
    @State private var tagCreateError: LocalizedStringKey?

    var body: some View {
        NavigationSplitView {
            sidebarColumn
        } detail: {
            detailColumn
        }
        .inspector(isPresented: $navigation.isInspectorPresented) {
            TaskDetailDrawer(taskID: $navigation.selectedTaskID)
                .inspectorColumnWidth(min: 280, ideal: 320, max: 400)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    navigation.isInspectorPresented.toggle()
                } label: {
                    Image(systemName: "sidebar.trailing")
                }
                .help("drawer.inspector.toggle")
            }
        }
        .navigationTitle("AreaChain")
        .sheet(isPresented: $isAddingProject) {
            addProjectSheet
        }
        .sheet(isPresented: $isAddingTag) {
            addTagSheet
        }
    }

    private var sidebarColumn: some View {
        WorkspaceSidebarView(
            navigation: navigation,
            projects: projects,
            tags: tags,
            todos: todos,
            actions: WorkspaceSidebarActions(
                onAddProject: { beginAddProject(parentID: nil) },
                onAddChildProject: { beginAddProject(parentID: $0) },
                onAddTag: {
                    newTagName = ""
                    tagCreateError = nil
                    isAddingTag = true
                }
            )
        )
        .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
    }

    private var detailColumn: some View {
        detailView
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                if !navigation.selectedTaskIDs.isEmpty {
                    WorkspaceBatchActionBar(
                        navigation: navigation,
                        data: WorkspaceBatchData(
                            todos: todos,
                            routines: routines,
                            checks: checks,
                            projects: projects,
                            tags: tags
                        )
                    )
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onKeyPress(.escape) {
                handleEscapeKey()
            }
    }

    private func handleEscapeKey() -> KeyPress.Result {
        if (NSApp.keyWindow?.firstResponder as? NSTextView)?.isEditable == true {
            BoardSelection.shared.markEscapeCancelsEdits()
            NSApp.keyWindow?.makeFirstResponder(nil)
            return .handled
        }
        if navigation.isInspectorPresented {
            navigation.closeInspector()
            return .handled
        }
        if navigation.selectedTaskID != nil {
            navigation.selectedTaskID = nil
            return .handled
        }
        if !navigation.selectedTaskIDs.isEmpty {
            navigation.clearSelection()
            return .handled
        }
        return .ignored
    }

    // MARK: - Detail Router

    @ViewBuilder
    private var detailView: some View {
        if let pid = navigation.selectedProjectID, let project = projects.first(where: { $0.id == pid && $0.deletedAt == nil }) {
            WorkspaceFilteredListView(project: project)
        } else if let tid = navigation.selectedTagID, let tag = tags.first(where: { $0.id == tid && $0.deletedAt == nil }) {
            WorkspaceFilteredListView(tag: tag)
        } else {
            switch navigation.selectedTab {
            case .today:
                WorkspaceTodayView()
            case .residents:
                ResidentsPage()
            case .calendar:
                CalendarStandaloneView()
            case .quadrant:
                QuadrantStandaloneView()
            case .gantt:
                GanttStandaloneView()
            case .diary:
                DiaryStandaloneView()
            case .attachments:
                AttachmentBrowserPage()
            case .search:
                SearchPage()
            case .trash:
                TrashPage()
            case .settings:
                SettingsView(resignsChromeOnDisappear: false)
            }
        }
    }

    // MARK: - Sheets

    private var addProjectSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(newProjectParentID == nil ? "sidebar.add.project" : "sidebar.add.child")
                .font(DaybookType.body.weight(.semibold))
                .foregroundStyle(DaybookTheme.ink)
            TextField("sidebar.sheet.project.name", text: $newProjectName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("alert.cancel") {
                    newProjectName = ""
                    newProjectParentID = nil
                    isAddingProject = false
                }
                Button("drawer.tag.create") {
                    commitNewProject()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(DaybookSpacing.page)
        .frame(width: 260)
    }

    private func beginAddProject(parentID: UUID?) {
        newProjectParentID = parentID
        newProjectName = ""
        isAddingProject = true
    }

    private func commitNewProject() {
        let name = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let project = ProjectItem(
            name: name,
            sortOrder: Catalog.nextSortOrder(projects.map(\.sortOrder)),
            parentID: newProjectParentID
        )
        modelContext.insert(project)
        newProjectName = ""
        newProjectParentID = nil
        isAddingProject = false
        navigation.selectedProjectID = project.id
        BoardEvents.changed()
    }

    private var addTagSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("sidebar.add.tag")
                .font(DaybookType.body.weight(.semibold))
                .foregroundStyle(DaybookTheme.ink)
            TextField("drawer.tag.create.name", text: $newTagName)
                .textFieldStyle(.roundedBorder)
                .onChange(of: newTagName) { _, _ in tagCreateError = nil }
            if let tagCreateError {
                Text(tagCreateError)
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookTheme.destructive)
            }
            HStack {
                Spacer()
                Button("alert.cancel") {
                    newTagName = ""
                    tagCreateError = nil
                    isAddingTag = false
                }
                Button("drawer.tag.create") {
                    let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    if let tag = DayBoardMutations.resolveTaskTag(named: name, among: tags, context: modelContext) {
                        newTagName = ""
                        tagCreateError = nil
                        isAddingTag = false
                        navigation.selectedTagID = tag.id
                        BoardEvents.changed()
                    } else {
                        tagCreateError = "tag.preset.reserved"
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(DaybookSpacing.page)
        .frame(width: 260)
    }
}
