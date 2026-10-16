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

/// 主应用端注册的手记翻页 AppIntent
struct DiaryPageIntent: AppIntent {
    static var title: LocalizedStringResource = "切换手记翻页"
    static var description = IntentDescription("在手记小组件中原位翻阅今日的多篇手记")

    @Parameter(title: "翻页方向")
    var direction: String

    init() {
        self.direction = "next"
    }

    init(direction: String) {
        self.direction = direction
    }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.areachain.app")
        let currentIndex = defaults?.integer(forKey: "widget_diary_page_index") ?? 0

        let fetchedCount = await MainActor.run { () -> Int in
            let context = Persistence.session.container.mainContext
            let todayKey = DayKey.today()
            let descriptor = FetchDescriptor<DiaryEntry>(
                predicate: #Predicate<DiaryEntry> { $0.deletedAt == nil && $0.dayKey == todayKey }
            )
            return (try? context.fetch(descriptor).count) ?? 1
        }
        let totalCount = max(1, fetchedCount)

        let newIndex: Int
        if direction == "next" {
            newIndex = (currentIndex + 1) % totalCount
        } else {
            newIndex = (currentIndex - 1 + totalCount) % totalCount
        }

        defaults?.set(newIndex, forKey: "widget_diary_page_index")
        WidgetCenter.shared.reloadTimelines(ofKind: "AreaChainDiaryWidget")
        return .result()
    }
}

/// 主应用端注册的手记微打卡 AppIntent
struct DiaryQuickMoodIntent: AppIntent {
    static var title: LocalizedStringResource = "一键记录微状态"
    static var description = IntentDescription("在手记小组件中一键追加当前微状态与心情")

    @Parameter(title: "状态文案")
    var moodText: String

    init() {
        self.moodText = "☕️ 摸鱼"
    }

    init(moodText: String) {
        self.moodText = moodText
    }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            let context = Persistence.session.container.mainContext
            let todayKey = DayKey.today()
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            let timeStr = formatter.string(from: Date())

            _ = ModelChanges.perform(in: context) {
                let entry = DiaryEntry(
                    text: "\(timeStr) \(moodText)",
                    dayKey: todayKey,
                    createdAt: Date()
                )
                context.insert(entry)
            }
        }

        let defaults = UserDefaults(suiteName: "group.com.areachain.app")
        defaults?.set(0, forKey: "widget_diary_page_index")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// 主应用端注册的事项分类切换 AppIntent
struct TasksTabIntent: AppIntent {
    static var title: LocalizedStringResource = "切换事项分类"
    static var description = IntentDescription("在今日小组件中原位切换显示待办或习惯")

    @Parameter(title: "分类标识")
    var tab: String

    init() {
        self.tab = "todos"
    }

    init(tab: String) {
        self.tab = tab
    }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.areachain.app")
        defaults?.set(tab, forKey: "widget_tasks_active_tab")
        WidgetCenter.shared.reloadTimelines(ofKind: "AreaChainTodayWidget")
        return .result()
    }
}

