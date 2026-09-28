import Foundation
import Testing
@testable import AreaChain

struct SyntaxHotPathTests {
    @Test func detectTriggerTypingStaysBounded() {
        let text = "准备周报 #工作 !p2 @15:30 会议"
        let nsText = text as NSString
        _ = SyntaxAutocompleteEngine.detectTrigger(in: text, cursorLocation: nsText.length)
        var samples: [TimeInterval] = []
        for _ in 1...3 {
            samples.append(elapsedSeconds {
                for cursor in 1...nsText.length {
                    for _ in 0..<80 {
                        _ = SyntaxAutocompleteEngine.detectTrigger(in: text, cursorLocation: cursor)
                    }
                }
            })
        }
        let median = medianElapsed(samples)
        #expect(median < 0.2, "detectTrigger median \(median)s")
        print("SYNTAX_TRIGGER detect=\(median)")
    }

    @Test func typedSearchReusesParsedQueryAndStaysEquivalent() {
        var todos: [TodoSnapshot] = []
        var diaries: [DiarySnapshot] = []
        for index in 0..<400 {
            todos.append(
                TodoSnapshot(
                    id: UUID(),
                    title: index.isMultiple(of: 7) ? "周报 \(index)" : "备忘 \(index)",
                    isDone: false,
                    dayKey: "2026-09-10",
                    isImportant: index.isMultiple(of: 5),
                    isUrgent: index.isMultiple(of: 9)
                )
            )
            diaries.append(
                DiarySnapshot(
                    id: UUID(),
                    text: index.isMultiple(of: 13) ? "周报想法 \(index)" : "随笔 \(index)",
                    dayKey: "2026-09-10",
                    createdAt: Date(timeIntervalSince1970: Double(index))
                )
            )
        }
        let prefixes = ["周", "周报", "周报 ", "周报 #", "周报 #工", "周报 会议", "周报 !p2", "周报 @15:30"]
        var parsedHits: [[BoardSearchHit]] = []
        var stringHits: [[BoardSearchHit]] = []
        _ = typedSearch(prefixes: prefixes, todos: todos, diaries: diaries, parseOnce: true)
        _ = typedSearch(prefixes: prefixes, todos: todos, diaries: diaries, parseOnce: false)

        var indexedSamples: [TimeInterval] = []
        var naiveSamples: [TimeInterval] = []
        for _ in 1...3 {
            indexedSamples.append(elapsedSeconds {
                parsedHits = typedSearch(prefixes: prefixes, todos: todos, diaries: diaries, parseOnce: true)
            })
            naiveSamples.append(elapsedSeconds {
                stringHits = typedSearch(prefixes: prefixes, todos: todos, diaries: diaries, parseOnce: false)
            })
        }
        let indexedMedian = medianElapsed(indexedSamples)
        let naiveMedian = medianElapsed(naiveSamples)
        #expect(parsedHits == stringHits)
        #expect(
            indexedMedian < 0.2,
            "typed search indexed median \(indexedMedian)s vs naive median \(naiveMedian)s"
        )
        #expect(indexedMedian <= naiveMedian + 0.05)
        print("TYPED_SEARCH indexed=\(indexedMedian) naive=\(naiveMedian)")
    }

    private func typedSearch(
        prefixes: [String],
        todos: [TodoSnapshot],
        diaries: [DiarySnapshot],
        parseOnce: Bool
    ) -> [[BoardSearchHit]] {
        prefixes.map { raw in
            if parseOnce {
                let parsed = BoardSearch.parseQuery(raw)
                let hits = BoardSearch.hits(parsed, todos: todos, diaries: diaries, routines: [])
                _ = WorkspaceAttachmentQuery.matches(filename: "week-report.pdf", keywords: parsed.textKeywords)
                return hits
            }
            let hits = BoardSearch.hits(query: raw, todos: todos, diaries: diaries, routines: [])
            _ = WorkspaceAttachmentQuery.matches(filename: "week-report.pdf", query: raw)
            return hits
        }
    }

    private func elapsedSeconds(_ work: () -> Void) -> TimeInterval {
        let start = CFAbsoluteTimeGetCurrent()
        work()
        return CFAbsoluteTimeGetCurrent() - start
    }

    private func medianElapsed(_ samples: [TimeInterval]) -> TimeInterval {
        let ordered = samples.sorted()
        return ordered[ordered.count / 2]
    }
}
