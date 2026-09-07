import SwiftUI

extension TasksPage {
    var todayList: some View {
        Group {
            if openDayItems.isEmpty {
                emptyLine("empty.todos")
            } else {
                ForEach(openDayItems) { row in
                    dayRow(row, isDone: false)
                }
            }
        }
    }

    var completedSection: some View {
        Group {
            if completedCount > 0 {
                Button {
                    showCompleted.toggle()
                } label: {
                    SectionStamp(
                        title: showCompleted
                            ? "stamp.completed.collapse \(completedCount)"
                            : "stamp.completed \(completedCount)"
                    )
                }
                .buttonStyle(.plain)
            }
            if showCompleted {
                ForEach(doneDayItems) { row in
                    dayRow(row, isDone: true)
                }
            }
        }
    }

    var upcomingSection: some View {
        Group {
            if showUpcoming, !upcomingModels.isEmpty {
                SectionStamp(title: "stamp.upcoming")
                ForEach(upcomingModels, id: \.id) { todo in
                    todoRow(todo, isDone: false, note: DayKey.shortStamp(todo.dayKey, locale: locale))
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
            }
            .font(.system(size: 11))
            .foregroundStyle(DaybookTheme.muted)
        }
        .buttonStyle(.plain)
        .disabled(count == 0)
        .opacity(count == 0 ? 0.45 : 1)
        .accessibilityLabel(count == 0 ? emptyLabel : countLabel)
    }

    func emptyLine(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(DaybookTheme.muted)
            .padding(.vertical, 4)
    }

    @ViewBuilder
    func dayRow(_ row: BoardRow, isDone: Bool) -> some View {
        switch row {
        case .resident(let routine):
            residentRow(routine, isDone: isDone)
        case .todo(let todo):
            todoRow(todo, isDone: isDone)
        }
    }

    func residentRow(_ routine: DailyRoutine, isDone: Bool) -> some View {
        TaskRow(
            title: routine.title,
            isDone: isDone,
            isResident: true,
            note: isDone ? doneRoutineNote(routine) : daysNote(routine, locale: locale),
            remindMinutes: routine.remindMinutes,
            onToggle: { toggleRoutine(routine) },
            onSkip: isDone ? nil : { skipRoutine(routine) }
        )
    }

    func todoRow(_ todo: TodoItem, isDone: Bool, note: String? = nil) -> some View {
        TaskRow(
            title: todo.title,
            isDone: isDone,
            note: note,
            remindMinutes: todo.remindMinutes,
            todayKey: todayKey,
            currentDayKey: todo.dayKey,
            onToggle: { toggleTodo(todo) },
            onDelete: { deleteTodo(todo) },
            onEdit: { editTodo(todo, title: $0) },
            onMoveToDay: { moveTodo(todo, to: $0) },
            onRemindMinutes: { setRemind(todo, minutes: $0) }
        )
    }

    @ViewBuilder
    func leftoverRow(_ item: UnfinishedItem) -> some View {
        if item.kind == .todo, let todo = todos.first(where: { $0.id == item.id }) {
            todoRow(todo, isDone: false)
        } else if item.kind == .routine, let routine = routines.first(where: { $0.id == item.id }) {
            TaskRow(
                title: routine.title,
                isDone: false,
                isResident: true,
                remindMinutes: routine.remindMinutes,
                onToggle: { completeYesterday(item) }
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
