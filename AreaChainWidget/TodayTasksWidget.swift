import SwiftUI
import WidgetKit

struct TodayTasksWidget: Widget {
    let kind: String = "AreaChainTodayWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: TodayTasksConfigurationIntent.self,
            provider: TodayTasksTimelineProvider()
        ) { entry in
            TodayTasksWidgetView(entry: entry)
        }
        .configurationDisplayName(WidgetL10n.isChinese ? "今日事项与习惯" : "Today’s Tasks & Habits")
        .description(WidgetL10n.isChinese ? "快速查看今日待办并直接在桌面打勾完成，支持右键切换正式/测试环境。" : "Quickly view today’s tasks and check them off. Supports editing environment.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
