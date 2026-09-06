import SwiftUI
import SwiftData

struct TasksPage: View {
    @Environment(\.modelContext) private var modelContext

    var todayKey: String
    var yesterdayKey: String
    var routines: [DailyRoutine]
    var checks: [RoutineCheck]
    var todos: [TodoItem]

    @State private var showYesterday = false

    private var todayRoutines: [DailyRoutine] {
        let dueIDs = Set(
            DayBoardLogic.routines(for: todayKey, in: routines.map(\.snapshot)).map(\.id)
        )
        return routines
            .filter { dueIDs.contains($0.id) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var todayTodos: [TodoItem] {
        DayBoardLogic.todos(for: todayKey, in: todos.map(\.snapshot))
            .compactMap { snapshot in todos.first { $0.id == snapshot.id } }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var yesterdayItems: [UnfinishedItem] {
        DayBoardLogic.yesterdayUnfinished(
            routines: routines.map(\.snapshot),
            checks: checks.compactMap(\.snapshot),
            todos: todos.map(\.snapshot),
            yesterdayKey: yesterdayKey
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            yesterdayChip
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    SectionStamp(title: "例行")
                    if todayRoutines.isEmpty {
                        emptyLine("还没有例行项，去设置里加。")
                    } else {
                        ForEach(todayRoutines, id: \.id) { routine in
                            TaskRow(
                                title: routine.title,
                                isDone: isRoutineDone(routine),
                                onToggle: { toggleRoutine(routine) }
                            )
                        }
                    }

                    SectionStamp(title: "今天")
                    if todayTodos.isEmpty {
                        emptyLine("突然想到的，打在上面回车。")
                    } else {
                        ForEach(todayTodos, id: \.id) { todo in
                            TaskRow(
                                title: todo.title,
                                isDone: todo.isDone,
                                onToggle: { todo.isDone.toggle() },
                                onDelete: { modelContext.delete(todo) }
                            )
                        }
                    }

                    if showYesterday {
                        SectionStamp(title: "昨天未完成")
                        ForEach(yesterdayItems) { item in
                            TaskRow(
                                title: item.title,
                                isDone: false,
                                onToggle: { completeYesterday(item) }
                            )
                        }
                    }
                }
            }
        }
    }

    private var yesterdayChip: some View {
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

    private func emptyLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(DaybookTheme.muted)
            .padding(.vertical, 4)
    }

    private func isRoutineDone(_ routine: DailyRoutine) -> Bool {
        DayBoardLogic.isRoutineDone(
            routine.snapshot,
            checks: checks.compactMap(\.snapshot),
            on: todayKey
        )
    }

    private func toggleRoutine(_ routine: DailyRoutine) {
        if let check = checks.first(where: { $0.routine?.id == routine.id && $0.dayKey == todayKey }) {
            check.isDone.toggle()
            return
        }
        modelContext.insert(RoutineCheck(dayKey: todayKey, isDone: true, routine: routine))
    }

    private func completeYesterday(_ item: UnfinishedItem) {
        switch item.kind {
        case .todo:
            todos.first { $0.id == item.id }?.isDone = true
        case .routine:
            guard let routine = routines.first(where: { $0.id == item.id }) else { return }
            if let check = checks.first(where: { $0.routine?.id == routine.id && $0.dayKey == yesterdayKey }) {
                check.isDone = true
            } else {
                modelContext.insert(RoutineCheck(dayKey: yesterdayKey, isDone: true, routine: routine))
            }
        }
    }
}

struct TaskRow: View {
    var title: String
    var isDone: Bool
    var onToggle: () -> Void
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            InkCheckbox(isDone: isDone, action: onToggle)
            Text(title)
                .font(.system(size: 13))
                .strikethrough(isDone, color: DaybookTheme.done)
                .foregroundStyle(isDone ? DaybookTheme.done : DaybookTheme.ink)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .contextMenu {
            if let onDelete {
                Button("删除", role: .destructive, action: onDelete)
            }
        }
    }
}
