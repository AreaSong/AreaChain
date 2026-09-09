import SwiftData
import SwiftUI

enum WorkspaceTab: String, CaseIterable, Identifiable {
    case today
    case calendar
    case quadrant
    case gantt
    case diary
    case attachments
    case search
    case trash
    case settings

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .today: return "tab.tasks"
        case .calendar: return "window.calendar"
        case .quadrant: return "window.quadrant"
        case .gantt: return "window.gantt"
        case .diary: return "window.diary"
        case .attachments: return "window.attachments"
        case .search: return "window.search"
        case .trash: return "window.trash"
        case .settings: return "window.settings"
        }
    }

    var iconName: String {
        switch self {
        case .today: return "checklist"
        case .calendar: return "calendar"
        case .quadrant: return "square.grid.2x2"
        case .gantt: return "chart.bar.xaxis"
        case .diary: return "book.closed"
        case .attachments: return "paperclip"
        case .search: return "magnifyingglass"
        case .trash: return "trash"
        case .settings: return "gearshape"
        }
    }
}

@Observable
@MainActor
final class WorkspaceNavigation {
    static let shared = WorkspaceNavigation()

    var selectedTab: WorkspaceTab = .today {
        didSet {
            selectedProjectID = nil
            selectedTagID = nil
            clearSelection()
        }
    }

    var selectedProjectID: UUID? = nil {
        didSet {
            if selectedProjectID != nil {
                selectedTagID = nil
            }
            clearSelection()
        }
    }

    var selectedTagID: UUID? = nil {
        didSet {
            if selectedTagID != nil {
                selectedProjectID = nil
            }
            clearSelection()
        }
    }

    var selectedTaskID: UUID? = nil
    var selectedTaskIDs: Set<UUID> = []
    var isInspectorPresented: Bool = false

    func toggleSelection(_ id: UUID) {
        if selectedTaskIDs.contains(id) {
            selectedTaskIDs.remove(id)
        } else {
            selectedTaskIDs.insert(id)
        }
    }

    func clearSelection() {
        selectedTaskIDs.removeAll()
    }
}

/// 现代 Pro 风格三栏大屏工作台
struct MainSplitWorkspaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable private var navigation = WorkspaceNavigation.shared

    @Query(sort: \ProjectItem.sortOrder) private var projects: [ProjectItem]
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    @Query private var todos: [TodoItem]

    @State private var isAddingProject = false
    @State private var newProjectName = ""
    @State private var isAddingTag = false
    @State private var newTagName = ""

    var body: some View {
        NavigationSplitView {
            WorkspaceSidebarView(
                navigation: navigation,
                projects: projects,
                tags: tags,
                todos: todos,
                onAddProject: { isAddingProject = true },
                onAddTag: { isAddingTag = true }
            )
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottom) {
                    if !navigation.selectedTaskIDs.isEmpty {
                        WorkspaceBatchActionBar(
                            navigation: navigation,
                            todos: todos,
                            projects: projects,
                            tags: tags
                        )
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
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
                .help("显示/隐藏检查器")
            }
        }
        .navigationTitle("AreaChain")
        .sheet(isPresented: $isAddingProject) {
            addProjectSheet
        }
        .sheet(isPresented: $isAddingTag) {
            addTagSheet
        }
        .onChange(of: navigation.selectedTaskID) { _, newValue in
            if newValue != nil {
                navigation.isInspectorPresented = true
            }
        }
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
                SettingsView()
            }
        }
    }

    // MARK: - Sheets

    private var addProjectSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("新建项目")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DaybookTheme.ink)
            TextField("项目名称", text: $newProjectName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("取消") {
                    newProjectName = ""
                    isAddingProject = false
                }
                Button("创建") {
                    let name = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty {
                        let project = ProjectItem(name: name, sortOrder: projects.count)
                        modelContext.insert(project)
                        newProjectName = ""
                        isAddingProject = false
                        navigation.selectedProjectID = project.id
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 260)
    }

    private var addTagSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("新建标签")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DaybookTheme.ink)
            TextField("标签名称", text: $newTagName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("取消") {
                    newTagName = ""
                    isAddingTag = false
                }
                Button("创建") {
                    let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty {
                        let tag = TagItem(name: name, sortOrder: tags.count)
                        modelContext.insert(tag)
                        newTagName = ""
                        isAddingTag = false
                        navigation.selectedTagID = tag.id
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 260)
    }
}

// MARK: - Workspace Today View

struct WorkspaceTodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    private var dayClock: DayClock { DayClock.shared }

    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query(sort: \TodoItem.createdAt) private var todos: [TodoItem]
    @Query private var checks: [RoutineCheck]

    @Bindable private var navigation = WorkspaceNavigation.shared
    @State private var dayTick = Date()
    @State private var capture = CaptureSession.shared
    @FocusState private var captureFocused: Bool

    var body: some View {
        let todayKey: String = {
            _ = dayTick
            return dayClock.todayKey
        }()

        VStack(alignment: .leading, spacing: 12) {
            Text(DayKey.displayName(todayKey, locale: locale))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(DaybookTheme.ink)

            CaptureField(
                text: $capture.draft,
                focus: $captureFocused,
                onTodo: addTodo,
                onDiary: addDiary
            )

            TasksPage(
                todayKey: todayKey,
                yesterdayKey: dayClock.yesterdayKey,
                routines: routines,
                checks: checks,
                todos: todos,
                focusedTaskID: $navigation.selectedTaskID,
                onReturnToInput: {
                    navigation.selectedTaskID = nil
                    captureFocused = true
                }
            )
        }
        .daybookPanel(minWidth: 480, minHeight: 480)
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            DayClock.shared.refresh()
            dayTick = Date()
        }
    }

    private func addTodo() {
        let text = capture.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let parsed = NaturalLanguageParser.parse(text)
        let todayKey = dayClock.todayKey
        let todo = TodoItem(
            title: parsed.cleanTitle,
            dayKey: todayKey,
            remindMinutes: parsed.remindMinutes,
            isImportant: parsed.isImportant,
            isUrgent: parsed.isUrgent,
            sourceBundleID: CaptureStamp.current(enabled: AppPreferences.shared.stampCaptureApp),
            notes: parsed.notes
        )
        if let tagName = parsed.tagName {
            let tagDescriptor = FetchDescriptor<TagItem>(predicate: #Predicate { $0.name == tagName && $0.deletedAt == nil })
            if let existingTag = try? modelContext.fetch(tagDescriptor).first {
                todo.tagIDs = TagIDList.toggling(todo.tagIDs, existingTag.id)
            } else {
                let newTag = TagItem(name: tagName, sortOrder: 0)
                modelContext.insert(newTag)
                todo.tagIDs = TagIDList.toggling(todo.tagIDs, newTag.id)
            }
        }
        modelContext.insert(todo)
        capture.draft = ""
        BoardEvents.changed()
    }

    private func addDiary() {
        let text = capture.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        modelContext.insert(DiaryEntry(text: text, dayKey: dayClock.todayKey))
        capture.draft = ""
        BoardEvents.changed()
    }
}
