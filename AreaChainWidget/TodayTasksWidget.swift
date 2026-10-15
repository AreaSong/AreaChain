import SwiftUI
import WidgetKit

struct TodayTasksWidget: Widget {
    let kind: String = "AreaChainTodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayTasksTimelineProvider()) { entry in
            TodayTasksWidgetView(entry: entry)
        }
        .configurationDisplayName("今日事项与习惯")
        .description("快速查看今日待办并直接在桌面打勾完成。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
