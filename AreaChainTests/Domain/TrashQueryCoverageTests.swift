import Foundation
import Testing
@testable import AreaChain

struct TrashQueryCoverageTests {
    @Test func missingTypesAndPartialIdentityNeverBecomeCompleteZero() {
        var input = TrashTombstoneInput()
        let missing = TrashQueryFixture.read("/trash absent", input)
        #expect(missing.hasIncompleteInput && missing.typeCoverage.count == 6)
        #expect(missing.typeCoverage.values.allSatisfy { $0 == .notProvided })
        input = TrashFixture.family()
        input.coverage.types[.subtask] = .partial
        let partial = TrashQueryFixture.read("/trash absent", input)
        #expect(partial.hasIncompleteInput)
        #expect(partial.undeterminedObjects.contains(TrashFixture.ref(.subtask, TrashFixture.childID)))
        input.coverage.objects[TrashFixture.ref(.subtask, TrashFixture.childID)] = .completeIncludingDeleted
        #expect(TrashQueryFixture.read("/trash 合成子任务", input).definiteMatchCount == 1)
    }

    @Test func absentTagEvidenceIsLocalAndDoesNotPoisonUnrelatedText() {
        let input = TrashFixture.family()
        let request = TrashQueryRequest(requestID: UUID(), session: TodoQueryFixture.session("/trash #工作"), input: input)
        let result = TrashQueryProvider.read(request)
        #expect(result.diagnostics.contains { $0.issue == .missingTagNames })
        #expect(result.undeterminedObjects.count == 3)
        #expect(TrashQueryFixture.read("/trash 合成子任务", input).definiteMatchCount == 1)
    }

    @Test func imageExistenceAndRoutineHistoryRemainExplicitCapabilityGaps() {
        let images = TrashQueryFixture.read("/trash has:image", TrashQueryFixture.all())
        #expect(images.matches.isEmpty)
        #expect(images.diagnostics.contains { $0.issue == .imageAssociationUnavailable })
        let routine = TrashQueryFixture.read("/trash on:2026-10-02 status:done", TrashQueryFixture.all())
        #expect(routine.matches.isEmpty)
        #expect(routine.undeterminedObjects.contains(TrashFixture.ref(.routine)))
        #expect(routine.diagnostics.contains { $0.issue == .routineEvidenceUnavailable })
    }

    @Test func invalidParentDateDoesNotBlockChildTitleAndOwnCreation() {
        var input = TrashFixture.family()
        input.todos?[0].dayKey = "invalid"
        #expect(TrashQueryFixture.read("/trash 合成子任务", input).definiteMatchCount == 1)
        let result = TrashQueryFixture.read("/trash 合成子任务 date:2026-10-02", input)
        #expect(result.matches.isEmpty)
        #expect(result.undeterminedObjects == [TrashFixture.ref(.subtask, TrashFixture.childID)])
    }

    @Test func queryUsesFullSessionRatherThanReparsingSource() {
        var session = TodoQueryFixture.session("/trash")
        session = TodoQueryFixture.add(.clause([.init(atom: .text("合成子任务", phrase: false))]), to: session)
        let result = TrashQueryFixture.read(session, TrashFixture.family())
        #expect(result.definiteMatchCount == 1)
        #expect(result.requestID == TodoQueryFixture.requestID)
        #expect(result.matches[0].evidence.allSatisfy { evidence in session.conditions.contains { $0.id == evidence.conditionID } })
    }
}
