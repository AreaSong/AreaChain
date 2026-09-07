import SwiftUI

extension TasksPage {
    var routineSection: some View {
        Group {
            SectionStamp(title: "stamp.routines")
            if openRoutineModels.isEmpty {
                emptyLine("empty.routines.today")
            } else {
                ForEach(openRoutineModels, id: \.id) { routine in
                    TaskRow(
                        title: routine.title,
                        isDone: false,
                        note: routine.weekdaysOnly ? L10n.string("note.weekdays", locale: locale) : nil,
                        onToggle: { toggleRoutine(routine) },
                        onEdit: { routine.title = $0 },
                        onSkip: { skipRoutine(routine) }
                    )
                }
            }
        }
    }

    var todaySection: some View {
        Group {
            SectionStamp(title: "stamp.today")
            if openTodoModels.isEmpty {
                emptyLine("empty.todos")
            } else {
                ForEach(openTodoModels, id: \.id) { todo in
                    TaskRow(
                        title: todo.title,
                        isDone: false,
                        todayKey: todayKey,
                        currentDayKey: todo.dayKey,
                        onToggle: { todo.isDone.toggle() },
                        onDelete: { modelContext.delete(todo) },
                        onEdit: { todo.title = $0 },
                        onMoveToDay: { moveTodo(todo, to: $0) }
                    )
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
                ForEach(doneRoutineModels, id: \.id) { routine in
                    TaskRow(
                        title: routine.title,
                        isDone: true,
                        note: doneRoutineNote(routine),
                        onToggle: { toggleRoutine(routine) },
                        onEdit: { routine.title = $0 }
                    )
                }
                ForEach(doneTodoModels, id: \.id) { todo in
                    TaskRow(
                        title: todo.title,
                        isDone: true,
                        todayKey: todayKey,
                        currentDayKey: todo.dayKey,
                        onToggle: { todo.isDone.toggle() },
                        onDelete: { modelContext.delete(todo) },
                        onEdit: { todo.title = $0 },
                        onMoveToDay: { moveTodo(todo, to: $0) }
                    )
                }
            }
        }
    }

    var upcomingSection: some View {
        Group {
            if showUpcoming, !upcomingModels.isEmpty {
                SectionStamp(title: "stamp.upcoming")
                ForEach(upcomingModels, id: \.id) { todo in
                    TaskRow(
                        title: todo.title,
                        isDone: false,
                        note: DayKey.shortStamp(todo.dayKey, locale: locale),
                        todayKey: todayKey,
                        currentDayKey: todo.dayKey,
                        onToggle: { todo.isDone.toggle() },
                        onDelete: { modelContext.delete(todo) },
                        onEdit: { todo.title = $0 },
                        onMoveToDay: { moveTodo(todo, to: $0) }
                    )
                }
            }
        }
    }

    var yesterdaySection: some View {
        Group {
            if showYesterday {
                SectionStamp(title: "stamp.yesterday")
                ForEach(yesterdayItems) { item in
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
    }

    var leftoverChips: some View {
        HStack(spacing: 12) {
            leftoverChip(
                title: "chip.yesterday",
                count: yesterdayItems.count,
                expanded: showYesterday,
                emptyLabel: "a11y.yesterday.zero",
                countLabel: "a11y.yesterday.count \(yesterdayItems.count)"
            ) {
                showYesterday.toggle()
            }
            leftoverChip(
                title: "chip.upcoming",
                count: upcomingModels.count,
                expanded: showUpcoming,
                emptyLabel: "a11y.upcoming.zero",
                countLabel: "a11y.upcoming.count \(upcomingModels.count)"
            ) {
                showUpcoming.toggle()
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
}
