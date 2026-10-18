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

    @Parameter(title: "环境标识")
    var isDebug: Bool

    init() {
        self.direction = "next"
        self.isDebug = false
    }

    init(direction: String, isDebug: Bool = false) {
        self.direction = direction
        self.isDebug = isDebug
    }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.areachain.app")
        let pageKey = isDebug ? "widget_diary_page_index_debug" : "widget_diary_page_index"
        let currentIndex = defaults?.integer(forKey: pageKey) ?? 0

        // 查询今日条目数量以做边界约束
        var totalCount = 1
        if let container = WidgetPersistence.makeContainer(isDebug: isDebug) {
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

        defaults?.set(newIndex, forKey: pageKey)
        let kind = isDebug ? "AreaChainDebugDiaryWidget" : "AreaChainDiaryWidget"
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
        return .result()
    }
}

/// 手记一键微状态 / 心情打卡 Intent
struct DiaryQuickMoodIntent: AppIntent {
    static var title: LocalizedStringResource = "一键记录微状态"
    static var description = IntentDescription("在手记小组件中一键追加当前微状态与心情")

    @Parameter(title: "状态文案")
    var moodText: String

    @Parameter(title: "环境标识")
    var isDebug: Bool

    init() {
        self.moodText = "☕️ 摸鱼"
        self.isDebug = false
    }

    init(moodText: String, isDebug: Bool = false) {
        self.moodText = moodText
        self.isDebug = isDebug
    }

    func perform() async throws -> some IntentResult {
        guard let container = WidgetPersistence.makeContainer(isDebug: isDebug) else {
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
        let pageKey = isDebug ? "widget_diary_page_index_debug" : "widget_diary_page_index"
        defaults?.set(0, forKey: pageKey)
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

    @Parameter(title: "环境标识")
    var isDebug: Bool

    init() {
        self.tab = "todos"
        self.isDebug = false
    }

    init(tab: String, isDebug: Bool = false) {
        self.tab = tab
        self.isDebug = isDebug
    }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.areachain.app")
        let tabKey = isDebug ? "widget_tasks_active_tab_debug" : "widget_tasks_active_tab"
        defaults?.set(tab, forKey: tabKey)
        let kind = isDebug ? "AreaChainDebugTodayWidget" : "AreaChainTodayWidget"
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
        return .result()
    }
}
