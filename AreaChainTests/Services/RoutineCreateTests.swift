import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct RoutineCreateTests {
    @Test(arguments: [false, true]) func fullCreationAndOriginalRows(attributes: Bool) throws {
        let fixture = try RoutineCreateFixture()
        let before = try fixture.snapshots()
        let checks = try fixture.base.checks()
        try fixture.queue(title: attributes ? "散步 !p3 @09:30 #Work #恢复 #New" : "散步")
        let accepted = try fixture.accept()
        #expect(accepted.preview.sortOrder == 31 && accepted.preview.weekdayMask == WeekdayMask.workdays)
        #expect(try fixture.base.tags().count == 2 && fixture.base.base.deleted.deletedAt != nil)
        fixture.now += 60
        let facts = try fixture.submit(accepted)
        let row = try fixture.stored(accepted.creationID)
        #expect(facts.state == .saved && facts.save == .returned && facts.createdObject == accepted.object)
        #expect(row.title == "散步" && row.createdAt == fixture.now && row.createdDayKey == accepted.preview.createdDayKey)
        #expect(row.isEnabled && row.pausedOnDayKey == nil && row.deletedAt == nil && row.sourceBundleID.isEmpty && row.notes.isEmpty)
        #expect(row.weekdayMask == WeekdayMask.workdays && row.weekdaysOnly && row.sortOrder == 31 && row.checks.isEmpty)
        #expect(!row.isImportant && row.isUrgent == attributes && row.remindMinutes == (attributes ? 570 : nil))
        #expect(try fixture.snapshots().filter { $0.id != accepted.creationID } == before)
        #expect(try fixture.base.checks() == checks)
        #expect(fixture.base.count("save") == 1 && fixture.base.count("ui") == 1)
        #expect(fixture.base.notificationProcessed == 1 && fixture.base.calendarProcessed == 1)
        #expect(fixture.base.base.io.authorizations == (attributes ? [570] : []))
        #expect(fixture.base.sourceTargets.isEmpty)
        #expect(try fixture.handoff.state().execution?.outputs.isEmpty == true)
        #expect(try fixture.base.unit().routineCreation == facts)
        if attributes {
            #expect(TagIDList.parse(row.tagIDs).count == 3 && fixture.base.base.deleted.deletedAt == nil)
            #expect(facts.savedTagEffects?.contains(.createAndAssociate) == true)
            #expect(facts.savedTagEffects?.contains(.restoreAndAssociate) == true)
        }
    }

    @Test(arguments: [CommandFieldOperation.add, .remove, .replaceAll, .clear]) func finalTagOperations(mode: CommandFieldOperation) throws {
        let fixture = try RoutineCreateFixture()
        let id = fixture.base.base.deleted.id
        try fixture.queue(title: "散步 #恢复 #New", extra: [.init(parameter: .tags, operation: mode, value: mode == .clear ? nil : .tags([id]))])
        let accepted = try fixture.accept()
        let facts = try fixture.submit(accepted)
        let ids = TagIDList.parse(try fixture.stored(accepted.creationID).tagIDs)
        #expect(facts.state == .saved)
        #expect(ids.contains(id) == [CommandFieldOperation.add, .replaceAll].contains(mode))
        #expect(accepted.tagCreationIDs.isEmpty == [CommandFieldOperation.replaceAll, .clear].contains(mode))
        #expect((fixture.base.base.deleted.deletedAt == nil) == ids.contains(id))
    }

    @Test(arguments: [0, 1, 2, 3]) func explicitFieldsAndMetadataOnly(kind: Int) throws {
        let fixture = try RoutineCreateFixture()
        let title = kind == 0 ? "#New" : kind == 1 ? "@09:30" : kind == 2 ? "!p2" : "散步"
        let extra: [CommandArgument] = kind == 3 ? [
            .init(parameter: .priority, operation: .assign, value: .choice("p1")),
            .init(parameter: .time, operation: .setReminder, value: .time(600))] : []
        try fixture.queue(title: title, extra: extra)
        let accepted = try fixture.accept()
        let facts = try fixture.submit(accepted)
        #expect(facts.state == .saved)
        #expect(facts.savedRoutine?.title == (kind == 3 ? "散步" : ""))
        if kind == 3 { #expect(facts.savedRoutine?.remindMinutes == 600 && facts.savedRoutine?.isImportant == true) }
    }

    @Test(arguments: [0, 1, 2, 3, 4, 5]) func conflictAndIneffectiveMetadata(kind: Int) throws {
        let fixture = try RoutineCreateFixture()
        let titles = ["散步 !p1", "散步 @09:30", "散步 !p1", "散步 @09:30", "!p4", "#New"]
        let arguments: [CommandArgument] = [
            .init(parameter: .priority, operation: .assign, value: .choice("p2")),
            .init(parameter: .time, operation: .setReminder, value: .time(600)),
            .init(parameter: .priority, operation: .clear, value: nil),
            .init(parameter: .time, operation: .cancelReminder, value: nil),
            .init(parameter: .priority, operation: .clear, value: nil),
            .init(parameter: .tags, operation: .clear, value: nil)]
        try fixture.queue(title: titles[kind], extra: [arguments[kind]])
        let preview = try fixture.preview()
        #expect(!preview.canAccept)
        #expect(throws: RoutineCreateIssue.invalidInput) { try fixture.adapter.acceptCreation(preview, expecting: fixture.handoff.owned().lease) }
        #expect(try fixture.base.tags().count == 2 && fixture.base.count("save") == 0)
    }

    @Test(arguments: [0, -1, 128, 255]) func invalidWeekdays(mask: Int) throws {
        let fixture = try RoutineCreateFixture()
        try fixture.queue(mask: mask)
        #expect(throws: RoutineCreateIssue.invalidWeekdays) { try fixture.preview() }
        #expect(fixture.base.count("save") == 0)
    }

    @Test(arguments: ["one\ntwo", "one\r", "one // notes", ""]) func rejectedInputRetainsRaw(raw: String) throws {
        let fixture = try RoutineCreateFixture()
        try fixture.queue(title: raw)
        #expect(throws: (any Error).self) { try fixture.preview() }
        #expect(try fixture.handoff.state().plan.items.first?.draft.arguments.first?.value == .shortText(raw))
        #expect(fixture.base.count("save") == 0)
    }

    @Test func explicitCancellationOnNewObject() throws {
        let fixture = try RoutineCreateFixture()
        try fixture.queue(extra: [.init(parameter: .priority, operation: .clear, value: nil),
                                  .init(parameter: .time, operation: .cancelReminder, value: nil)])
        let facts = try fixture.submit(fixture.accept())
        #expect(facts.savedRoutine?.remindMinutes == nil && facts.savedRoutine?.isImportant == false)
        #expect(fixture.base.base.io.authorizations.isEmpty)
    }
}
