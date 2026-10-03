import Foundation
import Testing
@testable import AreaChain

struct ContentQueryBatchOccurrenceTests {
    @Test func truncatedEnumerationKeepsExactRemainingWorkWithoutGlobalPagination() {
        var batch = QueryBatchFixture.occurrences("date:2026-10-01..2026-10-10")
        batch.options.occurrenceBudget.maxResults = 2
        let result = ContentQueryBatchReader.read(batch)
        #expect(result.definiteMatchCount == 2 && !result.completeness.matchingIsComplete)
        guard case .routineOccurrence(let reading) = result.readings.first else { Issue.record("缺少执行记录读取"); return }
        #expect(reading.matches.map(\.id.dayKey) == ["2026-10-01", "2026-10-02"])
        #expect(reading.coverage.unprocessed.first?.window == RoutineOccurrenceQueryFixture.window("2026-10-03", "2026-10-10"))
        #expect(reading.coverage.unprocessed.first?.reason == .resultLimit)
        #expect(result.completeness.providers[0].limitations.contains(.enumerationRemainder))
        #expect(result.order == .temporaryProviderThenInput)
    }

    @Test func unknownHistoryAndReviewAreNeverCertainMatches() {
        var batch = QueryBatchFixture.occurrences()
        batch.facts.routine.scheduleEvidence = []
        batch.facts.routine.checks = [RoutineQueryFixture.check(.completed, id: QueryBatchFixture.id)]
        let result = ContentQueryBatchReader.read(batch)
        #expect(result.definiteMatchCount == 0 && !result.canDeclareCompleteNoMatch)
        guard case .routineOccurrence(let reading) = result.readings.first else { Issue.record("缺少执行记录读取"); return }
        #expect(!reading.reviewRecords.isEmpty && !reading.coverage.gaps.isEmpty)
        #expect(result.completeness.providers[0].limitations.contains(.reviewRecords))
        #expect(result.completeness.providers[0].limitations.contains(.historyCoverage))
    }

    @Test func unattributedRecordsPreserveUnprocessedIndices() {
        var batch = QueryBatchFixture.occurrences("date:2026-10-01..2026-10-02")
        batch.snapshots.routines = .complete([])
        batch.facts.routine.checks = [RoutineQueryFixture.check(.completed, id: QueryBatchFixture.id),
            RoutineQueryFixture.check(.completed, day: "2026-10-02", id: QueryBatchFixture.id)]
        batch.options.occurrenceBudget.maxResults = 1
        let result = ContentQueryBatchReader.read(batch)
        guard case .routineOccurrence(let reading) = result.readings.first else { Issue.record("缺少执行记录读取"); return }
        #expect(reading.coverage.unprocessedCheckIndices == [1])
        #expect(reading.reviewRecords.count == 1 && result.definiteMatchCount == 0)
        #expect(!result.canDeclareCompleteNoMatch)
    }

    @Test func missingWindowIsRequiresInputAndNotEmptySuccess() {
        let result = ContentQueryBatchReader.read(QueryBatchFixture.occurrences(""))
        guard case .routineOccurrence(let reading) = result.readings.first else { Issue.record("缺少执行记录读取"); return }
        #expect(reading.state == .requiresInput && reading.diagnostics.contains { $0.issue == .missingWindow })
        #expect(result.completeness.evaluatedTypes.isEmpty && !result.canDeclareCompleteNoMatch)
    }

    @Test func identicalCheckRowsAndConflictingCheckRowsRemainDifferent() {
        var batch = QueryBatchFixture.occurrences()
        let done = RoutineQueryFixture.check(.completed, id: QueryBatchFixture.id)
        batch.facts.routine.checks = [done, done]
        let identical = ContentQueryBatchReader.read(batch)
        #expect(identical.definiteMatchCount == 1 && identical.completeness.matchingIsComplete)
        #expect(identical.consistencyIssues.isEmpty)
        batch.facts.routine.checks = [done, RoutineQueryFixture.check(.skipped, id: QueryBatchFixture.id)]
        let conflict = ContentQueryBatchReader.read(batch)
        #expect(conflict.definiteMatchCount == 0 && !conflict.canDeclareCompleteNoMatch)
        guard case .routineOccurrence(let reading) = conflict.readings.first else { Issue.record("缺少执行记录读取"); return }
        #expect(reading.reviewRecords.contains { $0.kind == .conflict })
    }

    @Test func sameRoutineEvidenceFeedsDefinitionAndOccurrenceProviders() {
        let batch = QueryBatchFixture.occurrences("date:2026-10-01")
        let records = ContentQueryBatchReader.read(batch)
        let definitions = ContentQueryBatchReader.read(QueryBatchFixture.replacingSession(batch,
            TodoQueryFixture.session("/routines on:2026-10-01 status:open")))
        guard case .routineOccurrence(let record) = records.matches.first,
              case .routine(let definition) = definitions.matches.first else { Issue.record("缺少习惯结果"); return }
        #expect(record.occurrence == definition.occurrence)
        #expect(record.status == .open && record.source == .derivedUnprocessed)
    }
}
