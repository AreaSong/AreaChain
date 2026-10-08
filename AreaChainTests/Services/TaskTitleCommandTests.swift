import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TaskTitleCommandTests {
    @Test func originalParametersPreviewAcceptanceRunAndRealModification() throws {
        let fixture = try TaskTitleCommandFixture()
        let preview = try fixture.prepare()
        #expect(preview.impact.changedFields == [.title])
        #expect(fixture.base.io.trace.isEmpty && !fixture.base.io.context.hasChanges)
        let accepted = try fixture.accept(preview)
        #expect(accepted.tagCreationIDs.isEmpty && fixture.base.io.trace.isEmpty)
        let request = try fixture.request()
        let resolved = try #require(fixture.handoff.state().execution?.resolvedInput(request.operation.item.id))
        #expect(resolved.arguments == preview.arguments + [
            .init(parameter: .target, operation: .assign, value: .object(preview.impact.target))
        ])
        #expect(throws: CommandTaskTitlePreviewIssue.unsupportedPlan) {
            try fixture.environment.reader.prepare(in: fixture.handoff.owned())
        }
        let facts = try fixture.adapter.execute(request)
        #expect(facts.state == .saved && facts.targetID == fixture.base.todo.id)
        #expect(try fixture.base.io.readTodos().first?.title == "新标题")
        #expect(try fixture.handoff.state().execution?.snapshot.items.first?.draft.arguments == preview.arguments)
        #expect(try fixture.handoff.state().execution?.outputs.isEmpty == true)
        #expect(try fixture.unit().taskCreation == nil && fixture.unit().local == .committed)
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 1 && fixture.count("authorize") == 0)
        #expect(CommandCatalog.standard.command(id: .init(rawValue: "todo.title"))?.createdObjectType == nil)
    }

    @Test func derivedFieldsTagsAndRestorationSaveTogetherWithReservedIdentity() throws {
        let fixture = try TaskTitleCommandFixture()
        fixture.io.notificationResult = .succeeded
        fixture.io.calendarResult = .failed
        let preview = try fixture.prepare("新标题 #恢复 #新 !p3 @18:00")
        #expect(preview.impact.tags.sideEffects.map(\.effect) == [.restoreAndAssociate, .createAndAssociate])
        #expect(preview.impact.tags.finalEncodedIDs == nil)
        #expect(try fixture.base.io.context.fetchCount(FetchDescriptor<TagItem>()) == 2)
        let accepted = try fixture.accept(preview)
        let newID = try #require(accepted.tagCreationIDs[TagSyntax.normalizedName("新")])
        #expect(try fixture.base.io.context.fetchCount(FetchDescriptor<TagItem>()) == 2)
        let facts = try fixture.submit(accepted)
        let todo = try #require(fixture.base.io.readTodos().first)
        #expect(todo.title == "新标题" && todo.notes.isEmpty && !todo.isImportant && todo.isUrgent && todo.remindMinutes == 1080)
        #expect(TagIDList.parse(todo.tagIDs) == [fixture.base.live.id, fixture.base.deleted.id, newID])
        #expect(fixture.base.deleted.deletedAt == nil)
        #expect(facts.savedTagEffects == [.restoreAndAssociate, .createAndAssociate])
        #expect(facts.authorizationRequest == .returned && facts.authorizationResult == .granted)
        #expect(facts.refreshRequested && facts.notificationRequested == true && facts.calendarRequested == true)
        #expect(try fixture.unit().effects[.notification] == .succeeded && fixture.unit().effects[.calendar] == .failed)
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 1 && fixture.base.io.authorizations == [1080])
        #expect(fixture.io.notificationProcessed == 1 && fixture.io.calendarProcessed == 1)
    }

    @Test(arguments: ["原标题 !p3", "原标题 @18:00", "原标题 #新", "原标题 #恢复"])
    func equalTitleDoesNotHideOtherWrites(text: String) throws {
        let fixture = try TaskTitleCommandFixture()
        let accepted = try fixture.accept(fixture.prepare(text))
        #expect(try fixture.submit(accepted).state == .saved)
        #expect(fixture.base.todo.title == "原标题" && fixture.count("save") == 1 && fixture.count("ui") == 1)
        if text.contains("!p3") { #expect(!fixture.base.todo.isImportant && fixture.base.todo.isUrgent) }
        if text.contains("@") { #expect(fixture.base.todo.remindMinutes == 1080 && fixture.base.io.authorizations == [1080]) }
        if text.contains("#新") { #expect(try fixture.base.fields().tags == ["Work", "新"]) }
        if text.contains("#恢复") { #expect(fixture.base.deleted.deletedAt == nil) }
    }

    @Test func completeNoChangeHasNoSaveTagWritePublicationOrAuthorization() throws {
        let fixture = try TaskTitleCommandFixture()
        let before = try fixture.base.fields()
        let accepted = try fixture.accept(fixture.prepare("原标题 #Work !p2 @07:00"))
        #expect(accepted.preview.impact.changedFields.isEmpty && accepted.preview.impact.tags.sideEffects.isEmpty)
        let facts = try fixture.submit(accepted)
        #expect(facts.state == .noChange && facts.save == .notCalled && facts.publication == .notCalled)
        #expect(facts.authorizationRequest == .notCalled && !facts.refreshRequested)
        #expect(try fixture.base.fields() == before)
        #expect(fixture.base.io.trace.isEmpty && !fixture.base.io.context.hasChanges)
        #expect(try fixture.unit().state == .succeeded && fixture.unit().local == .notSubmitted)
        #expect(try fixture.handoff.state().execution?.outputs.isEmpty == true)
    }

    @Test func encodingNormalizationAndExistingTombstoneAreRealEffects() throws {
        let fixture = try TaskTitleCommandFixture()
        fixture.base.todo.tagIDs = "\(fixture.base.live.id.uuidString.lowercased()),\(fixture.base.live.id.uuidString)"
        try fixture.base.io.context.save()
        let accepted = try fixture.accept(fixture.prepare("原标题"))
        #expect(accepted.preview.impact.changedFields == [.tagIDs])
        #expect(try fixture.submit(accepted).state == .saved)
        #expect(fixture.base.todo.tagIDs == TagIDList.encode([fixture.base.live.id]))
        let restore = try TaskTitleCommandFixture()
        restore.base.todo.tagIDs = TagIDList.encode([restore.base.live.id, restore.base.deleted.id])
        try restore.base.io.context.save()
        let plan = try restore.accept(restore.prepare("原标题 #恢复"))
        #expect(plan.preview.impact.changedFields.isEmpty && !plan.preview.impact.tags.sideEffects.isEmpty)
        #expect(try restore.submit(plan).state == .saved && restore.base.deleted.deletedAt == nil)
    }

    @Test(arguments: ["普通标题", "新 #恢复 #新标签 !p1 @18:00", "新 !p4", "新 #Work #Work", "新 !p3 @00:00"])
    func supportedInputMatchesOldTitleUIAndSharedEntry(text: String) throws {
        let command = try TaskTitleCommandFixture()
        let old = try TaskTitleCommandFixture()
        let shared = try TaskTitleCommandFixture()
        let accepted = try command.accept(command.prepare(text))
        _ = try command.submit(accepted)
        #expect(DayBoardMutations.editTodoWithSyntax(old.base.todo, rawInput: text, dependencies: old.base.dependencies))
        #expect(shared.base.edit(text).saved)
        #expect(try command.base.fields() == old.base.fields())
        #expect(try command.base.fields() == shared.base.fields())
        #expect(command.count("save") == 1 && old.count("save") == 1 && shared.count("save") == 1)
    }
}
