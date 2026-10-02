import Foundation

/// 旧搜索与只读提供者共用同一 needle 语义；每个实例至多编译一次正则。
/// 同步 Foundation 正则没有此接口可承诺的取消或超时保障。
struct ClipboardTextMatching: CustomStringConvertible, CustomDebugStringConvertible {
    private let needle: String
    private let mode: ClipboardSearchMode
    private let expression: NSRegularExpression?
    let isValid: Bool

    init(needle: String, mode: ClipboardSearchMode) {
        self.needle = needle.trimmingCharacters(in: .whitespacesAndNewlines)
        self.mode = mode
        if mode == .regex && !self.needle.isEmpty {
            expression = try? NSRegularExpression(pattern: self.needle, options: [.caseInsensitive])
            isValid = expression != nil
        } else {
            expression = nil
            isValid = true
        }
    }

    func matches(_ text: String) -> Bool {
        matchRanges(in: text) != nil
    }

    /// nil 表示不匹配；空数组表示空 needle 的无高亮浏览，零长度命中仍保留实际范围。
    func matchRanges(in text: String) -> [Range<String.Index>]? {
        guard isValid else { return nil }
        if needle.isEmpty { return [] }
        // exact 的过滤原来使用 contains；保留它与高亮 range(of:) 各自的 Foundation 语义。
        if mode == .exact { return text.contains(needle) ? ranges(in: text) : nil }
        let found = ranges(in: text)
        return found.isEmpty ? nil : found
    }

    func ranges(in text: String) -> [Range<String.Index>] {
        guard isValid, !needle.isEmpty, !text.isEmpty else { return [] }
        switch mode {
        case .exact: return text.range(of: needle).map { [$0] } ?? []
        case .regex:
            let range = NSRange(text.startIndex..., in: text)
            return expression?.matches(in: text, range: range).compactMap { Range($0.range, in: text) } ?? []
        case .mixed: return fuzzyRanges(in: text)
        }
    }

    private func fuzzyRanges(in text: String) -> [Range<String.Index>] {
        var search = text.startIndex
        var ranges: [Range<String.Index>] = []
        for character in needle {
            let rest = text[search...]
            guard let found = rest.firstIndex(where: {
                String($0).localizedCaseInsensitiveCompare(String(character)) == .orderedSame
            }) else { return [] }
            let next = text.index(after: found)
            ranges.append(found..<next)
            search = next
        }
        return ranges
    }

    var description: String { "ClipboardTextMatching(redacted)" }
    var debugDescription: String { description }
}
