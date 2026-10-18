import AppIntents
import Foundation
import WidgetKit

enum WidgetEnvironmentMode: String, AppEnum {
    case release = "release"
    case debug = "debug"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "环境模式"
    static var caseDisplayRepresentations: [WidgetEnvironmentMode: DisplayRepresentation] = [
        .release: DisplayRepresentation(title: "正式环境 (Release)"),
        .debug: DisplayRepresentation(title: "开发调试 (Debug)")
    ]
}

struct TodayTasksConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "配置今日事项与习惯"
    static var description: IntentDescription = "选择显示正式环境或开发调试环境的数据"

    @Parameter(title: "数据环境", default: .release)
    var environment: WidgetEnvironmentMode

    init() {
        self.environment = .release
    }

    init(environment: WidgetEnvironmentMode) {
        self.environment = environment
    }
}

struct DiaryConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "配置今日手记与心情"
    static var description: IntentDescription = "选择显示正式环境或开发调试环境的数据"

    @Parameter(title: "数据环境", default: .release)
    var environment: WidgetEnvironmentMode

    init() {
        self.environment = .release
    }

    init(environment: WidgetEnvironmentMode) {
        self.environment = environment
    }
}
