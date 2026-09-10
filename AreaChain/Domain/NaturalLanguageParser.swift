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
        let priority = consumePriority(from: &text)
        let tagName = consumeTag(from: &text, consumeDiaryPresetTags: consumeDiaryPresetTags)
        let remindMinutes = consumeTime(from: &text)

        let fallbackTitle = firstLine.isEmpty ? input : firstLine
        let cleanTitle = cleanTitle(from: text, fallback: fallbackTitle)

        return ParsedCapture(
            rawInput: input,
            cleanTitle: cleanTitle,
            remindMinutes: remindMinutes,
            tagName: tagName,
            isImportant: priority.isImportant,
            isUrgent: priority.isUrgent,
            hasPriorityToken: priority.hasPriorityToken,
            notes: notesText
        )
    }

    private struct PriorityResult {
        let isImportant: Bool
        let isUrgent: Bool
        let hasPriorityToken: Bool

        static let none = PriorityResult(isImportant: false, isUrgent: false, hasPriorityToken: false)
    }

    private static func consumePriority(from text: inout String) -> PriorityResult {
        let priorityPattern = #"!(重要紧急|紧急重要|重要且紧急|重要不紧急|不重要紧急|重要|紧急|p[1-4]|P[1-4])"#
        guard let match = firstMatch(pattern: priorityPattern, in: text) else {
            return .none
        }
        text = text.replacingOccurrences(of: match, with: "")
        let token = match.lowercased()

        switch token {
        case "!重要紧急", "!紧急重要", "!重要且紧急", "!p1":
            return PriorityResult(isImportant: true, isUrgent: true, hasPriorityToken: true)
        case "!重要", "!重要不紧急", "!p2":
            return PriorityResult(isImportant: true, isUrgent: false, hasPriorityToken: true)
        case "!紧急", "!不重要紧急", "!p3":
            return PriorityResult(isImportant: false, isUrgent: true, hasPriorityToken: true)
        case "!p4":
            return PriorityResult(isImportant: false, isUrgent: false, hasPriorityToken: true)
        default:
            return .none
        }
    }

    private static func consumeTime(from text: inout String) -> Int? {
        guard let extracted = extractTime(from: text) else { return nil }
        text = text.replacingOccurrences(of: extracted.matchedString, with: "")
        return extracted.minutes
    }

    private static func cleanTitle(from text: String, fallback: String) -> String {
        let cleaned = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return cleaned.isEmpty ? fallback : cleaned
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
