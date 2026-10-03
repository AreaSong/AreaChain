import Foundation
import Testing
@testable import AreaChain

struct ContentQuerySnippetTests {
    private func snippet(_ text: String, hits: [(NSRange, Int)], budget: ContentQueryPresentationBudget = QueryPresentationFixture.budget)
        -> (ContentQueryDisplayText?, [ContentQueryPresentationDiagnostic]) {
        var diagnostics: [ContentQueryPresentationDiagnostic] = []
        let value = ContentQuerySnippet.make(text: text, field: .diaryBody,
            hits: hits.map { .init(range: $0.0, source: .condition(.init(rawValue: $0.1), alternative: 0), weight: $0.1) },
            budget: budget, diagnostics: &diagnostics)
        return (value, diagnostics)
    }

    @Test func compactWindowCoversMoreDistinctKnownConditions() throws {
        let text = "alpha" + String(repeating: ".", count: 80) + "beta gamma" + String(repeating: ".", count: 80)
        let known = [(NSRange(location: 0, length: 5), 0), (NSRange(location: 85, length: 4), 1),
                     (NSRange(location: 90, length: 5), 2)]
        let value = try #require(snippet(text, hits: known).0)
        #expect(QueryPresentationFixture.highlighted(value) == ["beta", "gamma"])
        #expect(value.text == "…....beta gamma....…")
        #expect(value == snippet(text, hits: known.reversed()).0)
    }

    @Test func duplicateVotesDoNotBeatTwoDifferentConditions() {
        let text = "a" + String(repeating: ".", count: 80) + "b c"
        let repeated = Array(repeating: (NSRange(location: 0, length: 1), 0), count: 30)
        let result = snippet(text, hits: repeated + [(.init(location: 81, length: 1), 1), (.init(location: 83, length: 1), 2)]).0
        #expect(QueryPresentationFixture.highlighted(result) == ["b", "c"])
    }

    @Test func equalCoveragePrefersCompactThenEarlier() {
        let text = "a.........b" + String(repeating: ".", count: 80) + "a b"
        let hits = [(NSRange(location: 0, length: 1), 0), (NSRange(location: 10, length: 1), 1),
                    (NSRange(location: 91, length: 1), 0), (NSRange(location: 93, length: 1), 1)]
        #expect(snippet(text, hits: hits).0?.mapping?.originalRange.location == 87)
        #expect(snippet("a" + String(repeating: ".", count: 80) + "a", hits: [(.init(location: 81, length: 1), 0),
            (.init(location: 0, length: 1), 0)]).0?.mapping?.originalRange.location == 0)
    }

    @Test func chineseEmojiCombiningAndNewlinesPreserveExactMappings() throws {
        let text = "前文👩🏽‍💻\nCafe\u{301}后文"
        let row = QueryPresentationFixture.todo("cafe", title: "任务", notes: text)
        let value = try #require(row.summary)
        #expect(QueryPresentationFixture.highlighted(value) == ["Cafe\u{301}"])
        let mapping = try #require(value.mapping)
        #expect((value.text as NSString).substring(with: mapping.range) == (text as NSString).substring(with: mapping.originalRange))
        #expect(Range(mapping.range, in: value.text) != nil)
        #expect(value.text.contains("\n"))
        let emoji = QueryPresentationFixture.todo("👩🏽‍💻", title: "任务", notes: "前👩🏽‍💻后")
        #expect(QueryPresentationFixture.highlighted(emoji.summary) == ["👩🏽‍💻"])
    }

    @Test func overlappingRangesMergeConditionSourcesWithoutHighlightingEllipsis() throws {
        let text = String(repeating: ".", count: 60) + "abcdef" + String(repeating: ".", count: 60)
        let value = try #require(snippet(text, hits: [(.init(location: 60, length: 4), 0),
            (.init(location: 62, length: 4), 1)]).0)
        #expect(value.highlights.count == 1 && value.highlights[0].sources.count == 2)
        #expect(value.highlights[0].contributions.map(\.originalRange) == [.init(location: 60, length: 4), .init(location: 62, length: 4)])
        #expect(QueryPresentationFixture.highlighted(value) == ["abcdef"])
        #expect(value.text.first == "…" && value.text.last == "…")
        #expect(value.highlights[0].range.location > 0)
        #expect(NSMaxRange(value.highlights[0].range) < value.text.utf16.count)
        #expect(value.highlights[0].originalRange == NSRange(location: 60, length: 6))
    }

    @Test func noncontiguousModeRangesDoNotPaintTheGap() {
        let result = QueryPresentationFixture.project(QueryPresentationFixture.clipboard("abc", text: "a-b-c", mode: .mixed))
        #expect(QueryPresentationFixture.highlighted(result.rows[0].summary) == ["a", "b", "c"])
        let long = QueryPresentationFixture.project(QueryPresentationFixture.clipboard("abc",
            text: String(repeating: ".", count: 80) + "a-b-c" + String(repeating: ".", count: 80), mode: .mixed))
        #expect(QueryPresentationFixture.highlighted(long.rows[0].summary) == ["a", "b", "c"])
    }

    @Test func hugeGraphemeIsNotSplitToMeetBudget() {
        let text = "a" + String(repeating: "\u{301}", count: 80)
        let result = snippet(text, hits: [])
        #expect(result.0 == nil && result.1.contains(.init(issue: .graphemeExceedsBudget)))
    }

    @Test func oversizedKnownHitDoesNotPretendAPartialRangeIsComplete() {
        let result = snippet(String(repeating: "a", count: 100), hits: [(.init(location: 20, length: 60), 0)])
        #expect(result.0 == nil && result.1.contains(.init(issue: .hitExceedsBudget)))
    }

    @Test func longTextAndCandidateWorkRemainBounded() throws {
        let text = String(repeating: "公开长文", count: 250_000) + "needle"
        let value = try #require(snippet(text, hits: [(.init(location: 1_000_000, length: 6), 0)]).0)
        #expect(value.text.utf16.count <= QueryPresentationFixture.budget.maxUTF16 + 2)
        #expect(QueryPresentationFixture.highlighted(value) == ["needle"])
        let hits = (0..<100).map { (NSRange(location: $0 * 5, length: 1), $0) }
        let limited = snippet(String(repeating: "a", count: 600), hits: hits,
            budget: .init(maxUTF16: 20, contextUTF16: 2, maxEvidence: 128, maxCandidates: 3))
        #expect(limited.1.contains(.init(issue: .candidateLimit)))
        #expect(limited.0!.text.utf16.count <= 22)
    }
}
