import Foundation
import Testing
@testable import AreaChain

struct RoutineCheckReadingTests {
    @Test func completeAbsentUnprocessedAndUnavailableAreDistinct() {
        let absent = RoutineQueryFixture.read([])
        #expect(absent.state == .absent && absent.isComplete && absent.observedState == nil)
        let incomplete = RoutineQueryFixture.read([], complete: [])
        #expect(incomplete.state == .incomplete && !incomplete.isComplete)
        #expect(incomplete.diagnostics == [.incompleteInput])
        let pending = RoutineQueryFixture.read([RoutineQueryFixture.check(.unprocessed)])
        #expect(pending.state == .unprocessed && pending.observedState == .unprocessed)
        #expect(RoutineQueryFixture.read([RoutineQueryFixture.check(.completed)]).state == .completed)
        #expect(RoutineQueryFixture.read([RoutineQueryFixture.check(.skipped)]).state == .skipped)
    }

    @Test func identicalDuplicatesAreCollapsedAndFlaggedIncludingIncompleteInput() {
        for state in [RoutineCheckState.completed, .skipped, .unprocessed] {
            let check = RoutineQueryFixture.check(state)
            let single = RoutineQueryFixture.read([check])
            let duplicate = RoutineQueryFixture.read([check, check, check])
            #expect(single.state == duplicate.state)
            #expect(duplicate.observedState == state && duplicate.inputIndices == [0, 1, 2])
            #expect(duplicate.diagnostics == [.identicalDuplicates])
            let partial = RoutineQueryFixture.read([check, check], complete: [])
            #expect(partial.state == .incomplete && partial.observedState == state)
            #expect(partial.diagnostics == [.incompleteInput, .identicalDuplicates])
        }
    }

    @Test func inconsistentStatesNeverUseFirstOrLastAndSingleDoubleFlagIsConflict() {
        for left in [RoutineCheckState.completed, .skipped, .unprocessed] {
            for right in [RoutineCheckState.completed, .skipped, .unprocessed] where left != right {
                let rows = [RoutineQueryFixture.check(left), RoutineQueryFixture.check(right)]
                let result = RoutineQueryFixture.read(rows)
                #expect(result.state == .conflict && result.observedState == nil)
                #expect(result.diagnostics == [.conflictingRecords])
                #expect(RoutineQueryFixture.read(Array(rows.reversed())).state == .conflict)
                #expect(RoutineQueryFixture.read(rows, complete: []).state == .conflict)
            }
        }
        var invalid = RoutineQueryFixture.check(.completed)
        invalid.isSkipped = true
        let result = RoutineQueryFixture.read([invalid])
        #expect(result.state == .conflict && result.diagnostics == [.doneAndSkipped])
        #expect(RoutineQueryFixture.read([invalid, invalid]).diagnostics == [.identicalDuplicates, .doneAndSkipped])
    }

    @Test func coverageCannotLeakToOtherDaysOrAcrossIntervalGaps() {
        let coverage = RoutineCheckCoverage(routineID: RoutineQueryFixture.id, completeIntervals: [
            .init(lowerBound: "2026-10-01", upperBound: "2026-10-02"),
            .init(lowerBound: "2026-10-04", upperBound: "2026-10-05")
        ])
        let calendar = RoutineQueryFixture.dates.calendar
        #expect(coverage.covers(.init(lowerBound: "2026-10-01", upperBound: "2026-10-02"), calendar: calendar))
        #expect(!coverage.covers(.init(lowerBound: "2026-10-01", upperBound: "2026-10-05"), calendar: calendar))
        #expect(RoutineQueryFixture.read([], day: "2026-10-03", complete: coverage.completeIntervals).state == .incomplete)
        #expect(RoutineQueryFixture.read([], day: "2026-09-30", complete: coverage.completeIntervals).state == .incomplete)
        let adjacent = RoutineCheckCoverage(routineID: RoutineQueryFixture.id, completeIntervals: [
            .init(lowerBound: "2026-10-01", upperBound: "2026-10-02"),
            .init(lowerBound: "2026-10-03", upperBound: "2026-10-05")
        ])
        #expect(adjacent.covers(.init(lowerBound: "2026-10-01", upperBound: "2026-10-05"), calendar: calendar))
    }

    @Test func invalidRequestAndCoverageAreNotEmptyData() {
        for day in ["2026-02-30", "2026-10-1", ""] {
            #expect(RoutineQueryFixture.read([], day: day).state == .invalidInput)
        }
        let invalid = RoutineQueryFixture.read([], complete: [.init(lowerBound: "2026-10-03", upperBound: "2026-10-01")])
        #expect(invalid.state == .invalidInput && invalid.diagnostics == [.invalidCoverage])
        let wrongOwner = RoutineCheckReading.read(routineID: RoutineQueryFixture.id, on: "2026-10-01", checks: [],
            coverage: .init(routineID: UUID(), completeIntervals: [QuerySessionFixture.interval()]), dates: RoutineQueryFixture.dates)
        #expect(wrongOwner.state == .invalidInput && wrongOwner.diagnostics == [.coverageRoutineMismatch])
    }

    @Test func conflictsAreLocalToTheRoutineAndDayAndInputIsNotChanged() {
        let otherID = UUID()
        let rows = [RoutineQueryFixture.check(.completed, id: otherID), RoutineQueryFixture.check(.skipped, id: otherID),
                    RoutineQueryFixture.check(.completed, day: "2026-10-02"), RoutineQueryFixture.check(.skipped, day: "2026-10-02"),
                    RoutineQueryFixture.check(.skipped)]
        let original = rows
        let result = RoutineQueryFixture.read(rows)
        #expect(result.state == .skipped && result.inputIndices == [4] && result.diagnostics.isEmpty)
        #expect(result.object == .init(type: .routineOccurrence, id: RoutineQueryFixture.id, dayKey: "2026-10-01"))
        #expect(rows == original)
    }

    @Test func malformedRecordDayCannotProduceCompleteAbsenceOrNormalizeSilently() {
        let invalid = RoutineQueryFixture.check(.completed, day: "2026-10-1")
        let result = RoutineQueryFixture.read([invalid])
        #expect(result.state == .invalidInput && result.inputIndices == [0])
        #expect(result.diagnostics == [.invalidRecordDay])
        #expect(RoutineQueryFixture.read([RoutineQueryFixture.check(.completed, day: "invalid", id: UUID())]).state == .absent)
    }
}
