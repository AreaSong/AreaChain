import Foundation

enum SyntaxTokenKind: Equatable {
    case tag(name: String)
    case time(minutes: Int)
    case priority(isImportant: Bool, isUrgent: Bool, raw: String)
    case note(text: String)
}

struct SyntaxHighlightToken: Equatable {
    let kind: SyntaxTokenKind
    let range: NSRange
}

struct ParsedCapture: Equatable {
    var rawInput: String
    var cleanTitle: String
    var remindMinutes: Int?
    var tagName: String?
    var isImportant: Bool
    var isUrgent: Bool
    var hasPriorityToken: Bool = false
    var notes: String = ""
    var tagNames: [String] = []
    var hasContentTitle: Bool = true

    var hasTokens: Bool {
        remindMinutes != nil || tagName != nil || hasPriorityToken
    }

    var isTokenOnly: Bool {
        hasTokens && !hasContentTitle
    }

    var priorityLabel: String? {
        if isImportant && isUrgent { return "quadrant.iu" }
        if isImportant { return "quadrant.i" }
        if isUrgent { return "quadrant.u" }
        if hasPriorityToken { return "quadrant.rest" }
        return nil
    }

    var timeLabel: String? {
        guard let minutes = remindMinutes else { return nil }
        let h = minutes / 60
        let m = minutes % 60
        return String(format: "%02d:%02d", h, m)
    }
}

struct ParsedDiaryCapture: Equatable {
    var rawInput: String
    var cleanTitle: String
    var body: String
    var tagNames: [String] = []
    var hasNoteSeparator: Bool = false
    var hasContent: Bool = true
}

enum NaturalLanguageParser {
    static func parseTaskCapture(_ input: String) -> ParsedCapture {
        parse(input, consumeDiaryPresetTags: false)
    }

    static func parse(_ input: String, consumeDiaryPresetTags: Bool = true) -> ParsedCapture {
        let tagNames = TagSyntax.names(in: input, includesDiaryTags: consumeDiaryPresetTags)

        let baseTitlePart: String
        let finalNotes: String
        let noteRemind: Int?
        let notePriority: PriorityResult

        if let noteRange = findNoteRange(in: input) {
            baseTitlePart = String(input[..<noteRange.lowerBound])
            var noteRaw = String(input[noteRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            noteCleanTags(from: &noteRaw, consumeDiaryPresetTags: consumeDiaryPresetTags)
            notePriority = consumePriority(from: &noteRaw)
            // 备注中仅提取显式 @时间 语法（如 @14:00），避免误伤备注正文中的自然语言或URL
            noteRemind = firstMatch(
                pattern: #"(?<![^\s(\[（【])@\d{1,2}[:：]\d{2}(?=$|[\s,，.。;；!！?？)）\]】])"#, in: noteRaw
            ).flatMap(timeMinutes)
            if noteRemind != nil, let matchRange = firstMatchRange(pattern: #"(?<![^\s(\[（【])@\d{1,2}[:：]\d{2}(?=$|[\s,，.。;；!！?？)）\]】])"#, in: noteRaw) {
                noteRaw = (noteRaw as NSString).replacingCharacters(in: matchRange, with: "")
            }
            finalNotes = noteRaw
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        } else {
            let lines = input.components(separatedBy: .newlines)
            baseTitlePart = lines.first ?? ""
            finalNotes = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            noteRemind = nil
            notePriority = .none
        }

        var titleText = TagSyntax.removingTags(from: baseTitlePart, includesDiaryTags: consumeDiaryPresetTags)
        let titlePriority = consumePriority(from: &titleText)
        let titleRemind = consumeTime(from: &titleText)

        let priority = titlePriority.hasPriorityToken ? titlePriority : notePriority
        let remindMinutes = titleRemind ?? noteRemind

        let cleaned = titleText
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let hasTokens = !tagNames.isEmpty || priority.hasPriorityToken || remindMinutes != nil
        let cleanTitle = hasTokens ? cleaned : (cleaned.isEmpty ? (baseTitlePart.isEmpty ? input : baseTitlePart) : cleaned)
        let unescapedTitle = unescapeSyntax(cleanTitle)
        let unescapedNotes = unescapeSyntax(finalNotes)
        let hasContentTitle = !unescapedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return ParsedCapture(
            rawInput: input,
            cleanTitle: unescapedTitle,
            remindMinutes: remindMinutes,
            tagName: tagNames.first,
            isImportant: priority.isImportant,
            isUrgent: priority.isUrgent,
            hasPriorityToken: priority.hasPriorityToken,
            notes: unescapedNotes,
            tagNames: tagNames,
            hasContentTitle: hasContentTitle
        )
    }

    private static func noteCleanTags(from text: inout String, consumeDiaryPresetTags: Bool) {
        text = TagSyntax.removingTags(from: text, includesDiaryTags: consumeDiaryPresetTags)
    }

    private static func findNoteRange(in input: String) -> Range<String.Index>? {
        let pattern = #"(?<![:\\])(//|／／)"#
        return input.range(of: pattern, options: .regularExpression)
    }

    /// 长正文只接受显式属性语法，不把句子里的自然时间当成修改提醒的指令。
    static func parseTaskNotes(_ input: String) -> ParsedCapture {
        var text = TagSyntax.removingTags(from: input, includesDiaryTags: false)
        let priority = consumePriority(from: &text)
        let time = firstMatch(
            pattern: #"(?<![^\s(\[（【])@\d{1,2}[:：]\d{2}(?=$|[\s,，.。;；!！?？)）\]】])"#, in: text
        ).flatMap(timeMinutes)
        let tags = TagSyntax.names(in: input, includesDiaryTags: false)
        return ParsedCapture(
            rawInput: input, cleanTitle: input, remindMinutes: time, tagName: tags.first,
            isImportant: priority.isImportant, isUrgent: priority.isUrgent,
            hasPriorityToken: priority.hasPriorityToken, notes: input, tagNames: tags,
            hasContentTitle: !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
    }

    /// 提取输入文本中所有的语法高亮 Token 区间（用于输入框实时着色）
    static func extractHighlightTokens(in text: String) -> [SyntaxHighlightToken] {
        guard !text.isEmpty else { return [] }
        var tokens: [SyntaxHighlightToken] = []
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let protected = TagSyntax.protectedRanges(in: text)

        func isFree(_ range: NSRange) -> Bool {
            guard range.location != NSNotFound, NSMaxRange(range) <= nsText.length else { return false }
            if protected.contains(where: { NSIntersectionRange($0, range).length > 0 }) { return false }
            return !tokens.contains(where: { NSIntersectionRange($0.range, range).length > 0 })
        }

        // 1. 标签（#标签）
        for tag in TagSyntax.tokens(in: text, includesDiaryTags: false) {
            if isFree(tag.range) {
                tokens.append(SyntaxHighlightToken(kind: .tag(name: tag.name), range: tag.range))
            }
        }

        // 2. 优先级（!p1 ~ !p4 / !重要紧急 等）
        let priorityPattern = #"(?<![^\s(\[（【])!(重要紧急|紧急重要|重要且紧急|重要不紧急|不重要不紧急|不重要紧急|紧急不重要|重要|紧急|p[1-4]|P[1-4])(?=$|[\s,，.。;；:：!！?？)）\]】])"#
        if let regex = try? NSRegularExpression(pattern: priorityPattern) {
            let unprotected = TagSyntax.unprotectedText(text)
            for match in regex.matches(in: unprotected, options: [], range: fullRange) {
                if isFree(match.range) {
                    let raw = nsText.substring(with: match.range)
                    let result = priorityResult(for: raw)
                    tokens.append(SyntaxHighlightToken(
                        kind: .priority(isImportant: result.isImportant, isUrgent: result.isUrgent, raw: raw),
                        range: match.range
                    ))
                }
            }
        }

        // 3. 时间时刻（@15:30 或 中文时刻）
        if let time = extractTime(from: text), isFree(time.range) {
            tokens.append(SyntaxHighlightToken(kind: .time(minutes: time.minutes), range: time.range))
        }

        // 4. 单行备注（// 或 ／／ 开始直到末尾，排除 URL 协议冒号，避开已有属性 Token）
        if let firstNote = findNoteRange(in: text) {
            let noteNSRange = NSRange(firstNote.lowerBound..<text.endIndex, in: text)
            var currentLoc = noteNSRange.location
            let endLoc = NSMaxRange(noteNSRange)

            let containedTokens = tokens
                .filter { $0.range.location >= currentLoc && NSMaxRange($0.range) <= endLoc }
                .sorted { $0.range.location < $1.range.location }

            for token in containedTokens {
                if token.range.location > currentLoc {
                    let freeRange = NSRange(location: currentLoc, length: token.range.location - currentLoc)
                    if isFree(freeRange) {
                        let noteSub = nsText.substring(with: freeRange)
                        tokens.append(SyntaxHighlightToken(kind: .note(text: noteSub), range: freeRange))
                    }
                }
                currentLoc = NSMaxRange(token.range)
            }
            if currentLoc < endLoc {
                let freeRange = NSRange(location: currentLoc, length: endLoc - currentLoc)
                if isFree(freeRange) {
                    let noteSub = nsText.substring(with: freeRange)
                    tokens.append(SyntaxHighlightToken(kind: .note(text: noteSub), range: freeRange))
                }
            }
        }

        return tokens.sorted { $0.range.location < $1.range.location }
    }

    static func timeMinutes(_ token: String) -> Int? {
        guard token.range(of: #"^@\d{1,2}[:：]\d{2}$"#, options: .regularExpression) != nil else { return nil }
        let parts = token.dropFirst().replacingOccurrences(of: "：", with: ":").split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        return hour * 60 + minute
    }

    private struct PriorityResult {
        let isImportant: Bool
        let isUrgent: Bool
        let hasPriorityToken: Bool

        static let none = PriorityResult(isImportant: false, isUrgent: false, hasPriorityToken: false)
    }

    private static func priorityResult(for token: String) -> PriorityResult {
        guard let flags = PriorityToken.flags(in: token) else { return .none }
        return PriorityResult(isImportant: flags.isImportant, isUrgent: flags.isUrgent, hasPriorityToken: true)
    }

    private static func consumePriority(from text: inout String) -> PriorityResult {
        let priorityPattern = #"(?<![^\s(\[（【])!(重要紧急|紧急重要|重要且紧急|重要不紧急|不重要不紧急|不重要紧急|紧急不重要|重要|紧急|p[1-4]|P[1-4])(?=$|[\s,，.。;；:：!！?？)）\]】])"#
        var lastResult: PriorityResult = .none
        while let range = firstMatchRange(pattern: priorityPattern, in: text) {
            let match = (text as NSString).substring(with: range)
            text = (text as NSString).replacingCharacters(in: range, with: "")
            lastResult = priorityResult(for: match)
        }
        return lastResult
    }

    private static func consumeTime(from text: inout String) -> Int? {
        var lastMinutes: Int? = nil
        while let extracted = extractTime(from: text) {
            text = (text as NSString).replacingCharacters(in: extracted.range, with: "")
            lastMinutes = extracted.minutes
        }
        return lastMinutes
    }

    private struct ExtractedTime {
        let minutes: Int
        let range: NSRange
    }

    private static func extractTime(from text: String) -> ExtractedTime? {
        // Pattern A: @15:30 or @9:00 or 15:30 or 09:30
        let standardPattern = #"(?<![^\s(\[（【])@?(\d{1,2})[:：](\d{2})(?=$|[\s,，.。;；!！?？)）\]】])"#
        if let match = matchRegex(pattern: standardPattern, in: text) {
            if let h = Int(match.group1), let m = Int(match.group2), h >= 0 && h < 24 && m >= 0 && m < 60 {
                return ExtractedTime(minutes: h * 60 + m, range: match.range)
            }
        }

        // Pattern B: 带时段（下午3点开会）；点后直接跟「问题」仍不当时刻
        let withPeriod = #"(早上|上午|中午|下午|晚上)\s*(\d{1,2})\s*点(?:半|(\d{1,2})分?)?(?!问题)"#
        if let match = matchChineseTime(pattern: withPeriod, in: text) {
            return match
        }

        // Pattern C: 无时段，必须是边界，避免「修复3点问题」
        let withoutPeriod = #"(\d{1,2})\s*点(?:半|(\d{1,2})分?)?(?=\s|$|[，。！？、；：]|[[:punct:]]|[#@!]|[和跟与在去到给把从向])"#
        if let match = matchBareChineseHour(pattern: withoutPeriod, in: text) {
            return match
        }

        return nil
    }

    private static func matchChineseTime(pattern: String, in text: String) -> ExtractedTime? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = text as NSString
        let range = NSRange(location: 0, length: nsString.length)
        guard let result = regex.firstMatch(in: TagSyntax.unprotectedText(text), options: [], range: range) else { return nil }

        let full = nsString.substring(with: result.range)
        var period = ""
        if result.range(at: 1).location != NSNotFound {
            period = nsString.substring(with: result.range(at: 1))
        }

        guard result.range(at: 2).location != NSNotFound,
              var hour = Int(nsString.substring(with: result.range(at: 2))) else {
            return nil
        }

        var minute = 0
        if full.contains("半") {
            minute = 30
        } else if result.numberOfRanges > 3 && result.range(at: 3).location != NSNotFound {
            minute = Int(nsString.substring(with: result.range(at: 3))) ?? 0
        }

        if (period == "下午" || period == "晚上") && hour < 12 {
            hour += 12
        } else if period == "早上" || period == "上午" {
            if hour == 12 { hour = 0 }
        }

        guard hour >= 0 && hour < 24 && minute >= 0 && minute < 60 else { return nil }
        return ExtractedTime(minutes: hour * 60 + minute, range: result.range)
    }

    private static func matchBareChineseHour(pattern: String, in text: String) -> ExtractedTime? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = text as NSString
        let range = NSRange(location: 0, length: nsString.length)
        guard let result = regex.firstMatch(in: TagSyntax.unprotectedText(text), options: [], range: range) else { return nil }

        let full = nsString.substring(with: result.range)
        guard result.range(at: 1).location != NSNotFound,
              let hour = Int(nsString.substring(with: result.range(at: 1))) else {
            return nil
        }

        var minute = 0
        if full.contains("半") {
            minute = 30
        } else if result.numberOfRanges > 2 && result.range(at: 2).location != NSNotFound {
            minute = Int(nsString.substring(with: result.range(at: 2))) ?? 0
        }

        guard hour >= 0 && hour < 24 && minute >= 0 && minute < 60 else { return nil }
        return ExtractedTime(minutes: hour * 60 + minute, range: result.range)
    }

    private static func firstMatch(pattern: String, in text: String) -> String? {
        guard let range = firstMatchRange(pattern: pattern, in: text) else { return nil }
        return (text as NSString).substring(with: range)
    }

    private static func firstMatchRange(pattern: String, in text: String) -> NSRange? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = text as NSString
        let range = NSRange(location: 0, length: nsString.length)
        guard let match = regex.firstMatch(in: TagSyntax.unprotectedText(text), options: [], range: range) else { return nil }
        return match.range
    }

    private struct MatchResult {
        let range: NSRange
        let group1: String
        let group2: String
    }

    private static func matchRegex(pattern: String, in text: String) -> MatchResult? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = text as NSString
        let range = NSRange(location: 0, length: nsString.length)
        guard let match = regex.firstMatch(in: TagSyntax.unprotectedText(text), options: [], range: range),
              match.numberOfRanges > 2,
              match.range(at: 1).location != NSNotFound,
              match.range(at: 2).location != NSNotFound else { return nil }
        return MatchResult(
            range: match.range,
            group1: nsString.substring(with: match.range(at: 1)),
            group2: nsString.substring(with: match.range(at: 2))
        )
    }

    // MARK: - 手记语法解析 (Diary Capture)

    static func parseDiaryCapture(_ input: String) -> ParsedDiaryCapture {
        let tagNames = TagSyntax.names(in: input, includesDiaryTags: true)
        let noteRange = findNoteRange(in: input)

        if let noteRange {
            let rawTitle = String(input[..<noteRange.lowerBound])
            let rawBody = String(input[noteRange.upperBound...])

            let cleanTitlePart = TagSyntax.removingTags(from: rawTitle, includesDiaryTags: true)
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            let cleanBodyPart = TagSyntax.removingTags(from: rawBody, includesDiaryTags: true)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let title = unescapeSyntax(cleanTitlePart)
            let body = unescapeSyntax(cleanBodyPart)
            let hasContent = !title.isEmpty || !body.isEmpty || !tagNames.isEmpty

            return ParsedDiaryCapture(
                rawInput: input,
                cleanTitle: title,
                body: body,
                tagNames: tagNames,
                hasNoteSeparator: true,
                hasContent: hasContent
            )
        } else {
            let cleanText = TagSyntax.removingTags(from: input, includesDiaryTags: true)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let unescaped = unescapeSyntax(cleanText)
            let hasContent = !unescaped.isEmpty || !tagNames.isEmpty

            return ParsedDiaryCapture(
                rawInput: input,
                cleanTitle: "",
                body: unescaped,
                tagNames: tagNames,
                hasNoteSeparator: false,
                hasContent: hasContent
            )
        }
    }

    // MARK: - 转义反编译 (Escape Unescaping)

    static func unescapeSyntax(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        let pattern = #"\\(//|／／|[#＃@＠!！])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "$1")
    }
}
