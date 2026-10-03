import Foundation
import Testing
@testable import AreaChain

struct ContentQueryReadSnapshotTests {
    @Test func callerMutationCannotReplaceFrozenBatchAndFullPipelineMatchesDirectRead() throws {
        var batch = QueryReadFixture.batch()
        var expected = batch
        let owner = try QueryReadFixture.owner(batch)
        batch.snapshots.routines = .complete([])
        batch.facts.routine.scheduleEvidence = []
        batch.options.locale = Locale(identifier: "zh-Hans")
        batch.options.occurrenceWindow = RoutineOccurrenceQueryFixture.window("2026-11-01", "2026-11-10")
        try QueryReadFixture.complete(owner)
        expected.options.occurrenceBudget.maxResults = 10
        let direct = ContentQueryDisplayBuilder.build(ContentQueryPresenter.project(
            QuerySortFixture.sort(expected), budget: .init(), locale: expected.options.locale))
        let actual = owner.published!.pagination.snapshot
        #expect(actual.source.source.source.matches == direct.source.source.source.matches)
        #expect(actual.source.source.source.completeness == direct.source.source.source.completeness)
        #expect(actual.source.source.ordered == direct.source.source.ordered && actual.source.rows == direct.source.rows)
        #expect(actual.units == direct.units && actual.source.locale == expected.options.locale)
        #expect(actual.known.count == 10)
        #expect(ContentQueryBatchReader.read(batch).definiteMatchCount == 0)
    }

    @Test func completingBudgetDoesNotEraseHistoryConflictOrRecordGaps() throws {
        var batch = QueryReadFixture.batch(results: 0)
        batch.facts.routine.scheduleEvidence = []
        batch.facts.routine.checkCoverage = []
        batch.facts.routine.checks = [RoutineQueryFixture.check(.completed, id: QueryBatchFixture.id),
            RoutineQueryFixture.check(.skipped, id: QueryBatchFixture.id)]
        let owner = try QueryReadFixture.owner(batch)
        #expect(!ContentQueryContinuationRemainder(owner.published!.response).dimensions.isEmpty)
        try QueryReadFixture.complete(owner)
        let response = owner.published!.response
        #expect(ContentQueryContinuationRemainder(response).dimensions.isEmpty)
        #expect(!response.completeness.matchingIsComplete && !response.canDeclareCompleteNoMatch)
        #expect(response.completeness.providers[0].limitations.contains(.historyCoverage))
        #expect(response.completeness.providers[0].limitations.contains(.recordCoverage))
        #expect(response.completeness.providers[0].limitations.contains(.reviewRecords))
    }

    @Test func protectedAndRegexOrSnippetLimitsNeverCreateContinuation() throws {
        var protected = QueryBatchFixture.mixed("/diaries")
        protected.facts.metadata = .init(tagNames: nil, privateTagIDs: nil)
        let protectedRead = ContentQueryBatchReader.read(protected)
        #expect(protectedRead.definiteMatchCount == 1 && protectedRead.readings.first?.state == .evaluated)
        guard case .diary(let diary) = protectedRead.matches.first, case .hiddenTitle = diary.presentation else {
            Issue.record("合成手记必须实际走受保护投影"); return
        }
        var regex = QueryBatchFixture.empty("/clipboard")
        regex.snapshots.clipboard = .complete([ClipboardQueryFixture.record(1, "synthetic needle")])
        regex.options.clipboardMode = .explicit(.regex, needle: "[")
        for batch in [protected, regex] {
            let owner = try QueryReadFixture.owner(batch)
            #expect(ContentQueryContinuationRemainder(owner.published!.response).dimensions.isEmpty)
            #expect(throws: ContentQueryReadError.noBudgetRemainder) {
                try owner.continueReading(source: owner.source!, budget: .init(maxResults: 2_000))
            }
        }
        let owner = try ContentQueryReadOwner()
        let task = try owner.begin(QuerySortFixture.batch("needle", titles: [("needle needle needle", "")]),
                                   presentation: .init(budget: .init(maxUTF16: 1, contextUTF16: 0)))
        try owner.publish(owner.evaluate(task))
        #expect(ContentQueryContinuationRemainder(owner.published!.response).dimensions.isEmpty)
    }

    @Test func everyExplicitSourceReplacementChangesGenerationIncludingDateFactsAndMode() throws {
        let owner = try QueryReadFixture.owner()
        let original = QueryReadFixture.batch()
        var facts = original
        facts.facts.metadata = .init(tagNames: nil, privateTagIDs: nil)
        var dates = original
        dates.options.occurrenceWindow = RoutineOccurrenceQueryFixture.window("2026-10-01", "2026-10-10")
        var calendar = original.dates.calendar
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var session = ContentQuerySession(page: .init(location: original.session.page.location,
            page: .overview, todayKey: "2026-10-02", calendar: calendar))
        QuerySessionFixture.apply(.setInput("date:today"), &session)
        session = TodoQueryFixture.add(.scope(.routineOccurrences), to: session)
        let environment = QueryBatchFixture.replacingSession(original, session)
        let query = QueryBatchFixture.replacingSession(original, TodoQueryFixture.session("different"))
        for batch in [original, facts, dates, environment, query] {
            let previous = owner.source!
            let task = try owner.begin(batch, presentation: .init(sortMode: .recent))
            #expect(task.source != previous)
            #expect(throws: ContentQueryReadError.staleSource) { try owner.continueReading(source: previous, budget: .init()) }
        }
    }

    @Test func descriptionsDoNotExposeSyntheticBodyOrFilename() throws {
        let secret = "synthetic-sensitive-filename.txt"
        let owner = try ContentQueryReadOwner()
        let task = try owner.begin(QuerySortFixture.batch("", titles: [(secret, secret)]))
        let ticket = try owner.evaluate(task)
        try owner.publish(ticket)
        for text in [String(describing: owner), String(reflecting: owner), String(describing: task), String(reflecting: task),
                     String(describing: ticket), String(reflecting: ticket), String(reflecting: owner.published!)] {
            #expect(!text.contains(secret))
        }
    }
}
