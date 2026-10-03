import Foundation
import Testing
@testable import AreaChain

struct RoutineOccurrenceQueryHistoryTests {
    @Test func currentDefinitionOnlyCoversObservedDay() {
        var fixture = RoutineOccurrenceQueryFixture("date:2026-09-30..2026-10-02")
        fixture.evidence = [.currentDefinition(fixture.routines[0], observedOn: "2026-10-01")]
        let response = fixture.read()
        #expect(response.matches.map(\.id.dayKey) == ["2026-10-01"])
        #expect(response.coverage.gaps.filter { $0.reason == .schedule(.missingHistory) }.count == 2)
        #expect(!response.isCompleteForCoveredTypes)
    }

    @Test func conflictingEvidenceKeepsReliableDaysAndReportsUnknownWeekdays() {
        var fixture = RoutineOccurrenceQueryFixture("date:2026-10-01..2026-10-07")
        fixture.evidence.append(RoutineQueryFixture.evidence("2026-10-01", "2026-10-07", rule: .weekdays(WeekdayMask.workdays)))
        let response = fixture.read()
        #expect(response.matches.map(\.id.dayKey) == ["2026-10-01", "2026-10-02", "2026-10-05", "2026-10-06", "2026-10-07"])
        #expect(response.coverage.gaps.contains { $0.reason == .schedule(.conflictingEvidence) && $0.weekdayMask == 0b1000001 })
    }

    @Test func creationBoundaryDoesNotGenerateEarlierDays() {
        var fixture = RoutineOccurrenceQueryFixture("date:2026-08-30..2026-09-02")
        fixture.evidence = [RoutineQueryFixture.evidence("2026-08-01", "2026-10-01")]
        fixture.coverage = [.init(routineID: RoutineQueryFixture.id, completeIntervals: [.init(lowerBound: "2026-08-01", upperBound: "2026-10-01")])]
        #expect(fixture.read().matches.map(\.id.dayKey) == ["2026-09-01", "2026-09-02"])
    }

    @Test func disabledDefinitionsKeepReliableHistoryAndDeletedOnesAreExcluded() {
        var fixture = RoutineOccurrenceQueryFixture()
        fixture.routines[0].isEnabled = false
        fixture.routines[0].pausedOnDayKey = "2026-09-15"
        #expect(fixture.read().matches.count == 1)
        fixture.routines[0].deletedAt = Date(timeIntervalSince1970: 1)
        fixture.checks = [RoutineQueryFixture.check(.completed)]
        #expect(fixture.read().matches.isEmpty && fixture.read().reviewRecords.isEmpty)
    }

    @Test func missingAndAmbiguousDefinitionsNeverSupplyMadeUpTitles() {
        var fixture = RoutineOccurrenceQueryFixture()
        fixture.routines = []
        fixture.checks = [RoutineQueryFixture.check(.completed)]
        let missing = fixture.read()
        #expect(missing.matches.isEmpty && missing.reviewRecords.first?.kind == .unattributed)
        #expect(missing.diagnostics.contains { $0.issue == .missingRoutine })
        var deleted = RoutineQueryFixture.routine()
        deleted.deletedAt = Date(timeIntervalSince1970: 1)
        fixture.routines = [RoutineQueryFixture.routine(), deleted]
        let ambiguous = fixture.read()
        #expect(ambiguous.matches.isEmpty && ambiguous.reviewRecords.count == 1)
        #expect(ambiguous.coverage.gaps.contains { $0.reason == .ambiguousDefinition })
        #expect(ambiguous.diagnostics.contains { $0.issue == .duplicateRoutineID && $0.inputIndices == [0, 1] })
    }

    @Test func evidenceAndCoverageCannotLeakAcrossRoutines() {
        var fixture = RoutineFixtureWithSecond.make()
        fixture.evidence.removeLast()
        fixture.coverage.removeFirst()
        let response = fixture.read()
        #expect(response.matches.isEmpty)
        #expect(response.coverage.gaps.contains { $0.routine.id == fixture.routines[0].id && $0.reason == .recordsIncomplete })
        #expect(response.coverage.gaps.contains { $0.routine.id == fixture.routines[1].id && $0.reason == .schedule(.missingHistory) })
    }

    @Test func invalidEvidenceAndRecordDaysAreIsolatedByRoutine() {
        var fixture = RoutineFixtureWithSecond.make()
        fixture.evidence[0] = .init(routineID: fixture.routines[0].id,
            interval: .init(lowerBound: "2026-10-01", upperBound: "2026-10-02"), rule: .weekdays(WeekdayMask.all),
            source: .currentDefinition(observedOn: "2026-10-01"))
        fixture.checks = [RoutineQueryFixture.check(.completed, day: "2026-99-01")]
        let response = fixture.read()
        #expect(response.matches.map(\.routine.id) == [fixture.routines[1].id])
        #expect(response.diagnostics.contains { $0.issue == .invalidScheduleEvidence })
        #expect(response.diagnostics.contains { $0.issue == .check(.invalidRecordDay) })
    }

    @Test func adjacentCoverageMergesButGapsRemainUnknown() {
        var fixture = RoutineOccurrenceQueryFixture("date:2026-10-01..2026-10-05")
        fixture.coverage = [.init(routineID: RoutineQueryFixture.id, completeIntervals: [
            .init(lowerBound: "2026-10-01", upperBound: "2026-10-02"),
            .init(lowerBound: "2026-10-03", upperBound: "2026-10-03"),
            .init(lowerBound: "2026-10-05", upperBound: "2026-10-05")])]
        let response = fixture.read()
        #expect(response.matches.map(\.id.dayKey) == ["2026-10-01", "2026-10-02", "2026-10-03", "2026-10-05"])
        #expect(response.coverage.gaps.filter { $0.reason == .recordsIncomplete }.map(\.interval)
            == [.init(lowerBound: "2026-10-04", upperBound: "2026-10-04")])
    }

    @Test func invalidCoverageDoesNotBecomeCompleteEmptyRecords() {
        var fixture = RoutineOccurrenceQueryFixture()
        fixture.coverage = [.init(routineID: RoutineQueryFixture.id,
            completeIntervals: [.init(lowerBound: "2026-10-02", upperBound: "2026-10-01")])]
        #expect(fixture.read().matches.isEmpty)
        #expect(fixture.read().diagnostics.contains { $0.issue == .check(.invalidCoverage) })
    }
}

private enum RoutineFixtureWithSecond {
    static func make() -> RoutineOccurrenceQueryFixture {
        var fixture = RoutineOccurrenceQueryFixture()
        var second = RoutineQueryFixture.routine()
        second.id = UUID(uuidString: "50000000-0000-0000-0000-000000000002")!
        fixture.routines.append(second)
        fixture.evidence.append(RoutineQueryFixture.evidence("2026-10-01", "2026-10-01", id: second.id))
        fixture.coverage.append(.init(routineID: second.id, completeIntervals: [QuerySessionFixture.interval()]))
        return fixture
    }
}
