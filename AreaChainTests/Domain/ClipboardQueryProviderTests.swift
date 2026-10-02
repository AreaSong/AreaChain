import Foundation
import Testing
@testable import AreaChain

struct ClipboardQueryProviderTests {
    @Test(arguments: ["Alpha", "/tasks Alpha", "/tags Alpha", "/trash Alpha"])
    func ordinaryScopesDoNotEvaluateRecords(_ source: String) throws {
        var bad = ClipboardQueryFixture.record(1)
        bad.copiedAt = .init(timeIntervalSince1970: .nan)
        let session = TodoQueryFixture.session(source)
        let inputs: [ClipboardQueryInput] = [.unified(session), .explicit(try .init(mode: .regex, needle: "(",
            filters: TodoQueryFixture.session(source.components(separatedBy: " ").first == "Alpha" ? "" : String(source.split(separator: " ")[0]))))]
        for input in inputs {
            let result = ClipboardQueryFixture.read(input, records: .complete([bad, bad]))
            #expect(result.state == .notApplicable && result.matches.isEmpty)
            #expect(!result.coverage.didEvaluateRecords && result.coverage.coveredTypes.isEmpty && result.diagnostics.isEmpty)
        }
    }

    @Test func unifiedTextUsesAndPhraseOrExclusionAndOriginalUnicodeRanges() {
        let records = [ClipboardQueryFixture.record(1, "👩🏽‍💻 Cafe\u{301} beta Alpha 工作"),
                       ClipboardQueryFixture.record(2, "Alpha beta 归档"), ClipboardQueryFixture.record(3, "Alpha only")]
        let source = "/clipboard CAFE (missing | Alpha) beta -归档"
        let result = ClipboardQueryFixture.read(source, records)
        #expect(result.matches.map(\.id.id) == [records[0].id] && result.isCompleteForCoveredTypes)
        #expect(result.mode == .unified && result.matches[0].modeEvidence == nil)
        let ranges = result.matches[0].evidence.compactMap { $0.range }
        #expect(ranges.map { (records[0].plainText as NSString).substring(with: $0) } == ["Cafe\u{301}", "Alpha", "beta"])
        #expect(result.matches[0].evidence.contains { $0.kind == .absence && $0.range == nil })
        #expect(ClipboardQueryFixture.read("/clipboard \"Alpha beta\"", records).matches.map(\.id.id) == [records[1].id])
        #expect(ClipboardQueryFixture.read("/clipboard -\"Alpha beta\"", records).matches.map(\.id.id) == [records[0].id, records[2].id])
    }

    @Test func inputOrderIdentitiesAndFullTextArePreserved() {
        var first = ClipboardQueryFixture.record(1, String(repeating: "x", count: 240) + " needle")
        var second = ClipboardQueryFixture.record(2, first.plainText)
        first.copiedAt = first.copiedAt.addingTimeInterval(-100)
        second.pinnedAt = second.copiedAt
        first.pinKey = "a"
        second.pinKey = "a"
        let result = ClipboardQueryFixture.read("/clipboard needle", [first, second])
        #expect(result.matches.map(\.id) == [first, second].map { .init(type: .clipboardEntry, id: $0.id) })
        #expect(result.matches.map(\.pinKey) == ["a", "a"] && result.matches.map(\.isPinned) == [false, true])
        #expect(result.matches[0].plainText == first.plainText)
        #expect(result.matches[0].evidence.contains { $0.range == NSRange(location: 241, length: 6) })
        #expect(result.ordering.applied == .inputOrder && result.ordering.isComplete)
    }

    @Test func duplicateUUIDQuarantinesEntireGroupIncludingNonmatchingRecord() {
        let first = ClipboardQueryFixture.record(1)
        var duplicate = first
        duplicate.plainText = "does not match"
        let unique = ClipboardQueryFixture.record(2)
        let result = ClipboardQueryFixture.read("/clipboard Alpha", [first, unique, duplicate])
        #expect(result.matches.map(\.id.id) == [unique.id])
        #expect(result.undeterminedObjects == [.init(type: .clipboardEntry, id: first.id)])
        #expect(result.diagnostics.contains { $0.issue == .duplicateRecordID && $0.inputIndices == [0, 2] })
        #expect(!result.isCompleteForCoveredTypes && !result.ordering.isComplete)
    }

    @Test(arguments: ["#工作", "-#工作", "!p1", "@15:30", "status:open", "status:done", "status:skipped",
                      "created:2026-10-01", "on:2026-10-01"])
    func fieldsCannotBeInventedFromPlainText(_ condition: String) {
        let result = ClipboardQueryFixture.read("/clipboard " + condition, [ClipboardQueryFixture.record(1, condition)])
        #expect(result.queryIsValid && result.state == .inapplicableConditions && result.matches.isEmpty)
        #expect(result.typeAnalysis.assessment(for: .clipboardEntry)?.reasons.contains { $0.binding == .notApplicable } == true)
    }

    @Test func quotedSymbolsAreTextAndPayloadsNeverEnterHaystack() {
        var record = ClipboardQueryFixture.record(1, "#工作 !p1 /tasks plain/path.txt")
        record.html = "<b>html-marker</b>"
        record.rtf = Data("rtf-marker".utf8)
        record.imageFile = "image-marker.png"
        record.filePaths = ["/tmp/file-marker.txt"]
        record.contentHash = "hash-marker"
        for query in ["html-marker", "rtf-marker", "image-marker", "file-marker", "hash-marker", "com.example.Editor"] {
            #expect(ClipboardQueryFixture.read("/clipboard " + query, [record]).matches.isEmpty)
        }
        for query in ["\"#工作\"", "\"!p1\"", "\"/tasks\"", "\"plain/path.txt\""] {
            #expect(ClipboardQueryFixture.read("/clipboard " + query, [record]).matches.count == 1)
        }
    }

    @Test func noInjectedHistoryTruncationAtCaptureLimit() {
        let records = (1...1_030).map { ClipboardQueryFixture.record($0) }
        let result = ClipboardQueryFixture.read("/clipboard", records)
        #expect(result.matches.map(\.id.id) == records.map(\.id) && result.isCompleteForCoveredTypes)
    }
}
