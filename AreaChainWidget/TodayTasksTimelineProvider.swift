import Foundation
import SwiftData
import WidgetKit

struct WidgetTodoItem: Identifiable, Hashable {
    var id: UUID
    var title: String
    var isDone: Bool
    var isImportant: Bool
    var isUrgent: Bool
    var dueMinutes: Int?
    var dueTimeText: String? = nil
    var isOverdue: Bool = false
}

struct WidgetRoutineItem: Identifiable, Hashable {
    var id: UUID
    var title: String
    var isDone: Bool
}

struct TodayTasksEntry: TimelineEntry {
    var date: Date
    var todos: [WidgetTodoItem]
    var routines: [WidgetRoutineItem]
    var completedCount: Int
    var totalCount: Int
    var streakCount: Int
    var activeTab: String = "todos"
    var isPlaceholder: Bool = false

    static var empty: TodayTasksEntry {
        TodayTasksEntry(
            date: Date(),
            todos: [],
            routines: [],
            completedCount: 0,
            totalCount: 0,
            streakCount: 0,
            activeTab: "todos",
            isPlaceholder: false
        )
    }

    static var placeholder: TodayTasksEntry {
        TodayTasksEntry(
            date: Date(),
            todos: [
                WidgetTodoItem(id: UUID(), title: "整理今日工作要点", isDone: true, isImportant: true, isUrgent: false, dueMinutes: 600, dueTimeText: "10:00", isOverdue: false),
                WidgetTodoItem(id: UUID(), title: "完成小组件设计评审", isDone: false, isImportant: true, isUrgent: true, dueMinutes: 840, dueTimeText: "14:00", isOverdue: false),
                WidgetTodoItem(id: UUID(), title: "阅读技术文档 30 分钟", isDone: false, isImportant: false, isUrgent: false, dueMinutes: nil, dueTimeText: nil, isOverdue: false)
            ],
            routines: [
                WidgetRoutineItem(id: UUID(), title: "晨间阅读与思考", isDone: true),
                WidgetRoutineItem(id: UUID(), title: "运动 30 分钟", isDone: false)
            ],
            completedCount: 2,
            totalCount: 5,
            streakCount: 7,
            activeTab: "todos",
            isPlaceholder: true
        )
    }
}

struct TodayTasksTimelineProvider: TimelineProvider {
    typealias Entry = TodayTasksEntry

    func placeholder(in context: Context) -> TodayTasksEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayTasksEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
        } else {
            completion(fetchCurrentEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayTasksEntry>) -> Void) {
        let entry = fetchCurrentEntry()
        // 建议半小时或午夜刷新时间线
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())
            ?? Date().addingTimeInterval(1800)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func fetchCurrentEntry() -> TodayTasksEntry {
        guard let container = WidgetPersistence.makeContainer() else {
            return .empty
        }

        let context = ModelContext(container)
        let todayKey = WidgetDateHelper.todayDayKey()

        // 1. 查询今日待办（未删除，属于今天或今天之前未完成）
        let todoDesc = FetchDescriptor<TodoItem>(
            predicate: #Predicate<TodoItem> { $0.deletedAt == nil }
        )
        let allTodos = (try? context.fetch(todoDesc)) ?? []
        let todayTodos = allTodos.filter { todo in
            if todo.dayKey == todayKey { return true }
            if !todo.isDone && todo.dayKey < todayKey { return true } // 逾期未完成
            return false
        }.sorted { a, b in
            if a.isDone != b.isDone { return !a.isDone } // 未完成排前面
            if a.isImportant != b.isImportant { return a.isImportant }
            if a.isUrgent != b.isUrgent { return a.isUrgent }
            let dueA = a.dueMinutes ?? 9999
            let dueB = b.dueMinutes ?? 9999
            if dueA != dueB { return dueA < dueB }
            return a.sortOrder < b.sortOrder
        }

        let currentMinutes = Calendar.current.component(.hour, from: Date()) * 60 + Calendar.current.component(.minute, from: Date())
        let widgetTodos = todayTodos.map { todo in
            let isPastDay = todo.dayKey < todayKey
            let isTimePassed = (todo.dueMinutes != nil && todo.dueMinutes! < currentMinutes)
            let isOverdue = !todo.isDone && (isPastDay || isTimePassed)
            let dueTimeText = todo.dueMinutes.map { String(format: "%02d:%02d", $0 / 60, $0 % 60) }

            return WidgetTodoItem(
                id: todo.id,
                title: todo.title,
                isDone: todo.isDone,
                isImportant: todo.isImportant,
                isUrgent: todo.isUrgent,
                dueMinutes: todo.dueMinutes,
                dueTimeText: dueTimeText,
                isOverdue: isOverdue
            )
        }

        // 2. 查询今日排定的打卡习惯
        let routineDesc = FetchDescriptor<DailyRoutine>(
            predicate: #Predicate<DailyRoutine> { $0.isEnabled && $0.deletedAt == nil }
        )
        let allRoutines = (try? context.fetch(routineDesc)) ?? []

        let checkDesc = FetchDescriptor<RoutineCheck>(
            predicate: #Predicate<RoutineCheck> { $0.dayKey == todayKey }
        )
        let todayChecks = (try? context.fetch(checkDesc)) ?? []

        var widgetRoutines: [WidgetRoutineItem] = []
        for routine in allRoutines {
            // 检查星期掩码是否包含今天
            guard WidgetDateHelper.isRoutineScheduled(mask: routine.weekdayMask, on: Date()) else { continue }
            if let paused = routine.pausedOnDayKey, paused == todayKey { continue }

            let isDone = todayChecks.first(where: { $0.routine?.id == routine.id })?.isDone ?? false
            widgetRoutines.append(WidgetRoutineItem(id: routine.id, title: routine.title, isDone: isDone))
        }

        let doneTodos = widgetTodos.filter(\.isDone).count
        let doneRoutines = widgetRoutines.filter(\.isDone).count
        let totalCount = widgetTodos.count + widgetRoutines.count
        let completedCount = doneTodos + doneRoutines

        let activeTab = UserDefaults(suiteName: "group.com.areachain.app")?.string(forKey: "widget_tasks_active_tab") ?? "todos"

        return TodayTasksEntry(
            date: Date(),
            todos: widgetTodos,
            routines: widgetRoutines,
            completedCount: completedCount,
            totalCount: totalCount,
            streakCount: doneRoutines,
            activeTab: activeTab
        )
    }
}
