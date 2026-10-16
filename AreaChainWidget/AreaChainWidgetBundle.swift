import SwiftUI
import WidgetKit

@main
struct AreaChainWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayTasksWidget()
        DiaryWidget()
    }
}
