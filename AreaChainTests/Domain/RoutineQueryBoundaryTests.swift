import Foundation
import Testing
@testable import AreaChain

struct RoutineQueryBoundaryTests {
    @Test func unrelatedUnknownObjectDoesNotBlockKnownMatch() {
        var second = RoutineQueryFixture.routine()
        second.id = TodoQueryFixture.work
        let response = RoutineProviderFixture.read("/routines date:today", routines: [second, RoutineQueryFixture.routine()],
                                                   evidence: [RoutineProviderFixture.schedule])
        #expect(response.matches.map(\.id.id) == [RoutineQueryFixture.id])
        #expect(response.undeterminedObjects.map(\.id) == [second.id])
        #expect(response.diagnostics.allSatisfy { $0.object?.id == second.id })
    }

    @Test func identicalWarningDoesNotCauseUncertaintyWhenOtherInputIsMissing() {
        let done = RoutineQueryFixture.check(.completed)
        let response = RoutineProviderFixture.read("/routines on:today status:done", checks: [done, done])
        #expect(response.undeterminedObjects.count == 1)
        #expect(response.diagnostics.filter { $0.issue == .check(.identicalDuplicates) }.allSatisfy { !$0.affectsDetermination })
        #expect(response.diagnostics.contains { $0.issue == .check(.incompleteInput) && $0.affectsDetermination })
    }

    @Test func evidenceConflictsAndSourcesAreExplicitButRedacted() throws {
        let positive = RoutineProviderFixture.schedule
        let negative = RoutineQueryFixture.evidence("2026-10-01", "2026-10-01", rule: .notScheduled)
        let response = RoutineProviderFixture.read("/routines date:today", evidence: [positive, negative])
        #expect(response.diagnostics.contains { $0.issue == .schedule(.conflictingEvidence) })
        let source = "synthetic-private-source"
        let evidence = RoutineScheduleEvidence(routineID: RoutineQueryFixture.id, interval: QuerySessionFixture.interval(),
                                                rule: .weekdays(WeekdayMask.all), source: .recordedSchedule(reference: source))
        #expect(!String(describing: evidence).contains(source))
        #expect(!String(reflecting: evidence).contains(source))
        let matched = try #require(RoutineProviderFixture.read("/routines date:today", evidence: [evidence]).matches.first)
        #expect(!String(reflecting: matched).contains(source))
    }

    @Test func malformedCoverageIsLocalAndNoDateDoesNotReadIt() {
        let invalid = RoutineCheckCoverage(routineID: RoutineQueryFixture.id,
                                          completeIntervals: [QuerySessionFixture.interval("bad", "bad")])
        #expect(RoutineProviderFixture.read("合成", coverage: [invalid]).matches.count == 1)
        let response = RoutineProviderFixture.read("/routines on:today status:open", evidence: [RoutineProviderFixture.schedule],
                                                   coverage: [invalid])
        #expect(response.diagnostics.contains { $0.issue == .check(.invalidCoverage) })
        #expect(response.undeterminedObjects.count == 1)
        let empty = RoutineProviderFixture.read("/routines has:image", routines: [])
        #expect(empty.diagnostics.contains { $0.issue == .imageAssociationUnavailable })
    }

    @Test func structureAndOccurrenceScopeStaySeparateFromRoutineProvider() {
        var session = TodoQueryFixture.session("/routines 合成")
        session.conditions.append(session.conditions[0])
        #expect(RoutineProviderFixture.read(session).state == .invalidQuery)
        let occurrenceSession = TodoQueryFixture.add(.scope(.routineOccurrences), to: TodoQueryFixture.session())
        #expect(RoutineProviderFixture.read(occurrenceSession).state == .notApplicable)
    }

    @Test func booleanCompositionRetainsErrorsAndKnownAlternative() {
        let id = ContentQueryConditionID(rawValue: 12)
        let unknown = RoutineQueryEvaluationResult.unknown(.missingTagNames, id: id)
        let known = RoutineQueryEvaluationResult.known(true, id: id, field: .tags)
        let combined = RoutineQueryEvaluationResult.combine([unknown, known], any: true)
        #expect(combined.truth == .matches && combined.diagnostics.count == 1)
        #expect(!combined.diagnostics[0].affectsDetermination)
    }
}
