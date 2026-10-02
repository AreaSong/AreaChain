import Foundation
import Testing
@testable import AreaChain

struct RoutineQueryTemporalTests {
    @Test func dateExistenceAndPartialHistory() throws {
        let source = "/routines date:2026-10-01..2026-10-10"
        let known = RoutineQueryFixture.evidence("2026-10-03", "2026-10-03")
        let response = RoutineProviderFixture.read(source, evidence: [known])
        let match = try #require(response.matches.first)
        #expect(match.dateExistence?.witnessDay == "2026-10-03")
        #expect(match.occurrence == nil)
        #expect(response.isCompleteForCoveredTypes)
        #expect(response.diagnostics.contains { $0.issue == .uncertainSchedule && !$0.affectsDetermination })
        let unknown = RoutineProviderFixture.read(source)
        #expect(unknown.matches.isEmpty && unknown.undeterminedObjects.count == 1)
        #expect(!unknown.isCompleteForCoveredTypes)
        let noSchedule = RoutineQueryFixture.evidence("2026-10-01", "2026-10-10", rule: .notScheduled)
        #expect(RoutineProviderFixture.read(source, evidence: [noSchedule]).isCompleteForCoveredTypes)
        #expect(RoutineProviderFixture.read(source, evidence: [noSchedule]).matches.isEmpty)
    }

    @Test func dateIntersectionAndAlternativeEvidence() throws {
        let source = "/routines (date:2026-10-01 | date:2026-10-03) date:2026-10-02..2026-10-04"
        let response = RoutineProviderFixture.read(source, evidence: [RoutineProviderFixture.schedule])
        let match = try #require(response.matches.first)
        #expect(match.dateExistence?.witnessDay == "2026-10-03")
        let firstGroup = match.evidence.filter { $0.field == .scheduleExistence }.first
        #expect(firstGroup?.alternativeIndex == 1)
    }

    @Test func creationObservationAndConflictIsolation() {
        let routine = RoutineQueryFixture.routine()
        #expect(RoutineProviderFixture.read("/routines date:2026-08-31").matches.isEmpty)
        #expect(RoutineProviderFixture.read("/routines date:2026-08-31").isCompleteForCoveredTypes)
        let current = RoutineScheduleEvidence.currentDefinition(routine, observedOn: "2026-10-01")
        #expect(RoutineProviderFixture.read("/routines date:2026-10-01", evidence: [current]).matches.count == 1)
        #expect(RoutineProviderFixture.read("/routines date:2026-10-02", evidence: [current]).undeterminedObjects.count == 1)
        let conflict = RoutineQueryFixture.evidence("2026-10-01", "2026-10-01", rule: .notScheduled)
        #expect(RoutineProviderFixture.read("/routines date:2026-10-01", evidence: [current, conflict]).undeterminedObjects.count == 1)
        let foreign = RoutineQueryFixture.evidence("bad", "bad", id: TodoQueryFixture.work)
        #expect(RoutineProviderFixture.read("/routines date:2026-10-01", evidence: [current, foreign]).matches.count == 1)
        let malformed = RoutineQueryFixture.evidence("bad", "bad")
        #expect(RoutineProviderFixture.read("/routines date:2026-10-01", evidence: [malformed]).diagnostics.contains {
            $0.issue == .invalidScheduleEvidence
        })
        #expect(RoutineProviderFixture.read("/routines 合成", evidence: [malformed]).matches.count == 1)
    }

    @Test func explicitOccurrenceStateMatrix() {
        let states: [(RoutineCheckState?, String)] = [(nil, "open"), (.unprocessed, "open"), (.completed, "done"), (.skipped, "skipped")]
        for (state, expected) in states {
            for requested in ["open", "done", "skipped"] {
                let checks = state.map { [RoutineQueryFixture.check($0)] } ?? []
                let response = RoutineProviderFixture.read("/routines on:today status:" + requested,
                    evidence: [RoutineProviderFixture.schedule], checks: checks, coverage: [RoutineProviderFixture.complete])
                #expect(response.matches.count == (requested == expected ? 1 : 0))
                #expect(response.isCompleteForCoveredTypes)
                #expect(response.matches.first?.occurrence?.records.object.dayKey == (requested == expected ? "2026-10-01" : nil))
            }
        }
    }

    @Test func recordAmbiguityAndCompleteness() {
        let done = RoutineQueryFixture.check(.completed)
        let open = RoutineQueryFixture.check(.unprocessed)
        let source = "/routines on:today status:done"
        let duplicate = RoutineProviderFixture.read(source, evidence: [RoutineProviderFixture.schedule],
            checks: [done, done], coverage: [RoutineProviderFixture.complete])
        #expect(duplicate.matches.count == 1 && duplicate.isCompleteForCoveredTypes)
        #expect(duplicate.diagnostics.contains { $0.issue == .check(.identicalDuplicates) && $0.severity == .warning })
        var invalid = done
        invalid.isSkipped = true
        for checks in [[done, open], [invalid]] {
            let response = RoutineProviderFixture.read(source, evidence: [RoutineProviderFixture.schedule],
                checks: checks, coverage: [RoutineProviderFixture.complete])
            #expect(response.undeterminedObjects.count == 1 && response.matches.isEmpty)
        }
        let incomplete = RoutineProviderFixture.read(source, evidence: [RoutineProviderFixture.schedule], checks: [done])
        #expect(incomplete.undeterminedObjects.count == 1)
        let noHistory = RoutineProviderFixture.read(source, checks: [done], coverage: [RoutineProviderFixture.complete])
        #expect(noHistory.undeterminedObjects.count == 1)
        let notScheduled = RoutineQueryFixture.evidence("2026-10-01", "2026-10-01", rule: .notScheduled)
        #expect(RoutineProviderFixture.read(source, evidence: [notScheduled], checks: [done],
            coverage: [RoutineProviderFixture.complete]).matches.isEmpty)
        let foreignCoverage = RoutineCheckCoverage(routineID: TodoQueryFixture.work, completeIntervals: [QuerySessionFixture.interval()])
        #expect(RoutineProviderFixture.read(source, evidence: [RoutineProviderFixture.schedule], checks: [done],
            coverage: [foreignCoverage]).undeterminedObjects.count == 1)
    }

    @Test func onAndDateAreIndependent() {
        #expect(RoutineProviderFixture.read("/routines date:today status:open").state == .requiresInput)
        #expect(RoutineProviderFixture.read("/routines date:2026-10-02 on:today").state == .unsatisfiable)
        let response = RoutineProviderFixture.read("/routines date:today on:today status:open",
            evidence: [RoutineProviderFixture.schedule], coverage: [RoutineProviderFixture.complete])
        #expect(response.matches.count == 1)
        #expect(response.matches[0].dateExistence?.witnessDay == "2026-10-01")
        // 单独 on 只要求当天应执行，打卡不足的诊断不改变其排程真值。
        let onOnly = RoutineProviderFixture.read("/routines on:today", evidence: [RoutineProviderFixture.schedule])
        #expect(onOnly.matches.count == 1 && onOnly.isCompleteForCoveredTypes)
    }
}
