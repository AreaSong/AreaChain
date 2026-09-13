import Foundation

struct TagSyntaxToken: Equatable {
    let name: String
    let range: NSRange
}

/// 标签识别、补全和搜索共用边界；转义、链接及代码中的符号始终按原文保留。
enum TagSyntax {
    private static let expression = try! NSRegularExpression(
        pattern: ##"(?<![^\s(\[（【])#(?:"((?:\\.|[^"\\\r\n])+)"|([\p{L}\p{M}\p{N}_-]+))(?=$|[\s,，.。;；:：!！?？)）\]】])"##
    )
    private static let codeExpression = try! NSRegularExpression(
        pattern: #"\x60{3}[\s\S]*?(?:\x60{3}|\z)|~~~[\s\S]*?(?:~~~|\z)|\x60[^\x60\r\n]*(?:\x60|\r?\n|\z)"#
    )

    static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
            .folding(options: [.caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    static func tokens(in text: String, includesDiaryTags: Bool = true) -> [TagSyntaxToken] {
        let source = text as NSString
        let protected = protectedRanges(in: text)
        return expression.matches(in: text, range: NSRange(location: 0, length: source.length)).compactMap { match in
            guard !protected.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) else { return nil }
            let raw = source.substring(with: match.range)
            let name = decodedName(String(raw.dropFirst()))
            guard !name.isEmpty, includesDiaryTags || !DiaryMemoTags.isPresetName(name) else { return nil }
            return TagSyntaxToken(name: name, range: match.range)
        }
    }

    static func names(in text: String, includesDiaryTags: Bool = true) -> [String] {
        uniqueNames(tokens(in: text, includesDiaryTags: includesDiaryTags).map(\.name))
    }

    static func uniqueNames(_ names: [String]) -> [String] {
        var seen: Set<String> = []
        return names.filter { name in
            let key = normalizedName(name)
            return !key.isEmpty && seen.insert(key).inserted
        }
    }

    static func removingTags(from text: String, includesDiaryTags: Bool = true) -> String {
        let result = NSMutableString(string: text)
        for token in tokens(in: text, includesDiaryTags: includesDiaryTags).reversed() {
            result.replaceCharacters(in: token.range, with: "")
        }
        return result as String
    }

    static func title(from text: String, includesDiaryTags: Bool = true) -> String {
        let cleaned = removingTags(from: text, includesDiaryTags: includesDiaryTags)
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return cleaned.isEmpty ? text.trimmingCharacters(in: .whitespacesAndNewlines) : cleaned
    }

    static func spelling(for name: String) -> String {
        if name.range(of: #"^[\p{L}\p{M}\p{N}_-]+$"#, options: .regularExpression) != nil {
            return "#" + name
        }
        let quoted = (try? JSONEncoder().encode(name)).flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
        return "#" + quoted
    }

    static func decodedName(_ token: String) -> String {
        guard token.hasPrefix("\"") else { return token }
        return (try? JSONDecoder().decode(String.self, from: Data(token.utf8))) ?? ""
    }

    static func protectedRanges(in text: String) -> [NSRange] {
        codeExpression.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length)).map(\.range)
    }

    static func isBoundary(before location: Int, in text: NSString) -> Bool {
        guard location > 0 else { return true }
        guard let scalar = UnicodeScalar(text.character(at: location - 1)) else { return false }
        return CharacterSet.whitespacesAndNewlines.contains(scalar) || "(（[【".unicodeScalars.contains(scalar)
    }

    static func unprotectedText(_ text: String) -> String {
        let result = NSMutableString(string: text)
        for range in protectedRanges(in: text).reversed() {
            result.replaceCharacters(in: range, with: String(repeating: " ", count: range.length))
        }
        return result as String
    }
}
