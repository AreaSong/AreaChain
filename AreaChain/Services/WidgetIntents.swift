import AppIntents
import Foundation
import SwiftData
import WidgetKit

/// 主应用端注册的切换待办完成状态 AppIntent，使 macOS 系统能正确派发小组件点击事件并即时更新主应用内存与 UI
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
        guard let uuid = UUID(uuidString: taskId) else {
            return .result()
        }

        await MainActor.run {
            let context = Persistence.session.container.mainContext
            var descriptor = FetchDescriptor<TodoItem>(
                predicate: #Predicate<TodoItem> { $0.id == uuid }
            )
            descriptor.fetchLimit = 1

            if let todo = try? context.fetch(descriptor).first {
                _ = ModelChanges.perform(in: context) {
                    todo.isDone.toggle()
                }
            }
        }

        return .result()
    }
}

/// 主应用端注册的切换习惯打卡 AppIntent
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
        guard let uuid = UUID(uuidString: routineId) else {
            return .result()
        }

        let targetDayKey = dayKey.isEmpty ? DayKey.today() : dayKey

        await MainActor.run {
            let context = Persistence.session.container.mainContext
            var routineDescriptor = FetchDescriptor<DailyRoutine>(
                predicate: #Predicate<DailyRoutine> { $0.id == uuid }
            )
            routineDescriptor.fetchLimit = 1

            guard let routine = try? context.fetch(routineDescriptor).first else {
                return
            }

            let checkDescriptor = FetchDescriptor<RoutineCheck>(
                predicate: #Predicate<RoutineCheck> { $0.dayKey == targetDayKey }
            )
            let checks = (try? context.fetch(checkDescriptor)) ?? []
            _ = ModelChanges.perform(in: context) {
                if let existing = checks.first(where: { $0.routine?.id == routine.id }) {
                    existing.isDone.toggle()
                } else {
                    let newCheck = RoutineCheck(dayKey: targetDayKey, isDone: true, routine: routine)
                    context.insert(newCheck)
                }
            }
        }

        return .result()
    }
}
