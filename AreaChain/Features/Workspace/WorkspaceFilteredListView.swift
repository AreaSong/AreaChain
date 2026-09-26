import AppKit
import SwiftData
import SwiftUI

struct WorkspaceFilteredListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var tag: TagItem

    @Query private var todos: [TodoItem]
    @Query private var routines: [DailyRoutine]
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]
    @Query private var attachments: [AttachmentItem]
    @Query private var checks: [RoutineCheck]

    @Bindable private var navigation = WorkspaceNavigation.shared
    @State private var draftTitle = ""
    @State private var showCompleted = false
    @State private var pendingTrash: PendingTrash?

    var body: some View {
        DaybookPage(
            titleText: tag.name,
            titleStyle: .entity,
            systemImage: "number",
            minWidth: 480,
            minHeight: 480
        ) {
            headerTrailing
        } content: {
            DaybookComposer(
                text: $draftTitle,
                placeholder: "filtered.add.tag",
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
            tag: tag,
            dayKey: DayClock.shared.todayKey
        )
    }

    private func addTask() {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let todayKey = DayClock.shared.todayKey
        guard DayBoardMutations.addCapturedTodo(
            text: title, dayKey: todayKey, context: modelContext,
            tagIDs: [tag.id]
        ) else { return }
        draftTitle = ""
    }

    // MARK: - Task List

    private var taskList: some View {
        let openRows = mixedRows(open: true)
        let doneRows = mixedRows(open: false)
        return ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if openRows.isEmpty && doneRows.isEmpty && matchingSubtasks.isEmpty {
                    DaybookEmptyState(
                        title: "empty.filtered.todos",
                        systemImage: "tag"
                    )
                    .padding(.top, 40)
                } else {
                    taggedOpenRows(openRows)
                    completedSection(doneRows)
                    subtaskSection
                }
            }
            .padding(.vertical, 2)
        }
        .daybookScroll()
    }

    @ViewBuilder
    private func taggedOpenRows(_ rows: [BoardRow]) -> some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(rows, id: \.listID, content: taggedRow)
            }
        }
    }

    @ViewBuilder
    private func taggedRow(_ row: BoardRow) -> some View {
        switch row {
        case .todo(let todo):
            todoRowView(todo, isDone: todo.isDone)
        case .resident(let routine):
            routineRowView(routine)
        }
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
    private func completedSection(_ doneRows: [BoardRow]) -> some View {
        if !doneRows.isEmpty {
            Button {
                withAnimation(DaybookMotion.animation(reduceMotion)) {
                    showCompleted.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: showCompleted ? "chevron.down" : "chevron.right")
                        .font(DaybookType.micro.weight(.bold))
                        .foregroundStyle(DaybookPalette.text.secondary)
                    Text("stamp.completed \(doneRows.count)")
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
                    ForEach(doneRows, id: \.listID, content: taggedRow)
                }
            }
        }
    }

    private var catalogContext: TaskCatalogContext {
        TaskCatalogContext(
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
        let snapshot = routine.snapshot
        let checkSnapshots = checks.compactMap(\.snapshot)
        let dueToday = DayBoardLogic.isRoutineDue(snapshot, on: todayKey)
        let isDone = DayBoardLogic.isRoutineDone(snapshot, checks: checkSnapshots, on: todayKey)
        let schedule = RoutineScheduleContext(
            todayKey: todayKey,
            checkDayKey: todayKey,
            checks: checks,
            locale: locale
        )
        let display = RoutineRowDisplayOptions(
            isDone: isDone,
            isSelected: isRowSelected(routine.id),
            allowsCompletion: dueToday
        )
        let actions = RoutineRowActions(
            onSelect: { selectRow(routine.id, modifiers: $0) },
            onDelete: {
                pendingTrash = PendingTrash(title: routine.title) {
                    DayBoardMutations.trashRoutine(routine)
                }
            },
            onSkip: dueToday && !isDone ? {
                DayBoardMutations.skipRoutine(routine, on: todayKey, checks: checks, context: modelContext)
            } : nil
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
        Catalog.matchingTodos(todos, tag: tag)
    }

    private var matchingSubtasks: [SubtaskItem] {
        Catalog.matchingSubtasks(todos, tag: tag)
    }

    private func mixedRows(open: Bool) -> [BoardRow] {
        let todos = matchingTodos.filter { open ? !$0.isDone : $0.isDone }
        let listedRoutines = Catalog.matchingListedRoutines(
            routines,
            checks: checks,
            tag: tag,
            dayKey: DayClock.shared.todayKey,
            open: open
        )
        let rows = todos.map(BoardRow.todo) + listedRoutines.map(BoardRow.resident)
        return rows.sorted { Classification.precedes($0.boardSortKey, $1.boardSortKey) }
    }

    private var orderedVisibleIDs: [UUID] {
        mixedRows(open: true).map(\.id)
            + (showCompleted ? mixedRows(open: false).map(\.id) : [])
    }

    private var canBatchSelect: Bool {
        !orderedVisibleIDs.isEmpty
    }
}
