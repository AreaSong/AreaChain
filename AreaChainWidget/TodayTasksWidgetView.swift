import AppIntents
import SwiftUI
import WidgetKit

struct TodayTasksWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: TodayTasksEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(entry: entry)
            case .systemLarge:
                LargeWidgetView(entry: entry)
            default:
                MediumWidgetView(entry: entry)
            }
        }
        .containerBackground(for: .widget) {
            Color(nsColor: .windowBackgroundColor)
        }
    }
}

// MARK: - Medium Widget View (主力形态)

struct MediumWidgetView: View {
    var entry: TodayTasksEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 页头
            HStack(alignment: .center) {
                Label("今日事项", systemImage: "checklist")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer()

                if entry.totalCount > 0 {
                    Text("\(entry.completedCount)/\(entry.totalCount)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }

                Text(Date(), style: .date)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 2)

            Divider()

            // 列表区（最多展示 3~4 条）
            if entry.todos.isEmpty && entry.routines.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.orange)
                    Text("今日暂无未完成待办，尽情享受吧")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(entry.todos.prefix(3)) { todo in
                        TodoRowView(todo: todo)
                    }

                    ForEach(entry.routines.prefix(max(0, 4 - entry.todos.prefix(3).count))) { routine in
                        RoutineRowView(routine: routine)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Small Widget View (轻量摘要)

struct SmallWidgetView: View {
    var entry: TodayTasksEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(Date(), style: .date)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if entry.streakCount > 0 {
                    Text("🔥 \(entry.streakCount)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(entry.completedCount)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(" / \(entry.totalCount) 完成")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Divider()

            if let nextTodo = entry.todos.first(where: { !$0.isDone }) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("下一事项")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(nextTodo.title)
                        .font(.system(size: 12))
                        .lineLimit(1)
                }
            } else {
                Text("今日安排已达成 🎉")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Large Widget View (大号展开)

struct LargeWidgetView: View {
    var entry: TodayTasksEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("今日概览", systemImage: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Text("\(entry.completedCount)/\(entry.totalCount) 完成")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.accentColor)
            }

            Divider()

            if !entry.todos.isEmpty {
                Text("待办事项")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                ForEach(entry.todos.prefix(5)) { todo in
                    TodoRowView(todo: todo)
                }
            }

            if !entry.routines.isEmpty {
                Text("习惯打卡")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                ForEach(entry.routines.prefix(3)) { routine in
                    RoutineRowView(routine: routine)
                }
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Row Subviews with AppIntent

struct TodoRowView: View {
    var todo: WidgetTodoItem

    var body: some View {
        HStack(spacing: 8) {
            Button(intent: ToggleTaskIntent(taskId: todo.id.uuidString)) {
                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(todo.isDone ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)

            Text(todo.title)
                .font(.system(size: 12))
                .strikethrough(todo.isDone, color: .secondary)
                .foregroundStyle(todo.isDone ? .secondary : .primary)
                .lineLimit(1)

            Spacer()

            if todo.isImportant {
                Circle()
                    .fill(Color.red)
                    .frame(width: 5, height: 5)
            }
        }
    }
}

struct RoutineRowView: View {
    var routine: WidgetRoutineItem

    var body: some View {
        HStack(spacing: 8) {
            Button(intent: ToggleRoutineIntent(routineId: routine.id.uuidString, dayKey: WidgetDateHelper.todayDayKey())) {
                Image(systemName: routine.isDone ? "flame.fill" : "flame")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(routine.isDone ? Color.orange : Color.secondary)
            }
            .buttonStyle(.plain)

            Text(routine.title)
                .font(.system(size: 12))
                .strikethrough(routine.isDone, color: .secondary)
                .foregroundStyle(routine.isDone ? .secondary : .primary)
                .lineLimit(1)

            Spacer()
        }
    }
}
