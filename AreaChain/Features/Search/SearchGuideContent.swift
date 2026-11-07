import Foundation

/// 「搜索与指令」页的常用精选，全部映射至 `ActionRegistry` 中的标准 `BaseAction` 及 Linux CLI 示例。
struct SearchGuideFeatured: Identifiable, Equatable {
    enum Group: String, CaseIterable {
        case tasks, routines, diaries, tags, clipboard, navigation, system

        var titleKey: String { "searchGuide.featured.group." + rawValue }
    }

    let id: String
    let group: Group
    let actionID: ActionID
    let example: String

    var summaryKey: String { "searchGuide.featured.\(id).summary" }

    static let all: [SearchGuideFeatured] = [
        row(.tasks, "todo.create", "/todo 买牛奶 !p1 @15:30 #生活", id: "todo.create"),
        row(.tasks, "todo.move", "/move tomorrow", id: "todo.move"),
        row(.tasks, "todo.complete", "/done", id: "todo.completion"),
        row(.tasks, "todo.priority", "/priority p1", id: "todo.priority"),
        row(.tasks, "todo.tag", "/tag-todo 工作", id: "todo.tags"),
        row(.tasks, "todo.remind", "/remind 09:00", id: "todo.reminder"),
        row(.tasks, "todo.due", "/due 18:00", id: "todo.due"),
        row(.tasks, "todo.trash", "/rm", id: "todo.trash"),
        row(.tasks, "todo.move", "/move today", id: "tasks.postponeYesterday"),
        row(.tasks, "todo.move", "/move tomorrow", id: "batch.move"),
        row(.routines, "routine.create", "/habit 每日阅读", id: "routine.capture"),
        row(.routines, "routine.check", "/check", id: "occurrence.complete"),
        row(.routines, "routine.pause", "/pause-habit", id: "routine.enabled"),
        row(.diaries, "diary.create", "/diary 今日复盘 #随想", id: "diary.create"),
        row(.diaries, "diary.toTodo", "/diary-to-todo", id: "diary.toTodo"),
        row(.tags, "tag.create", "/new-tag 项目", id: "tag.create"),
        row(.tags, "tag.merge", "/merge-tag 旧名 新名", id: "tag.merge"),
        row(.clipboard, "clip.pin", "/clip-pin", id: "clipboard.paste"),
        row(.clipboard, "clip.togglePanel", "/clip", id: "clipboard.search"),
        row(.navigation, "go.today", "/today", id: "go"),
        row(.navigation, "ui.inspector", "/inspector", id: "inspector.open"),
        row(.system, "privacy.lock", "/lock", id: "privacy.lock"),
        row(.system, "pref.theme", "/theme dark", id: "setting.appearance"),
        row(.system, "trash.restore", "/restore", id: "trash.restore"),
    ]

    private static func row(_ group: Group, _ actionID: ActionID, _ example: String, id: String) -> Self {
        .init(id: id, group: group, actionID: actionID, example: example)
    }
}

/// 页首“基本用法”与“搜索条件速查”的条目。
enum SearchGuideSyntax {
    struct Condition: Identifiable {
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
