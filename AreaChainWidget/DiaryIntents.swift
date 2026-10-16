import AppIntents
import Foundation
import SwiftData
import WidgetKit

/// 手记翻页交互 Intent（上一篇 / 下一篇）
struct DiaryPageIntent: AppIntent {
    static var title: LocalizedStringResource = "切换手记翻页"
    static var description = IntentDescription("在手记小组件中原位翻阅今日的多篇手记")

    @Parameter(title: "翻页方向")
    var direction: String // "next" 或 "prev"

    init() {
        self.direction = "next"
    }

    init(direction: String) {
        self.direction = direction
    }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.areachain.app")
        let currentIndex = defaults?.integer(forKey: "widget_diary_page_index") ?? 0

        // 查询今日条目数量以做边界约束
        var totalCount = 1
        if let container = WidgetPersistence.makeContainer() {
            let context = ModelContext(container)
            let todayKey = WidgetDateHelper.todayDayKey()
            let descriptor = FetchDescriptor<DiaryEntry>(
                predicate: #Predicate<DiaryEntry> { $0.deletedAt == nil && $0.dayKey == todayKey }
            )
            totalCount = (try? context.fetch(descriptor).count) ?? 1
        }

        if totalCount < 1 { totalCount = 1 }

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

/// 手记一键微状态 / 心情打卡 Intent
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
        guard let container = WidgetPersistence.makeContainer() else {
            return .result()
        }

        let context = ModelContext(container)
        let todayKey = WidgetDateHelper.todayDayKey()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeStr = formatter.string(from: Date())

        let entryText = "\(timeStr) \(moodText)"
        let newEntry = DiaryEntry(
            id: UUID(),
            text: entryText,
            dayKey: todayKey,
            createdAt: Date(),
            deletedAt: nil,
            tagIDs: "",
            isPinned: false
        )

        context.insert(newEntry)
        try? context.save()

        // 打卡后将翻页重置为第一篇（最新篇），并刷新桌面
        let defaults = UserDefaults(suiteName: "group.com.areachain.app")
        defaults?.set(0, forKey: "widget_diary_page_index")
        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }
}

/// 事项小组件 Tab 切换（待办 / 习惯）
struct TasksTabIntent: AppIntent {
    static var title: LocalizedStringResource = "切换事项分类"
    static var description = IntentDescription("在今日小组件中原位切换显示待办或习惯")

    @Parameter(title: "分类标识")
    var tab: String // "todos" 或 "routines"

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
