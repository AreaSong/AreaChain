import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct RoutineContentQueryCoverageTests {
    @Test func singleDayCoverageDoesNotClaimOtherDaysOrUnobservedRoutines() throws {
        let f = try RoutineContentQueryFixture()
        let parent = f.routine()
        f.check(parent, day: "2020-01-01", done: true)
        let result = f.read("/routines on:today status:open")
        #expect(result.routine.fetchScope == .allStoredRows)
        #expect(result.batch.facts.routine.checks.first?.dayKey == "2020-01-01")
        #expect(RoutineContentQueryFixture.covers(result, parent.id, "2026-10-01"))
        #expect(!RoutineContentQueryFixture.covers(result, parent.id, "2026-10-02"))
        #expect(!RoutineContentQueryFixture.covers(result, UUID(), "2026-10-01"))
        #expect(!RoutineContentQueryFixture.covers(result, parent.id, "2020-01-01"))
    }

    @Test func explicitIntervalsAndOnNarrowingStayBoundedDespiteFullFetch() throws {
        let f = try RoutineContentQueryFixture()
        let parent = f.routine()
        let ranged = f.records("date:2026-09-30..2026-10-02")
        #expect(RoutineContentQueryFixture.covers(ranged, parent.id, "2026-09-30", "2026-10-02"))
        #expect(!RoutineContentQueryFixture.covers(ranged, parent.id, "2026-09-29", "2026-10-02"))
        let narrowed = f.records("date:2026-09-30..2026-10-02 on:today")
        #expect(RoutineContentQueryFixture.covers(narrowed, parent.id, "2026-10-01"))
        #expect(!RoutineContentQueryFixture.covers(narrowed, parent.id, "2026-09-30"))
        var options = ContentQueryBatchOptions()
        options.occurrenceWindow = RoutineOccurrenceQueryFixture.window("2026-10-02", "2026-10-04")
        let browse = f.records("", options: options)
        #expect(RoutineContentQueryFixture.covers(browse, parent.id, "2026-10-02", "2026-10-04"))
        let conflict = f.records("date:today", options: options)
        #expect(conflict.routine.fetchScope == .notRequested)
        #expect(try RoutineContentQueryFixture.occurrence(conflict).state == .invalidQuery)
    }

    @Test(arguments: ["/routines needle", "/routines date:today", "/routines status:done"])
    func definitionQueriesWithoutCheckDependencyDoNotFetchHistory(source: String) throws {
        let f = try RoutineContentQueryFixture()
        f.routine()
        var reads = RoutineContentQueryReads(context: f.context)
        reads.allChecks = { Issue.record("unexpected history read"); return [] }
        let result = f.read(source, reads: reads)
        #expect(result.routine.fetchScope == .notRequested && result.batch.facts.routine.checkCoverage.isEmpty)
    }

    @Test func emptyChecksAreCompleteButMissingWindowDoesNotDefaultToToday() throws {
        let f = try RoutineContentQueryFixture()
        f.routine()
        let empty = f.records()
        #expect(empty.routine.checkSource == .complete && empty.batch.facts.routine.checks.isEmpty)
        let response = try RoutineContentQueryFixture.occurrence(empty)
        #expect(response.matches.count == 1 && response.matches.first?.occurrence.state == .open)
        let missing = f.records("")
        #expect(missing.routine.checkSource == .notProvided)
        #expect(try RoutineContentQueryFixture.occurrence(missing).state == .requiresInput)
    }

    @Test func legacyOverdueNeedsCreationThroughYesterdaySeparateFromOn() throws {
        let f = try RoutineContentQueryFixture()
        let parent = f.routine()
        parent.createdDayKey = "2026-09-29"
        f.check(parent, day: "2026-09-29", done: false)
        f.check(parent, day: "2026-09-29", done: true)
        f.check(parent, day: "2026-09-30", done: true, skipped: true)
        let session = TodoQueryFixture.session("needle on:today", page: .pending(lane: .overdue, filter: .init()))
        let result = f.reader.read(session: session, requestID: UUID(), observation: RoutineContentQueryFixture.observation())
        #expect(RoutineContentQueryFixture.covers(result, parent.id, "2026-09-29", "2026-10-01"))
        #expect(!RoutineContentQueryFixture.covers(result, parent.id, "2026-09-28"))
        let response = try RoutineContentQueryFixture.definitions(result)
        #expect(response.matches.isEmpty && !response.diagnostics.contains { $0.issue == .missingPageCheckCoverage })
        let justOn = f.read("/routines on:today")
        #expect(!RoutineContentQueryFixture.covers(justOn, parent.id, "2026-09-29", "2026-09-30"))
    }

    @Test func multipleDefinitionsUseOneIndependentRecordFetchIncludingTombstones() throws {
        let f = try RoutineContentQueryFixture()
        let live = f.routine()
        let disabled = f.routine(enabled: false)
        let deleted = f.routine(deleted: TodoQueryFixture.created)
        [live, disabled, deleted].forEach { f.check($0) }
        try f.context.save()
        var reads = RoutineContentQueryReads(context: f.context)
        let fetch = reads.allChecks
        var calls = 0
        reads.allChecks = { calls += 1; return try fetch() }
        let result = f.records(reads: reads)
        #expect(calls == 1 && result.batch.facts.routine.checks.count == 3)
        #expect(result.routine.rows.count == 3)
        #expect(try RoutineContentQueryFixture.occurrence(result).matches.map(\.id.id) == [live.id])
    }

    @Test func badInputLeavesLegacyPageCoverageUnknownAlongsideOn() throws {
        let f = try RoutineContentQueryFixture()
        f.routine()
        f.check(nil, day: "2026-09-04")
        let session = TodoQueryFixture.session("needle on:today", page: .pending(lane: .overdue, filter: .init()))
        let result = f.reader.read(session: session, requestID: UUID(), observation: RoutineContentQueryFixture.observation())
        #expect(result.routine.requestedCoverage.first?.completeIntervals.first?.lowerBound == "2026-09-01")
        #expect(result.batch.facts.routine.checkCoverage.isEmpty)
        #expect(try RoutineContentQueryFixture.definitions(result).diagnostics.contains { $0.issue == .missingPageCheckCoverage })
        let owner = try QueryReadFixture.owner(result.batch)
        #expect(owner.published?.response.completeness.matchingIsComplete == false)
    }
}
