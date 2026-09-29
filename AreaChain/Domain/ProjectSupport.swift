import Foundation

/// 应用内版本、支持和关于的稳定入口。问题报告只拼接环境字段，不能把用户正文放进这个类型。
enum ProjectSupport {
    static let repository = URL(string: "https://github.com/AreaSong/AreaChain")!
    static let usageHelp = URL(string: "https://github.com/AreaSong/AreaChain/discussions/categories/q-a")!
    static let featureRequest = URL(string: "https://github.com/AreaSong/AreaChain/discussions/categories/ideas")!
    static let bugReport = URL(string: "https://github.com/AreaSong/AreaChain/issues/new?template=bug-report.yml")!
    static let license = URL(string: "https://github.com/AreaSong/AreaChain/blob/main/LICENSE")!

    struct Environment: Equatable {
        var appVersion: String
        var buildNumber: String
        var macOSVersion: String
        var interfaceLanguage: String
    }

    enum IssueHandoff: Equatable {
        case copied
        case copiedBrowserFailed
        case copyFailed
    }

    /// 标题与 GitHub 问题表单的占位格式一致，不随界面语言改写，方便直接粘贴。
    static func environmentReport(_ environment: Environment) -> String {
        """
        ### 环境 / Environment
        App 版本 / App version: \(environment.appVersion) (\(environment.buildNumber))
        macOS: \(environment.macOSVersion)
        界面语言 / Interface language: \(environment.interfaceLanguage)
        """
    }

    static func issueHandoff(copied: Bool, opened: Bool) -> IssueHandoff {
        guard copied else { return .copyFailed }
        return opened ? .copied : .copiedBrowserFailed
    }
}
