import SwiftUI

extension TasksPage {
    var routineSection: some View {
        Group {
            SectionStamp(title: "例行")
            if openRoutineModels.isEmpty && !addingRoutine {
                emptyLine("还没有例行项。")
                Button("加上一条例行") { addingRoutine = true }
                    .font(.system(size: 12))
                    .foregroundStyle(DaybookTheme.stamp)
                    .buttonStyle(.plain)
            } else {
                ForEach(openRoutineModels, id: \.id) { routine in
                    TaskRow(
                        title: routine.title,
                        isDone: false,
                        note: routine.weekdaysOnly ? "仅工作日" : nil,
                        onToggle: { toggleRoutine(routine) },
                        onEdit: { routine.title = $0 },
                        onSkip: { skipRoutine(routine) }
                    )
                }
            }
            if addingRoutine {
                HStack {
                    TextField("例行名称", text: $routineDraft)
                        .textFieldStyle(.plain)
                        .onSubmit(addRoutineFromPopover)
                    Button("加上", action: addRoutineFromPopover)
                        .disabled(routineDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .font(.system(size: 12))
            }
        }
    }

    var todaySection: some View {
        Group {
            SectionStamp(title: "今天")
            if openTodoModels.isEmpty {
                emptyLine("突然想到的，打在上面回车。")
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
                    SectionStamp(title: showCompleted ? "已完成 \(completedCount) · 收起" : "已完成 \(completedCount)")
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
                SectionStamp(title: "即将")
                ForEach(upcomingModels, id: \.id) { todo in
                    TaskRow(
                        title: todo.title,
                        isDone: false,
                        note: DayKey.shortStamp(todo.dayKey),
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
                SectionStamp(title: "昨天未完成")
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
                title: "昨天",
                count: yesterdayItems.count,
                expanded: showYesterday,
                emptyLabel: "昨天未完成 0 条"
            ) {
                showYesterday.toggle()
            }
            leftoverChip(
                title: "即将",
                count: upcomingModels.count,
                expanded: showUpcoming,
                emptyLabel: "即将 0 条"
            ) {
                showUpcoming.toggle()
            }
        }
    }

    func leftoverChip(
        title: String,
        count: Int,
        expanded: Bool,
        emptyLabel: String,
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
        .accessibilityLabel(count == 0 ? emptyLabel : "\(title) \(count) 条")
    }

    func emptyLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(DaybookTheme.muted)
            .padding(.vertical, 4)
    }
}
