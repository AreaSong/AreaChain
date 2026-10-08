import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct RoutineContentQueryReaderTests {
    @Test func allDefinitionsAndRealSnapshotFieldsSurviveProjection() throws {
        let f = try RoutineContentQueryFixture()
        let active = f.routine()
        let disabled = f.routine(enabled: false)
        let tombstone = f.routine(deleted: TodoQueryFixture.created)
        let both = f.routine(enabled: false, deleted: TodoQueryFixture.created)
        active.weekdayMask = nil
        active.weekdaysOnly = true
        active.sortOrder = 14
        active.notes = "合成备注"
        active.remindMinutes = 345
        active.isImportant = true
        active.isUrgent = true
        active.sourceBundleID = "fixture.source"
        active.pausedOnDayKey = "2026-09-17"
        try f.context.save()
        let result = f.read()
        let values = try #require(result.batch.snapshots.routines.values)
        #expect(values.count == 4 && result.batch.snapshots.routines.coverage == .complete)
        for model in [active, disabled, tombstone, both] { #expect(values.first { $0.id == model.id } == model.snapshot) }
        let response = try RoutineContentQueryFixture.definitions(result)
        #expect(Set(response.matches.map(\.id.id)) == [active.id, disabled.id])
        #expect(result.routine.fetchScope == .notRequested && result.routine.checkSource == .notProvided)
    }

    @Test func duplicateIdentityIncludesDisabledAndDeletedRows() throws {
        let f = try RoutineContentQueryFixture()
        let live = f.routine()
        let deleted = f.routine(enabled: false, deleted: TodoQueryFixture.created)
        deleted.id = live.id
        f.check(live)
        try f.context.save()
        let result = f.read("/routines on:today status:open")
        #expect(result.batch.snapshots.routines.values?.count == 2)
        #expect(result.batch.snapshots.routines.coverage == .complete)
        #expect(result.batch.facts.routine.scheduleEvidence.isEmpty)
        #expect(result.batch.facts.routine.checkCoverage.isEmpty)
        #expect(result.routine.issues.contains { if case .ambiguousCheckParent = $0 { return true }; return false })
        let response = try RoutineContentQueryFixture.definitions(result)
        #expect(response.matches.isEmpty && response.diagnostics.contains { $0.issue == .duplicateRoutineID })
    }

    @Test func sameBusinessDayDuplicatesAndRawConflictingFlagsAreNotRewritten() throws {
        let f = try RoutineContentQueryFixture()
        let parent = f.routine()
        let first = f.check(parent, done: true)
        let second = f.check(parent, done: true)
        let both = f.check(parent, day: "2026-10-02", done: true, skipped: true)
        f.check(parent, day: "2026-10-03", done: false)
        f.check(parent, day: "2026-10-03", done: true)
        try f.context.save()
        let result = f.records("date:2026-10-01..2026-10-03")
        #expect(result.batch.facts.routine.checks.count == 5 && result.routine.rows.count == 5)
        #expect(Set(result.routine.rows.map(\.recordID)).count == 5)
        #expect(first.id != second.id && both.isDone && both.isSkipped)
        let coverage = try #require(result.batch.facts.routine.checkCoverage.first)
        let read = RoutineCheckReading.read(routineID: parent.id, on: "2026-10-01", checks: result.batch.facts.routine.checks,
                                            coverage: coverage, dates: result.batch.dates)
        #expect(read.state == .completed && read.inputIndices.count == 2 && read.diagnostics.contains(.identicalDuplicates))
        for day in ["2026-10-02", "2026-10-03"] {
            let conflict = RoutineCheckReading.read(routineID: parent.id, on: day, checks: result.batch.facts.routine.checks,
                                                    coverage: coverage, dates: result.batch.dates)
            #expect(conflict.state == (day == "2026-10-02" ? .skipped : .conflict))
        }
    }

    @Test func orphanRowsRemainEvidenceAndPreventCompleteEmptyResult() throws {
        let f = try RoutineContentQueryFixture()
        let orphan = f.check(nil)
        try f.context.save()
        let result = f.records()
        #expect(result.routine.rows.count == 1 && result.routine.rows.first?.recordID == orphan.id)
        #expect(result.routine.rows.first?.snapshotIndex == nil && result.batch.facts.routine.checks.isEmpty)
        #expect(result.routine.checkSource == .partial && result.batch.facts.routine.checkCoverage.isEmpty)
        #expect(result.batch.facts.routine.checkSourceProblem == .incompleteUnattributedInput)
        let response = ContentQueryBatchReader.read(result.batch)
        #expect(!response.canDeclareCompleteNoMatch && !response.completeness.matchingIsComplete)
        #expect(response.completeness.providers.contains { $0.limitations.contains(.checkSource(.incompleteUnattributedInput)) })
        #expect(orphan.routine == nil)
    }

    @Test(arguments: [0, 1, 2, 3]) func mixedSkipEncodingsKeepPhysicalEvidenceAndIntegrityLimits(issue: Int) throws {
        let f = try RoutineContentQueryFixture()
        let parent = f.routine()
        let legacy = f.check(parent, done: true, skipped: true)
        let alternate = f.check(parent, done: false, skipped: true)
        if issue == 1 { alternate.id = legacy.id }
        if issue == 2 { f.check(nil) }
        if issue == 3 { f.check(parent, day: "2026-02-30") }
        try f.context.save()
        let result = f.records("date:today status:skipped")
        let rows = result.routine.rows.filter { $0.recordID == legacy.id || $0.recordID == alternate.id }
        #expect(rows.count == 2)
        let indices = try rows.map { try #require($0.snapshotIndex) }
        let snapshots = indices.map { result.batch.facts.routine.checks[$0] }
        #expect(snapshots.count == 2 && snapshots.allSatisfy { $0.routineId == parent.id && $0.isSkipped })
        #expect(snapshots.filter(\.isDone).count == 1)
        #expect(legacy.isDone && legacy.isSkipped && !alternate.isDone && alternate.isSkipped)
        let response = try RoutineContentQueryFixture.occurrence(result)
        #expect(RoutineContentQueryFixture.covers(result, parent.id, QuerySessionFixture.today) == (issue == 0))
        if issue == 0 {
            let match = try #require(response.matches.first)
            #expect(match.id.id == parent.id && match.occurrence.records.state == .skipped)
            #expect(Set(match.occurrence.records.inputIndices) == Set(indices))
            #expect(response.diagnostics.contains { $0.issue == .check(.equivalentEncodingDuplicates)
                && !$0.affectsDetermination && Set($0.inputIndices) == Set(indices) })
        } else {
            #expect(response.matches.isEmpty && !response.isCompleteForCoveredTypes)
            #expect(!result.routine.issues.isEmpty)
        }
    }

    @Test func orphanPreventsDerivedOpenForOtherwiseValidDefinition() throws {
        let f = try RoutineContentQueryFixture()
        f.routine()
        f.check(nil)
        let result = f.records()
        #expect(result.batch.facts.routine.checkCoverage.isEmpty)
        #expect(try RoutineContentQueryFixture.occurrence(result).matches.isEmpty)
    }

    @Test func invalidDateIsPreservedAndOnlyRestrictsItsKnownRoutine() throws {
        let f = try RoutineContentQueryFixture()
        let bad = f.routine("bad")
        let good = f.routine("good")
        f.check(bad, day: "2026-02-30")
        try f.context.save()
        let result = f.records()
        #expect(result.batch.facts.routine.checks.first?.dayKey == "2026-02-30")
        #expect(result.routine.issues.contains { if case .invalidCheckDay = $0 { return true }; return false })
        #expect(!RoutineContentQueryFixture.covers(result, bad.id, QuerySessionFixture.today))
        #expect(RoutineContentQueryFixture.covers(result, good.id, QuerySessionFixture.today))
        #expect(result.batch.facts.routine.checkSourceProblem == nil)
        #expect(try RoutineContentQueryFixture.occurrence(result).matches.map(\.id.id) == [good.id])
    }

    @Test func duplicatePhysicalIDIsNotBusinessDayDeduplication() throws {
        let f = try RoutineContentQueryFixture()
        let bad = f.routine("bad")
        let good = f.routine("good")
        let first = f.check(bad)
        let second = f.check(bad, day: "2026-10-02")
        second.id = first.id
        try f.context.save()
        let result = f.records()
        #expect(result.routine.rows.count == 2 && result.batch.facts.routine.checks.count == 2)
        #expect(result.routine.issues.contains { if case .duplicateCheckID(let indices) = $0 { return indices.count == 2 }; return false })
        #expect(!RoutineContentQueryFixture.covers(result, bad.id, QuerySessionFixture.today))
        #expect(RoutineContentQueryFixture.covers(result, good.id, QuerySessionFixture.today))
    }

    @Test func absentEnumeratedParentIsLocalWithoutInventingIdentity() throws {
        let f = try RoutineContentQueryFixture()
        let missing = f.routine("missing")
        let good = f.routine("good")
        f.check(missing)
        var reads = RoutineContentQueryReads(context: f.context)
        reads.definitions = { [good] }
        let result = f.records(reads: reads)
        #expect(result.batch.facts.routine.checks.first?.routineId == missing.id)
        #expect(result.routine.issues.contains { if case .uncontainedCheckParent = $0 { return true }; return false })
        #expect(RoutineContentQueryFixture.covers(result, good.id, QuerySessionFixture.today))
        #expect(try RoutineContentQueryFixture.occurrence(result).matches.map(\.id.id) == [good.id])
    }
}
