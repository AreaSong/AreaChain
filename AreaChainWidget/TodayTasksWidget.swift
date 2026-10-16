import SwiftUI
import WidgetKit

struct TodayTasksWidget: Widget {
    let kind: String = "AreaChainTodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayTasksTimelineProvider()) { entry in
            TodayTasksWidgetView(entry: entry)
        }
        .configurationDisplayName(WidgetL10n.isChinese ? "今日事项与习惯" : "Today’s Tasks & Habits")
        .description(WidgetL10n.isChinese ? "快速查看今日待办并直接在桌面打勾完成。" : "Quickly view today’s tasks and check them off right on your desktop.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
