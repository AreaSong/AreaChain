import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Daybook Widget Theme (对齐主应用 DaybookPalette 质感)

enum WidgetDaybookTheme {
    static let paperBackground = Color(
        nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1.0)
                : NSColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1.0)
        })
    )

    static let inkText = Color(
        nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1.0)
                : NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
        })
    )

    static let mutedText = Color(
        nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 0.70, green: 0.71, blue: 0.75, alpha: 1.0)
                : NSColor(red: 0.40, green: 0.41, blue: 0.45, alpha: 1.0)
        })
    )

    static let ruleLine = Color(
        nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 0.24, green: 0.25, blue: 0.28, alpha: 0.8)
                : NSColor(red: 0.86, green: 0.88, blue: 0.92, alpha: 0.8)
        })
    )

    static let stampAccent = Color(
        nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 0.38, green: 0.68, blue: 1.0, alpha: 1.0)
                : NSColor(red: 0.08, green: 0.35, blue: 0.76, alpha: 1.0)
        })
    )

    static let capsuleBackground = Color(
        nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 0.38, green: 0.68, blue: 1.0, alpha: 0.18)
                : NSColor(red: 0.08, green: 0.35, blue: 0.76, alpha: 0.12)
        })
    )

    static let streakOrange = Color(
        nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 1.0, green: 0.60, blue: 0.20, alpha: 1.0)
                : NSColor(red: 0.90, green: 0.42, blue: 0.10, alpha: 1.0)
        })
    )

    static let destructiveRed = Color(
        nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 0.98, green: 0.52, blue: 0.48, alpha: 1.0)
                : NSColor(red: 0.78, green: 0.16, blue: 0.14, alpha: 1.0)
        })
    )
}

// MARK: - Localized Copy (支持中英双语自适应，内置标准文本防丢)

enum WidgetL10n {
    static var isChinese: Bool {
        if let pref = WidgetPersistence.readLanguagePreference() {
            if pref == "chinese" { return true }
            if pref == "english" { return false }
        }
        if let groupDefaults = UserDefaults(suiteName: "group.com.areachain.app"),
           let pref = groupDefaults.string(forKey: "areachain.prefs.language") {
            if pref == "chinese" { return true }
            if pref == "english" { return false }
        }
        if Locale.preferredLanguages.contains(where: { $0.hasPrefix("zh") }) {
            return true
        }
        if Locale.current.identifier.contains("zh") || Locale.current.identifier.contains("CN") {
            return true
        }
        return false
    }

    static var titleToday: String { isChinese ? "今日事项" : "Today" }
    static var titleOverview: String { isChinese ? "今日概览" : "Today's Overview" }
    static var sectionTodos: String { isChinese ? "待办事项" : "To-Dos" }
    static var sectionRoutines: String { isChinese ? "习惯打卡" : "Habits" }
    static var sectionNextAction: String { isChinese ? "下一事项" : "Next Action" }
    static var emptyTodayDone: String { isChinese ? "今日暂无未完成待办，尽情享受吧" : "No pending tasks today. Enjoy your day!" }
    static var emptyAllDone: String { isChinese ? "今日安排已达成 🎉" : "All caught up for today 🎉" }
    static var statusCompleted: String { isChinese ? "完成" : "completed" }
    static var statusOverdue: String { isChinese ? "逾期" : "Overdue" }
    static var titleDiary: String { isChinese ? "今日手记" : "Today's Notes" }
    static var diaryWidgetDisplayName: String { isChinese ? "今日手记" : "Today's Notes" }
    static var diaryWidgetDescription: String { isChinese ? "在桌面随时阅览今日随想与手记灵感，一键快速记录。" : "Read your notes and inspirations on desktop, and capture thoughts instantly." }
    static var emptyDiary: String { isChinese ? "今日暂无手记，点击记录此刻灵感..." : "No notes for today yet. Click to capture your thoughts..." }
    static var privateDiaryLocked: String { isChinese ? "🔒 私密手记已锁定" : "🔒 Private note is locked" }
    static func formatWordsCount(_ count: Int) -> String {
        isChinese ? "\(count) 字" : "\(count) words"
    }
}

// MARK: - Debug Badge

struct WidgetDebugBadgeView: View {
    var body: some View {
        Text("DEBUG")
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.orange)
            .padding(.horizontal, 4)
            .padding(.vertical, 1.5)
            .background(Color.orange.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

// MARK: - Root View

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
            WidgetDaybookTheme.paperBackground
        }
        .widgetURL(URL(string: entry.isDebug ? "areachain://today?debug=1" : "areachain://today"))
    }
}

// MARK: - Medium Widget View (主力形态)

struct MediumWidgetView: View {
    var entry: TodayTasksEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 页头
            HStack(alignment: .center, spacing: 6) {
                Label(WidgetL10n.titleToday, systemImage: "checklist")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(WidgetDaybookTheme.inkText)
                    .lineLimit(1)

                if entry.isDebug {
                    WidgetDebugBadgeView()
                }

                // 原位 Tab 切换
                HStack(spacing: 2) {
                    Button(intent: TasksTabIntent(tab: "todos", isDebug: entry.isDebug)) {
                        Text(WidgetL10n.sectionTodos)
                            .font(.system(size: 9, weight: entry.activeTab == "todos" ? .bold : .regular))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(entry.activeTab == "todos" ? WidgetDaybookTheme.stampAccent.opacity(0.15) : Color.clear)
                            .foregroundStyle(entry.activeTab == "todos" ? WidgetDaybookTheme.stampAccent : WidgetDaybookTheme.mutedText)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(intent: TasksTabIntent(tab: "routines", isDebug: entry.isDebug)) {
                        Text(WidgetL10n.sectionRoutines)
                            .font(.system(size: 9, weight: entry.activeTab == "routines" ? .bold : .regular))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(entry.activeTab == "routines" ? WidgetDaybookTheme.stampAccent.opacity(0.15) : Color.clear)
                            .foregroundStyle(entry.activeTab == "routines" ? WidgetDaybookTheme.stampAccent : WidgetDaybookTheme.mutedText)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Link(destination: URL(string: entry.isDebug ? "areachain://quick-task?debug=1" : "areachain://quick-task")!) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(WidgetDaybookTheme.stampAccent)
                }
                .buttonStyle(.plain)

                if entry.totalCount > 0 {
                    Text("\(entry.completedCount)/\(entry.totalCount)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(WidgetDaybookTheme.capsuleBackground)
                        .foregroundStyle(WidgetDaybookTheme.stampAccent)
                        .clipShape(Capsule())
                }

                Text(Date(), style: .date)
                    .font(.system(size: 11))
                    .foregroundStyle(WidgetDaybookTheme.mutedText)
                    .lineLimit(1)
            }
            .padding(.bottom, 2)

            Rectangle()
                .fill(WidgetDaybookTheme.ruleLine)
                .frame(height: 1)

            // 列表区
            if entry.todos.isEmpty && entry.routines.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(WidgetDaybookTheme.streakOrange)
                    Text(WidgetL10n.emptyTodayDone)
                        .font(.system(size: 12))
                        .foregroundStyle(WidgetDaybookTheme.mutedText)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if entry.activeTab == "routines" {
                if entry.routines.isEmpty {
                    VStack(spacing: 6) {
                        Spacer()
                        Text("今日无排定习惯")
                            .font(.system(size: 11))
                            .foregroundStyle(WidgetDaybookTheme.mutedText)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(entry.routines.prefix(4)) { routine in
                            RoutineRowView(routine: routine, isDebug: entry.isDebug)
                        }
                    }
                }
            } else {
                if entry.todos.isEmpty {
                    VStack(spacing: 6) {
                        Spacer()
                        Text(WidgetL10n.emptyTodayDone)
                            .font(.system(size: 11))
                            .foregroundStyle(WidgetDaybookTheme.mutedText)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(entry.todos.prefix(4)) { todo in
                            TodoRowView(todo: todo, isDebug: entry.isDebug)
                        }
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
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                if entry.isDebug {
                    WidgetDebugBadgeView()
                }
                Text(Date(), style: .date)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WidgetDaybookTheme.mutedText)
                Spacer()
                if entry.streakCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                        Text("\(entry.streakCount)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(WidgetDaybookTheme.streakOrange)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(entry.completedCount)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetDaybookTheme.inkText)
                Text(" / \(entry.totalCount)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(WidgetDaybookTheme.mutedText)
                Text(WidgetL10n.statusCompleted)
                    .font(.system(size: 11))
                    .foregroundStyle(WidgetDaybookTheme.mutedText)
                    .padding(.leading, 2)
            }

            Rectangle()
                .fill(WidgetDaybookTheme.ruleLine)
                .frame(height: 1)

            if let nextTodo = entry.todos.first(where: { !$0.isDone }) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(WidgetL10n.sectionNextAction)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(WidgetDaybookTheme.mutedText)
                    TodoRowView(todo: nextTodo, isDebug: entry.isDebug)
                }
            } else {
                Text(WidgetL10n.emptyAllDone)
                    .font(.system(size: 11))
                    .foregroundStyle(WidgetDaybookTheme.mutedText)
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
            HStack(spacing: 8) {
                Label(WidgetL10n.titleOverview, systemImage: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(WidgetDaybookTheme.inkText)
                    .lineLimit(1)

                if entry.isDebug {
                    WidgetDebugBadgeView()
                }

                Spacer()

                Link(destination: URL(string: entry.isDebug ? "areachain://quick-task?debug=1" : "areachain://quick-task")!) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(WidgetDaybookTheme.stampAccent)
                }
                .buttonStyle(.plain)

                (Text("\(entry.completedCount)/\(entry.totalCount) ")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(WidgetDaybookTheme.stampAccent)
                + Text(WidgetL10n.statusCompleted)
                    .font(.system(size: 11))
                    .foregroundStyle(WidgetDaybookTheme.mutedText))
                    .lineLimit(1)
            }

            Rectangle()
                .fill(WidgetDaybookTheme.ruleLine)
                .frame(height: 1)

            if !entry.todos.isEmpty {
                Text(WidgetL10n.sectionTodos)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WidgetDaybookTheme.mutedText)

                ForEach(entry.todos.prefix(5)) { todo in
                    TodoRowView(todo: todo, isDebug: entry.isDebug)
                }
            }

            if !entry.routines.isEmpty {
                Text(WidgetL10n.sectionRoutines)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WidgetDaybookTheme.mutedText)
                    .padding(.top, 4)

                ForEach(entry.routines.prefix(3)) { routine in
                    RoutineRowView(routine: routine, isDebug: entry.isDebug)
                }
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Row Subviews with AppIntent

struct TodoRowView: View {
    var todo: WidgetTodoItem
    var isDebug: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Button(intent: ToggleTaskIntent(taskId: todo.id.uuidString, isDebug: isDebug)) {
                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(todo.isDone ? WidgetDaybookTheme.stampAccent : WidgetDaybookTheme.mutedText)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(todo.title)
                .font(.system(size: 12))
                .strikethrough(todo.isDone, color: WidgetDaybookTheme.mutedText.opacity(0.6))
                .foregroundStyle(todo.isDone ? WidgetDaybookTheme.mutedText : WidgetDaybookTheme.inkText)
                .lineLimit(1)

            Spacer()

            if let time = todo.dueTimeText {
                Text(time)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(todo.isOverdue ? WidgetDaybookTheme.destructiveRed.opacity(0.12) : WidgetDaybookTheme.capsuleBackground)
                    .foregroundStyle(todo.isOverdue ? WidgetDaybookTheme.destructiveRed : WidgetDaybookTheme.stampAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else if todo.isOverdue {
                HStack(spacing: 2) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 8))
                    Text(WidgetL10n.statusOverdue)
                        .font(.system(size: 9, weight: .medium))
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(WidgetDaybookTheme.destructiveRed.opacity(0.12))
                .foregroundStyle(WidgetDaybookTheme.destructiveRed)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }

            if todo.isImportant {
                Circle()
                    .fill(WidgetDaybookTheme.destructiveRed)
                    .frame(width: 5, height: 5)
            }
        }
    }
}

struct RoutineRowView: View {
    var routine: WidgetRoutineItem
    var isDebug: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Button(intent: ToggleRoutineIntent(routineId: routine.id.uuidString, dayKey: WidgetDateHelper.todayDayKey(), isDebug: isDebug)) {
                Image(systemName: routine.isDone ? "flame.fill" : "flame")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(routine.isDone ? WidgetDaybookTheme.streakOrange : WidgetDaybookTheme.mutedText)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(routine.title)
                .font(.system(size: 12))
                .strikethrough(routine.isDone, color: WidgetDaybookTheme.mutedText.opacity(0.6))
                .foregroundStyle(routine.isDone ? WidgetDaybookTheme.mutedText : WidgetDaybookTheme.inkText)
                .lineLimit(1)

            Spacer()
        }
    }
}
