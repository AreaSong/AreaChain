import Foundation

/// 编辑状态与能力声明分离；解析成功永远不代表已经授权或可以执行。
enum CommandPathState: Equatable {
    case ordinaryText, group, scope, command, incompletePath, incompleteArguments, invalid
}

enum CommandPathIssue: Equatable {
    case unknownPath, ambiguous, invalidSyntax, invalidCursor, restricted
    case chooseParameter, invalidArgument, unsupportedTail
}

struct CommandPathDiagnostic: Equatable {
    let issue: CommandPathIssue
    let range: NSRange
    var commandIDs: [CommandID] = []
    var parameterIDs: [CommandParameterID] = []
}

/// 仅供调用方提出下一步编辑；刻意没有 execute / submit 分支。
enum CommandPathIntent: Equatable {
    case expand(CommandID)
    case complete(CommandID)
    case chooseParameter(CommandID, [CommandParameterID])
    case setArgument(CommandID, CommandArgument)
}

enum CommandPathMatch: Int, Equatable {
    case exactPath, pathPrefix, exactNameOrAlias, nameOrAliasPrefix, exactArgument, argumentPrefix
}

struct CommandPathCandidate: Identifiable, Equatable {
    let id: String
    let command: CommandDescriptor
    let title: String
    let summary: String
    let replacementRange: NSRange
    let insertText: String
    let intent: CommandPathIntent
    let match: CommandPathMatch

    var category: CommandCategory { command.category }
}

struct CommandPathResult: Equatable {
    let input: String
    var state: CommandPathState
    var command: CommandDescriptor?
    var arguments: [CommandArgument] = []
    var argumentIssues: [CommandArgumentIssue] = []
    var diagnostics: [CommandPathDiagnostic] = []
    var candidates: [CommandPathCandidate] = []
    var requiresCompositionEnd = false

    /// 必须显式接受本结果中的候选；拒绝旧缓冲、组合输入与非法 Unicode 边界。
    /// 返回值仍只是文本和参数修改意图，不发送通知、不保存、不执行。
    func accepting(
        _ candidate: CommandPathCandidate, in currentInput: String, hasMarkedText: Bool
    ) -> CommandPathEdit? {
        guard !hasMarkedText, !requiresCompositionEnd, currentInput.utf16.elementsEqual(input.utf16),
              candidates.contains(candidate), CommandPathText.valid(candidate.replacementRange, in: input) else { return nil }
        let text = (input as NSString).replacingCharacters(in: candidate.replacementRange, with: candidate.insertText)
        return CommandPathEdit(
            text: text, cursorLocation: candidate.replacementRange.location + candidate.insertText.utf16.count,
            intent: candidate.intent
        )
    }
}

struct CommandPathEdit: Equatable {
    let text: String
    let cursorLocation: Int
    let intent: CommandPathIntent
}

struct CommandPathRequest {
    let text: String
    var cursorLocation: Int?
    var locale = Locale(identifier: "en")
    var configuration = CommandDiscoveryConfiguration.standard
    var contentScopes: Set<CommandContentScope> = []
    var hasMarkedText = false
}

/// 与原生桥接一致使用 UTF-16；不钳制非法偏移，避免切断 emoji 或组合字符。
enum CommandPathText {
    static func valid(_ range: NSRange, in text: String) -> Bool {
        let length = text.utf16.count
        guard range.location >= 0, range.location <= length,
              range.length >= 0, range.length <= length - range.location,
              let swiftRange = Range(range, in: text) else { return false }
        return boundary(swiftRange.lowerBound, in: text) && boundary(swiftRange.upperBound, in: text)
    }

    private static func boundary(_ index: String.Index, in text: String) -> Bool {
        index == text.endIndex || text.indices.contains(index)
    }

    static func folded(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping.folding(
            options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")
        )
    }

    static func names(of entry: CommandDescriptor) -> [String] {
        ["en", "zh-Hans"].flatMap { language in
            let locale = Locale(identifier: language)
            return [entry.name(locale: locale)] + entry.aliases(locale: locale)
        }
    }
}
