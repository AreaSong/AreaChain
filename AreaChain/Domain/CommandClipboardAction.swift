import Foundation

/// 合并批 M-2 D：剪贴板历史的页面指令（显式 /clipboard 范围，不进普通搜索）。浏览与搜索只读；复制、粘贴、
/// 字母快捷复制与置顶沿历史页原入口；小窗置顶沿小窗现有窗口管理。删除、清空、记录控制与偏好不在这里（用户决策 1、2）。
enum CommandClipboardAction: Equatable {
    case browse, search(String, ClipboardSearchMode)
    case copy(UUID), paste(UUID, plain: Bool)
    case pin(UUID, Bool)
    case copyLetter(String)
    case pinWindow(Bool)

    static let commands: Set<String> = [
        "clipboard.browse", "clipboard.search", "clipboard.copy", "clipboard.paste", "clipboard.pastePlain",
        "clipboard.pinned", "clipboard.copyLetter", "clipboard.pinWindow",
    ]

    init(_ command: String, arguments: [CommandParameterID: CommandArgument], objects: [CommandObjectReference]) throws {
        func entry() throws -> UUID {
            guard objects.count == 1, objects[0].type == .clipboardEntry, objects[0].dayKey == nil else {
                throw CommandPageIssue.invalidTarget
            }
            return objects[0].id
        }
        func enabled() throws -> Bool {
            guard case .boolean(let value)? = arguments[.enabled]?.value else { throw CommandPageIssue.invalidArguments }
            return value
        }
        switch command {
        case "clipboard.browse": self = .browse
        case "clipboard.search":
            // 2G：query 可省略（代表空，浏览全部）；显式给出时沿参数校验非空单行。模式必须显式给出，不暗中模糊。
            guard case .choice(let raw)? = arguments[.mode]?.value, let mode = ClipboardSearchMode(rawValue: raw) else {
                throw CommandPageIssue.invalidArguments
            }
            var needle = ""
            if let argument = arguments[.query] {
                guard case .shortText(let text)? = argument.value else { throw CommandPageIssue.invalidArguments }
                needle = text
            }
            if mode == .regex, !needle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               (try? NSRegularExpression(pattern: needle.trimmingCharacters(in: .whitespacesAndNewlines))) == nil {
                throw CommandPageIssue.invalidArguments
            }
            self = .search(needle, mode)
        case "clipboard.copy": self = .copy(try entry())
        case "clipboard.paste": self = .paste(try entry(), plain: false)
        case "clipboard.pastePlain": self = .paste(try entry(), plain: true)
        case "clipboard.pinned": self = .pin(try entry(), try enabled())
        case "clipboard.copyLetter":
            guard case .choice(let letter)? = arguments[.letter]?.value, letter.count == 1 else { throw CommandPageIssue.invalidArguments }
            self = .copyLetter(letter)
        case "clipboard.pinWindow": self = .pinWindow(try enabled())
        default: throw CommandPageIssue.unsupported
        }
    }
}

/// 小窗的导航类指令（不建草稿）：打开、关闭、返回工作台。
enum CommandClipboardWindow: String, Equatable {
    case open = "clipboard.openWindow", close = "clipboard.closeWindow", workspace = "clipboard.workspace"
}
