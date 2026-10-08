import Foundation
import Testing
@testable import AreaChain

struct RoutineSkippedCompatibilityTests {
    @Test(arguments: [0, 1, 2, 3]) func encodingSetsPreserveLogicalStateAndRawEvidence(kind: Int) {
        let alternate = RoutineQueryFixture.check(.skipped)
        var legacy = alternate
        legacy.isDone = true
        let inputs = [[legacy], [legacy, legacy], [legacy, alternate], [legacy, legacy, alternate]][kind]
        let before = inputs
        let read = RoutineQueryFixture.read(inputs)
        #expect(read.state == .skipped && read.observedState == .skipped && read.isComplete)
        #expect(read.inputIndices == Array(inputs.indices) && inputs == before)
        #expect(read.diagnostics.contains(.identicalDuplicates) == (kind == 1 || kind == 3))
        #expect(read.diagnostics.contains(.equivalentEncodingDuplicates) == (kind >= 2))
        #expect(read.diagnostics.allSatisfy { !$0.affectsDetermination })
        let partial = RoutineQueryFixture.read(inputs, complete: [])
        #expect(partial.state == .incomplete && partial.observedState == .skipped && !partial.isComplete)
        let conflict = RoutineQueryFixture.read(inputs + [RoutineQueryFixture.check(.completed)])
        #expect(conflict.state == .conflict && conflict.diagnostics.contains(.conflictingRecords))
    }

    @Test func routineOccurrenceAndImageConsumersAgreeWithoutPromotingCoverage() {
        var legacy = RoutineQueryFixture.check(.skipped)
        legacy.isDone = true
        let alternate = RoutineQueryFixture.check(.skipped)
        let rows = [legacy, alternate]
        let routine = RoutineProviderFixture.read("/routines on:today status:skipped", evidence: [RoutineProviderFixture.schedule],
            checks: rows, coverage: [RoutineProviderFixture.complete])
        #expect(routine.matches.count == 1 && routine.isCompleteForCoveredTypes)
        #expect(routine.diagnostics.contains { $0.issue == .check(.equivalentEncodingDuplicates) && !$0.affectsDetermination })
        var occurrence = RoutineOccurrenceQueryFixture("date:today status:skipped")
        occurrence.checks = rows
        #expect(occurrence.read().matches.count == 1 && occurrence.read().reviewRecords.isEmpty)
        occurrence.coverage = []
        #expect(occurrence.read().matches.isEmpty && !occurrence.read().isCompleteForCoveredTypes)
        let imageRows = rows.map { CheckSnapshot(routineId: ImageQueryFixture.ownerID, dayKey: $0.dayKey, isDone: $0.isDone, isSkipped: $0.isSkipped) }
        let image = ImageQueryProvider.read(ImageQueryFixture.scheduled("/images on:today status:skipped", checks: imageRows))
        #expect(image.matches.count == 1 && image.isCompleteForCoveredTypes)
        #expect(image.diagnostics.contains { $0.issue == .check(.equivalentEncodingDuplicates) && !$0.affectsDetermination })
    }
}
