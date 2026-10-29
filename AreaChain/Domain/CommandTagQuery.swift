import Foundation

/// 标签的只读查询指令。结果沿标签页同一取法（TagListQuery），不写库、不建 Run。
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

/// 图片的只读浏览与原图查阅。浏览沿既有图片口径（已挂在对象上、附件中心可见），
/// 查阅沿普通图片的原图打开；受保护的不浏览、不打开。不写库、不建 Run。
enum CommandImageAction: Equatable {
    case browse(AttachmentOwner?), preview(CommandObjectReference)

    static let commands: Set<String> = ["image.browse", "image.preview"]

    init(_ command: String, arguments: [CommandParameterID: CommandArgument], objects: [CommandObjectReference]) throws {
        switch command {
        case "image.browse":
            // 目录给 kind 默认值 all；草稿里没写时按默认处理。
            let kind: String
            switch arguments[.kind]?.value {
            case .choice(let value)?: kind = value
            case nil: kind = "all"
            default: throw CommandPageIssue.invalidArguments
            }
            guard kind == "all" || AttachmentOwner(rawValue: kind) != nil else { throw CommandPageIssue.invalidArguments }
            self = .browse(AttachmentOwner(rawValue: kind))
        case "image.preview":
            guard objects.count == 1, objects[0].type == .image, objects[0].dayKey == nil else { throw CommandPageIssue.invalidTarget }
            self = .preview(objects[0])
        default: throw CommandPageIssue.unsupported
        }
    }
}
