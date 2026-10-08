import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct RoutineCreateBoundaryTests {
    @Test(arguments: Array(0...7)) func invalidatedEnvironmentIsNotSubmitted(kind: Int) throws {
        let fixture = try RoutineCreateFixture()
        try fixture.queue(title: "散步 #New")
        let accepted = try fixture.accept()
        switch kind {
        case 0: fixture.now += 86400
        case 1: fixture.base.other.sortOrder += 1
        case 2: fixture.context.insert(DailyRoutine(title: "另一条", sortOrder: -1))
        case 3: fixture.context.delete(fixture.base.other)
        case 4: fixture.inputRevision = UUID()
        case 5: fixture.environmentRevision = UUID()
        case 6: fixture.base.base.live.name = "Changed"
        default: fixture.base.base.todo.title = "唯一未保存输入"
        }
        if kind != 7 { try fixture.context.save() }
        #expect(throws: (any Error).self) { try fixture.submit(accepted) }
        #expect(fixture.base.count("save") == 0 && fixture.base.count("preSave") == 0 && fixture.base.count("ui") == 0)
        if kind == 7 { #expect(fixture.context.hasChanges && fixture.base.base.todo.title == "唯一未保存输入") }
        #expect(try fixture.handoff.state().plan.items.first?.draft.arguments == accepted.preview.arguments)
    }

    @Test(arguments: [0, 1, 2, 3]) func collisionsIncludeDisabledTombstoneAndDuplicate(kind: Int) throws {
        let fixture = try RoutineCreateFixture()
        try fixture.queue(title: "散步 #New")
        let accepted = try fixture.accept()
        if kind == 3 {
            fixture.context.insert(TagItem(id: try #require(accepted.tagCreationIDs.values.first), name: "collision", sortOrder: 9))
        } else {
            fixture.context.insert(DailyRoutine(id: accepted.creationID, title: "collision", sortOrder: 9,
                isEnabled: kind != 1, deletedAt: kind == 2 ? .now : nil))
        }
        try fixture.context.save()
        #expect(throws: (any Error).self) { try fixture.submit(accepted) }
        #expect(fixture.base.count("save") == 0)
        #expect(throws: (any Error).self) {
            try SwiftDataRoutineRepository(context: fixture.context).addRoutine(.init(title: "direct", creationID: fixture.base.routine.id))
        }
    }

    @Test(arguments: [false, true]) func invalidSortBasis(duplicate: Bool) throws {
        let fixture = try RoutineCreateFixture()
        if duplicate { fixture.context.insert(DailyRoutine(id: fixture.base.routine.id, title: "duplicate", sortOrder: 0)) }
        else { fixture.base.other.sortOrder = Int.max }
        try fixture.context.save()
        try fixture.queue()
        #expect(throws: RoutineCreateIssue.unreliableSort) { try fixture.preview() }
    }

    @Test func separateSourcesAndNotesAreRequired() throws {
        for kind in 0..<4 {
            let fixture = try RoutineCreateFixture()
            if kind == 0 { fixture.inputProtection = .required }
            if kind == 1 { fixture.environmentProtection = .required }
            if kind == 2 { fixture.onSource = { throw CocoaError(.fileReadUnknown) } }
            let extra: [CommandArgument] = kind == 3 ? [.init(parameter: .notes, operation: .assign, value: .longText("notes"))] : []
            try fixture.queue(extra: extra)
            #expect(throws: (any Error).self) { try fixture.preview() }
            #expect(fixture.base.sourceTargets.isEmpty && fixture.base.count("save") == 0)
        }
    }

    @Test func stableIdentityAcrossInstancesAndReentry() throws {
        let fixture = try RoutineCreateFixture()
        try fixture.queue(title: "散步 #New")
        fixture.onSource = { #expect(throws: CommandExecutionError.busy) { try fixture.preview() } }
        let accepted = try fixture.accept()
        fixture.onSource = nil
        let second = RoutineCommandAdapter(coordinator: fixture.handoff.coordinator, environment: fixture.environment)
        #expect(try second.acceptCreation(accepted.preview, expecting: fixture.handoff.owned().lease) == accepted)
        fixture.base.afterRegistration = {
            #expect(throws: (any Error).self) { try second.submitCreation(accepted: accepted, expecting: fixture.handoff.owned().lease) }
        }
        let facts = try fixture.submit(accepted)
        #expect(facts.createdObject == accepted.object)
        #expect(throws: (any Error).self) { try fixture.submit(accepted) }
        #expect(fixture.base.count("save") == 1 && fixture.base.count("ui") == 1)
        #expect(try fixture.context.fetchCount(FetchDescriptor<DailyRoutine>()) == 3)
    }

    @Test func newDayRequiresNewAcceptanceButPreservesReservedIdentity() throws {
        let fixture = try RoutineCreateFixture()
        try fixture.queue(title: "散步 #New")
        let old = try fixture.accept()
        fixture.now += 86400
        #expect(throws: RoutineCreateIssue.dateChanged) { try fixture.submit(old) }
        let current = try fixture.accept()
        #expect(current.creationID == old.creationID && current.tagCreationIDs == old.tagCreationIDs && current.id != old.id)
        #expect(throws: (any Error).self) { try fixture.submit(old) }
        #expect(try fixture.submit(current).state == .saved)
    }

    @Test(arguments: Array(0...4)) func rollbackUnknownAndExternalFailures(kind: Int) throws {
        let fixture = try RoutineCreateFixture()
        let rows = try fixture.snapshots()
        let checks = try fixture.base.checks()
        try fixture.queue(title: "散步 @09:30 #New #恢复")
        let accepted = try fixture.accept()
        if kind == 0 { fixture.base.saveMode = .throwBefore }
        if kind == 1 { fixture.base.saveMode = .throwAfter }
        if kind == 2 { fixture.environment.beforePublication = { throw CocoaError(.fileWriteUnknown) } }
        if kind == 3 { fixture.base.afterRegistration = { throw CocoaError(.fileWriteUnknown) } }
        if kind == 4 { fixture.base.notificationResult = .failed; fixture.base.calendarResult = .failed }
        let facts = try fixture.submit(accepted)
        #expect(facts.state == (kind < 2 ? .unknown : .saved))
        #expect(try fixture.base.checks() == checks)
        if kind == 0 {
            #expect(try fixture.snapshots() == rows && fixture.base.tags().count == 2 && fixture.base.base.deleted.deletedAt != nil)
        } else { #expect(try fixture.stored(accepted.creationID).title == "散步" && fixture.base.tags().count == 3) }
        if kind < 2 {
            let run = try #require(fixture.handoff.state().execution)
            let operation = try #require(run.operation(accepted.preview.item.id))
            #expect(try fixture.adapter.verifyCreation(operation, expecting: fixture.handoff.owned().lease) == (kind == 0 ? .absent : .singleLive))
            #expect(facts.createdObject == nil && fixture.base.base.io.authorizations.isEmpty)
        }
        #expect(kind != 2 || facts.publicationFailed)
        #expect(kind != 3 || facts.registrationFailed)
        #expect(throws: (any Error).self) { try fixture.submit(accepted) }
        #expect(fixture.base.count("save") == 1)
    }

    @Test func lastValidationRejectsLateChangesBeforePreSave() throws {
        let fixture = try RoutineCreateFixture()
        try fixture.queue()
        let accepted = try fixture.accept()
        var validations = 0
        fixture.base.beforeTransaction = {
            validations += 1
            if validations == 2 { fixture.base.base.todo.title = "Late unsaved" }
        }
        let facts = try fixture.submit(accepted)
        #expect(facts.state == .notSubmitted && fixture.base.count("preSave") == 0 && fixture.base.count("save") == 0)
        #expect(fixture.context.hasChanges && fixture.base.base.todo.title == "Late unsaved")
    }
}
