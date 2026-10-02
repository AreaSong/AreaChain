import Foundation

enum ContentQueryAtomParser {
    static func parse(
        _ token: ContentQueryLexeme, context: ContentQueryDateContext
    ) -> Result<ContentQueryTerm, Failure> {
        if let issue = token.issues.first { return .failure(.init(issue: issue)) }
        var raw = token.raw
        let excluded = raw.hasPrefix("-")
        if excluded { raw.removeFirst() }
        guard !raw.isEmpty else { return .failure(.init(issue: .incompleteCondition)) }
        let parsed = value(raw, literal: token.literal, context: context)
        return parsed.flatMap { atom in
            guard !excluded || atom.dimension == .text || atom.dimension == .tag else {
                return .failure(.init(issue: .unsupportedExclusion))
            }
            return .success(.init(atom: atom, excluded: excluded, range: token.range))
        }
    }

    struct Failure: Error { let issue: ContentQueryIssue }

    private static func value(
        _ raw: String, literal: Bool, context: ContentQueryDateContext
    ) -> Result<ContentQueryAtom, Failure> {
        if literal { return literalText(raw) }
        if raw.hasPrefix("/") { return .failure(.init(issue: .unsupportedStructure)) }
        if raw.hasPrefix("#") {
            let tags = TagSyntax.tokens(in: raw)
            guard tags.count == 1, let tag = tags.first, tag.range.length == raw.utf16.count else {
                return .failure(.init(issue: raw == "#" ? .incompleteCondition : .invalidCondition))
            }
            return .success(.tag(TagSyntax.normalizedName(tag.name)))
        }
        if raw.hasPrefix("\"") {
            let decoded = TagSyntax.decodedName(raw)
            guard !decoded.isEmpty else { return .failure(.init(issue: .invalidCondition)) }
            return .success(.text(decoded, phrase: true))
        }
        if raw.contains("\"") { return .failure(.init(issue: .unsupportedStructure)) }
        if raw.hasPrefix("!") {
            guard let flags = PriorityToken.flags(in: raw) else {
                return .failure(.init(issue: raw == "!" ? .incompleteCondition : .invalidCondition))
            }
            return .success(.priority(flags))
        }
        if raw.hasPrefix("@") {
            guard raw.range(of: #"^@[0-9]{2}:[0-9]{2}$"#, options: .regularExpression) != nil,
                  let minutes = NaturalLanguageParser.timeMinutes(raw), RemindMinutes.clamped(minutes) != nil else {
                return .failure(.init(issue: incompleteTime(raw) ? .incompleteCondition : .invalidCondition))
            }
            return .success(.reminder(minutes))
        }
        if let colon = raw.firstIndex(of: ":") {
            return field(String(raw[..<colon]), value: String(raw[raw.index(after: colon)...]), context: context)
        }
        return .success(.text(raw, phrase: false))
    }

    private static func field(
        _ field: String, value: String, context: ContentQueryDateContext
    ) -> Result<ContentQueryAtom, Failure> {
        guard !value.isEmpty else { return .failure(.init(issue: .incompleteCondition)) }
        switch field {
        case "status", "状态":
            switch value {
            case "open", "未完成": return .success(.status(.open))
            case "done", "已完成": return .success(.status(.done))
            case "skipped", "已跳过": return .success(.status(.skipped))
            default:
                let partial = ["open", "done", "skipped", "未完成", "已完成", "已跳过"].contains { $0.hasPrefix(value) }
                return .failure(.init(issue: partial ? .incompleteCondition : .invalidCondition))
            }
        case "on", "执行日":
            guard !value.contains("..") else { return .failure(.init(issue: .occurrenceDayMustBeSingle)) }
            return ContentQueryDates.parse(value, context: context)
                .map { .on($0.lowerBound) }.mapError { .init(issue: $0.issue) }
        case "date", "日期", "created", "创建日期":
            return ContentQueryDates.parse(value, context: context)
                .map { field == "date" || field == "日期" ? .date($0) : .created($0) }
                .mapError { .init(issue: $0.issue) }
        case "has", "包含":
            return value == "image" || value == "图片" ? .success(.image) : .failure(.init(issue: .invalidCondition))
        default: return .failure(.init(issue: .invalidCondition))
        }
    }

    private static func incompleteTime(_ raw: String) -> Bool {
        raw.range(of: #"^@(?:[0-2]?[0-9]?(?::[0-5]?[0-9]?)?)?$"#, options: .regularExpression) != nil
            && raw.count < 6
    }

    private static func literalText(_ raw: String) -> Result<ContentQueryAtom, Failure> {
        // 代码和 Markdown 链接沿 TagSyntax 原文保护；转义文字只解开语法标点。
        if raw.contains("`") || raw.hasPrefix("~~~") || raw.hasPrefix("[") {
            return .success(.text(raw, phrase: true))
        }
        var value = ""
        var escaped = false
        for char in raw {
            if escaped {
                guard "\\\"#@!-()|:/ ".contains(char) else { return .failure(.init(issue: .invalidEscape)) }
                value.append(char)
                escaped = false
            } else if char == "\\" { escaped = true }
            else { value.append(char) }
        }
        return .success(.text(value, phrase: false))
    }
}
