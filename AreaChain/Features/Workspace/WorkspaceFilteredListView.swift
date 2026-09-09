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
        VStack(alignment: .leading, spacing: 12) {
            headerBar
            quickInput
            taskList
        }
        .daybookPanel(minWidth: 480, minHeight: 480)
        .confirmMoveToTrash($pendingTrash)
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 8) {
            if let project {
                Image(systemName: "folder.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(DaybookTheme.stamp)
                Text(project.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DaybookTheme.ink)
            } else if let tag {
                Image(systemName: "number")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DaybookTheme.stamp)
                Text(tag.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DaybookTheme.ink)
            }
            Spacer()
            let openCount = Catalog.openCount(
                todos: todos,
                routines: routines,
                checks: checks,
                project: project,
                tag: tag,
                projects: projects,
                dayKey: DayClock.shared.todayKey
            )
            Text("filter.open.count \(openCount)")
                .font(.system(size: 11, weight: .medium))
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
                        .font(.system(size: 12))
                        .foregroundStyle(navigation.selectedTaskIDs.isEmpty ? DaybookTheme.muted : DaybookTheme.stamp)
                }
                .buttonStyle(.plain)
                .help(navigation.selectedTaskIDs.isEmpty ? "batch.select.all" : "batch.exit")
            }
        }
    }

    // MARK: - Quick Input

    private var quickInput: some View {
        HStack(spacing: 8) {
            TextField(project != nil ? "filtered.add.project" : "filtered.add.tag", text: $draftTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(DaybookTheme.cardSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(DaybookTheme.rule.opacity(0.3), lineWidth: 0.8)
                        )
                )
                .onSubmit(addTask)

            Button(action: addTask) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DaybookTheme.stamp)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(DaybookTheme.cardSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(DaybookTheme.rule.opacity(0.3), lineWidth: 0.8)
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
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

    private func todoRowView(_ todo: TodoItem, isDone: Bool) -> some View {
        let isBatchSelected = navigation.selectedTaskIDs.contains(todo.id)
        return TaskRow(
            title: todo.title,
            isDone: isDone,
            remindMinutes: todo.remindMinutes,
            todayKey: DayClock.shared.todayKey,
            currentDayKey: todo.dayKey,
            onToggle: { DayBoardMutations.toggleTodo(todo) },
            onDelete: {
                pendingTrash = PendingTrash(title: todo.title) {
                    DayBoardMutations.trashTodo(todo)
                }
            },
            onEdit: { DayBoardMutations.editTodo(todo, title: $0) },
            onMoveToDay: { DayBoardMutations.moveTodo(todo, to: $0) },
            onRemindMinutes: { DayBoardMutations.setRemind(todo, minutes: $0) },
            classify: CatalogChoices.classify(for: todo, projects: projects, tags: tags),
            attachments: CatalogChoices.attachments(
                ownerKind: .todo,
                ownerID: todo.id,
                items: attachments,
                context: modelContext
            ),
            notes: todo.notes,
            subtasks: todo.subtasks
                .filter { $0.deletedAt == nil }
                .sorted(by: { $0.sortOrder < $1.sortOrder })
                .compactMap { $0.snapshot },
            onToggleSubtask: { subID in
                if let sub = todo.subtasks.first(where: { $0.id == subID }) {
                    DayBoardMutations.toggleSubtask(sub)
                }
            },
            isSelected: isBatchSelected || (navigation.selectedTaskIDs.isEmpty && navigation.selectedTaskID == todo.id),
            onSelect: {
                selectRow(todo.id)
            }
        )
    }

    private func routineRowView(_ routine: DailyRoutine) -> some View {
        let todayKey = DayClock.shared.todayKey
        let isDone = DayBoardLogic.isRoutineDone(
            routine.snapshot,
            checks: checks.compactMap(\.snapshot),
            on: todayKey
        )
        let skipped = DayBoardLogic.isRoutineSkipped(
            routine.snapshot,
            checks: checks.compactMap(\.snapshot),
            on: todayKey
        )
        let streak = HabitStreakLogic.calculate(
            routine: routine.snapshot,
            checks: checks.compactMap(\.snapshot),
            todayKey: todayKey
        )
        let isBatchSelected = navigation.selectedTaskIDs.contains(routine.id)
        return TaskRow(
            title: routine.title,
            isDone: isDone,
            isResident: true,
            note: isDone
                ? ResidentNote.done(routine, skipped: skipped, locale: locale)
                : ResidentNote.days(routine, locale: locale),
            streak: streak.currentStreak,
            remindMinutes: routine.remindMinutes,
            onToggle: {
                DayBoardMutations.toggleRoutine(routine, on: todayKey, checks: checks, context: modelContext)
            },
            onDelete: {
                pendingTrash = PendingTrash(title: routine.title) {
                    DayBoardMutations.trashRoutine(routine)
                }
            },
            onEdit: { DayBoardMutations.editRoutine(routine, title: $0) },
            onSkip: isDone ? nil : {
                DayBoardMutations.skipRoutine(routine, on: todayKey, checks: checks, context: modelContext)
            },
            onRemindMinutes: { DayBoardMutations.setRemind(routine, minutes: $0) },
            onDisable: {
                DayBoardMutations.setRoutineEnabled(
                    routine,
                    enabled: false,
                    todayKey: todayKey,
                    checks: checks,
                    context: modelContext
                )
            },
            onEnable: {
                DayBoardMutations.setRoutineEnabled(
                    routine,
                    enabled: true,
                    todayKey: todayKey,
                    checks: checks,
                    context: modelContext
                )
            },
            isImportant: routine.isImportant,
            isUrgent: routine.isUrgent,
            classify: CatalogChoices.classify(for: routine, projects: projects, tags: tags),
            attachments: CatalogChoices.attachments(
                ownerKind: .routine,
                ownerID: routine.id,
                items: attachments,
                context: modelContext
            ),
            notes: routine.notes,
            isSelected: isBatchSelected || (navigation.selectedTaskIDs.isEmpty && navigation.selectedTaskID == routine.id),
            onSelect: { selectRow(routine.id) },
            isEnabled: routine.isEnabled
        )
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
