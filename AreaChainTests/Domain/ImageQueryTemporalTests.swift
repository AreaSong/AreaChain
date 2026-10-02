import Foundation
import Testing
@testable import AreaChain

struct ImageQueryTemporalTests {
    @Test func onStatusMatrixUsesExplicitDayAndRealRecordState() {
        for state in [RoutineCheckState.completed, .unprocessed, .skipped] {
            let check = RoutineQueryFixture.check(state, id: ImageQueryFixture.ownerID)
            for status in ["done", "open", "skipped"] {
                let expected = (state == .completed && status == "done") || (state == .unprocessed && status == "open")
                    || (state == .skipped && status == "skipped")
                let request = ImageQueryFixture.scheduled("/images on:today status:" + status, checks: [check])
                let response = ImageQueryProvider.read(request)
                #expect(response.matches.count == (expected ? 1 : 0))
                #expect(response.matches.allSatisfy { $0.owner.kind == .routine && $0.occurrence?.records.object.dayKey == "2026-10-01" })
                if let match = response.matches.first {
                    #expect(match.evidence.contains { $0.field == .ownerCompletion && $0.ownerObject?.type == .routine
                        && $0.relatedObject?.type == .routineOccurrence })
                    #expect(match.evidence.contains { $0.field == .ownerOccurrenceDay })
                }
            }
        }
    }

    @Test func missingAndConflictingHistoryDoNotBecomeOpen() {
        let missing = ImageQueryFixture.read("/images on:today status:open")
        #expect(missing.matches.isEmpty && missing.undeterminedObjects.count == 1)
        #expect(missing.diagnostics.contains { $0.issue == .schedule(.missingHistory) })
        var request = ImageQueryFixture.scheduled("/images on:today status:open")
        request.scheduleEvidence.append(RoutineQueryFixture.evidence("2026-10-01", "2026-10-01", rule: .notScheduled,
                                                                    id: ImageQueryFixture.ownerID))
        let conflict = ImageQueryProvider.read(request)
        #expect(conflict.undeterminedObjects.count == 1)
        #expect(conflict.diagnostics.contains { $0.issue == .schedule(.conflictingEvidence) })
        request.scheduleEvidence.removeLast()
        request.checkCoverage = []
        let incomplete = ImageQueryProvider.read(request)
        #expect(incomplete.undeterminedObjects.count == 1)
        #expect(incomplete.diagnostics.contains { $0.issue == .check(.incompleteInput) })
    }

    @Test func checkConflictsAndIdenticalDuplicatesHaveDifferentDetermination() {
        let done = RoutineQueryFixture.check(.completed, id: ImageQueryFixture.ownerID)
        let skipped = RoutineQueryFixture.check(.skipped, id: ImageQueryFixture.ownerID)
        let conflict = ImageQueryProvider.read(ImageQueryFixture.scheduled("/images on:today status:done", checks: [done, skipped]))
        #expect(conflict.undeterminedObjects.count == 1 && conflict.matches.isEmpty)
        #expect(conflict.diagnostics.contains { $0.issue == .check(.conflictingRecords) })
        var invalid = done
        invalid.isSkipped = true
        #expect(ImageQueryProvider.read(ImageQueryFixture.scheduled("/images on:today status:done", checks: [invalid]))
            .diagnostics.contains { $0.issue == .check(.doneAndSkipped) })
        let duplicate = ImageQueryProvider.read(ImageQueryFixture.scheduled("/images on:today status:done", checks: [done, done]))
        #expect(duplicate.matches.count == 1 && duplicate.isCompleteForCoveredTypes)
        #expect(duplicate.diagnostics.contains { $0.issue == .check(.identicalDuplicates) && !$0.affectsDetermination })
    }

    @Test func filenameDoesNotDependOnHistoryOrChecksAndOnAloneDoesNotRequireRecords() {
        var request = ImageQueryFixture.request("/images photo")
        request.scheduleEvidence = [RoutineQueryFixture.evidence("bad", "invalid", id: ImageQueryFixture.ownerID)]
        let response = ImageQueryProvider.read(request)
        #expect(response.matches.count == 3 && response.diagnostics.isEmpty && response.isCompleteForCoveredTypes)
        var on = ImageQueryFixture.scheduled("/images on:today")
        on.checkCoverage = []
        let scheduled = ImageQueryProvider.read(on)
        #expect(scheduled.matches.count == 1 && scheduled.isCompleteForCoveredTypes)
        #expect(scheduled.diagnostics.contains { $0.issue == .check(.incompleteInput) && !$0.affectsDetermination })
    }

    @Test func dateWitnessUsesFinalIntersectionAndIsNotAnOperationDay() {
        var request = ImageQueryFixture.scheduled("/images (date:2026-09-01 | date:today) date:today")
        request.scheduleEvidence = [RoutineQueryFixture.evidence("2026-10-01", "2026-10-01", id: ImageQueryFixture.ownerID)]
        let result = ImageQueryProvider.read(request)
        #expect(result.matches.count == 3)
        let routine = result.matches[1]
        #expect(routine.dateExistence?.witnessDay == "2026-10-01" && routine.occurrence == nil)
        #expect(routine.evidence.contains { $0.field == .ownerScheduleExistence && $0.alternativeIndex == 1 })
        let broad = ImageQueryFixture.scheduled("/images date:2026-09-01..2026-10-07")
        request = .init(requestID: broad.requestID, session: broad.session, association: broad.association,
                        scheduleEvidence: request.scheduleEvidence)
        let partial = ImageQueryProvider.read(request)
        #expect(partial.matches.count == 3)
        #expect(partial.matches[1].dateExistence?.unknownReasons == [.missingHistory])
        #expect(partial.isCompleteForCoveredTypes)
    }

    @Test func definiteFilenameMissCanExcludeObjectWithUnknownHistory() {
        let response = ImageQueryFixture.read("/images missing date:today")
        #expect(response.matches.isEmpty && response.undeterminedObjects.isEmpty && response.isCompleteForCoveredTypes)
        #expect(response.diagnostics.contains { $0.issue == .schedule(.missingHistory) && !$0.affectsDetermination })
        let mixed = ImageQueryFixture.read("/images photo date:today")
        #expect(mixed.matches.map(\.owner.kind) == [.todo, .diary])
        #expect(mixed.undeterminedObjects.count == 1 && !mixed.isCompleteForCoveredTypes)
    }
}
