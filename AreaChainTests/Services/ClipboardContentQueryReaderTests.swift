import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct ClipboardContentQueryReaderTests {
    @Test func onlyExplicitValidClipboardRequestsReadTheFile() throws {
        let f = ClipboardFileFixture()
        defer { f.cleanup() }
        var reads = 0
        let reader = ClipboardContentQueryReader(store: f.store) { _ in
            reads += 1
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError)
        }
        var sessions = ["", "Alpha", "/tasks", "/clipboard (Alpha |)", "/clipboard \"unfinished", "/settings"]
            .map { TodoQueryFixture.session($0) }
        var duplicate = TodoQueryFixture.session("/clipboard Alpha")
        duplicate.conditions.append(duplicate.conditions[0])
        sessions.append(duplicate)
        sessions.append(TodoQueryFixture.add(.page(.contentTypes([.clipboardEntry])), to: TodoQueryFixture.session("Alpha")))
        for session in sessions {
            let result = reader.read(session: session, requestID: TodoQueryFixture.requestID)
            #expect(result.state == .notRequested && result.batch.snapshots.clipboard.coverage == .notProvided)
        }
        #expect(reads == 0)
        let result = reader.read(session: TodoQueryFixture.session("/clipboard"), requestID: TodoQueryFixture.requestID)
        #expect(reads == 1 && result.state == .failed(.fileReadFailed))
        #expect(result.batch.snapshots.clipboard.coverage == .failed)
        #expect(!FileManager.default.fileExists(atPath: f.root.path))
    }

    @Test func modesUseOnlyExplicitOptionsAndIndependentFilters() throws {
        let f = ClipboardFileFixture()
        defer { f.cleanup() }
        try f.write([ClipboardQueryFixture.record(1, "catalog"), ClipboardQueryFixture.record(2, "cta")])
        let unified = try ClipboardFileFixture.response(f.read("/clipboard cta"))
        #expect(unified.mode == .unified && unified.matches.map(\.id.id) == [ClipboardQueryFixture.record(2).id])
        for mode in ClipboardSearchMode.allCases {
            var options = ContentQueryBatchOptions()
            options.clipboardMode = .explicit(mode, needle: mode == .regex ? "^cat.*g$" : "cta")
            let response = try ClipboardFileFixture.response(f.read(options: options))
            #expect(response.mode == .legacy(mode))
            let expected = mode == .mixed ? [1, 2] : mode == .exact ? [2] : [1]
            #expect(response.matches.map(\.id.id) == expected.map { ClipboardQueryFixture.record($0).id })
            #expect(response.matches.allSatisfy { $0.modeEvidence?.mode == mode })
        }
        var calls = 0
        let reader = ClipboardContentQueryReader(store: f.store) { url in calls += 1; return try Data(contentsOf: url) }
        let conflicting = reader.read(session: TodoQueryFixture.session("/clipboard cta"), requestID: UUID(),
            options: .init(clipboardMode: .explicit(.mixed, needle: "synthetic-mode")))
        #expect(calls == 0 && conflicting.state == .notRequested)
        #expect(ContentQueryBatchReader.read(conflicting.batch).completeness.providers.first?.limitations
            .contains(.clipboardMode(.conflictingTextConditions)) == true)
    }

    @Test func decodingPreservesDuplicatesBadFieldsAndInputOrderForTheProvider() throws {
        let f = ClipboardFileFixture()
        defer { f.cleanup() }
        var invalidTime = ClipboardQueryFixture.record(3)
        invalidTime.copiedAt = Date(timeIntervalSince1970: 1e20)
        var invalidImage = ClipboardQueryFixture.record(4)
        invalidImage.imageFile = "../synthetic-image.png"
        let duplicate = ClipboardQueryFixture.record(1)
        let records = [ClipboardQueryFixture.record(2), duplicate, invalidTime, duplicate, invalidImage]
        try f.write(records)
        let result = f.read()
        #expect(result.batch.snapshots.clipboard.records == records)
        #expect(result.batch.snapshots.clipboard.coverage == .complete)
        let response = try ClipboardFileFixture.response(result)
        #expect(response.matches.map(\.id.id) == [records[0].id, invalidImage.id])
        #expect(response.diagnostics.contains { $0.issue == .duplicateRecordID && $0.inputIndices == [1, 3] })
        #expect(response.diagnostics.contains { $0.issue == .invalidCopiedAt })
        #expect(response.diagnostics.contains { $0.issue == .invalidImageReference })
        #expect(!response.isCompleteForCoveredTypes)
    }

    @Test func fullRichPayloadIsDecodedButOnlyPlainTextIsSearchedAndPublished() throws {
        let f = ClipboardFileFixture()
        defer { f.cleanup() }
        var item = ClipboardQueryFixture.record(1, "synthetic plain text")
        item.html = "<a href='file:///synthetic-html-path'>rich-only-marker</a>"
        item.rtf = Data("synthetic-rtf-only-marker".utf8)
        item.imageFile = "synthetic-image-only-marker.png"
        item.filePaths = [f.root.appending(path: "synthetic-file-only-marker").path]
        item.contentHash = "synthetic-hash-only-marker"
        try f.write([item])
        var paths: [URL] = []
        let reader = ClipboardContentQueryReader(store: f.store) { url in
            paths.append(url)
            return try Data(contentsOf: url)
        }
        let read = reader.read(session: TodoQueryFixture.session("/clipboard synthetic"), requestID: UUID())
        #expect(paths == [f.file])
        #expect(read.batch.snapshots.clipboard.records == [item])
        let response = try ClipboardFileFixture.response(read)
        let match = try #require(response.matches.first)
        #expect(match.plainText == item.plainText && match.payload.hasHTML && match.payload.hasRTF && match.payload.hasFiles)
        #expect(match.payload.image == .reference)
        #expect(try ClipboardFileFixture.response(f.read("/clipboard rich-only-marker")).matches.isEmpty)
        let fields = Set(Mirror(reflecting: match).children.compactMap(\.label))
        #expect(fields.isDisjoint(with: ["html", "rtf", "imageFile", "filePaths", "contentHash", "record"]))
        for value in [String(reflecting: read), String(describing: read.batch), String(reflecting: match),
                      String(reflecting: response.diagnostics), String(reflecting: f.store.readHistory())] {
            #expect(!value.contains("only-marker") && !value.contains(f.root.path) && !value.contains(item.plainText))
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: f.root.path) == ["history.json"])
    }

    @Test func existingCaptureLimitsAreNotSilentReadLimits() throws {
        let f = ClipboardFileFixture()
        defer { f.cleanup() }
        var records = (1...1_030).map { ClipboardQueryFixture.record($0) }
        records[0].html = String(repeating: "x", count: ClipboardHistoryRules.maximumPayloadBytes + 1)
        try f.write(records)
        let read = f.read()
        #expect(read.batch.snapshots.clipboard.records == records)
        let response = try ClipboardFileFixture.response(read)
        #expect(response.matches.count == records.count && response.isCompleteForCoveredTypes)
    }
}
