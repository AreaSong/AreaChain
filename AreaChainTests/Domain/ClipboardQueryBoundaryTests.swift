import Foundation
import Testing
@testable import AreaChain

struct ClipboardQueryBoundaryTests {
    @Test func collectionCoverageDistinguishesEmptyPartialMissingAndFailure() {
        let input = ClipboardQueryInput.unified(TodoQueryFixture.session("/clipboard"))
        let complete = ClipboardQueryFixture.read(input, records: .complete([]))
        #expect(complete.isCompleteForCoveredTypes && complete.matches.isEmpty && complete.state == .evaluated)
        let partial = ClipboardQueryFixture.read(input, records: .partial([ClipboardQueryFixture.record(1)]))
        #expect(partial.matches.count == 1 && partial.state == .evaluated && !partial.isCompleteForCoveredTypes)
        #expect(partial.diagnostics.map(\.issue) == [.recordsPartial] && !partial.ordering.isComplete)
        let emptyPartial = ClipboardQueryFixture.read(input, records: .partial([]))
        #expect(emptyPartial.state == .evaluated && !emptyPartial.isCompleteForCoveredTypes)
        let missing = ClipboardQueryFixture.read(input, records: .notProvided)
        let failed = ClipboardQueryFixture.read(input, records: .failed)
        #expect(missing.state == .blocked && missing.diagnostics.map(\.issue) == [.recordsNotProvided])
        #expect(failed.state == .blocked && failed.diagnostics.map(\.issue) == [.recordsReadFailed])
        #expect(!missing.coverage.didEvaluateRecords && !failed.coverage.didEvaluateRecords)
        #expect(!failed.isCompleteForCoveredTypes && failed.coverage.records == .failed)
    }

    @Test func copiedAtUsesInjectedCivilDayAndDateIntersections() throws {
        let time = try #require(ISO8601DateFormatter().date(from: "2026-10-01T23:30:00Z"))
        var record = ClipboardQueryFixture.record(1)
        record.copiedAt = time
        for (zone, day) in [("Asia/Shanghai", "2026-10-02"), ("America/Los_Angeles", "2026-10-01")] {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: zone)!
            let page = ContentQueryPageContext(location: .init(hostID: "test", visitID: "visit", reference: "clipboard"),
                page: .clipboard, todayKey: day, calendar: calendar)
            let session = ContentQueryReducer.reduce(.init(page: page), .setInput("date:today date:2026-10-01..2026-10-02")).state
            let response = ClipboardQueryFixture.read(.unified(session), records: .complete([record]))
            #expect(response.matches.count == 1 && response.isCompleteForCoveredTypes)
            #expect(response.matches[0].evidence.filter { $0.field == .clipboardCapturedDay }.count == 2)
        }
        let conflict = ClipboardQueryFixture.read("/clipboard date:2026-10-01 date:2026-10-02", [record])
        #expect(conflict.state == .unsatisfiable && conflict.matches.isEmpty)
    }

    @Test(arguments: [Double.nan, Double.infinity, -Double.infinity, 1e20])
    func invalidTimestampsAreIsolatedEvenWithoutDateFilter(_ seconds: Double) {
        var bad = ClipboardQueryFixture.record(1)
        bad.copiedAt = Date(timeIntervalSince1970: seconds)
        let good = ClipboardQueryFixture.record(2)
        let result = ClipboardQueryFixture.read("/clipboard", [bad, good])
        #expect(result.matches.map(\.id.id) == [good.id] && !result.isCompleteForCoveredTypes)
        #expect(result.diagnostics.contains { $0.issue == .invalidCopiedAt && $0.inputIndices == [0] })
    }

    @Test func invalidPinTimeAndDateContextDoNotReachPresentation() {
        var record = ClipboardQueryFixture.record(1)
        record.pinnedAt = .init(timeIntervalSince1970: .nan)
        #expect(ClipboardQueryFixture.read("/clipboard", [record]).diagnostics.map(\.issue) == [.invalidPinnedAt])
        var session = TodoQueryFixture.session("/clipboard")
        session.page = .init(location: session.page.location, page: .clipboard, todayKey: "invalid", calendar: session.queryDates.calendar)
        let result = ClipboardQueryFixture.read(.unified(session), records: .complete([record]))
        #expect(result.state == .blocked && result.diagnostics.map(\.issue) == [.invalidDateContext])
    }

    @Test func imagePayloadIsIndependentOfAttachmentAssociationsAndFiles() {
        var valid = ClipboardQueryFixture.record(1)
        valid.imageFile = "synthetic-not-on-disk.png"
        let none = ClipboardQueryFixture.record(2)
        var invalid = ClipboardQueryFixture.record(3)
        invalid.imageFile = "../synthetic.png"
        var empty = ClipboardQueryFixture.record(4)
        empty.imageFile = ""
        let result = ClipboardQueryFixture.read("/clipboard has:image", [valid, none, invalid, empty])
        #expect(result.matches.map(\.id.id) == [valid.id] && result.matches[0].payload.image == .reference)
        #expect(result.matches[0].evidence.contains { $0.field == .clipboardImage && $0.relatedObject == nil })
        #expect(result.undeterminedObjects.map(\.id) == [invalid.id, empty.id])
        #expect(result.diagnostics.allSatisfy { $0.issue == .invalidImageReference && $0.affectsDetermination })
        let textOnly = ClipboardQueryFixture.read("/clipboard Alpha", [invalid])
        #expect(textOnly.matches.count == 1 && textOnly.isCompleteForCoveredTypes)
        #expect(textOnly.matches[0].payload.image == .invalidReference)
        #expect(textOnly.diagnostics.allSatisfy { !$0.affectsDetermination })
        #expect(ClipboardQueryFixture.read("/clipboard missing has:image", [invalid]).isCompleteForCoveredTypes)
    }

    @Test func malformedQueryScopesAndConditionIDsCannotBypassValidation() {
        let record = ClipboardQueryFixture.record(1)
        for query in ["/clipboard (Alpha |)", "/tasks /clipboard", "/clipboard \"unfinished"] {
            #expect(ClipboardQueryFixture.read(query, [record]).state == .invalidQuery)
        }
        var session = TodoQueryFixture.session("/clipboard Alpha")
        session.conditions.append(session.conditions[0])
        #expect(ClipboardQueryFixture.read(.unified(session), records: .complete([record])).state == .invalidQuery)
        let global = TodoQueryFixture.add(.page(.contentTypes([.clipboardEntry])), to: TodoQueryFixture.session("Alpha"))
        let result = ClipboardQueryFixture.read(.unified(global), records: .complete([record]))
        #expect(result.matches.isEmpty && !result.coverage.didEvaluateRecords)
    }
}
