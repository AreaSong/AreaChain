import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct RoutineCommandTests {
    @Test(arguments: Array(0...5), [true, false]) func realFieldsAndChecks(kind: Int, enabled: Bool) throws {
        let fixture = try RoutineCommandFixture(enabled: enabled)
        let before = fixture.routine.snapshot
        let checks = try fixture.checks()
        let accepted = try fixture.accept(RoutineCommandFixture.command(kind), RoutineCommandFixture.argument(kind))
        let facts = try fixture.submit(accepted)
        let stored = try fixture.stored()
        #expect(facts.object.type == .routine && facts.state == .saved && facts.save == .returned && facts.publication == .returned)
        switch kind {
        case 0:
            #expect(stored.title == "新习惯" && !stored.isImportant && stored.isUrgent && stored.remindMinutes == 570)
            let newID = try #require(accepted.tagCreationIDs.values.first)
            #expect(TagIDList.parse(stored.tagIDs) == [fixture.base.live.id, newID, fixture.base.deleted.id])
            #expect(try fixture.tags().count == 3 && fixture.tags().allSatisfy { $0.deletedAt == nil })
        case 1: #expect(stored.weekdayMask == 65 && !stored.weekdaysOnly)
        case 2: #expect(stored.remindMinutes == 570)
        case 3: #expect(!stored.isImportant && stored.isUrgent)
        case 4: #expect(stored.tagIDs.isEmpty && fixture.base.deleted.deletedAt != nil)
        default: #expect(stored.remindMinutes == nil)
        }
        try fixture.assertUnchanged(before, except: Set(accepted.preview.original.keys))
        #expect(try fixture.checks() == checks)
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 1)
        #expect(fixture.notificationProcessed == 1 && fixture.calendarProcessed == 1)
        #expect(fixture.base.io.authorizations == ([0, 2].contains(kind) ? [570] : []))
        #expect(try fixture.handoff.state().execution?.outputs.isEmpty == true)
        #expect(throws: (any Error).self) { try fixture.submit(accepted) }
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 1)
    }

    @Test(arguments: Array(0...5)) func noChangeHasNoWrites(kind: Int) throws {
        let fixture = try RoutineCommandFixture()
        if kind == 5 { fixture.routine.remindMinutes = nil; try fixture.context.save() }
        let checks = try fixture.checks()
        let accepted = try fixture.accept(RoutineCommandFixture.command(kind), RoutineCommandFixture.argument(kind, unchanged: true))
        #expect(accepted.preview.noChange)
        #expect(try fixture.submit(accepted).state == .noChange)
        #expect(fixture.base.io.trace.isEmpty && fixture.base.io.authorizations.isEmpty)
        #expect(try fixture.checks() == checks)
    }

    @Test(arguments: [CommandFieldOperation.add, .remove, .replaceAll, .clear]) func tagModes(mode: CommandFieldOperation) throws {
        let fixture = try RoutineCommandFixture()
        let checks = try fixture.checks()
        let target = mode == .remove ? fixture.base.live.id : fixture.base.deleted.id
        let accepted = try fixture.accept("routine.tags", .init(parameter: .tags, operation: mode, value: mode == .clear ? nil : .tags([target])))
        let facts = try fixture.submit(accepted)
        let expected = mode == .add ? [fixture.base.live.id, target] : mode == .replaceAll ? [target] : []
        let storedIDs = TagIDList.parse(try fixture.stored().tagIDs)
        #expect(facts.savedTagIDs == expected && storedIDs == expected)
        #expect(try fixture.tags().count == 2)
        #expect((fixture.base.deleted.deletedAt == nil) == [.add, .replaceAll].contains(mode))
        #expect(try fixture.checks() == checks)
    }

    @Test(arguments: [true, false]) func legacyWeekdaysRequireActualCompatibilityWrite(weekdaysOnly: Bool) throws {
        let fixture = try RoutineCommandFixture(enabled: false)
        fixture.routine.weekdayMask = nil
        fixture.routine.weekdaysOnly = weekdaysOnly
        try fixture.context.save()
        let checks = try fixture.checks()
        let mask = weekdaysOnly ? WeekdayMask.workdays : WeekdayMask.all
        let accepted = try fixture.accept("routine.weekdays", .init(parameter: .weekdays, operation: .assign, value: .weekdays(mask)))
        #expect(!accepted.preview.noChange && accepted.preview.original[.weekdayMask] == .number(nil))
        #expect(try fixture.submit(accepted).state == .saved)
        #expect(try fixture.stored().weekdayMask == mask && fixture.stored().weekdaysOnly == weekdaysOnly)
        #expect(try fixture.checks() == checks && !fixture.routine.isEnabled && fixture.routine.pausedOnDayKey == "2026-10-01")
    }

    @Test(arguments: ["原习惯 !p3", "原习惯 @09:30", "原习惯 #恢复", "原习惯 #New"]) func sameTitleWithEffectsStillSaves(raw: String) throws {
        let fixture = try RoutineCommandFixture()
        let accepted = try fixture.accept("routine.title", RoutineCommandFixture.title(raw))
        #expect(!accepted.preview.noChange)
        #expect(try fixture.submit(accepted).state == .saved && fixture.count("save") == 1)
        #expect(fixture.routine.title == "原习惯")
    }

    @Test func untouchedTombstoneAndUntouchedFieldsStayUnchanged() throws {
        let fixture = try RoutineCommandFixture()
        fixture.routine.tagIDs += "," + fixture.base.deleted.id.uuidString
        try fixture.context.save()
        let before = fixture.routine.snapshot
        let accepted = try fixture.accept("routine.title", RoutineCommandFixture.title("只是改标题"))
        _ = try fixture.submit(accepted)
        #expect(fixture.routine.tagIDs == before.tagIDs && fixture.base.deleted.deletedAt != nil)
        #expect(fixture.routine.remindMinutes == before.remindMinutes && fixture.routine.isImportant == before.isImportant)
    }
}
