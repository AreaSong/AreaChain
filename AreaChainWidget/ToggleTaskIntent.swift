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

    @Parameter(title: "环境标识")
    var isDebug: Bool

    init() {
        self.taskId = ""
        self.isDebug = false
    }

    init(taskId: String, isDebug: Bool = false) {
        self.taskId = taskId
        self.isDebug = isDebug
    }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: taskId),
              let container = WidgetPersistence.makeContainer(isDebug: isDebug) else {
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

    @Parameter(title: "环境标识")
    var isDebug: Bool

    init() {
        self.routineId = ""
        self.dayKey = ""
        self.isDebug = false
    }

    init(routineId: String, dayKey: String, isDebug: Bool = false) {
        self.routineId = routineId
        self.dayKey = dayKey
        self.isDebug = isDebug
    }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: routineId),
              let container = WidgetPersistence.makeContainer(isDebug: isDebug) else {
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

/// 辅助日期工具，独立计算民事日期与习惯排期掩码，与主应用 WeekdayMask 完全对齐
enum WidgetDateHelper {
    static func todayDayKey(from date: Date = Date()) -> String {
        let calendar = Calendar.current
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        let day = parts.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// 按照系统日历与主应用 WeekdayMask 规则匹配掩码
    /// Weekday 1=周日 (1 << 0), 2=周一 (1 << 1), ... 7=周六 (1 << 6)
    static func isRoutineScheduled(mask: Int?, on date: Date = Date()) -> Bool {
        let resolvedMask = mask ?? 0b1111111
        let weekday = Calendar.current.component(.weekday, from: date)
        guard (1...7).contains(weekday) else { return false }
        let bit = 1 << (weekday - 1)
        return (resolvedMask & 0b1111111 & bit) != 0
    }
}
