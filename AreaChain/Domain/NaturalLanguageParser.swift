import Foundation

struct ParsedCapture: Equatable {
    var rawInput: String
    var cleanTitle: String
    var remindMinutes: Int?
    var tagName: String?
    var isImportant: Bool
    var isUrgent: Bool
    var hasPriorityToken: Bool = false
    var notes: String = ""

    var hasTokens: Bool {
        remindMinutes != nil || tagName != nil || hasPriorityToken
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

enum NaturalLanguageParser {
    static func parseTaskCapture(_ input: String) -> ParsedCapture {
        parse(input, consumeDiaryPresetTags: false)
    }

    static func parse(_ input: String, consumeDiaryPresetTags: Bool = true) -> ParsedCapture {
        let lines = input.components(separatedBy: .newlines)
        let firstLine = lines.first ?? ""
        let notesText = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        var text = firstLine
        var remindMinutes: Int? = nil
        var tagName: String? = nil
        var isImportant = false
        var isUrgent = false
        var hasPriorityToken = false

        // 1. Parse priority (!重要紧急, !重要, !紧急, !p1, !p2, !p3, !p4)
        let priorityPattern = #"!(重要紧急|紧急重要|重要且紧急|重要不紧急|不重要紧急|重要|紧急|p[1-4]|P[1-4])"#
        if let match = firstMatch(pattern: priorityPattern, in: text) {
            hasPriorityToken = true
            let token = match.lowercased()
            if token.contains("重要紧急") || token.contains("紧急重要") || token.contains("重要且紧急") || token == "!p1" {
                isImportant = true
                isUrgent = true
            } else if token == "!重要" || token.contains("重要不紧急") || token == "!p2" {
                isImportant = true
                isUrgent = false
            } else if token == "!紧急" || token.contains("不重要紧急") || token == "!p3" {
                isImportant = false
                isUrgent = true
            } else if token == "!p4" {
                isImportant = false
                isUrgent = false
            }
            text = text.replacingOccurrences(of: match, with: "")
        }

        // 2. Parse tag (#工作, #读书, #project1)
        tagName = consumeTag(from: &text, consumeDiaryPresetTags: consumeDiaryPresetTags)

        // 3. Parse Chinese time: (下午3点半, 下午3点, 晚上8:30, 早上9点15, 中午12点, 15:30, @15:30)
        let timeResult = extractTime(from: text)
        if let extracted = timeResult {
            remindMinutes = extracted.minutes
            text = text.replacingOccurrences(of: extracted.matchedString, with: "")
        }

        let cleanTitle = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return ParsedCapture(
            rawInput: input,
            cleanTitle: cleanTitle.isEmpty ? (firstLine.isEmpty ? input : firstLine) : cleanTitle,
            remindMinutes: remindMinutes,
            tagName: tagName,
            isImportant: isImportant,
            isUrgent: isUrgent,
            hasPriorityToken: hasPriorityToken,
            notes: notesText
        )
    }

    private struct ExtractedTime {
        let minutes: Int
        let matchedString: String
    }

    private static func extractTime(from text: String) -> ExtractedTime? {
        // Pattern A: @15:30 or @9:00 or 15:30 or 09:30
        let standardPattern = #"(?:@|\b)(\d{1,2})[:：](\d{2})\b"#
        if let match = matchRegex(pattern: standardPattern, in: text) {
            if let h = Int(match.group1), let m = Int(match.group2), h >= 0 && h < 24 && m >= 0 && m < 60 {
                return ExtractedTime(minutes: h * 60 + m, matchedString: match.full)
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
        guard let result = regex.firstMatch(in: text, options: [], range: range) else { return nil }

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
        return ExtractedTime(minutes: hour * 60 + minute, matchedString: full)
    }

    private static func matchBareChineseHour(pattern: String, in text: String) -> ExtractedTime? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = text as NSString
        let range = NSRange(location: 0, length: nsString.length)
        guard let result = regex.firstMatch(in: text, options: [], range: range) else { return nil }

        let full = nsString.substring(with: result.range)
        guard result.range(at: 1).location != NSNotFound,
              var hour = Int(nsString.substring(with: result.range(at: 1))) else {
            return nil
        }

        var minute = 0
        if full.contains("半") {
            minute = 30
        } else if result.numberOfRanges > 2 && result.range(at: 2).location != NSNotFound {
            minute = Int(nsString.substring(with: result.range(at: 2))) ?? 0
        }

        guard hour >= 0 && hour < 24 && minute >= 0 && minute < 60 else { return nil }
        return ExtractedTime(minutes: hour * 60 + minute, matchedString: full)
    }

    private static let tagPattern = #"#([a-zA-Z0-9_\u4e00-\u9fa5\-]+)"#

    private static func consumeTag(from text: inout String, consumeDiaryPresetTags: Bool) -> String? {
        guard let regex = try? NSRegularExpression(pattern: tagPattern) else { return nil }
        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        for match in matches {
            guard match.numberOfRanges > 1, match.range(at: 1).location != NSNotFound else { continue }
            let name = nsString.substring(with: match.range(at: 1))
            if consumeDiaryPresetTags || !DiaryMemoTags.isPresetName(name) {
                guard let range = Range(match.range, in: text) else { return name }
                text.removeSubrange(range)
                return name
            }
        }
        return nil
    }

    private static func firstMatch(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = text as NSString
        let range = NSRange(location: 0, length: nsString.length)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else { return nil }
        return nsString.substring(with: match.range)
    }

    private struct MatchResult {
        let full: String
        let group1: String
        let group2: String
    }

    private static func matchRegex(pattern: String, in text: String) -> MatchResult? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = text as NSString
        let range = NSRange(location: 0, length: nsString.length)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 2,
              match.range(at: 1).location != NSNotFound,
              match.range(at: 2).location != NSNotFound else { return nil }
        return MatchResult(
            full: nsString.substring(with: match.range),
            group1: nsString.substring(with: match.range(at: 1)),
            group2: nsString.substring(with: match.range(at: 2))
        )
    }
}
