import Foundation

/// 子任务只解释标签；纯标签文本沿旧入口保留为标题，不解释优先级或时刻。
struct SubtaskTitleEdit: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let title: String
    let tagNames: [String]

    init?(_ rawInput: String) {
        let text = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        title = TagSyntax.title(from: text, includesDiaryTags: false)
        tagNames = TagSyntax.names(in: text, includesDiaryTags: false)
    }
    var description: String { "SubtaskTitleEdit(redacted)" }
    var debugDescription: String { description }
}

/// 已解析的字段；创建身份可缺省供旧入口使用，排序与创建时间仍由原仓储决定。
struct CreateSubtaskParams {
    let parentID: UUID
    let title: String
    var tagIDs = ""
    var creationID: UUID?
}

enum SubtaskFieldUpdate {
    case title(String, tagIDs: String), completion(Bool), tags(String)
}

enum SubtaskFields {
    static func title(_ subtask: SubtaskItem, title: String, tagIDs: String) {
        subtask.title = title
        subtask.tagIDs = tagIDs
    }
    static func completion(_ subtask: SubtaskItem, enabled: Bool) { subtask.isDone = enabled }
    static func tags(_ subtask: SubtaskItem, tagIDs: String) { subtask.tagIDs = tagIDs }
}
