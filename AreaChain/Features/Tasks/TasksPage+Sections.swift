import SwiftUI

extension TasksPage {
    var upcomingSection: some View {
        Group {
            if showUpcoming, !upcomingModels.isEmpty {
                SectionStamp(title: "stamp.upcoming")
                ForEach(upcomingModels, id: \.id) { todo in
                    leftoverTodoRow(todo, note: DayKey.shortStamp(todo.dayKey, locale: locale))
                }
            }
        }
    }

    var yesterdaySection: some View {
        Group {
            if showYesterday {
                SectionStamp(title: "stamp.yesterday")
                ForEach(yesterdayItems) { item in
                    leftoverRow(item)
                }
            }
        }
    }

    func leftoverTodoRow(_ todo: TodoItem, note: String? = nil) -> some View {
        TaskRowFactory.todo(
            todo,
            isDone: false,
            todayKey: todayKey,
            projects: projects,
            tags: tags,
            attachments: attachments,
            context: modelContext,
            isSelected: highlightedTaskID == todo.id,
            note: note,
            includeSubtasks: false,
            onSelect: { inspectLeftover(todo.id, dayKey: todo.dayKey) },
            onDelete: { deleteTodo(todo) }
        )
    }

    @ViewBuilder
    func leftoverRow(_ item: UnfinishedItem) -> some View {
        if item.kind == .todo, let todo = todos.first(where: { $0.id == item.id }) {
            leftoverTodoRow(todo)
        } else if item.kind == .routine, let routine = routines.first(where: { $0.id == item.id }) {
            TaskRowFactory.routine(
                routine,
                isDone: false,
                todayKey: todayKey,
                checkDayKey: yesterdayKey,
                checks: checks,
                context: modelContext,
                locale: locale,
                projects: projects,
                tags: tags,
                attachments: attachments,
                isSelected: highlightedTaskID == routine.id,
                usesDefaultNote: false,
                onToggle: { completeYesterday(item) },
                onSelect: { inspectLeftover(routine.id, dayKey: yesterdayKey) },
                onDelete: {
                    pendingTrash = PendingTrash(title: routine.title) {
                        DayBoardMutations.trashRoutine(routine)
                    }
                },
                onSkip: {
                    DayBoardMutations.skipRoutine(routine, on: yesterdayKey, checks: checks, context: modelContext)
                }
            )
        } else {
            TaskRowFactory.leftoverFallback(
                item: item,
                todayKey: todayKey,
                yesterdayKey: yesterdayKey,
                isSelected: highlightedTaskID == item.id,
                onToggle: { completeYesterday(item) },
                onSelect: { inspectLeftover(item.id, dayKey: yesterdayKey) },
                onMoveToDay: item.kind == .todo ? { moveYesterdayTodo(item, to: $0) } : nil
            )
        }
    }

    func inspectLeftover(_ id: UUID, dayKey: String) {
        BoardSelection.shared.inspectBoard(dayKey)
        if let onInspect {
            onInspect(id)
            return
        }
        AppWindows.openWorkspace(tab: .today)
        WorkspaceNavigation.shared.inspectTask(id)
    }
}

struct LeftoverChipsBar: View {
    var yesterdayCount: Int
    var upcomingCount: Int
    var showYesterday: Bool
    var showUpcoming: Bool
    var onToggleYesterday: () -> Void
    var onToggleUpcoming: () -> Void

    var body: some View {
        if yesterdayCount > 0 || upcomingCount > 0 {
            HStack(spacing: 12) {
                if yesterdayCount > 0 {
                    chip(
                        title: "chip.yesterday",
                        count: yesterdayCount,
                        expanded: showYesterday,
                        emptyLabel: "a11y.yesterday.zero",
                        countLabel: "a11y.yesterday.count \(yesterdayCount)",
                        action: onToggleYesterday
                    )
                }
                if upcomingCount > 0 {
                    chip(
                        title: "chip.upcoming",
                        count: upcomingCount,
                        expanded: showUpcoming,
                        emptyLabel: "a11y.upcoming.zero",
                        countLabel: "a11y.upcoming.count \(upcomingCount)",
                        action: onToggleUpcoming
                    )
                }
            }
        }
    }

    private func chip(
        title: LocalizedStringKey,
        count: Int,
        expanded: Bool,
        emptyLabel: LocalizedStringKey,
        countLabel: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                Text("\(count)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(DaybookTheme.stamp.opacity(count == 0 ? 0.15 : 0.25))
                    .clipShape(Capsule())
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .accessibilityHidden(true)
            }
            .font(.system(size: 11))
            .foregroundStyle(expanded ? DaybookTheme.ink : DaybookTheme.muted)
        }
        .buttonStyle(DaybookQuietButtonStyle())
        .disabled(count == 0)
        .opacity(count == 0 ? 0.45 : 1)
        .accessibilityLabel(count == 0 ? emptyLabel : countLabel)
        .accessibilityAddTraits(expanded ? [.isSelected] : [])
    }
}
