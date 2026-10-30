import Foundation

/// 「搜索与指令」页的常用精选。顺序即显示顺序；示例必须能被 CommandPathParser 解析回 `command`，
/// 参数不能写进路径的指令只给路径，说明里写“回车后在面板里填写”。可用性不在这里判断，页面只读 disposition(for:)。
struct SearchGuideFeatured: Identifiable, Equatable {
    enum Group: String, CaseIterable {
        case tasks, routines, diaries, tags, clipboard, navigation, system

        var titleKey: String { "searchGuide.featured.group." + rawValue }
    }

    /// 行身份与说明文案键的后缀；普通行等于指令 ID，合并行（`go.*`）用 `go`。
    let id: String
    let group: Group
    /// 可用性与名称都取这一条；合并行取示例对应的那条。
    let command: CommandID
    /// 只在合并行时替换指令名称。
    let nameKey: String?
    let example: String

    var summaryKey: String { "searchGuide.featured.\(id).summary" }

    static let all: [SearchGuideFeatured] = [
        row(.tasks, "todo.create", "/tasks/add"),
        row(.tasks, "todo.move", "/tasks/move"),
        row(.tasks, "todo.completion", "/tasks/completion"),
        row(.tasks, "todo.priority", "/tasks/priority"),
        row(.tasks, "todo.tags", "/tasks/tags"),
        row(.tasks, "todo.reminder", "/tasks/reminder"),
        row(.tasks, "todo.due", "/tasks/due"),
        row(.tasks, "todo.trash", "/tasks/trash"),
        row(.tasks, "tasks.postponeYesterday", "/tasks/postpone-yesterday"),
        row(.tasks, "batch.move", "/tasks/batch/move"),
        row(.routines, "routine.capture", "/routines/capture"),
        row(.routines, "occurrence.complete", "/routines/checks/complete"),
        row(.routines, "routine.enabled", "/routines/enabled"),
        row(.diaries, "diary.create", "/diaries/add"),
        row(.diaries, "diary.toTodo", "/diaries/to-task"),
        row(.tags, "tag.create", "/tags/add"),
        row(.tags, "tag.merge", "/tags/merge"),
        row(.clipboard, "clipboard.search", "/clipboard/search"),
        row(.clipboard, "clipboard.paste", "/clipboard/paste"),
        row(.navigation, "go.today", "/go/today", id: "go", nameKey: "command.group.go.name"),
        row(.navigation, "inspector.open", "/inspector/open"),
        row(.system, "privacy.lock", "/privacy/lock"),
        row(.system, "setting.appearance", "/setting/appearance/dark"),
        row(.system, "trash.restore", "/trash/restore"),
    ]

    private static func row(_ group: Group, _ command: String, _ example: String,
                            id: String? = nil, nameKey: String? = nil) -> Self {
        .init(id: id ?? command, group: group, command: .init(rawValue: command), nameKey: nameKey, example: example)
    }
}

/// 页首“基本用法”与“搜索条件速查”的条目。写法以 docs/usage.md「统一搜索与指令」为准，不新造语法：
/// 运算符与机器字段（`!p1`、`date:`、`/trash`）原样显示，只有示例里的普通词随界面语言变化。
enum SearchGuideSyntax {
    struct Condition: Identifiable {
        /// 原样显示的写法；`tokenKey` 非 nil 时改用它的本地化示例词。
        let token: String
        let tokenKey: String?
        let key: String
        var id: String { key }
    }

    static let basics: [String] = [
        "searchGuide.basics.focus", "searchGuide.basics.search", "searchGuide.basics.command",
        "searchGuide.basics.preview", "searchGuide.basics.menubar",
    ]

    static let conditions: [Condition] = [
        local("word"), local("phrase"), local("exclude"), local("tag"),
        literal("!p1 … !p4", "priority"), literal("@15:30", "time"), literal("date:", "date"),
        literal("on:", "on"), literal("has:image", "image"), literal("/clipboard  /trash", "explicit"),
    ]

    private static func local(_ name: String) -> Condition {
        .init(token: "", tokenKey: "searchGuide.condition.\(name).token", key: "searchGuide.condition." + name)
    }

    private static func literal(_ token: String, _ name: String) -> Condition {
        .init(token: token, tokenKey: nil, key: "searchGuide.condition." + name)
    }
}
