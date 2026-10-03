import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct ClipboardContentQueryLifecycleTests {
    @Test func explicitModesAndFiltersRemainFrozenThroughTheGate() async throws {
        let f = try ClipboardSearchFixture()
        defer { f.cleanup() }
        var image = ClipboardQueryFixture.record(1, "catalog")
        image.imageFile = "synthetic-unread.png"
        try f.files.write([image, ClipboardQueryFixture.record(2, "cta")])
        try f.handoff.send(.query(.setInput("/clipboard has:image")))
        for mode in ClipboardSearchMode.allCases {
            var options = ContentQueryBatchOptions(clipboardMode: .explicit(mode, needle: mode == .regex ? "^cat.*g$" : "cta"))
            let handle = try f.prepare(options: options)
            options.clipboardMode = .unified
            let result = try await f.publish(handle)
            #expect(result.response.matches.count == (mode == .exact ? 0 : 1))
            if case .clipboard(let read) = result.response.readings.first {
                #expect(read.mode == .legacy(mode))
                #expect(read.matches.allSatisfy { $0.id.id == image.id && $0.modeEvidence?.mode == mode })
            } else { Issue.record("Expected clipboard reading") }
        }
        try f.handoff.send(.query(.setInput("/clipboard catalog")))
        let unified = try await f.publish()
        if case .clipboard(let read) = unified.response.readings.first {
            #expect(read.mode == .unified && read.matches.count == 1)
        } else { Issue.record("Expected unified clipboard reading") }
    }

    @Test func richPayloadNeverEntersPublishedRowsOrSourceAndInvalidRegexIsRedacted() async throws {
        let f = try ClipboardSearchFixture()
        defer { f.cleanup() }
        var record = ClipboardQueryFixture.record(1, "synthetic safe summary")
        record.html = "synthetic-rich-payload-marker"
        record.rtf = Data("synthetic-rtf-marker".utf8)
        record.imageFile = "synthetic-image-marker.png"
        record.filePaths = [f.files.root.appending(path: "synthetic-path-marker").path]
        try f.files.write([record])
        let publication = try await f.publish()
        let row = try #require(publication.pagination.snapshot.source.rows.first)
        #expect(row.summary?.text == record.plainText)
        #expect(row.expansion.allSatisfy { $0.field == .clipboardPlainText })
        #expect(!containsStoragePayload(publication))
        let invalid = try f.prepare(options: .init(clipboardMode: .explicit(.regex, needle: "[synthetic-secret-pattern")))
        let response = try await f.publish(invalid)
        #expect(response.response.matches.isEmpty)
        if case .clipboard(let read) = response.response.readings.first {
            #expect(read.diagnostics.map(\.issue) == [.invalidRegex])
            #expect(!String(reflecting: read.diagnostics).contains("synthetic-secret-pattern"))
        } else { Issue.record("Expected invalid regex diagnostic") }
    }

    private func containsStoragePayload(_ value: Any) -> Bool {
        if value is ClipboardHistoryRecord || value is Data { return true }
        return Mirror(reflecting: value).children.contains { child in
            if let label = child.label, ["html", "rtf", "imageFile", "filePaths", "contentHash"].contains(label) { return true }
            return containsStoragePayload(child.value)
        }
    }

    @Test func realFileFlowsThroughFrozenOwnerSortingSnippetsAndPagination() async throws {
        let f = try ClipboardSearchFixture()
        defer { f.cleanup() }
        let original = (1...25).map { ClipboardQueryFixture.record($0, "synthetic \($0)") }
        try f.files.write(original)
        var reads = 0
        let reader = ClipboardContentQueryReader(store: f.files.store) { url in reads += 1; return try Data(contentsOf: url) }
        let handle = try f.prepare(reader: reader)
        try f.files.write([ClipboardQueryFixture.record(100, "replacement")])
        let publication = try await f.publish(handle)
        let snapshot = publication.pagination.snapshot
        #expect(reads == 1 && snapshot.units.count == 25 && snapshot.visible.count == 20)
        #expect(snapshot.source.source.ordered.map(\.id.id) == original.map(\.id))
        #expect(snapshot.source.rows.count == 25)
        #expect(snapshot.source.rows.allSatisfy { $0.summary?.text.isEmpty == false })
        #expect(try f.session.loadMore(.init(stamp: publication.pagination.stamp, action: .loadMoreUnits)).didPublish)
        #expect(try f.session.presentation().pagination.snapshot.visible.count == 25 && reads == 1)
        let next = try f.prepare(reader: reader)
        let renewed = try await f.publish(next)
        #expect(reads == 2 && renewed.task.requestID == publication.task.requestID)
        #expect(renewed.task.source != publication.task.source)
        #expect(renewed.pagination.snapshot.units.count == 1)
        #expect(renewed.response.matches.map(\.id.id) == [ClipboardQueryFixture.record(100).id])
        #expect(try f.session.loadMore(.init(stamp: publication.pagination.stamp, action: .loadMoreUnits)).rejection == .staleSource)
    }

    @Test func ordinaryCancellationKeepsOldPublicationButFailureNeverReusesOldRecords() async throws {
        let f = try ClipboardSearchFixture()
        defer { f.cleanup() }
        try f.files.write([ClipboardQueryFixture.record(1)])
        let original = try await f.publish()
        let cancelled = try f.prepare()
        try f.session.evaluate(cancelled)
        try f.session.cancel(cancelled)
        #expect(try f.session.presentation().task == original.task)
        await #expect(throws: ContentQueryReadSessionError.staleTask) { try await f.session.publish(cancelled) }
        try f.files.writeData(Data("broken-synthetic-json".utf8))
        let prepared = try f.session.prepareClipboard(reader: f.files.reader, requestID: original.task.requestID)
        #expect(prepared.state == .failed(.decodingFailed))
        let failure = try await f.publish(prepared.handle)
        #expect(failure.response.matches.isEmpty && failure.pagination.snapshot.visible.isEmpty)
        #expect(failure.response.completeness.providers.first?.limitations.contains(.source(.clipboardEntry, .failed)) == true)
        #expect(failure.task.source != original.task.source)
    }

    @Test func newPreparationAndReentrantReadRejectOldTasksEvenWithTheSameRequestID() async throws {
        let f = try ClipboardSearchFixture()
        defer { f.cleanup() }
        try f.files.write([ClipboardQueryFixture.record(1)])
        let old = try f.prepare()
        try f.session.evaluate(old)
        try f.files.write([ClipboardQueryFixture.record(2)])
        let newer = try f.prepare()
        let publication = try await f.publish(newer)
        await #expect(throws: ContentQueryReadSessionError.staleTask) { try await f.session.publish(old) }
        var reentrant: ContentQueryReadHandle?
        let reader = ClipboardContentQueryReader(store: f.files.store) { url in
            let oldData = try Data(contentsOf: url)
            try f.files.write([ClipboardQueryFixture.record(3)])
            reentrant = try f.prepare()
            return oldData
        }
        #expect(throws: ContentQueryReadSessionError.staleTask) { try f.prepare(reader: reader) }
        let prepared: ContentQueryReadHandle = try #require(reentrant)
        let latest = try await f.publish(prepared)
        #expect(latest.response.matches.map(\.id.id) == [ClipboardQueryFixture.record(3).id])
        #expect(latest.task.source != publication.task.source)
    }

    @Test func lockDuringReadAndBeforePublicationRevokesOldInputAndClearsQuery() async throws {
        let f = try ClipboardSearchFixture()
        defer { f.cleanup() }
        try f.files.write([ClipboardQueryFixture.record(1)])
        let reader = ClipboardContentQueryReader(store: f.files.store) { url in
            let data = try Data(contentsOf: url)
            f.vault.lock()
            return data
        }
        #expect(throws: ContentQueryReadSessionError.self) { try f.prepare(reader: reader) }
        #expect(!f.session.hasRetainedPresentation && !f.session.hasPublicationPermit)
        #expect(try f.handoff.state().query.binding == .independent(.privacyInvalidated))
        await f.settle()
        var blockedReads = 0
        let blocked = ClipboardContentQueryReader(store: f.files.store) { url in
            blockedReads += 1
            return try Data(contentsOf: url)
        }
        #expect(throws: ContentQueryReadSessionError.pageContextRequired) { try f.prepare(reader: blocked) }
        #expect(blockedReads == 0)
        try f.handoff.send(.query(.enterPage(QuerySessionFixture.page(.clipboard, host: HandoffFixture.source))))
        let handle = try f.prepare()
        try f.session.evaluate(handle)
        f.vault.lock()
        await #expect(throws: ContentQueryReadSessionError.self) { try await f.session.publish(handle) }
        #expect(!f.session.hasRetainedPresentation && !f.session.hasPublicationPermit)
    }

    @Test func focusAndPreReadGatesBlockIOAndRequireExplicitReread() async throws {
        let f = try ClipboardSearchFixture()
        defer { f.cleanup() }
        try f.files.write([ClipboardQueryFixture.record(1)])
        var reads = 0
        let reader = ClipboardContentQueryReader(store: f.files.store) { url in reads += 1; return try Data(contentsOf: url) }
        let handle = try f.prepare(reader: reader)
        try f.session.evaluate(handle)
        let query = try f.handoff.state().query
        f.focus.post(name: SearchReadFixture.focusLost, object: f.focusObject)
        #expect(throws: ContentQueryReadSessionError.masked) { try f.prepare(reader: reader) }
        await #expect(throws: ContentQueryReadSessionError.self) { try await f.session.publish(handle) }
        #expect(reads == 1 && !f.session.hasRetainedPresentation && !f.session.hasPublicationPermit)
        #expect(try f.handoff.state().query == query)
        try f.session.resumeDisplay(expecting: f.lease)
        #expect(throws: ContentQueryReadSessionError.self) { try f.session.presentation() }
        _ = try await f.publish(f.prepare(reader: reader))
        #expect(reads == 2)
        f.session.detach()
        #expect(throws: ContentQueryReadSessionError.detached) { try f.prepare(reader: reader) }
        #expect(reads == 2)
    }
}
