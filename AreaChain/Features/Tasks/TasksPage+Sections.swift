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
                        onToggle: { todo.isDone.toggle() },
                        onDelete: { modelContext.delete(todo) },
                        onEdit: { todo.title = $0 }
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
                        note: isSkipped(routine) ? "已跳过" : nil,
                        onToggle: { toggleRoutine(routine) },
                        onEdit: { routine.title = $0 }
                    )
                }
                ForEach(doneTodoModels, id: \.id) { todo in
                    TaskRow(
                        title: todo.title,
                        isDone: true,
                        onToggle: { todo.isDone.toggle() },
                        onDelete: { modelContext.delete(todo) },
                        onEdit: { todo.title = $0 }
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
                        onToggle: { completeYesterday(item) },
                        onMoveToToday: item.kind == .todo ? { moveYesterdayTodo(item) } : nil
                    )
                }
            }
        }
    }

    var yesterdayChip: some View {
        Button {
            showYesterday.toggle()
        } label: {
            HStack(spacing: 6) {
                Text("昨天")
                Text("\(yesterdayItems.count)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(DaybookTheme.stamp.opacity(yesterdayItems.isEmpty ? 0.15 : 0.25))
                    .clipShape(Capsule())
                Image(systemName: showYesterday ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .font(.system(size: 11))
            .foregroundStyle(DaybookTheme.muted)
        }
        .buttonStyle(.plain)
        .disabled(yesterdayItems.isEmpty)
        .opacity(yesterdayItems.isEmpty ? 0.45 : 1)
        .accessibilityLabel("昨天未完成 \(yesterdayItems.count) 条")
    }

    func emptyLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(DaybookTheme.muted)
            .padding(.vertical, 4)
    }
}
