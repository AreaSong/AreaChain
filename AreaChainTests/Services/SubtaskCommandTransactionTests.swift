import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct SubtaskCommandTransactionTests {
    typealias Fixture = SubtaskCommandFixture
    static let commands = ["subtask.create", "subtask.title", "subtask.completion", "subtask.tags"]
    func arguments(_ kind: Int, fixture: Fixture) -> [CommandArgument] {
        switch kind {
        case 0: return fixture.createArguments("新子项 #恢复 #New")
        case 1: return [Fixture.title("新标题 #恢复 #New")]
        case 2: return [TaskTM2Fixture.completion(true)]
        default: return [TaskTM2Fixture.tags(.add, [fixture.base.deleted.id])]
        }
    }

    @Test(arguments: 0..<4) func mutationFailureRollsBackChildAndTagsTogether(kind: Int) throws {
        let fixture = try Fixture()
        fixture.failMutation = true
        let before = fixture.child.snapshot
        let parent = fixture.base.todo.snapshot
        let accepted = try fixture.accept(Self.commands[kind], arguments(kind, fixture: fixture))
        let facts = try fixture.submit(accepted)
        #expect(facts.state == .notSubmitted && facts.save == .notCalled && facts.rollback == .returned)
        #expect(facts.createdObject == nil && facts.savedTagIDs == nil)
        #expect(try fixture.storedChild().snapshot == before && fixture.children().count == 3)
        #expect(try fixture.tags().count == 2 && fixture.tags().first { $0.id == fixture.base.deleted.id }?.deletedAt != nil)
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0 && !fixture.context.hasChanges)
        try fixture.assertParentUnchanged(parent)
    }

    @Test(arguments: 0..<4, [false, true]) func unknownNeverReplaysOrReallocatesIdentity(kind: Int, commitsFirst: Bool) throws {
        let fixture = try Fixture()
        let before = fixture.child.snapshot
        let accepted = try fixture.accept(Self.commands[kind], arguments(kind, fixture: fixture))
        fixture.saveMode = commitsFirst ? .throwAfter : .throwBefore
        let facts = try fixture.submit(accepted)
        #expect(facts.state == .unknown && facts.save == .called && facts.rollback == .returned)
        #expect(facts.createdObject == nil && facts.savedTagEffects == nil && facts.savedTitle == nil)
        #expect(try fixture.children().count == (kind == 0 && commitsFirst ? 4 : 3))
        if !commitsFirst { #expect(try fixture.storedChild().snapshot == before && fixture.tags().count == 2) }
        if commitsFirst && kind < 2 { #expect(try fixture.tags().count == 3) }
        let run = try #require(fixture.handoff.state().execution)
        let operation = try #require(run.operation(accepted.preview.item.id))
        _ = try fixture.adapter.verifyUnknown(operation, expecting: fixture.handoff.owned().lease)
        #expect(try fixture.unit().local == .unknown)
        #expect(fixture.handoff.coordinator.subtasks.acceptances[accepted.preview.draft.draftID] == accepted)
        #expect(throws: (any Error).self) { try fixture.submit(accepted) }
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 0 && !fixture.context.hasChanges)
    }

    @Test(arguments: 0..<4) func localSaveSurvivesRegistrationPublicationAndFakeFailures(kind: Int) throws {
        let fixture = try Fixture()
        let accepted = try fixture.accept("subtask.create", fixture.createArguments("New #恢复 #Tag"))
        switch kind {
        case 0: fixture.afterRegistration = { throw CocoaError(.fileWriteUnknown) }
        case 1: fixture.environment.beforePublication = { throw CocoaError(.fileWriteUnknown) }
        case 2: fixture.notificationResult = .failed; fixture.calendarResult = .failed
        default: fixture.environment.afterPublication = { throw CocoaError(.fileWriteUnknown) }
        }
        let facts = try fixture.submit(accepted)
        #expect(facts.state == .saved && facts.createdObject == accepted.object)
        #expect(facts.registrationFailed == (kind == 0) && facts.publicationFailed == (kind == 1 || kind == 3))
        #expect(try fixture.children().count == 4 && fixture.tags().count == 3)
        #expect(try fixture.unit().local == .committed && fixture.unit().subtask?.createdObject == accepted.object)
        #expect(throws: (any Error).self) { try fixture.submit(accepted) }
        #expect(fixture.count("save") == 1)
    }

    @Test func reentryFromSourceTransactionSaveAndPublicationCannotCreateTwice() throws {
        let fixture = try Fixture()
        let accepted = try fixture.accept("subtask.create", fixture.createArguments("New #Tag"))
        let other = SubtaskCommandAdapter(coordinator: fixture.handoff.coordinator, environment: fixture.environment)
        let attempt = try fixture.request()
        let reenter = {
            #expect(throws: (any Error).self) { try other.execute(attempt) }
            #expect(throws: (any Error).self) { try other.submit(accepted: accepted, expecting: fixture.handoff.owned().lease) }
        }
        fixture.sourceRead = reenter
        fixture.beforeTransaction = reenter
        fixture.onSave = reenter
        fixture.afterRegistration = reenter
        fixture.onRefresh = reenter
        #expect(try fixture.adapter.execute(attempt).state == .saved)
        #expect(throws: (any Error).self) { try other.execute(attempt) }
        #expect(try fixture.children().count == 4 && fixture.tags().count == 3)
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 1)
    }

    @Test func wrongTypedReceiptCannotReplaceSavedSubtask() throws {
        let fixture = try Fixture()
        let accepted = try fixture.accept("subtask.create", fixture.createArguments())
        let request = try fixture.request()
        var run = try #require(fixture.handoff.state().execution)
        let fake = CommandSubtaskFacts(object: .init(type: .todo, id: accepted.object.id), parentID: accepted.preview.parent.id,
                                      isCreation: true, state: .saved, save: .returned)
        #expect(throws: CommandExecutionError.invalidResult) { try run.recordSubtask(fake, attempt: request.attempt) }
        let facts = try fixture.adapter.execute(request)
        run = try #require(fixture.handoff.state().execution)
        #expect(throws: (any Error).self) { try run.recordSubtask(fake, attempt: request.attempt) }
        #expect(run.units.first?.subtask?.createdObject == facts.createdObject && run.outputs.isEmpty)
    }
}
