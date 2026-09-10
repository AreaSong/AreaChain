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
    }

    private var headerTrailing: some View {
        HStack(spacing: 8) {
            Text("filter.open.count \(openCount)")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookTheme.muted)

            if canBatchSelect {
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        if navigation.selectedTaskIDs.isEmpty {
                            navigation.selectedTaskIDs = selectableIDs
                        } else {
                            navigation.clearSelection()
                        }
                    }
                } label: {
                    Image(systemName: navigation.selectedTaskIDs.isEmpty ? "checklist" : "checklist.checked")
                        .font(DaybookType.subtitle)
                        .foregroundStyle(navigation.selectedTaskIDs.isEmpty ? DaybookTheme.muted : DaybookTheme.stamp)
                }
                .buttonStyle(.plain)
                .help(navigation.selectedTaskIDs.isEmpty ? "batch.select.all" : "batch.exit")
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
        let todo = TodoItem(
            title: title,
            dayKey: todayKey,
            projectID: project?.id,
            tagIDs: tag.map { $0.id.uuidString } ?? "",
            sourceBundleID: CaptureStamp.current(enabled: AppPreferences.shared.stampCaptureApp)
        )
        modelContext.insert(todo)
        draftTitle = ""
        BoardEvents.changed()
    }

    // MARK: - Task List

    private var taskList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                let openTodos = matchingTodos.filter { !$0.isDone }
                let doneTodos = matchingTodos.filter { $0.isDone }
                let listedRoutines = matchingRoutines

                if openTodos.isEmpty && doneTodos.isEmpty && listedRoutines.isEmpty {
                    DaybookEmptyState(
                        title: "empty.filtered.todos",
                        systemImage: project != nil ? "folder" : "tag"
                    )
                    .padding(.top, 40)
                } else {
                    ForEach(openTodos) { todo in
                        todoRowView(todo, isDone: false)
                    }
                    if !listedRoutines.isEmpty {
                        SectionStamp(title: "stamp.routines", icon: "repeat", count: listedRoutines.count)
                            .padding(.top, openTodos.isEmpty ? 0 : 8)
                        ForEach(listedRoutines) { routine in
                            routineRowView(routine)
                        }
                    }
                    completedSection(doneTodos)
                }
            }
            .padding(.vertical, 2)
        }
        .daybookScroll()
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
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(DaybookTheme.muted)
                    Text("stamp.completed \(doneTodos.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DaybookTheme.muted)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)

            if showCompleted {
                ForEach(doneTodos) { todo in
                    todoRowView(todo, isDone: true)
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
            onSelect: { selectRow(todo.id) },
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
            onSelect: { selectRow(routine.id) },
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

    private func selectRow(_ id: UUID) {
        if NSEvent.modifierFlags.contains(.command) || !navigation.selectedTaskIDs.isEmpty {
            withAnimation(.snappy(duration: 0.2)) {
                navigation.toggleSelection(id)
            }
        } else {
            navigation.inspectTask(id)
        }
    }

    private var matchingTodos: [TodoItem] {
        Catalog.matchingTodos(todos, project: project, tag: tag, projects: projects)
    }

    private var matchingRoutines: [DailyRoutine] {
        Catalog.matchingRoutines(routines, project: project, tag: tag, projects: projects)
    }

    private var selectableIDs: Set<UUID> {
        Set(matchingTodos.filter { !$0.isDone }.map(\.id) + matchingRoutines.map(\.id))
    }

    private var canBatchSelect: Bool {
        !selectableIDs.isEmpty
    }
}
