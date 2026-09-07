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

    var leftoverChips: some View {
        let yesterdayCount = yesterdayItems.count
        let upcomingCount = upcomingModels.count
        return Group {
            if yesterdayCount > 0 || upcomingCount > 0 {
                HStack(spacing: 12) {
                    if yesterdayCount > 0 {
                        leftoverChip(
                            title: "chip.yesterday",
                            count: yesterdayCount,
                            expanded: showYesterday,
                            emptyLabel: "a11y.yesterday.zero",
                            countLabel: "a11y.yesterday.count \(yesterdayCount)"
                        ) {
                            showYesterday.toggle()
                        }
                    }
                    if upcomingCount > 0 {
                        leftoverChip(
                            title: "chip.upcoming",
                            count: upcomingCount,
                            expanded: showUpcoming,
                            emptyLabel: "a11y.upcoming.zero",
                            countLabel: "a11y.upcoming.count \(upcomingCount)"
                        ) {
                            showUpcoming.toggle()
                        }
                    }
                }
            }
        }
    }

    func leftoverChip(
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

    func leftoverTodoRow(_ todo: TodoItem, note: String? = nil) -> some View {
        TaskRow(
            title: todo.title,
            isDone: false,
            note: note,
            remindMinutes: todo.remindMinutes,
            todayKey: todayKey,
            currentDayKey: todo.dayKey,
            onToggle: { DayBoardMutations.toggleTodo(todo) },
            onDelete: { deleteTodo(todo) },
            onEdit: { DayBoardMutations.editTodo(todo, title: $0) },
            onMoveToDay: { DayBoardMutations.moveTodo(todo, to: $0) },
            onRemindMinutes: { DayBoardMutations.setRemind(todo, minutes: $0) },
            classify: CatalogChoices.classify(for: todo, projects: projects, tags: tags),
            attachments: CatalogChoices.attachments(
                ownerKind: .todo,
                ownerID: todo.id,
                items: attachments,
                context: modelContext
            )
        )
    }

    @ViewBuilder
    func leftoverRow(_ item: UnfinishedItem) -> some View {
        if item.kind == .todo, let todo = todos.first(where: { $0.id == item.id }) {
            leftoverTodoRow(todo)
        } else if item.kind == .routine, let routine = routines.first(where: { $0.id == item.id }) {
            TaskRow(
                title: routine.title,
                isDone: false,
                isResident: true,
                remindMinutes: routine.remindMinutes,
                onToggle: { completeYesterday(item) },
                isImportant: routine.isImportant,
                isUrgent: routine.isUrgent
            )
        } else {
            TaskRow(
                title: item.title,
                isDone: false,
                todayKey: todayKey,
                currentDayKey: yesterdayKey,
                onToggle: { completeYesterday(item) },
                onMoveToDay: item.kind == .todo ? { moveYesterdayTodo(item, to: $0) } : nil
            )
        }
    }
}
