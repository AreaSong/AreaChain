import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct RoutineEnabledCommandTests {
    @Test(arguments: [0, 1, 2, 3]) func pauseAndAlreadyEnabledEffects(kind: Int) throws {
        let f = try RoutineStateFixture(enabled: kind != 1)
        if kind == 3 { f.routine.pausedOnDayKey = "2026-10-01" }
        try f.context.save()
        let before = try f.base.checks()
        let accepted = try f.accept(enabled: kind >= 2)
        #expect(accepted.preview.noChange == (kind == 1 || kind == 2))
        let facts = try f.base.submit(accepted)
        #expect(facts.state == (kind == 1 || kind == 2 ? .noChange : .saved))
        #expect(f.routine.isEnabled == (kind >= 2))
        #expect(f.routine.pausedOnDayKey == (kind == 0 ? f.base.today : kind == 1 ? "2026-10-05" : nil))
        #expect(try f.base.checks() == before)
    }

    @Test(arguments: [0, 1, 2]) func preciseBridgePreservesClosedConflictsAndUpdatesEveryOpenPhysicalRow(encoding: Int) throws {
        let f = try RoutineStateFixture()
        let first = f.row("2026-10-05"), second = f.row("2026-10-05")
        let closed = f.row("2026-10-06", encoding != 2, encoding != 0), open = f.row("2026-10-06")
        try f.context.save()
        let other = f.base.other.snapshot
        var accepted = try f.accept()
        let impact = try #require(accepted.preview.stateImpact)
        #expect(impact.start == "2026-10-05" && impact.span == 3 && impact.startSource == .pausedDay)
        #expect(impact.inserted == 1 && impact.modified == 2 && impact.preserved == 2)
        #expect(impact.effects[1].diagnostics.contains(.conflictingRecords))
        let changedIDs = Set(impact.effects[0].original.map(\.id))
        #expect(changedIDs == Set([first.id, second.id]))
        #expect(try f.base.adapter.accept(accepted.preview, expecting: f.base.handoff.owned().lease) == accepted)
        let refreshed = try f.base.adapter.accept(f.base.preview(), expecting: f.base.handoff.owned().lease)
        #expect(refreshed.checkCreationIDs == accepted.checkCreationIDs)
        accepted = refreshed
        let facts = try f.base.submit(accepted)
        #expect(facts.state == .saved && facts.stateImpact == impact && facts.checkCreationIDs == accepted.checkCreationIDs)
        #expect(first.isDone && first.isSkipped && second.isDone && second.isSkipped)
        #expect(closed.isDone == (encoding != 2) && closed.isSkipped == (encoding != 0))
        #expect(!open.isDone && !open.isSkipped)
        let inserted = try #require(f.routine.checks.first { $0.dayKey == "2026-10-07" })
        #expect(inserted.id == accepted.checkCreationIDs["2026-10-07"] && inserted.routine === f.routine)
        #expect(inserted.isDone && inserted.isSkipped && !f.routine.checks.contains { $0.dayKey == f.base.today })
        #expect(f.base.other.snapshot == other && f.base.count("save") == 1 && f.base.count("ui") == 1)
        #expect(f.base.base.io.authorizations.isEmpty && f.base.notificationProcessed == 1 && f.base.calendarProcessed == 1)
    }

    @Test(arguments: [0, 1, 2]) func fallbackAndEmptySpan(kind: Int) throws {
        let f = try RoutineStateFixture(start: "2026-10-08")
        if kind != 0 { f.routine.pausedOnDayKey = nil; f.routine.createdDayKey = "2026-10-05" }
        if kind == 2 { f.row("2026-10-07") }
        try f.context.save()
        let accepted = try f.accept()
        let impact = try #require(accepted.preview.stateImpact)
        #expect(impact.span == [0, 3, 1][kind])
        #expect(impact.startSource == [.pausedDay, .creationDay, .latestRecord][kind])
        #expect(!accepted.preview.noChange)
        #expect(try f.base.submit(accepted).state == .saved && f.routine.isEnabled && f.routine.pausedOnDayKey == nil)
    }

    @Test(arguments: [4000, 4001]) func fullCivilSpanPrecedesWeekdayFiltering(span: Int) throws {
        let f = try RoutineStateFixture(start: "2000-01-01")
        f.routine.createdDayKey = "2000-01-01"
        f.routine.weekdayMask = span == 4001 ? WeekdayMask.only(weekday: 2) : WeekdayMask.all
        f.base.today = DayKey.shifted("2000-01-01", by: span, calendar: RoutineQueryFixture.dates.calendar)
        try f.context.save()
        try f.queue("routine.enabled")
        if span == 4001 {
            #expect(throws: RoutineStateIssue.intervalLimit) { try f.base.preview() }
            #expect(!f.routine.isEnabled && f.routine.checks.isEmpty && f.base.count("save") == 0)
            return
        }
        let resourceBefore = Phase1Clock.probe()
        let prepareStart = ProcessInfo.processInfo.systemUptime
        let preview = try f.base.preview()
        let prepareSeconds = ProcessInfo.processInfo.systemUptime - prepareStart
        #expect(preview.stateImpact?.span == 4000 && preview.stateImpact?.inserted == 4000)
        let accepted = try f.base.adapter.accept(preview, expecting: f.base.handoff.owned().lease)
        #expect(Set(accepted.checkCreationIDs.values).count == 4000)
        let commitStart = ProcessInfo.processInfo.systemUptime
        let facts = try f.base.submit(accepted)
        let commitSeconds = ProcessInfo.processInfo.systemUptime - commitStart
        #expect(facts.state == .saved && f.routine.checks.count == 4000 && f.base.count("save") == 1)
        #expect(Set(f.routine.checks.map(\.id)) == Set(accepted.checkCreationIDs.values))
        #expect(f.routine.checks.allSatisfy { $0.isDone && $0.isSkipped && $0.routine === f.routine && $0.dayKey < f.base.today })
        let resourceAfter = Phase1Clock.probe()
        print("RM3_RESOURCE rssBefore=\(resourceBefore.rss) rssAfter=\(resourceAfter.rss) footprintBefore=\(resourceBefore.footprint) footprintAfter=\(resourceAfter.footprint)")
        print("RM3_COST Debug warm-process memory-store rows=4000 prepareSeconds=\(prepareSeconds) submitSeconds=\(commitSeconds)")
    }

    @Test func currentWeekdaysApplyWithoutPretendingHistoricalSchedule() throws {
        let f = try RoutineStateFixture()
        f.routine.weekdayMask = WeekdayMask.only(weekday: 3)
        f.history("2026-10-05")
        try f.context.save()
        let accepted = try f.accept()
        #expect(accepted.preview.stateImpact?.effects.map(\.day) == ["2026-10-06"])
        #expect(try f.base.submit(accepted).state == .saved && f.routine.checks.count == 1)
    }
}
