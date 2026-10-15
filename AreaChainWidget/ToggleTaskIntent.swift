import AppIntents
import Foundation
import SwiftData
import WidgetKit

/// 小组件中点击切换待办完成状态的交互 Intent
struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "切换待办完成状态"
    static var description = IntentDescription("在小组件中直接标记待办事项为完成或未完成")

    @Parameter(title: "待办 ID")
    var taskId: String

    init() {
        self.taskId = ""
    }

    init(taskId: String) {
        self.taskId = taskId
    }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: taskId),
              let container = WidgetPersistence.makeContainer() else {
            return .result()
        }

        let context = ModelContext(container)
        var descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate<TodoItem> { $0.id == uuid }
        )
        descriptor.fetchLimit = 1

        if let todo = try? context.fetch(descriptor).first {
            todo.isDone.toggle()
            try? context.save()
            WidgetCenter.shared.reloadAllTimelines()
        }

        return .result()
    }
}

/// 小组件中点击切换习惯打卡状态的交互 Intent
struct ToggleRoutineIntent: AppIntent {
    static var title: LocalizedStringResource = "切换习惯打卡"
    static var description = IntentDescription("在小组件中直接完成今日习惯打卡")

    @Parameter(title: "习惯 ID")
    var routineId: String

    @Parameter(title: "日期键")
    var dayKey: String

    init() {
        self.routineId = ""
        self.dayKey = ""
    }

    init(routineId: String, dayKey: String) {
        self.routineId = routineId
        self.dayKey = dayKey
    }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: routineId),
              let container = WidgetPersistence.makeContainer() else {
            return .result()
        }

        let context = ModelContext(container)
        var routineDescriptor = FetchDescriptor<DailyRoutine>(
            predicate: #Predicate<DailyRoutine> { $0.id == uuid }
        )
        routineDescriptor.fetchLimit = 1

        guard let routine = try? context.fetch(routineDescriptor).first else {
            return .result()
        }

        let targetDayKey = dayKey.isEmpty ? WidgetDateHelper.todayDayKey() : dayKey

        // 查找或新建今日 RoutineCheck
        let checkDescriptor = FetchDescriptor<RoutineCheck>(
            predicate: #Predicate<RoutineCheck> { $0.dayKey == targetDayKey }
        )
        let checks = (try? context.fetch(checkDescriptor)) ?? []
        if let existing = checks.first(where: { $0.routine?.id == routine.id }) {
            existing.isDone.toggle()
        } else {
            let newCheck = RoutineCheck(dayKey: targetDayKey, isDone: true, routine: routine)
            context.insert(newCheck)
        }

        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// 辅助日期工具，独立计算民事日期，避免对主工程额外依赖
enum WidgetDateHelper {
    static func todayDayKey() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    static func weekdayIndex(from date: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1 // 1 是周日，2 是周一
        let weekday = calendar.component(.weekday, from: date)
        // 转换成 0=周一 ... 6=周日
        return (weekday + 5) % 7
    }
}
