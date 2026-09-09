import SwiftData
import SwiftUI
import AppKit

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
        case .diary: return "note.text"
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
            if selectedTab != .diary {
                BoardSelection.shared.clearInspectedDiary()
            }
        }
    }

    var selectedProjectID: UUID? = nil {
        didSet {
            if selectedProjectID != nil {
                selectedTagID = nil
                BoardSelection.shared.clearInspectedDiary()
            }
            clearSelection()
        }
    }

    var selectedTagID: UUID? = nil {
        didSet {
            if selectedTagID != nil {
                selectedProjectID = nil
                BoardSelection.shared.clearInspectedDiary()
            }
            clearSelection()
        }
    }

    var selectedTaskID: UUID? = nil
    var selectedTaskIDs: Set<UUID> = []
    var isInspectorPresented: Bool = false

    func revealTab(_ tab: WorkspaceTab) {
        if tab != .diary {
            BoardSelection.shared.clearInspectedDiary()
        }
        if selectedTab != tab {
            selectedTab = tab
        } else {
            selectedProjectID = nil
            selectedTagID = nil
        }
    }

    func inspectTask(_ id: UUID) {
        selectedTaskID = id
        isInspectorPresented = true
    }

    func closeInspector() {
        isInspectorPresented = false
    }

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
                .onKeyPress(.escape) {
                    if (NSApp.keyWindow?.firstResponder as? NSTextView)?.isEditable == true {
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
                SettingsView(resignsChromeOnDisappear: false)
            }
        }
    }

    // MARK: - Sheets

    private var addProjectSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("sidebar.add.project")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DaybookTheme.ink)
            TextField("sidebar.sheet.project.name", text: $newProjectName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("alert.cancel") {
                    newProjectName = ""
                    isAddingProject = false
                }
                Button("drawer.tag.create") {
                    let name = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty {
                        let project = ProjectItem(name: name, sortOrder: projects.count)
                        modelContext.insert(project)
                        newProjectName = ""
                        isAddingProject = false
                        navigation.selectedProjectID = project.id
                        BoardEvents.changed()
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
            Text("sidebar.add.tag")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DaybookTheme.ink)
            TextField("drawer.tag.create.name", text: $newTagName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("alert.cancel") {
                    newTagName = ""
                    isAddingTag = false
                }
                Button("drawer.tag.create") {
                    let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty {
                        if let tag = DayBoardMutations.resolveTag(named: name, among: tags, context: modelContext) {
                            newTagName = ""
                            isAddingTag = false
                            navigation.selectedTagID = tag.id
                            BoardEvents.changed()
                        }
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
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]

    @Bindable private var navigation = WorkspaceNavigation.shared
    @State private var dayTick = Date()
    @State private var draftText = ""
    @FocusState private var composerFocused: Bool

    private var todayKey: String {
        _ = dayTick
        return dayClock.todayKey
    }

    private var openTodosCount: Int {
        todos.filter { $0.dayKey == todayKey && $0.deletedAt == nil && !$0.isDone }.count
    }

    private var completedTodosCount: Int {
        todos.filter { $0.dayKey == todayKey && $0.deletedAt == nil && $0.isDone }.count
    }

    private var totalTodosCount: Int {
        openTodosCount + completedTodosCount
    }

    private var progressRatio: Double {
        guard totalTodosCount > 0 else { return completedTodosCount > 0 ? 1.0 : 0.0 }
        return Double(completedTodosCount) / Double(totalTodosCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerBar

            workspaceComposer

            TasksPage(
                todayKey: todayKey,
                yesterdayKey: dayClock.yesterdayKey,
                routines: routines,
                checks: checks,
                todos: todos,
                focusedTaskID: $navigation.selectedTaskID,
                highlightedTaskID: navigation.selectedTaskID,
                onInspect: { WorkspaceNavigation.shared.inspectTask($0) },
                onReturnToInput: {
                    navigation.selectedTaskID = nil
                    composerFocused = true
                }
            )
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .frame(minWidth: 480, minHeight: 480)
        .background(DaybookTheme.paper.opacity(0.95))
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            DayClock.shared.refresh()
            dayTick = Date()
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text("workspace.today.title")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(DaybookTheme.ink)

                Text(DayKey.displayName(todayKey, locale: locale))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DaybookTheme.muted)
            }

            Spacer()

            if totalTodosCount > 0 {
                HStack(spacing: 10) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(completedTodosCount >= totalTodosCount ? "workspace.progress.done" : "workspace.progress.label")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(DaybookTheme.muted)

                        Text("\(completedTodosCount)/\(totalTodosCount)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(completedTodosCount >= totalTodosCount ? DaybookTheme.stamp : DaybookTheme.ink)
                    }

                    DaybookProgressRing(progress: progressRatio, lineWidth: 3.5, size: 36)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                        .fill(DaybookTheme.hoverFill)
                )
            }
        }
    }

    // MARK: - Workspace Composer

    private var workspaceComposer: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(composerFocused ? DaybookTheme.stamp : DaybookTheme.muted)

                DaybookTextField(
                    text: $draftText,
                    placeholder: L10n.string("workspace.composer.placeholder", locale: locale),
                    focus: $composerFocused,
                    onSubmit: addTodo,
                    onCommandReturn: {}
                )

                if !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: addTodo) {
                        Image(systemName: "return")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(DaybookTheme.stamp)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                                    .fill(DaybookTheme.stamp.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("workspace.composer.help")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .fill(composerFocused ? DaybookTheme.surface : DaybookTheme.hoverFill.opacity(0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .stroke(composerFocused ? DaybookTheme.focusRing : DaybookTheme.cardBorder, lineWidth: composerFocused ? 1.4 : 0.8)
            )

            parsedTokensBar
        }
    }

    private var parsedTokensBar: some View {
        let parsed = NaturalLanguageParser.parse(draftText)
        return Group {
            if parsed.hasTokens && !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing: 6) {
                    if let time = parsed.timeLabel {
                        PillBadge(title: L10n.format("workspace.remind.suffix", locale: locale, time), icon: "clock.fill", color: DaybookTheme.stamp, isSelected: true)
                    }
                    if let tag = parsed.tagName {
                        PillBadge(title: "#\(tag)", icon: "tag.fill", color: Color.daybook(light: NSColor.systemIndigo, dark: NSColor.systemIndigo), isSelected: true)
                    }
                    if let priority = parsed.priorityLabel {
                        PillBadge(
                            title: L10n.string(String.LocalizationValue(stringLiteral: priority), locale: locale),
                            icon: "exclamationmark.circle.fill",
                            color: parsed.isImportant && parsed.isUrgent ? DaybookTheme.destructive : DaybookTheme.stamp,
                            isSelected: true
                        )
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 4)
                .padding(.top, 1)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func addTodo() {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let parsed = NaturalLanguageParser.parse(text)
        let todo = TodoItem(
            title: parsed.cleanTitle,
            dayKey: todayKey,
            remindMinutes: parsed.remindMinutes,
            isImportant: parsed.isImportant,
            isUrgent: parsed.isUrgent,
            sourceBundleID: CaptureStamp.current(enabled: AppPreferences.shared.stampCaptureApp),
            notes: parsed.notes
        )
        if let tagName = parsed.tagName,
           let tag = DayBoardMutations.resolveTag(named: tagName, among: tags, context: modelContext)
        {
            todo.tagIDs = TagIDList.toggling(todo.tagIDs, tag.id)
        }
        modelContext.insert(todo)
        draftText = ""
        BoardEvents.changed()
        DayBoardMutations.requestReminderAccessIfNeeded(parsed.remindMinutes)
    }
}
