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
        let model = makeListModel()
        DaybookPage(
            titleText: tag.name,
            titleStyle: .entity,
            systemImage: "number",
            minWidth: 480,
            minHeight: 480
        ) {
            headerTrailing(model)
        } content: {
            DaybookComposer(
                text: $draftTitle,
                placeholder: "filtered.add.tag",
                onSubmit: addTask
            )
            taskList(model)
        }
        .confirmMoveToTrash($pendingTrash)
        .onChange(of: model.orderedVisibleIDs) { _, ids in
            navigation.reconcileTaskSelection(with: ids)
        }
    }

    private func makeListModel() -> WorkspaceFilteredListModel {
        WorkspaceFilteredListModel.make(
            tag: tag,
            todos: todos,
            routines: routines,
            checks: checks,
            catalogs: TaskCatalogContext(tags: tags, attachments: attachments, context: modelContext),
            locale: locale,
            showCompleted: showCompleted
        )
    }

    private func headerTrailing(_ model: WorkspaceFilteredListModel) -> some View {
        HStack(spacing: 8) {
            Text("filter.open.count \(model.openCount)")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)

            if model.canBatchSelect {
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        if navigation.selectedTaskIDs.isEmpty {
                            navigation.selectAllTasks(in: model.orderedVisibleIDs)
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

    private func taskList(_ model: WorkspaceFilteredListModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if model.isEmpty {
                    DaybookEmptyState(
                        title: "empty.filtered.todos",
                        systemImage: "tag"
                    )
                    .padding(.top, 40)
                } else {
                    taggedOpenRows(model.openRows, model: model)
                    completedSection(model.doneRows, model: model)
                    subtaskSection(model)
                }
            }
            .padding(.vertical, 2)
        }
        .daybookScroll()
    }

    @ViewBuilder
    private func taggedOpenRows(_ rows: [BoardRow], model: WorkspaceFilteredListModel) -> some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(rows, id: \.listID) { row in
                    taggedRow(row, model: model)
                }
            }
        }
    }

    @ViewBuilder
    private func taggedRow(_ row: BoardRow, model: WorkspaceFilteredListModel) -> some View {
        switch row {
        case .todo(let todo):
            todoRowView(todo, isDone: todo.isDone, model: model)
        case .resident(let routine):
            routineRowView(routine, model: model)
        }
    }

    @ViewBuilder
    private func subtaskSection(_ model: WorkspaceFilteredListModel) -> some View {
        if !model.matchingSubtasks.isEmpty {
            DaybookSectionHeader(title: "drawer.subtasks.title", icon: "checklist", count: model.matchingSubtasks.count)
                .padding(.top, 8)
            ForEach(model.matchingSubtasks) { subtask in
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
    private func completedSection(_ doneRows: [BoardRow], model: WorkspaceFilteredListModel) -> some View {
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
                    ForEach(doneRows, id: \.listID) { row in
                        taggedRow(row, model: model)
                    }
                }
            }
        }
    }

    private func isRowSelected(_ id: UUID) -> Bool {
        navigation.selectedTaskIDs.contains(id) ||
            (navigation.selectedTaskIDs.isEmpty && navigation.selectedTaskID == id)
    }

    private func todoRowView(_ todo: TodoItem, isDone: Bool, model: WorkspaceFilteredListModel) -> some View {
        let display = TodoRowDisplayOptions(
            isDone: isDone,
            isSelected: isRowSelected(todo.id)
        )
        let actions = TodoRowActions(
            onSelect: { selectRow(todo.id, modifiers: $0, visibleIDs: model.orderedVisibleIDs) },
            onDelete: {
                pendingTrash = PendingTrash(title: todo.title) {
                    DayBoardMutations.trashTodo(todo)
                }
            }
        )
        return TaskRowFactory.todo(TodoRowContext(
            todo: todo,
            todayKey: model.todayKey,
            catalogs: model.catalogs,
            display: display,
            actions: actions
        ))
    }

    private func routineRowView(_ routine: DailyRoutine, model: WorkspaceFilteredListModel) -> some View {
        let snapshot = routine.snapshot
        let dueToday = DayBoardLogic.isRoutineDue(snapshot, on: model.todayKey)
        let isDone = model.checkIndex.isClosed(routineId: routine.id, dayKey: model.todayKey)
        let schedule = RoutineScheduleContext(
            todayKey: model.todayKey,
            checkDayKey: model.todayKey,
            checks: model.checks,
            locale: model.locale,
            lookups: model.routineLookups(for: routine.id)
        )
        let display = RoutineRowDisplayOptions(
            isDone: isDone,
            isSelected: isRowSelected(routine.id),
            allowsCompletion: dueToday
        )
        let actions = RoutineRowActions(
            onSelect: { selectRow(routine.id, modifiers: $0, visibleIDs: model.orderedVisibleIDs) },
            onDelete: {
                pendingTrash = PendingTrash(title: routine.title) {
                    DayBoardMutations.trashRoutine(routine)
                }
            },
            onSkip: dueToday && !isDone ? {
                DayBoardMutations.skipRoutine(routine, on: model.todayKey, checks: model.checks, context: modelContext)
            } : nil
        )
        return TaskRowFactory.routine(RoutineRowContext(
            routine: routine,
            schedule: schedule,
            catalogs: model.catalogs,
            display: display,
            actions: actions
        ))
    }

    private func selectRow(_ id: UUID, modifiers: TaskSelectionModifiers, visibleIDs: [UUID]) {
        navigation.selectTask(id, in: visibleIDs, modifiers: modifiers)
    }
}
