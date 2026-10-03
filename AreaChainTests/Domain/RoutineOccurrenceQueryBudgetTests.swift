import Foundation
import Testing
@testable import AreaChain

struct RoutineOccurrenceQueryBudgetTests {
    @Test func thousandYearUnknownHistoryUsesOneGapWithoutDailyPlaceholders() {
        var fixture = RoutineOccurrenceQueryFixture("date:2026-09-01..9999-12-31")
        fixture.evidence = []
        fixture.coverage = [.init(routineID: RoutineQueryFixture.id,
            completeIntervals: [.init(lowerBound: "2026-09-01", upperBound: "9999-12-31")])]
        fixture.budget.maxWork = 300
        let response = fixture.read()
        #expect(response.matches.isEmpty && response.reviewRecords.isEmpty)
        #expect(response.coverage.gaps.count == 1)
        #expect(response.coverage.gaps.first?.interval.upperBound == "9999-12-31")
        #expect(response.coverage.enumerationIsComplete && !response.coverage.historyIsComplete)
        #expect(response.coverage.workUsed < 300)
    }

    @Test func incompleteRecordWindowIsCompressedAndActualRowsRemainReviewable() {
        var fixture = RoutineOccurrenceQueryFixture("date:2026-09-01..9999-12-31")
        fixture.coverage = []
        fixture.evidence = [RoutineQueryFixture.evidence("2026-09-01", "9999-12-31")]
        fixture.checks = [RoutineQueryFixture.check(.completed)]
        fixture.budget.maxWork = 300
        let response = fixture.read()
        #expect(response.matches.isEmpty && response.reviewRecords.count == 1)
        #expect(response.coverage.gaps.count == 1 && response.coverage.enumerationIsComplete)
        #expect(!response.coverage.recordsAreComplete)
    }

    @Test func resultLimitReportsExactRemainderAndKeepsDeterministicPrefix() {
        var fixture = RoutineOccurrenceQueryFixture("date:2026-10-01..2026-10-10")
        fixture.budget.maxResults = 2
        let response = fixture.read()
        #expect(response.matches.map(\.id.dayKey) == ["2026-10-01", "2026-10-02"])
        #expect(response.coverage.unprocessed.first?.window == RoutineOccurrenceQueryFixture.window("2026-10-03", "2026-10-10"))
        #expect(response.coverage.unprocessed.first?.reason == .resultLimit)
        #expect(!response.coverage.enumerationIsComplete && !response.isCompleteForCoveredTypes)
        #expect(response.coverage.resultRowsUsed == 2)
    }

    @Test func workBudgetBoundsLargeKnownWindowEvenWhenFilterMatchesNothing() {
        var fixture = RoutineOccurrenceQueryFixture("date:2026-10-01..9999-12-31 status:done")
        fixture.evidence = [RoutineQueryFixture.evidence("2026-10-01", "9999-12-31")]
        fixture.coverage = [.init(routineID: RoutineQueryFixture.id,
            completeIntervals: [.init(lowerBound: "2026-10-01", upperBound: "9999-12-31")])]
        fixture.budget.maxWork = 300
        let response = fixture.read()
        #expect(response.matches.isEmpty && !response.coverage.enumerationIsComplete)
        #expect(response.coverage.workUsed <= 300)
        #expect(response.coverage.unprocessed.first?.reason == .workLimit)
    }

    @Test func zeroAndInvalidBudgetsNeverClaimComplete() {
        var fixture = RoutineOccurrenceQueryFixture()
        fixture.budget.maxInputItems = 0
        #expect(fixture.read().coverage.unprocessed.first?.reason == .inputLimit)
        fixture.budget = .init(maxInputItems: 4_096, maxWork: 0, maxResults: 10)
        #expect(fixture.read().coverage.unprocessed.first?.reason == .workLimit)
        fixture.budget = .init(maxInputItems: 4_096, maxWork: 100_000, maxResults: 0)
        #expect(fixture.read().coverage.unprocessed.first?.reason == .resultLimit)
        fixture.budget.maxResults = -1
        #expect(fixture.read().state == .blocked)
        #expect(!fixture.read().isCompleteForCoveredTypes)
    }

    @Test func resultBudgetIncludesAnomalyRowsAndUnattributedRemainder() {
        var fixture = RoutineOccurrenceQueryFixture("date:2026-10-01..2026-10-02")
        fixture.routines = []
        fixture.checks = [RoutineQueryFixture.check(.completed), RoutineQueryFixture.check(.completed, day: "2026-10-02")]
        fixture.budget.maxResults = 1
        let response = fixture.read()
        #expect(response.reviewRecords.count == 1 && response.coverage.resultRowsUsed == 1)
        #expect(response.coverage.unprocessedCheckIndices == [1])
        #expect(!response.coverage.enumerationIsComplete)
    }

    @Test func upperCivilDateBoundaryTerminatesAndWeekdaysRespectCalendar() {
        var fixture = RoutineOccurrenceQueryFixture("date:9999-12-30..9999-12-31")
        fixture.evidence = [RoutineQueryFixture.evidence("9999-12-30", "9999-12-31")]
        fixture.coverage = [.init(routineID: RoutineQueryFixture.id,
            completeIntervals: [.init(lowerBound: "9999-12-30", upperBound: "9999-12-31")])]
        #expect(fixture.read().matches.map(\.id.dayKey) == ["9999-12-30", "9999-12-31"])
        #expect(fixture.read().coverage.enumerationIsComplete)
    }

    @Test func definitionCompletenessIsSeparateFromTypeAndEnumerationCoverage() {
        var fixture = RoutineOccurrenceQueryFixture()
        fixture.definitions = .partial
        let response = fixture.read()
        #expect(response.matches.count == 1 && response.coverage.enumerationIsComplete)
        #expect(!response.coverage.isPartialTypeCoverage && !response.isCompleteForCoveredTypes)
        #expect(response.diagnostics.contains { $0.issue == .definitionsIncomplete })
    }

    @Test func descriptionsNeverIncludeContextTitleOrQuery() throws {
        var fixture = RoutineOccurrenceQueryFixture()
        fixture.routines[0].title = "fixture-private-title-28"
        fixture.checks = [RoutineQueryFixture.check(.completed), RoutineQueryFixture.check(.completed)]
        let response = fixture.read()
        let match = try #require(response.matches.first)
        let descriptions = [String(describing: fixture.request), String(reflecting: fixture.request),
                            String(describing: response), String(reflecting: response),
                            String(describing: match), String(reflecting: match)]
            + response.diagnostics.map { String(reflecting: $0) }
        for value in descriptions {
            #expect(!value.contains(fixture.routines[0].title) && !value.contains("date:today"))
        }
    }
}

extension RoutineOccurrenceQueryBudgetTests {
    @Test func inputBoundIncludesNestedCoverageAndRemainderPreservesDateUnion() {
        var fixture = RoutineOccurrenceQueryFixture("(date:2026-10-01 | date:2026-10-03)")
        fixture.coverage[0] = .init(routineID: RoutineQueryFixture.id, completeIntervals: Array(repeating: QuerySessionFixture.interval(), count: 50))
        fixture.budget.maxInputItems = 20
        let limited = fixture.read()
        #expect(limited.coverage.unprocessed.first?.reason == .inputLimit)
        #expect(limited.coverage.unprocessed.first?.window.intervals.count == 2)
        #expect(!limited.coverage.recordsAreComplete && !limited.coverage.historyIsComplete)
        fixture = RoutineOccurrenceQueryFixture("(date:2026-10-01 | date:2026-10-03)")
        fixture.budget.maxResults = 1
        #expect(fixture.read().coverage.unprocessed.first?.window == RoutineOccurrenceQueryFixture.window("2026-10-03", "2026-10-03"))
    }

    @Test func recordAndHistoryCompletenessRemainIndependent() {
        var fixture = RoutineOccurrenceQueryFixture()
        fixture.evidence = []
        #expect(fixture.read().coverage.recordsAreComplete && !fixture.read().coverage.historyIsComplete)
        fixture.evidence = [RoutineQueryFixture.evidence("2026-10-01", "2026-10-01")]
        fixture.coverage = []
        #expect(!fixture.read().coverage.recordsAreComplete && fixture.read().coverage.historyIsComplete)
        fixture.coverage = [.init(routineID: RoutineQueryFixture.id, completeIntervals: [QuerySessionFixture.interval()])]
        fixture.checks = [RoutineQueryFixture.check(.completed, day: "bad-day")]
        #expect(!fixture.read().coverage.recordsAreComplete && fixture.read().coverage.historyIsComplete)
        fixture.routines = []
        #expect(!fixture.read().coverage.recordsAreComplete && !fixture.read().coverage.historyIsComplete)
    }

    @Test func laterDefinitionsRetainFullUnprocessedWindowAfterBudgetExhaustion() {
        var fixture = RoutineOccurrenceQueryFixture("date:2026-10-01..2026-10-03")
        var second = RoutineQueryFixture.routine()
        second.id = UUID()
        fixture.routines.append(second)
        fixture.budget.maxResults = 1
        let response = fixture.read()
        #expect(response.coverage.unprocessed.count == 2)
        #expect(response.coverage.unprocessed.last?.routine?.id == second.id)
        #expect(response.coverage.unprocessed.last?.window == RoutineOccurrenceQueryFixture.window("2026-10-01", "2026-10-03"))
    }
}
