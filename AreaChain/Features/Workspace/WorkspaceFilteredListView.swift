import AppKit
import SwiftData
import SwiftUI

struct WorkspaceFilteredListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var project: ProjectItem?
    var tag: TagItem?

    @Query private var todos: [TodoItem]
    @Query private var routines: [DailyRoutine]
    @Query(sort: \ProjectItem.sortOrder) private var projects: [ProjectItem]
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    @Query private var attachments: [AttachmentItem]
    @Query private var checks: [RoutineCheck]

    @Bindable private var navigation = WorkspaceNavigation.shared
    @State private var draftTitle = ""
    @State private var showCompleted = false
    @State private var pendingTrash: PendingTrash?

    var body: some View {
        DaybookPage(
            titleText: project?.name ?? tag?.name,
            titleStyle: .entity,
            systemImage: project != nil ? "folder.fill" : "number",
            minWidth: 480,
            minHeight: 480
        ) {
            headerTrailing
        } content: {
            DaybookComposer(
                text: $draftTitle,
                placeholder: project != nil ? "filtered.add.project" : "filtered.add.tag",
                onSubmit: addTask
            )
            taskList
        }
        .confirmMoveToTrash($pendingTrash)
        .onChange(of: orderedVisibleIDs) { _, ids in
            navigation.reconcileTaskSelection(with: ids)
        }
    }

    private var headerTrailing: some View {
        HStack(spacing: 8) {
            Text("filter.open.count \(openCount)")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)

            if canBatchSelect {
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        if navigation.selectedTaskIDs.isEmpty {
                            navigation.selectAllTasks(in: orderedVisibleIDs)
                        } else {
                            navigation.clearSelection()
                        }
                    }
                } label: {
                    Image(systemName: navigation.selectedTaskIDs.isEmpty ? "checklist" : "checklist.checked")
                }
                .buttonStyle(DaybookButtonStyle(navigation.selectedTaskIDs.isEmpty ? .icon : .iconActive, size: .compact))
                .help(navigation.selectedTaskIDs.isEmpty ? "batch.select.all" : "batch.exit")
                .accessibilityLabel(navigation.selectedTaskIDs.isEmpty ? "batch.select.all" : "batch.exit")
            }
        }
    }

    private var openCount: Int {
        Catalog.openCount(
            todos: todos,
            routines: routines,
            checks: checks,
            project: project,
            tag: tag,
            projects: projects,
            dayKey: DayClock.shared.todayKey
        )
    }

    private func addTask() {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let todayKey = DayClock.shared.todayKey
        guard DayBoardMutations.addCapturedTodo(
            text: title, dayKey: todayKey, context: modelContext,
            projectID: project?.id, tagIDs: tag.map { [$0.id] } ?? []
        ) else { return }
        draftTitle = ""
    }

    // MARK: - Task List

    private var taskList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                let openTodos = matchingTodos.filter { !$0.isDone }
                let doneTodos = matchingTodos.filter { $0.isDone }
                let listedRoutines = matchingRoutines

                if openTodos.isEmpty && doneTodos.isEmpty && listedRoutines.isEmpty && matchingSubtasks.isEmpty {
                    DaybookEmptyState(
                        title: "empty.filtered.todos",
                        systemImage: project != nil ? "folder" : "tag"
                    )
                    .padding(.top, 40)
                } else {
                    if !openTodos.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(openTodos) { todo in
                                todoRowView(todo, isDone: false)
                            }
                        }
                    }
                    if !listedRoutines.isEmpty {
                        DaybookSectionHeader(title: "stamp.routines", icon: "repeat", count: listedRoutines.count)
                            .padding(.top, openTodos.isEmpty ? 0 : 8)
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(listedRoutines) { routine in
                                routineRowView(routine)
                            }
                        }
                    }
                    completedSection(doneTodos)
                    subtaskSection
                }
            }
            .padding(.vertical, 2)
        }
        .daybookScroll()
    }

    @ViewBuilder
    private var subtaskSection: some View {
        if !matchingSubtasks.isEmpty {
            DaybookSectionHeader(title: "drawer.subtasks.title", icon: "checklist", count: matchingSubtasks.count)
                .padding(.top, 8)
            ForEach(matchingSubtasks) { subtask in
                VStack(alignment: .leading, spacing: 3) {
                    if let parent = subtask.todo {
                        Button(parent.title) { navigation.inspectTask(parent.id) }
                            .buttonStyle(DaybookButtonStyle(.subtle, size: .compact))
                    }
                    SubtaskRowView(
                        subtask: subtask, onToggle: { DayBoardMutations.toggleSubtask(subtask) },
                        onUpdateTitle: { DayBoardMutations.editSubtask(subtask, title: $0) },
                        onDelete: { DayBoardMutations.deleteSubtask(subtask) }
                    )
                }
                .padding(6)
            }
        }
    }

    @ViewBuilder
    private func completedSection(_ doneTodos: [TodoItem]) -> some View {
        if !doneTodos.isEmpty {
            Button {
                withAnimation(DaybookMotion.animation(reduceMotion)) {
                    showCompleted.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: showCompleted ? "chevron.down" : "chevron.right")
                        .font(DaybookType.micro.weight(.bold))
                        .foregroundStyle(DaybookPalette.text.secondary)
                    Text("stamp.completed \(doneTodos.count)")
                        .font(DaybookType.caption.weight(.medium))
                        .foregroundStyle(DaybookPalette.text.secondary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain) // control: 已完成折叠头，整行点击
            .padding(.top, 8)

            if showCompleted {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(doneTodos) { todo in
                        todoRowView(todo, isDone: true)
                    }
                }
            }
        }
    }

    private var catalogContext: TaskCatalogContext {
        TaskCatalogContext(
            projects: projects,
            tags: tags,
            attachments: attachments,
            context: modelContext
        )
    }

    private func isRowSelected(_ id: UUID) -> Bool {
        navigation.selectedTaskIDs.contains(id) ||
            (navigation.selectedTaskIDs.isEmpty && navigation.selectedTaskID == id)
    }

    private func todoRowView(_ todo: TodoItem, isDone: Bool) -> some View {
        let display = TodoRowDisplayOptions(
            isDone: isDone,
            isSelected: isRowSelected(todo.id)
        )
        let actions = TodoRowActions(
            onSelect: { selectRow(todo.id, modifiers: $0) },
            onDelete: {
                pendingTrash = PendingTrash(title: todo.title) {
                    DayBoardMutations.trashTodo(todo)
                }
            }
        )
        return TaskRowFactory.todo(TodoRowContext(
            todo: todo,
            todayKey: DayClock.shared.todayKey,
            catalogs: catalogContext,
            display: display,
            actions: actions
        ))
    }

    private func routineRowView(_ routine: DailyRoutine) -> some View {
        let todayKey = DayClock.shared.todayKey
        let isDone = DayBoardLogic.isRoutineDone(
            routine.snapshot,
            checks: checks.compactMap(\.snapshot),
            on: todayKey
        )
        let schedule = RoutineScheduleContext(
            todayKey: todayKey,
            checkDayKey: todayKey,
            checks: checks,
            locale: locale
        )
        let display = RoutineRowDisplayOptions(
            isDone: isDone,
            isSelected: isRowSelected(routine.id)
        )
        let actions = RoutineRowActions(
            onSelect: { selectRow(routine.id, modifiers: $0) },
            onDelete: {
                pendingTrash = PendingTrash(title: routine.title) {
                    DayBoardMutations.trashRoutine(routine)
                }
            },
            onSkip: isDone ? nil : {
                DayBoardMutations.skipRoutine(routine, on: todayKey, checks: checks, context: modelContext)
            }
        )
        return TaskRowFactory.routine(RoutineRowContext(
            routine: routine,
            schedule: schedule,
            catalogs: catalogContext,
            display: display,
            actions: actions
        ))
    }

    private func selectRow(_ id: UUID, modifiers: TaskSelectionModifiers) {
        navigation.selectTask(id, in: orderedVisibleIDs, modifiers: modifiers)
    }

    private var matchingTodos: [TodoItem] {
        Catalog.matchingTodos(todos, project: project, tag: tag, projects: projects)
    }

    private var matchingRoutines: [DailyRoutine] {
        Catalog.matchingRoutines(routines, project: project, tag: tag, projects: projects)
    }

    private var matchingSubtasks: [SubtaskItem] {
        project == nil ? Catalog.matchingSubtasks(todos, tag: tag) : []
    }

    private var orderedVisibleIDs: [UUID] {
        let listedTodos = matchingTodos
        return listedTodos.filter { !$0.isDone }.map(\.id)
            + matchingRoutines.map(\.id)
            + (showCompleted ? listedTodos.filter(\.isDone).map(\.id) : [])
    }

    private var canBatchSelect: Bool {
        !orderedVisibleIDs.isEmpty
    }
}
