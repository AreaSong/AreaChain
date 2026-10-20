import Foundation

/// 合并批 M-2 B：标签的只读查询指令。结果沿标签页同一取法（TagListQuery），不写库、不建 Run。
enum CommandTagQuery: Equatable {
    case search(String), view(TagListFilter), deleted

    static let commands: Set<String> = ["tag.search", "tag.view", "tag.deleted"]

    init(_ command: String, arguments: [CommandParameterID: CommandArgument]) throws {
        switch command {
        case "tag.search":
            guard case .shortText(let raw)? = arguments[.query]?.value else { throw CommandPageIssue.invalidArguments }
            let needle = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !needle.isEmpty else { throw CommandPageIssue.invalidArguments }
            self = .search(needle)
        case "tag.view":
            guard case .choice(let value)? = arguments[.kind]?.value, let filter = TagListFilter(rawValue: value) else {
                throw CommandPageIssue.invalidArguments
            }
            self = .view(filter)
        case "tag.deleted": self = .deleted
        default: throw CommandPageIssue.unsupported
        }
    }

    /// 与标签页同一份参数：搜索在“全部”视图里，已删除视图不看使用情况。
    var page: (filter: TagListFilter, showsDeleted: Bool, query: String) {
        switch self {
        case .search(let needle): (.all, false, needle)
        case .view(let filter): (filter, false, "")
        case .deleted: (.all, true, "")
        }
    }
}
