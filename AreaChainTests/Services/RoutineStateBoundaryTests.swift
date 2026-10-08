import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct RoutineStateBoundaryTests {
    @Test(arguments: Array(0...7)) func unreliableRecordsAndStartsKeepPause(kind: Int) throws {
        let f = try RoutineStateFixture()
        switch kind {
        case 0: f.routine.pausedOnDayKey = "2026-10-09"
        case 1: f.routine.pausedOnDayKey = "2026-02-30"
        case 2: f.routine.pausedOnDayKey = ""
        case 3: f.row("bad")
        case 4: f.context.insert(RoutineCheck(dayKey: f.base.today))
        case 5:
            let one = f.row("2026-10-05"), two = f.row("2026-10-06")
            two.id = one.id
        case 6: f.routine.pausedOnDayKey = nil; f.row("2026-10-09")
        default: f.routine.createdDayKey = "bad"
        }
        try f.context.save()
        let before = try f.base.checks(), snapshot = f.routine.snapshot
        try f.queue("routine.enabled")
        #expect(throws: (any Error).self) { try f.base.preview() }
        #expect(f.routine.snapshot == snapshot && !f.routine.isEnabled && f.base.count("save") == 0)
        #expect(try f.base.checks() == before)
    }

    @Test(arguments: Array(0...10), [false, true]) func acceptanceRejectsChangedEvidence(kind: Int, occurrence: Bool) throws {
        let f = try RoutineStateFixture(enabled: occurrence)
        let row = f.row(occurrence ? f.base.today : "2026-10-05")
        try f.context.save()
        let accepted = try f.accept(occurrence ? "occurrence.complete" : "routine.enabled", day: occurrence ? f.base.today : nil)
        switch kind {
        case 0: f.base.today = "2026-10-09"
        case 1: f.routine.weekdayMask = WeekdayMask.workdays
        case 2: f.routine.pausedOnDayKey = "2026-10-04"
        case 3: f.row(row.dayKey)
        case 4: row.isSkipped = true
        case 5: f.context.delete(row)
        case 6: f.base.targetRevision = UUID()
        case 7: f.base.inputRevision = UUID()
        case 8: row.routine = f.base.other
        case 9: f.row("2026-09-15")
        default: row.dayKey = "2026-09-16"
        }
        try f.context.save()
        #expect(throws: (any Error).self) { try f.base.submit(accepted) }
        #expect(f.base.count("save") == 0 && f.base.count("ui") == 0)
        #expect(try f.base.handoff.state().execution == nil)
    }

    @Test(arguments: [false, true]) func acceptedHistoricalOccurrenceRejectsWithdrawnOrChangedSchedule(withdraw: Bool) throws {
        let f = try RoutineStateFixture(enabled: true)
        let day = "2026-10-07"
        f.history(day)
        let accepted = try f.accept("occurrence.complete", day: day)
        let before = try f.base.checks(), definition = f.routine.snapshot
        f.base.stateHistory = withdraw ? [] : [.init(routineID: f.routine.id,
            interval: .init(lowerBound: day, upperBound: day), rule: .weekdays(WeekdayMask.all),
            source: .synthetic(reference: "rm3-revised-history"))]
        #expect(throws: (any Error).self) { try f.base.submit(accepted) }
        #expect(try f.base.checks() == before && f.routine.snapshot == definition)
        #expect(f.base.count("save") == 0 && f.base.count("ui") == 0)
        #expect(try f.base.handoff.state().execution == nil)
        #expect(f.base.handoff.coordinator.routines.acceptances[accepted.preview.draft.draftID] == accepted)
    }

    @Test func acceptedBridgeCannotUseTransferredHostLease() throws {
        let f = try RoutineStateFixture()
        let accepted = try f.accept()
        let lease = try f.base.handoff.owned().lease
        let before = try f.base.checks(), definition = f.routine.snapshot
        try f.base.handoff.transfer()
        #expect(throws: (any Error).self) { try f.base.adapter.submit(accepted: accepted, expecting: lease) }
        #expect(f.base.count("save") == 0 && f.base.count("ui") == 0)
        #expect(try f.base.checks() == before && f.routine.snapshot == definition)
        #expect(try f.base.handoff.state(HandoffFixture.target).execution == nil)
        #expect(!accepted.checkCreationIDs.isEmpty)
    }

    @Test(arguments: [0, 1, 2, 3], [false, true]) func commitRollbackUnknownAndPublicationAreSeparate(kind: Int, occurrence: Bool) throws {
        let f = try RoutineStateFixture(enabled: occurrence)
        let before = f.routine.snapshot, checks = try f.base.checks()
        let accepted = try f.accept(occurrence ? "occurrence.skip" : "routine.enabled", day: occurrence ? f.base.today : nil)
        if kind < 2 { f.base.saveMode = kind == 0 ? .throwBefore : .throwAfter }
        if kind == 2 { f.base.environment.beforePublication = { throw CocoaError(.fileWriteUnknown) } }
        if kind == 3 { f.base.afterRegistration = { throw CocoaError(.fileWriteUnknown) } }
        let facts = try f.base.submit(accepted)
        #expect(facts.state == (kind < 2 ? .unknown : .saved))
        #expect(facts.stateImpact == accepted.preview.stateImpact && facts.checkCreationIDs == accepted.checkCreationIDs)
        #expect(try f.base.unit().routine?.stateImpact == facts.stateImpact)
        if kind == 0 {
            #expect(try f.base.stored().snapshot == before && f.base.checks() == checks)
            #expect(facts.rollback == .returned)
        } else {
            #expect(Set(f.routine.checks.map(\.id)) == Set(accepted.checkCreationIDs.values))
            let stored = try f.base.checks().filter { $0.parent == f.routine.id }
            #expect(Set(stored.map(\.id)) == Set(accepted.checkCreationIDs.values))
            #expect(stored.allSatisfy { $0.done && $0.skipped && accepted.checkCreationIDs[$0.day] == $0.id })
            #expect(kind != 2 || facts.publicationFailed)
            #expect(kind != 3 || facts.registrationFailed)
        }
        #expect(f.base.count("save") == 1)
        if kind < 2 {
            let run = try #require(f.base.handoff.state().execution)
            let operation = try #require(run.operation(accepted.preview.item.id))
            #expect(try f.base.adapter.verifyUnknown(operation, expecting: f.base.handoff.owned().lease) == .singleLive)
            #expect(try f.base.unit().local == .unknown)
        }
        #expect(throws: (any Error).self) { try f.base.submit(accepted) }
        #expect(f.base.count("save") == 1)
    }

    @Test func reentryIsOccupiedAndLastMomentAdditionRejectsWithoutPartialBackfill() throws {
        let f = try RoutineStateFixture()
        try f.queue("routine.enabled")
        f.base.sourceRead = { #expect(throws: CommandExecutionError.busy) { try f.base.preview() } }
        let accepted = try f.base.adapter.accept(f.base.preview(), expecting: f.base.handoff.owned().lease)
        f.base.sourceRead = nil
        var calls = 0
        f.base.beforeTransaction = {
            calls += 1
            if calls == 2 { f.row("2026-10-05"); try f.context.save() }
        }
        let facts = try f.base.submit(accepted)
        #expect(facts.state == .notSubmitted && facts.conflict && f.base.count("save") == 0)
        #expect(!f.routine.isEnabled && f.routine.checks.count == 1 && f.routine.checks.allSatisfy { !$0.isDone && !$0.isSkipped })
    }

    @Test func unassembledStateCommandsCannotPiggybackOnFiveFields() throws {
        let f = try RoutineCommandFixture()
        for command in CommandRoutineEdit.stateCommands { #expect(!f.adapter.supports(.init(rawValue: command))) }
        try f.queue("routine.enabled", .init(parameter: .enabled, operation: .assign, value: .boolean(true)))
        #expect(throws: RoutineCommandIssue.unassembled) { try f.preview() }
        #expect(f.count("save") == 0)
    }
    @Test func failureAfterApplyingDefinitionAndRowsRollsBackOneTransaction() throws {
        let f = try RoutineStateFixture()
        let row = f.row("2026-10-05")
        try f.context.save()
        let before = f.routine.snapshot, checks = try f.base.checks()
        let accepted = try f.accept()
        let repository = RecurringToggleRepository(f.context)
        repository.afterStateWork = {
            #expect(f.routine.isEnabled && f.routine.pausedOnDayKey == nil && row.isDone && row.isSkipped)
            #expect(f.routine.checks.count == 3)
            throw CocoaError(.fileWriteUnknown)
        }
        f.base.repository = { _ in repository }
        let facts = try f.base.submit(accepted)
        #expect(facts.state == .notSubmitted && facts.rollback == .returned && facts.save == .notCalled)
        #expect(f.routine.snapshot == before && !f.context.hasChanges)
        #expect(try f.base.checks() == checks && f.base.stored().snapshot == before)
        #expect(f.base.count("save") == 0 && f.base.count("ui") == 0 && f.base.base.io.registered.isEmpty)
        #expect(facts.checkCreationIDs == accepted.checkCreationIDs)
    }

}
