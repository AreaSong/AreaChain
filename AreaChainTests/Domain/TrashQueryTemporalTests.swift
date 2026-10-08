import Foundation
import Testing
@testable import AreaChain

struct TrashQueryTemporalTests {
    private let day = "2026-10-02"

    private func read(_ query: String, evidence: TrashQueryRoutineInput?) -> TrashQueryResponse {
        var input = TrashFixture.input()
        input.routines = [TrashFixture.routine()]
        input.images = [TrashFixture.image(owner: .routine)]
        return TrashQueryProvider.read(.init(requestID: UUID(), session: TodoQueryFixture.session(query), input: input,
                                            routineInput: evidence))
    }

    private func evidence() -> TrashQueryRoutineInput {
        let interval = ContentQueryDateInterval(lowerBound: day, upperBound: day)
        return .init(schedules: [.init(routineID: TrashFixture.parentID, interval: interval,
            rule: .weekdays(WeekdayMask.all), source: .synthetic(reference: "trash-fixture"))],
            checks: [.init(routineId: TrashFixture.parentID, dayKey: day, isDone: true)],
            checkCoverage: [.init(routineID: TrashFixture.parentID, completeIntervals: [interval])])
    }

    @Test func explicitEvidenceMatchesDeletedDefinitionAndItsPublicImage() {
        let result = read("/trash on:\(day) status:done date:\(day)", evidence: evidence())
        #expect(Set(result.matches.map(\.id.type)) == [.routine, .image])
        #expect(result.definiteMatchCount == 2 && result.visibleGroupCount == 1)
        #expect(result.matches.first { $0.id.type == .image }?.evidence.contains { $0.field == .ownerCompletion } == true)
    }

    @Test func missingRecordsAreUnknownButDoNotInvalidatePureScheduleCondition() {
        var input = evidence()
        input.checkCoverage = []
        let status = read("/trash on:\(day) status:done", evidence: input)
        #expect(status.matches.isEmpty && status.undeterminedObjects.count == 2)
        #expect(status.diagnostics.contains { $0.issue == .check(.incompleteInput) && $0.affectsDetermination })
        let on = read("/trash on:\(day)", evidence: input)
        #expect(on.definiteMatchCount == 2)
        #expect(on.diagnostics.allSatisfy { !$0.affectsDetermination })
    }

    @Test func otherRoutineEvidenceAndConflictsCannotProveThisRoutine() {
        var input = evidence()
        input.schedules = [RoutineQueryFixture.evidence(day, day)]
        #expect(read("/trash date:\(day)", evidence: input).undeterminedObjects.count == 2)
        input = evidence()
        input.checks.append(.init(routineId: TrashFixture.parentID, dayKey: day, isDone: false, isSkipped: true))
        let conflict = read("/trash on:\(day) status:done", evidence: input)
        #expect(conflict.matches.isEmpty && conflict.undeterminedObjects.count == 2)
        #expect(conflict.diagnostics.contains { $0.issue == .check(.conflictingRecords) })
    }

    @Test func currentDisabledDefinitionIsNotHistoricalScheduleProof() {
        #expect(read("/trash date:\(day)", evidence: nil).undeterminedObjects.count == 2)
        #expect(read("/trash date:\(day)", evidence: .init()).undeterminedObjects.count == 2)
        let result = read("/trash created:\(day)", evidence: nil)
        #expect(result.definiteMatchCount == 2)
    }
    @Test func legacyAndAlternateSkipRemainDistinctRowsWithoutConflict() {
        var input = evidence()
        input.checks = [.init(routineId: TrashFixture.parentID, dayKey: day, isDone: true, isSkipped: true),
                        .init(routineId: TrashFixture.parentID, dayKey: day, isDone: false, isSkipped: true)]
        let result = read("/trash on:\(day) status:skipped", evidence: input)
        #expect(Set(result.matches.map(\.id.type)) == [.routine, .image])
        #expect(result.undeterminedObjects.isEmpty)
        #expect(result.diagnostics.contains { $0.issue == .check(.equivalentEncodingDuplicates) && !$0.affectsDetermination })
        input.checkCoverage = []
        #expect(read("/trash on:\(day) status:skipped", evidence: input).matches.isEmpty)
    }

}
