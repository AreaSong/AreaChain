import Foundation

/// 命令行中内联的自然语言属性解析结果（标签、提醒时刻、四象限优先级与备注）。
struct ActionInlineNLP: Equatable, Hashable, Codable, Sendable {
    var cleanText: String
    var tags: [String]
    var remindMinutes: Int?
    var isImportant: Bool
    var isUrgent: Bool
    var hasPriorityToken: Bool
    var notes: String

    static let empty = ActionInlineNLP(
        cleanText: "", tags: [], remindMinutes: nil,
        isImportant: false, isUrgent: false, hasPriorityToken: false, notes: ""
    )

    var timeLabel: String? {
        guard let minutes = remindMinutes else { return nil }
        return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}

/// 解析后的统一动作命令与参数载荷。
struct ParsedActionArguments: Equatable, Hashable, Codable, Sendable {
    var rawInput: String
    var commandName: String
    var targetQuery: String?
    var positional: [String]
    var options: [String: String]
    var flags: Set<String>
    var inlineNLP: ActionInlineNLP

    init(
        rawInput: String = "",
        commandName: String = "",
        targetQuery: String? = nil,
        positional: [String] = [],
        options: [String: String] = [:],
        flags: Set<String> = [],
        inlineNLP: ActionInlineNLP = .empty
    ) {
        self.rawInput = rawInput
        self.commandName = commandName
        self.targetQuery = targetQuery
        self.positional = positional
        self.options = options
        self.flags = flags
        self.inlineNLP = inlineNLP
    }

    var joinedPositional: String { positional.joined(separator: " ") }

    func option(_ key: String) -> String? {
        if let exact = options[key] { return exact }
        let lower = key.lowercased()
        return options.first { $0.key.lowercased() == lower }?.value
    }

    func hasFlag(_ key: String) -> Bool {
        let lower = key.lowercased()
        if flags.contains(where: { $0.lowercased() == lower }) { return true }
        if let val = option(key)?.lowercased() {
            return val == "true" || val == "1" || val == "yes"
        }
        return false
    }

    func value(for parameterID: String, index: Int? = nil, defaultValue: String? = nil) -> String? {
        if let opt = option(parameterID), !opt.isEmpty { return opt }
        if let index, positional.indices.contains(index) { return positional[index] }
        return defaultValue
    }
}

/// 统一搜索框输入的顶层语法分类。
enum ParsedCLIInput: Equatable, Sendable {
    case command(ParsedActionArguments)
    case pipeline(ParsedActionArguments)
    case search(query: String)

    var actionArguments: ParsedActionArguments? {
        switch self {
        case .command(let args), .pipeline(let args): return args
        case .search: return nil
        }
    }
}

/// Tab 自动补全候选项类型。
enum ActionCompletionKind: String, Equatable, Hashable, Codable, Sendable {
    case command
    case parameterName
    case parameterValue
}

/// Tab 自动补全建议条目。
struct ActionCompletionCandidate: Equatable, Hashable, Codable, Sendable {
    let kind: ActionCompletionKind
    let insertText: String
    let completedInput: String
    let displayTitle: String
    let actionID: ActionID?
}

/// 统一搜索框 Linux 风格命令行、目标管道、动作名匹配与 Tab 补全解析器。
enum ActionCLIParser {
    static func parse(_ rawInput: String) -> ParsedCLIInput {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .search(query: "") }
        if trimmed.hasPrefix("/") {
            let withoutSlash = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            return .command(parseCommandBody(withoutSlash, rawInput: rawInput, targetQuery: nil))
        }
        if let pipeSplit = splitPipeline(in: trimmed) {
            let args = parseCommandBody(pipeSplit.commandPart, rawInput: rawInput, targetQuery: pipeSplit.targetPart)
            if !args.commandName.isEmpty { return .pipeline(args) }
        }
        return .search(query: trimmed)
    }

    /// 根据普通搜索词匹配已注册动作的名称、简写或中英文别名。
    static func matchActions(query: String, in actions: [ActionMetadataDescriptor]) -> [ActionMetadataDescriptor] {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingPrefix("/").trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return [] }
        let lower = cleaned.lowercased()
        return actions
            .compactMap { action -> (action: ActionMetadataDescriptor, rank: Int)? in
                guard let rank = matchRank(queryLower: lower, action: action) else { return nil }
                return (action, rank)
            }
            .sorted { lhs, rhs in
                lhs.rank != rhs.rank ? lhs.rank < rhs.rank : lhs.action.id < rhs.action.id
            }
            .map(\.action)
    }

    /// 根据当前输入前缀计算命令名或参数可选值的 Tab 自动补全列表。
    static func completions(for rawInput: String, in actions: [ActionMetadataDescriptor]) -> [ActionCompletionCandidate] {
        let trimmedLeading = rawInput.drop(while: \.isWhitespace)
        if trimmedLeading.hasPrefix("/") {
            return completeCommandBody(String(trimmedLeading.dropFirst()), prefixWrapper: "/", in: actions)
        }
        if let pipeRange = findPipelineOperatorRange(in: String(trimmedLeading)) {
            let leftPart = String(trimmedLeading[..<pipeRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            guard !leftPart.isEmpty else { return [] }
            var rightPart = String(trimmedLeading[pipeRange.upperBound...].drop(while: \.isWhitespace))
            let hasLeadingSlash = rightPart.hasPrefix("/")
            if hasLeadingSlash { rightPart.removeFirst() }
            let wrapper = "\(leftPart) > \(hasLeadingSlash ? "/" : "")"
            return completeCommandBody(rightPart, prefixWrapper: wrapper, in: actions)
        }
        return []
    }

    // MARK: - 内部解析实现

    private static func splitPipeline(in text: String) -> (targetPart: String, commandPart: String)? {
        guard let range = findPipelineOperatorRange(in: text) else { return nil }
        let left = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        var right = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if right.hasPrefix("/") { right = String(right.dropFirst()).trimmingCharacters(in: .whitespaces) }
        guard !left.isEmpty, !right.isEmpty else { return nil }
        return (left, right)
    }

    private static func findPipelineOperatorRange(in text: String) -> Range<String.Index>? {
        let activeSegment: Substring
        if let noteRange = text.range(of: #"(?<![:\\])(//|／／)"#, options: .regularExpression) {
            activeSegment = text[..<noteRange.lowerBound]
        } else {
            activeSegment = text[...]
        }
        var inQuote: Character?
        var idx = activeSegment.startIndex
        while idx < activeSegment.endIndex {
            let ch = activeSegment[idx]
            if let q = inQuote {
                if ch == q { inQuote = nil }
            } else if ch == "\"" || ch == "'" {
                inQuote = ch
            } else if ch == ">" {
                let hasLeftSpace = idx > activeSegment.startIndex && activeSegment[activeSegment.index(before: idx)].isWhitespace
                let nextIdx = activeSegment.index(after: idx)
                let hasRightSpace = nextIdx == activeSegment.endIndex || activeSegment[nextIdx].isWhitespace
                if hasLeftSpace || hasRightSpace { return idx..<nextIdx }
            }
            idx = activeSegment.index(after: idx)
        }
        return nil
    }

    private static func parseCommandBody(_ body: String, rawInput: String, targetQuery: String?) -> ParsedActionArguments {
        let (headSegment, noteRawSegment) = splitNoteSegment(in: body)
        let tokens = tokenizeShellWords(headSegment)
        guard let firstToken = tokens.first else {
            return ParsedActionArguments(rawInput: rawInput, commandName: "", targetQuery: targetQuery)
        }
        let commandName = firstToken.hasPrefix("/") ? String(firstToken.dropFirst()) : firstToken
        let extracted = extractOptionsAndPositionalTokens(from: Array(tokens.dropFirst()))
        let nlpInput = buildNLPInput(nonOptionTokens: extracted.nonOptionTokens, noteSegment: noteRawSegment)
        let captured = NaturalLanguageParser.parse(nlpInput, consumeDiaryPresetTags: true)
        let inlineNLP = ActionInlineNLP(
            cleanText: captured.cleanTitle, tags: captured.tagNames,
            remindMinutes: captured.remindMinutes, isImportant: captured.isImportant,
            isUrgent: captured.isUrgent, hasPriorityToken: captured.hasPriorityToken,
            notes: captured.notes
        )
        let cleanPositional = extracted.nonOptionTokens.compactMap { token -> String? in
            let parsedToken = NaturalLanguageParser.parse(token, consumeDiaryPresetTags: true)
            return parsedToken.hasContentTitle ? parsedToken.cleanTitle : nil
        }
        return ParsedActionArguments(
            rawInput: rawInput, commandName: commandName, targetQuery: targetQuery,
            positional: cleanPositional, options: extracted.options,
            flags: extracted.flags, inlineNLP: inlineNLP
        )
    }

    private static func splitNoteSegment(in text: String) -> (head: String, note: String?) {
        guard let range = text.range(of: #"(?<![:\\])(//|／／)"#, options: .regularExpression) else {
            return (text, nil)
        }
        let head = String(text[..<range.lowerBound])
        let note = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (head, note)
    }

    private static let booleanFlags: Set<String> = [
        "confirm", "private", "force", "plain", "all", "yes", "pinned", "unpinned", "done", "undone",
    ]

    private static func extractOptionsAndPositionalTokens(
        from tokens: [String]
    ) -> (options: [String: String], flags: Set<String>, nonOptionTokens: [String]) {
        var options: [String: String] = [:]
        var flags: Set<String> = []
        var nonOptionTokens: [String] = []
        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            if token.hasPrefix("--"), token.count > 2 {
                let body = String(token.dropFirst(2))
                if let eqIndex = body.firstIndex(of: "=") {
                    let key = String(body[..<eqIndex]).trimmingCharacters(in: .whitespaces)
                    let value = unquote(String(body[body.index(after: eqIndex)...]))
                    if !key.isEmpty { options[key] = value }
                } else if !booleanFlags.contains(body.lowercased()),
                          index + 1 < tokens.count,
                          !tokens[index + 1].hasPrefix("--") {
                    options[body] = unquote(tokens[index + 1])
                    index += 1
                } else {
                    flags.insert(body)
                    options[body] = "true"
                }
            } else {
                nonOptionTokens.append(token)
            }
            index += 1
        }
        return (options, flags, nonOptionTokens)
    }

    private static func buildNLPInput(nonOptionTokens: [String], noteSegment: String?) -> String {
        let joined = nonOptionTokens.joined(separator: " ")
        guard let noteSegment else { return joined }
        return joined.isEmpty ? "// \(noteSegment)" : "\(joined) // \(noteSegment)"
    }

    private static func tokenizeShellWords(_ text: String) -> [String] {
        var words: [String] = []
        var current = ""
        var activeQuote: Character?
        for ch in text {
            if let quote = activeQuote {
                if ch == quote { activeQuote = nil } else { current.append(ch) }
            } else if ch == "\"" || ch == "'" {
                activeQuote = ch
            } else if ch.isWhitespace {
                if !current.isEmpty {
                    words.append(current)
                    current.removeAll(keepingCapacity: true)
                }
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { words.append(current) }
        return words
    }

    private static func unquote(_ text: String) -> String {
        guard text.count >= 2 else { return text }
        if (text.hasPrefix("\"") && text.hasSuffix("\"")) || (text.hasPrefix("'") && text.hasSuffix("'")) {
            return String(text.dropFirst().dropLast())
        }
        return text
    }

    private static func matchRank(queryLower: String, action: ActionMetadataDescriptor) -> Int? {
        let names = action.commandNames.map { $0.lowercased() }
        let enTitle = action.englishTitle.lowercased()
        let zhTitle = action.chineseTitle.lowercased()
        let idLower = action.id.rawValue.lowercased()
        if names.contains(queryLower) || enTitle == queryLower || zhTitle == queryLower || idLower == queryLower { return 0 }
        if names.contains(where: { $0.hasPrefix(queryLower) }) { return 1 }
        if enTitle.hasPrefix(queryLower) || zhTitle.hasPrefix(queryLower) { return 2 }
        if names.contains(where: { $0.contains(queryLower) })
            || enTitle.contains(queryLower) || zhTitle.contains(queryLower) || idLower.contains(queryLower) {
            return 3
        }
        return nil
    }

    private static func completeCommandBody(
        _ body: String, prefixWrapper: String, in actions: [ActionMetadataDescriptor]
    ) -> [ActionCompletionCandidate] {
        let hasTrailingSpace = body.last?.isWhitespace == true
        let parts = body.split(whereSeparator: \.isWhitespace).map(String.init)
        if parts.isEmpty || (parts.count == 1 && !hasTrailingSpace) {
            let cmdPrefix = (parts.first ?? "").lowercased()
            return completeCommandNames(prefix: cmdPrefix, prefixWrapper: prefixWrapper, in: actions)
        }
        let commandToken = parts[0].lowercased()
        guard let matchedAction = actions.first(where: { action in
            action.commandNames.contains { $0.lowercased() == commandToken } || action.id.rawValue.lowercased() == commandToken
        }) else { return [] }
        let currentToken = hasTrailingSpace ? "" : (parts.last ?? "")
        let priorTokens = hasTrailingSpace ? Array(parts.dropFirst()) : Array(parts.dropFirst().dropLast())
        let basePrefix = ([prefixWrapper + parts[0]] + priorTokens).joined(separator: " ")
        return completeParameters(currentToken: currentToken, priorTokens: priorTokens, basePrefix: basePrefix, action: matchedAction)
    }

    private static func completeCommandNames(
        prefix: String, prefixWrapper: String, in actions: [ActionMetadataDescriptor]
    ) -> [ActionCompletionCandidate] {
        actions.compactMap { action in
            guard let matchedName = action.commandNames.first(where: {
                prefix.isEmpty || $0.lowercased().hasPrefix(prefix)
            }) else { return nil }
            return ActionCompletionCandidate(
                kind: .command, insertText: matchedName,
                completedInput: "\(prefixWrapper)\(matchedName) ",
                displayTitle: "\(matchedName) — \(action.chineseTitle) (\(action.englishTitle))",
                actionID: action.id
            )
        }
    }

    private static func completeParameters(
        currentToken: String, priorTokens: [String], basePrefix: String, action: ActionMetadataDescriptor
    ) -> [ActionCompletionCandidate] {
        if currentToken.hasPrefix("--") {
            return completeOptionToken(String(currentToken.dropFirst(2)), basePrefix: basePrefix, action: action)
        }
        let positionalIndex = priorTokens.filter { !$0.hasPrefix("--") }.count
        let specs = action.parameters.indices.contains(positionalIndex) ? [action.parameters[positionalIndex]] : action.parameters
        let lowerToken = currentToken.lowercased()
        return specs.flatMap { spec in
            spec.allowedValues
                .filter { lowerToken.isEmpty || $0.lowercased().hasPrefix(lowerToken) }
                .map { val in
                    ActionCompletionCandidate(
                        kind: .parameterValue, insertText: val,
                        completedInput: "\(basePrefix) \(val)", displayTitle: val, actionID: action.id
                    )
                }
        }
    }

    private static func completeOptionToken(
        _ optionBody: String, basePrefix: String, action: ActionMetadataDescriptor
    ) -> [ActionCompletionCandidate] {
        if let eqIdx = optionBody.firstIndex(of: "=") {
            let paramKey = String(optionBody[..<eqIdx]).lowercased()
            let valPrefix = String(optionBody[optionBody.index(after: eqIdx)...]).lowercased()
            guard let spec = action.parameters.first(where: {
                $0.id.lowercased() == paramKey || $0.englishName.lowercased() == paramKey
            }) else { return [] }
            return spec.allowedValues
                .filter { valPrefix.isEmpty || $0.lowercased().hasPrefix(valPrefix) }
                .map { val in
                    ActionCompletionCandidate(
                        kind: .parameterValue, insertText: val,
                        completedInput: "\(basePrefix) --\(spec.id)=\(val)", displayTitle: val, actionID: action.id
                    )
                }
        }
        let keyPrefix = optionBody.lowercased()
        return action.parameters
            .filter { keyPrefix.isEmpty || $0.id.lowercased().hasPrefix(keyPrefix) }
            .map { spec in
                let token = "--\(spec.id)="
                return ActionCompletionCandidate(
                    kind: .parameterName, insertText: token,
                    completedInput: "\(basePrefix) \(token)",
                    displayTitle: "\(token) (\(spec.chineseName))", actionID: action.id
                )
            }
    }
}
