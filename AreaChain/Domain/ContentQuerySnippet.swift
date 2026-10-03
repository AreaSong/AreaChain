import Foundation

/// 内部依据只带范围与去重权重，不带正文副本；weight 把重复语义条件归为一票。
struct ContentQuerySnippetHit {
    let range: NSRange
    let source: ContentQueryHighlightSource
    let weight: Int
}

enum ContentQuerySnippet {
    struct Selection {
        let range: NSRange
        let coverage: Int
        let span: Int
    }

    static func make(text: String, field: ContentQueryMatchField, hits: [ContentQuerySnippetHit],
                     budget: ContentQueryPresentationBudget,
                     diagnostics: inout [ContentQueryPresentationDiagnostic]) -> ContentQueryDisplayText? {
        guard !text.isEmpty else { return nil }
        let original = text as NSString
        let known = hits.sorted { $0.range.location == $1.range.location
            ? $0.range.length < $1.range.length : $0.range.location < $1.range.location }
        let selection = select(original, hits: known, budget: budget, diagnostics: &diagnostics)
        guard let selection else { return nil }
        let leading = selection.location > 0 ? "…" : ""
        let trailing = NSMaxRange(selection) < original.length ? "…" : ""
        let display = leading + original.substring(with: selection) + trailing
        return .init(text: display, field: field,
            mapping: .init(originalRange: selection, range: .init(location: leading.utf16.count, length: selection.length)),
            highlights: highlights(known, window: selection, offset: leading.utf16.count),
            omittedPublicContent: !leading.isEmpty || !trailing.isEmpty)
    }

    private static func select(_ text: NSString, hits: [ContentQuerySnippetHit], budget: ContentQueryPresentationBudget,
                               diagnostics: inout [ContentQueryPresentationDiagnostic]) -> NSRange? {
        guard !hits.isEmpty else {
            let prefix = inward(.init(location: 0, length: min(text.length, budget.maxUTF16)), in: text)
            if prefix.length == 0 { diagnostics.append(.init(issue: .graphemeExceedsBudget)); return nil }
            return prefix
        }
        if text.length <= budget.maxUTF16 { return .init(location: 0, length: text.length) }
        var candidates: [NSRange] = []
        for hit in hits {
            for start in [max(0, hit.range.location - budget.contextUTF16), hit.range.location] {
                let range = inward(.init(location: start, length: min(budget.maxUTF16, text.length - start)), in: text)
                guard !candidates.contains(range) else { continue }
                if candidates.count == budget.maxCandidates {
                    if !diagnostics.contains(.init(issue: .candidateLimit)) { diagnostics.append(.init(issue: .candidateLimit)) }
                    break
                }
                candidates.append(range)
            }
            if candidates.count == budget.maxCandidates { break }
        }
        if candidates.count == budget.maxCandidates && hits.count > budget.maxCandidates / 2 {
            diagnostics.append(.init(issue: .candidateLimit))
        }
        let best = candidates.compactMap { candidate -> Selection? in
            let contained = hits.filter { contains(candidate, $0.range) }
            guard let first = contained.first, let end = contained.map({ NSMaxRange($0.range) }).max() else { return nil }
            // mixed 的非连续范围共同证明一次模式命中，完整容纳时优先于只露出一个字符。
            let mixed = hits.filter { $0.source == .clipboardMode(.mixed) }
            let coversMixed = !mixed.isEmpty && mixed.allSatisfy { contains(candidate, $0.range) }
            return .init(range: candidate, coverage: Set(contained.map(\.weight)).count + (coversMixed ? 1 : 0),
                         span: end - first.range.location)
        }.sorted {
            if $0.coverage != $1.coverage { return $0.coverage > $1.coverage }
            if $0.span != $1.span { return $0.span < $1.span }
            return $0.range.location < $1.range.location
        }.first
        guard let best else {
            diagnostics.append(.init(issue: .hitExceedsBudget))
            return nil
        }
        let contained = hits.filter { contains(best.range, $0.range) }
        let first = contained[0].range.location
        let end = contained.map { NSMaxRange($0.range) }.max() ?? first
        let start = max(best.range.location, first - budget.contextUTF16)
        let finish = min(NSMaxRange(best.range), end + budget.contextUTF16)
        return inward(.init(location: start, length: finish - start), in: text)
    }

    /// 只向内收边；预算容不下一个完整字素时返回空，不切开 emoji 或组合字符。
    private static func inward(_ range: NSRange, in text: NSString) -> NSRange {
        guard range.length > 0 else { return range }
        var start = range.location
        var end = NSMaxRange(range)
        let first = text.rangeOfComposedCharacterSequence(at: start)
        if first.location < start { start = NSMaxRange(first) }
        let last = text.rangeOfComposedCharacterSequence(at: end - 1)
        if NSMaxRange(last) > end { end = last.location }
        return .init(location: start, length: max(0, end - start))
    }

    private static func contains(_ outer: NSRange, _ inner: NSRange) -> Bool {
        inner.location >= outer.location && NSMaxRange(inner) <= NSMaxRange(outer)
    }

    private static func highlights(_ hits: [ContentQuerySnippetHit], window: NSRange, offset: Int) -> [ContentQueryHighlight] {
        var result: [ContentQueryHighlight] = []
        for hit in hits where contains(window, hit.range) {
            let contribution = ContentQueryHighlightContribution(
                range: .init(location: hit.range.location - window.location + offset, length: hit.range.length),
                originalRange: hit.range, source: hit.source)
            if let last = result.last, NSMaxRange(last.originalRange) > hit.range.location {
                let union = NSUnionRange(last.originalRange, hit.range)
                var sources = last.sources
                if !sources.contains(hit.source) { sources.append(hit.source) }
                var contributions = last.contributions
                if !contributions.contains(contribution) { contributions.append(contribution) }
                result[result.count - 1] = .init(range: .init(location: union.location - window.location + offset,
                    length: union.length), originalRange: union, sources: sources, contributions: contributions)
            } else {
                result.append(.init(range: .init(location: hit.range.location - window.location + offset,
                    length: hit.range.length), originalRange: hit.range, sources: [hit.source], contributions: [contribution]))
            }
        }
        return result
    }
}
