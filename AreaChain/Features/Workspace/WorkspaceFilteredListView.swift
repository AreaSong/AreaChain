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
            let count = matchingTodos.filter { !$0.isDone }.count
            Text("\(count) 项待办")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DaybookTheme.muted)
        }
    }

    // MARK: - Quick Input

    private var quickInput: some View {
        HStack(spacing: 8) {
            TextField(project != nil ? "添加任务到此项目..." : "添加带此标签的任务...", text: $draftTitle)
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
            tagIDs: tag.map { $0.id.uuidString } ?? ""
        )
        modelContext.insert(todo)
        draftTitle = ""
        BoardEvents.changed()
    }

    // MARK: - Task List

    private var taskList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                let openItems = matchingTodos.filter { !$0.isDone }
                let doneItems = matchingTodos.filter { $0.isDone }

                if openItems.isEmpty && doneItems.isEmpty {
                    DaybookEmptyState(
                        title: "暂无相关任务",
                        systemImage: project != nil ? "folder" : "tag"
                    )
                    .padding(.top, 40)
                } else {
                    ForEach(openItems) { todo in
                        todoRowView(todo, isDone: false)
                    }

                    if !doneItems.isEmpty {
                        Button {
                            withAnimation(DaybookMotion.animation(reduceMotion)) {
                                showCompleted.toggle()
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: showCompleted ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(DaybookTheme.muted)
                                Text("已完成 (\(doneItems.count))")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(DaybookTheme.muted)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)

                        if showCompleted {
                            ForEach(doneItems) { todo in
                                todoRowView(todo, isDone: true)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .daybookScroll()
    }

    private func todoRowView(_ todo: TodoItem, isDone: Bool) -> some View {
        TaskRow(
            title: todo.title,
            isDone: isDone,
            remindMinutes: todo.remindMinutes,
            todayKey: DayClock.shared.todayKey,
            currentDayKey: todo.dayKey,
            onToggle: { DayBoardMutations.toggleTodo(todo) },
            onDelete: {
                pendingTrash = PendingTrash(title: todo.title) {
                    DayBoardMutations.persist { todo.deletedAt = .now }
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
            isSelected: navigation.selectedTaskID == todo.id,
            onSelect: {
                navigation.selectedTaskID = todo.id
                navigation.isInspectorPresented = true
            }
        )
    }

    // MARK: - Matching Logic

    private var matchingTodos: [TodoItem] {
        todos.filter { todo in
            guard todo.deletedAt == nil else { return false }
            if let project {
                let subtree = ProjectTree.subtreeIDs(root: project.id, in: projects)
                if let pid = todo.projectID {
                    return subtree.contains(pid)
                }
                return false
            }
            if let tag {
                return TagIDList.contains(todo.tagIDs, tag.id)
            }
            return true
        }
    }
}
