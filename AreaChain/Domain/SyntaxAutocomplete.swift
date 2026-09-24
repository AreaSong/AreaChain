import Foundation

/// 语法触发类型枚举
enum SyntaxTriggerKind: String, CaseIterable, Equatable, Sendable {
    case tag = "#"
    case priority = "!"
    case time = "@"

    var symbol: String { rawValue }
}

enum SyntaxInputContext: Equatable, Sendable {
    case capture
    case diaryCapture
    case search
    case tags
    case taskTags
    case tagSearch

    var isSearch: Bool { self == .search || self == .tagSearch }
    var includesDiaryTags: Bool { self != .capture && self != .taskTags }
    var supportsTaskAttributes: Bool { self == .capture || self == .search }
}

/// 语法触发信息
struct SyntaxTrigger: Equatable, Sendable {
    let kind: SyntaxTriggerKind
    let query: String
    let range: NSRange
}

/// 语法补全候选条目
struct SyntaxCandidate: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let subtitle: String?
    let insertText: String
    let kind: SyntaxTriggerKind
    let isCreation: Bool

    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        insertText: String,
        kind: SyntaxTriggerKind,
        isCreation: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.insertText = insertText
        self.kind = kind
        self.isCreation = isCreation
    }
}

/// 纯领域语法补全解析与计算引擎
enum SyntaxAutocompleteEngine {
    // MARK: - 触发检测 (Detection)

    static func detectTrigger(in text: String, cursorLocation: Int) -> SyntaxTrigger? {
        let nsString = text as NSString
        let cursor = max(0, min(cursorLocation, nsString.length))
        guard cursor > 0 else { return nil }
        guard !TagSyntax.protectedRanges(in: text).contains(where: { NSLocationInRange(cursor - 1, $0) }) else { return nil }
        let prefix = nsString.substring(to: cursor)
        let pattern = ##"(?<![^\s(\[（【])([#!@＃！＠])("(?:\\.|[^"\\\r\n])*"?|[\p{L}\p{M}\p{N}_:：.\-]*)$"##
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: prefix, range: NSRange(location: 0, length: cursor)) else { return nil }
        let rawSymbol = nsString.substring(with: match.range(at: 1))
        let symbol: String
        switch rawSymbol {
        case "#", "＃": symbol = "#"
        case "!", "！": symbol = "!"
        case "@", "＠": symbol = "@"
        default: symbol = rawSymbol
        }
        guard let kind = SyntaxTriggerKind(rawValue: symbol) else { return nil }
        let rawQuery = nsString.substring(with: match.range(at: 2))
        let query = rawQuery.hasPrefix("\"")
            ? String(rawQuery.dropFirst()).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            : rawQuery
        var range = match.range
        if kind == .tag, let whole = TagSyntax.tokens(in: text).first(where: {
            $0.range.location == range.location && NSMaxRange($0.range) >= cursor
        }) { range = whole.range }
        return SyntaxTrigger(kind: kind, query: query, range: range)
    }

    // MARK: - 候选构建 (Candidates)

    static func candidates(
        for trigger: SyntaxTrigger, availableTags: [String] = [], context: SyntaxInputContext = .capture
    ) -> [SyntaxCandidate] {
        switch trigger.kind {
        case .tag:
            return tagCandidates(query: trigger.query, tags: availableTags, context: context)
        case .priority:
            return context.supportsTaskAttributes ? priorityCandidates(query: trigger.query) : []
        case .time:
            guard context.supportsTaskAttributes else { return [] }
            return timeCandidates(query: trigger.query).map { candidate in
                guard context.isSearch else { return candidate }
                return SyntaxCandidate(
                    id: candidate.id, title: candidate.title, subtitle: "syntax.search.time",
                    insertText: candidate.insertText, kind: .time
                )
            }
        }
    }

    private static func tagPromptCandidate(query: String, existingTags: [String], context: SyntaxInputContext) -> SyntaxCandidate? {
        let hasExactMatch = existingTags.contains { TagSyntax.normalizedName($0) == TagSyntax.normalizedName(query) }
        if !query.isEmpty && !hasExactMatch {
            return SyntaxCandidate(
                id: "new_tag_\(query)",
                title: "#\(query)",
                subtitle: context.isSearch ? "syntax.search.tag" : "syntax.tag.create.on.save",
                insertText: TagSyntax.spelling(for: query) + " ",
                kind: .tag,
                isCreation: !context.isSearch
            )
        } else if query.isEmpty && existingTags.isEmpty && !context.isSearch {
            return SyntaxCandidate(
                id: "tag_empty_guide",
                title: "#...",
                subtitle: "syntax.tag.type.to.create",
                insertText: "#",
                kind: .tag,
                isCreation: true
            )
        }
        return nil
    }

    private static func tagCandidates(query: String, tags: [String], context: SyntaxInputContext) -> [SyntaxCandidate] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard context.includesDiaryTags || !DiaryMemoTags.isPresetName(trimmed) else { return [] }
        let tags = TagSyntax.uniqueNames(tags.filter { context.includesDiaryTags || !DiaryMemoTags.isPresetName($0) })
        var result: [SyntaxCandidate] = []

        let filteredTags: [String] = trimmed.isEmpty
            ? tags
            : tags.filter { $0.localizedCaseInsensitiveContains(trimmed) }

        if let prompt = tagPromptCandidate(query: trimmed, existingTags: tags, context: context) {
            result.append(prompt)
        }

        for tag in filteredTags {
            result.append(
                SyntaxCandidate(
                    id: "tag_\(tag)",
                    title: "#\(tag)",
                    subtitle: context.isSearch ? "syntax.search.tag" : "syntax.tag.label",
                    insertText: TagSyntax.spelling(for: tag) + " ",
                    kind: .tag
                )
            )
        }

        return result
    }

    private static func priorityCandidates(query: String) -> [SyntaxCandidate] {
        let definitions: [(code: String, subtitleKey: String, matchText: String)] = [
            ("p1", "syntax.priority.p1", "重要且紧急 important urgent"),
            ("p2", "syntax.priority.p2", "重要不紧急 important"),
            ("p3", "syntax.priority.p3", "紧急不重要 urgent"),
            ("p4", "syntax.priority.p4", "不重要不紧急 neither")
        ]

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matches = definitions.filter { item in
            guard !trimmed.isEmpty else { return true }
            return item.code.contains(trimmed) || spokenText(item.matchText, contains: trimmed)
        }

        return matches.map { item in
            SyntaxCandidate(
                id: "priority_\(item.code)",
                title: "!\(item.code)",
                subtitle: item.subtitleKey,
                insertText: "!\(item.code) ",
                kind: .priority
            )
        }
    }

    /// 「重要」不能命中「不重要」，「紧急」不能命中「不紧急」。
    private static func spokenText(_ haystack: String, contains needle: String) -> Bool {
        guard !needle.isEmpty else { return true }
        let haystack = haystack.lowercased()
        var start = haystack.startIndex
        while let range = haystack.range(of: needle, range: start..<haystack.endIndex) {
            let precededByNegation = range.lowerBound > haystack.startIndex
                && haystack[haystack.index(before: range.lowerBound)] == "不"
            if !precededByNegation { return true }
            start = haystack.index(after: range.lowerBound)
        }
        return false
    }

    private static func timeCandidates(query: String) -> [SyntaxCandidate] {
        let presets: [(time: String, subtitleKey: String, matchText: String)] = [
            ("09:00", "syntax.time.morning", "早上 morning"),
            ("12:00", "syntax.time.noon", "中午 noon"),
            ("15:00", "syntax.time.afternoon", "下午 afternoon"),
            ("18:00", "syntax.time.evening", "傍晚 evening"),
            ("21:00", "syntax.time.night", "晚上 night")
        ]

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let needle = trimmed.lowercased()
        var list: [SyntaxCandidate] = []

        if !trimmed.isEmpty, let custom = formatCustomTime(trimmed) {
            list.append(
                SyntaxCandidate(
                    id: "time_custom_\(custom.time)",
                    title: "@\(custom.time)",
                    subtitle: custom.label,
                    insertText: "@\(custom.time) ",
                    kind: .time,
                    isCreation: true
                )
            )
        }

        let filtered = presets.filter { item in
            guard !trimmed.isEmpty else { return true }
            return item.time.contains(trimmed) || item.matchText.lowercased().contains(needle)
        }

        for item in filtered {
            if !list.contains(where: { $0.title == "@\(item.time)" }) {
                list.append(
                    SyntaxCandidate(
                        id: "time_\(item.time)",
                        title: "@\(item.time)",
                        subtitle: item.subtitleKey,
                        insertText: "@\(item.time) ",
                        kind: .time
                    )
                )
            }
        }

        return list
    }

    private static func formatCustomTime(_ input: String) -> (time: String, label: String)? {
        let digits = input.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }

        if digits.count <= 2, let h = Int(digits), h >= 0 && h < 24 {
            let formatted = String(format: "%02d:00", h)
            return (formatted, "syntax.time.hour")
        }
        if digits.count == 3 || digits.count == 4 {
            let hStr = String(digits.prefix(digits.count == 3 ? 1 : 2))
            let mStr = String(digits.suffix(2))
            if let h = Int(hStr), let m = Int(mStr), h >= 0 && h < 24 && m >= 0 && m < 60 {
                let formatted = String(format: "%02d:%02d", h, m)
                return (formatted, "syntax.time.custom")
            }
        }
        return nil
    }

    // MARK: - 补全应用 (Apply Replacement)

    static func applyCandidate(
        _ candidate: SyntaxCandidate,
        to text: String,
        range: NSRange
    ) -> (newText: String, newCursor: Int) {
        let nsString = text as NSString
        guard range.location != NSNotFound,
              range.location + range.length <= nsString.length else {
            return (text, nsString.length)
        }
        let replacement = candidate.insertText
        let newText = nsString.replacingCharacters(in: range, with: replacement)
        let newCursor = range.location + (replacement as NSString).length
        return (newText, newCursor)
    }
}
