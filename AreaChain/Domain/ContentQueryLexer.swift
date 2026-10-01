import Foundation

struct ContentQueryLexeme {
    enum Kind { case atom, open, close, or }
    let kind: Kind
    let raw: String
    let range: NSRange
    var literal = false
    var issues: [ContentQueryIssue] = []
}

/// 按 Character 前进、按 UTF-16 记录位置，避免切断 emoji 与组合字符。
enum ContentQueryLexer {
    static func scan(_ text: String, from start: String.Index) -> [ContentQueryLexeme] {
        let protected = TagSyntax.protectedRanges(in: text)
        var cursor = start
        var result: [ContentQueryLexeme] = []
        while cursor < text.endIndex {
            if text[cursor].isWhitespace { cursor = text.index(after: cursor); continue }
            let begin = cursor
            if let kind = punctuation(text[cursor]) {
                cursor = text.index(after: cursor)
                result.append(.init(kind: kind, raw: String(text[begin..<cursor]), range: NSRange(begin..<cursor, in: text)))
            } else {
                result.append(atom(text, cursor: &cursor, protected: protected))
            }
        }
        return result
    }

    private static func punctuation(_ char: Character) -> ContentQueryLexeme.Kind? {
        switch char {
        case "(": .open
        case ")": .close
        case "|": .or
        default: nil
        }
    }

    private static func atom(
        _ text: String, cursor: inout String.Index, protected: [NSRange]
    ) -> ContentQueryLexeme {
        let begin = cursor
        var quoted = false
        var literal = false
        var issues: [ContentQueryIssue] = []
        while cursor < text.endIndex {
            let char = text[cursor]
            if !quoted && (char.isWhitespace || punctuation(char) != nil) { break }
            let location = cursor.utf16Offset(in: text)
            // 转义由下方处理；代码/链接保护区整段保留为一个文字条件。
            if !quoted, char != "\\", let range = protected.first(where: { $0.location == location }),
               let swiftRange = Range(range, in: text) {
                cursor = swiftRange.upperBound
                literal = true
                continue
            }
            cursor = text.index(after: cursor)
            if char == "\\" {
                if cursor == text.endIndex { issues.append(.incompleteEscape); break }
                cursor = text.index(after: cursor)
                if !quoted { literal = true }
            } else if char == "\"" {
                quoted.toggle()
            }
        }
        if quoted { issues.append(.incompleteQuote) }
        return .init(kind: .atom, raw: String(text[begin..<cursor]), range: NSRange(begin..<cursor, in: text),
                     literal: literal, issues: issues)
    }
}
