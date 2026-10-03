import Foundation
import Testing
@testable import AreaChain

struct RoutineOccurrenceQueryStateTests {
    @Test func reliableCompleteAbsenceDerivesOpenWithoutChangingInput() throws {
        let fixture = RoutineOccurrenceQueryFixture("date:today status:open")
        let before = fixture.request
        let response = fixture.read()
        let match = try #require(response.matches.first)
        #expect(match.id == .init(type: .routineOccurrence, id: RoutineQueryFixture.id, dayKey: "2026-10-01"))
        #expect(match.routine == .init(type: .routine, id: RoutineQueryFixture.id))
        #expect(match.status == .open && match.source == .derivedUnprocessed)
        #expect(match.occurrence.records.state == .absent && match.occurrence.records.inputIndices.isEmpty)
        #expect(fixture.checks == before.checks && fixture.routines == before.routines)
        #expect(response.isCompleteForCoveredTypes)
    }

    @Test func completeExistingStatesAndStatusFiltering() throws {
        let states: [(RoutineCheckState, ContentQueryStatus)] = [(.completed, .done), (.skipped, .skipped), (.unprocessed, .open)]
        for (state, expected) in states {
            var fixture = RoutineOccurrenceQueryFixture()
            fixture.checks = [RoutineQueryFixture.check(state)]
            let match = try #require(fixture.read().matches.first)
            #expect(match.status == expected && match.source == .existingRecords)
            for status in [ContentQueryStatus.open, .done, .skipped] {
                fixture.session = RoutineOccurrenceQueryFixture("date:today status:" + status.rawValue).session
                #expect(fixture.read().matches.count == (status == expected ? 1 : 0))
            }
        }
    }

    @Test func incompleteChecksNeverProduceDeterminateStateEvenWithObservedDone() {
        for checks in [[], [RoutineQueryFixture.check(.completed)], [RoutineQueryFixture.check(.skipped)]] {
            var fixture = RoutineOccurrenceQueryFixture("date:today status:open")
            fixture.coverage = []
            fixture.checks = checks
            let response = fixture.read()
            #expect(response.matches.isEmpty && !response.isCompleteForCoveredTypes)
            #expect(response.coverage.gaps.contains { $0.reason == .recordsIncomplete })
            if !checks.isEmpty {
                #expect(response.reviewRecords.first?.kind == .unknown)
                #expect(response.reviewRecords.first?.records.state == .incomplete)
            }
        }
    }

    @Test func identicalDuplicatesMergeOnceAndKeepOriginalInputIndices() throws {
        var fixture = RoutineOccurrenceQueryFixture()
        fixture.checks = [RoutineQueryFixture.check(.skipped, id: UUID()), RoutineQueryFixture.check(.completed),
                          RoutineQueryFixture.check(.completed)]
        let response = fixture.read()
        let match = try #require(response.matches.first)
        #expect(response.matches.count == 1 && match.hasIdenticalDuplicates)
        #expect(match.occurrence.records.inputIndices == [1, 2])
        #expect(response.diagnostics.contains { $0.issue == .check(.identicalDuplicates) && !$0.affectsDetermination })
    }

    @Test func conflictingDuplicatesAndDonePlusSkippedNeverMatchAnyState() {
        let pairs = [[RoutineQueryFixture.check(.completed), RoutineQueryFixture.check(.skipped)],
                     [RoutineQueryFixture.check(.unprocessed), RoutineQueryFixture.check(.completed)],
                     [CheckSnapshot(routineId: RoutineQueryFixture.id, dayKey: "2026-10-01", isDone: true, isSkipped: true)]]
        for checks in pairs {
            for status in ["open", "done", "skipped"] {
                var fixture = RoutineOccurrenceQueryFixture("date:today status:" + status)
                fixture.checks = checks
                let response = fixture.read()
                #expect(response.matches.isEmpty && response.reviewRecords.first?.kind == .conflict)
                #expect(!response.isCompleteForCoveredTypes)
            }
        }
    }

    @Test func actualNonScheduledAndBeforeCreationRowsAreAnomalies() {
        var fixture = RoutineOccurrenceQueryFixture("date:2026-08-31..2026-09-02")
        fixture.checks = [RoutineQueryFixture.check(.completed, day: "2026-08-31"),
                          RoutineQueryFixture.check(.skipped, day: "2026-09-01")]
        fixture.evidence = [RoutineQueryFixture.evidence("2026-09-01", "2026-09-02", rule: .notScheduled)]
        let response = fixture.read()
        #expect(response.matches.isEmpty)
        #expect(response.reviewRecords.map(\.kind) == [.notScheduled, .notScheduled])
        #expect(response.reviewRecords.first?.schedule?.reason == .beforeCreation)
        #expect(response.reviewRecords.last?.records.state == .skipped)
    }

    @Test func scheduleUnknownKeepsObservedRowForReviewAndNeverBecomesOpen() {
        var fixture = RoutineOccurrenceQueryFixture()
        fixture.evidence = []
        fixture.checks = [RoutineQueryFixture.check(.completed)]
        let response = fixture.read()
        #expect(response.matches.isEmpty)
        #expect(response.reviewRecords.first?.kind == .unknown)
        #expect(response.reviewRecords.first?.records.state == .completed)
        #expect(response.coverage.gaps.contains { $0.reason == .schedule(.missingHistory) })
    }

    @Test func identitiesAreDailyAndSortingUsesDefinitionInputThenAscendingDay() {
        var fixture = RoutineOccurrenceQueryFixture("date:2026-10-01..2026-10-03")
        var second = RoutineQueryFixture.routine()
        second.id = UUID()
        second.sortOrder = -10
        fixture.routines.append(second)
        fixture.evidence.append(RoutineQueryFixture.evidence("2026-10-01", "2026-10-03", id: second.id))
        fixture.coverage.append(.init(routineID: second.id, completeIntervals: [.init(lowerBound: "2026-10-01", upperBound: "2026-10-03")]))
        fixture.checks = [RoutineQueryFixture.check(.completed, day: "2026-10-03"), RoutineQueryFixture.check(.skipped),
                          RoutineQueryFixture.check(.completed, day: "2026-10-03")]
        let response = fixture.read()
        #expect(response.matches.map(\.id.id) == Array(repeating: RoutineQueryFixture.id, count: 3) + Array(repeating: second.id, count: 3))
        #expect(response.matches.map(\.id.dayKey) == ["2026-10-01", "2026-10-02", "2026-10-03", "2026-10-01", "2026-10-02", "2026-10-03"])
        #expect(Set(response.matches.map(\.id)).count == 6)
    }
}
