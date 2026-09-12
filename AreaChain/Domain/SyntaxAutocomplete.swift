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
    case search
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

        var tokenStart = cursor - 1
        while tokenStart >= 0 {
            let char = nsString.character(at: tokenStart)
            guard let scalar = UnicodeScalar(char) else { break }
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                tokenStart += 1
                break
            }
            if tokenStart == 0 {
                break
            }
            tokenStart -= 1
        }
        tokenStart = max(0, tokenStart)
        guard tokenStart < cursor else { return nil }

        let tokenLength = cursor - tokenStart
        let tokenRange = NSRange(location: tokenStart, length: tokenLength)
        let token = nsString.substring(with: tokenRange)
        guard let firstChar = token.first else { return nil }

        let kind: SyntaxTriggerKind
        switch firstChar {
        case "#": kind = .tag
        case "!": kind = .priority
        case "@": kind = .time
        default: return nil
        }

        if tokenStart > 0 {
            let prevChar = nsString.character(at: tokenStart - 1)
            if let prevScalar = UnicodeScalar(prevChar),
               !CharacterSet.whitespacesAndNewlines.contains(prevScalar),
               !CharacterSet.punctuationCharacters.contains(prevScalar) {
                return nil
            }
        }

        let query = String(token.dropFirst())
        return SyntaxTrigger(kind: kind, query: query, range: tokenRange)
    }

    // MARK: - 候选构建 (Candidates)

    static func candidates(
        for trigger: SyntaxTrigger, availableTags: [String] = [], context: SyntaxInputContext = .capture
    ) -> [SyntaxCandidate] {
        switch trigger.kind {
        case .tag:
            return tagCandidates(query: trigger.query, tags: availableTags, context: context)
        case .priority:
            return priorityCandidates(query: trigger.query)
        case .time:
            // 搜索解析尚不支持时刻条件，不能用补全暗示它已经生效。
            return context == .search ? [] : timeCandidates(query: trigger.query)
        }
    }

    private static func tagCandidates(query: String, tags: [String], context: SyntaxInputContext) -> [SyntaxCandidate] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var result: [SyntaxCandidate] = []

        let filteredTags: [String]
        if trimmed.isEmpty {
            filteredTags = tags
        } else {
            filteredTags = tags.filter { $0.localizedCaseInsensitiveContains(trimmed) }
        }

        let hasExactMatch = tags.contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        if !trimmed.isEmpty && !hasExactMatch {
            result.append(
                SyntaxCandidate(
                    id: "new_tag_\(trimmed)",
                    title: "#\(trimmed)",
                    subtitle: context == .search ? "syntax.search.tag" : "新建标签",
                    insertText: "#\(trimmed) ",
                    kind: .tag,
                    isCreation: context == .capture
                )
            )
        }

        for tag in filteredTags {
            result.append(
                SyntaxCandidate(
                    id: "tag_\(tag)",
                    title: "#\(tag)",
                    subtitle: context == .search ? "syntax.search.tag" : "标签",
                    insertText: "#\(tag) ",
                    kind: .tag
                )
            )
        }

        return result
    }

    private static func priorityCandidates(query: String) -> [SyntaxCandidate] {
        let definitions: [(code: String, name: String)] = [
            ("p1", "重要且紧急"),
            ("p2", "重要不紧急"),
            ("p3", "紧急不重要"),
            ("p4", "不重要不紧急")
        ]

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matches = definitions.filter { item in
            guard !trimmed.isEmpty else { return true }
            return item.code.contains(trimmed) || item.name.contains(trimmed)
        }

        return matches.map { item in
            SyntaxCandidate(
                id: "priority_\(item.code)",
                title: "!\(item.code)",
                subtitle: item.name,
                insertText: "!\(item.code) ",
                kind: .priority
            )
        }
    }

    private static func timeCandidates(query: String) -> [SyntaxCandidate] {
        let presets: [(time: String, label: String)] = [
            ("09:00", "早上"),
            ("12:00", "中午"),
            ("15:00", "下午"),
            ("18:00", "傍晚"),
            ("21:00", "晚上")
        ]

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
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
            return item.time.contains(trimmed) || item.label.contains(trimmed)
        }

        for item in filtered {
            if !list.contains(where: { $0.title == "@\(item.time)" }) {
                list.append(
                    SyntaxCandidate(
                        id: "time_\(item.time)",
                        title: "@\(item.time)",
                        subtitle: item.label,
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
            return (formatted, "整点")
        }
        if digits.count == 3 || digits.count == 4 {
            let hStr = String(digits.prefix(digits.count == 3 ? 1 : 2))
            let mStr = String(digits.suffix(2))
            if let h = Int(hStr), let m = Int(mStr), h >= 0 && h < 24 && m >= 0 && m < 60 {
                let formatted = String(format: "%02d:%02d", h, m)
                return (formatted, "自定义时刻")
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
