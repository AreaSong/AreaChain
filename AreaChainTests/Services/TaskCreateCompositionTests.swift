import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TaskCreateCompositionTests {
    typealias Fixture = TaskCreateCompositionFixture

    @Test func argumentsPreviewAcceptanceTransactionRunAndRealOutput() throws {
        let fixture = try Fixture()
        let live = try fixture.seed("活标签")
        let deleted = try fixture.seed("恢复", deleted: true)
        let preview = try fixture.preview("任务 #活标签 #恢复 #新建 !p2 @08:30", extra: [
            .init(parameter: .priority, operation: .assign, value: .choice("p2")),
            .init(parameter: .time, operation: .setReminder, value: .time(510))
        ])
        #expect(preview.composition.tags.final.map(\.effect) == [.associateLive, .restoreAndAssociate, .createAndAssociate])
        #expect(preview.composition.priority.origins == [.titleSyntax, .explicitSet])
        #expect(fixture.handoff.coordinator.taskCreations.preparations.isEmpty)
        try fixture.expectNoCommandWrites()
        let accepted = try fixture.accept(preview)
        #expect(accepted.preview == preview && accepted.input == nil && accepted.tagCreationIDs.count == 1)
        #expect(try fixture.accept(preview) == accepted)
        #expect(try fixture.tags().count == 2 && !fixture.context.hasChanges && deleted.deletedAt != nil)
        fixture.base.io.notificationResult = .succeeded
        fixture.base.io.calendarResult = .succeeded
        fixture.environment.beforePublication = {
            let run = try #require(fixture.handoff.state().execution)
            #expect(run.outputs[accepted.item.id]?.id == accepted.creationID)
            #expect(run.units[0].local == .committed)
            #expect(try fixture.tags().count == 3 && fixture.tags().allSatisfy { $0.deletedAt == nil })
        }
        let facts = try fixture.submit(accepted)
        let todo = try #require(fixture.base.io.capture.readTodos().first)
        #expect(todo.id == accepted.creationID && facts.savedID == todo.id && facts.state == .saved)
        #expect(todo.title == "任务" && todo.dayKey == "2026-10-06" && todo.notes.isEmpty)
        #expect(todo.isImportant && !todo.isUrgent && todo.remindMinutes == 510)
        #expect(todo.dueMinutes == nil && todo.calendarEventID.isEmpty && todo.sourceBundleID == fixture.base.io.capture.source)
        #expect(try TagIDList.parse(todo.tagIDs) == [live.id, deleted.id, #require(accepted.tagCreationIDs["新建"])])
        #expect(fixture.base.count("save") == 1 && fixture.base.count("ui") == 1 && fixture.base.count("preSave") == 0)
        #expect(fixture.base.io.capture.authorizations == [510])
        #expect(facts.authorizationRequest == .returned && facts.authorizationResult == .unknown)
        let run = try #require(fixture.handoff.state().execution)
        #expect(run.snapshot.items[0].draft.arguments == preview.arguments && run.units[0].taskCreation == facts)
        #expect(run.creationOutput(for: .init(producer: accepted.item, outputType: .todo)) == .init(type: .todo, id: todo.id))
    }

    @Test(arguments: [CommandFieldOperation.add, .remove, .replaceAll, .clear, .unspecified])
    func finalTagOrderAndRemovedCandidatesHaveNoWrites(operation: CommandFieldOperation) throws {
        let fixture = try Fixture()
        let live = try fixture.seed("活")
        let removed = try fixture.seed("墓碑", deleted: true)
        let other = try fixture.seed("另外")
        let ids = operation == .remove ? [removed.id] : [other.id, live.id]
        let preview = try fixture.preview("任务 #活 #墓碑 #新建", extra: [TaskCreatePreviewFixture.tags(operation, ids)])
        let accepted = try fixture.accept(preview)
        _ = try fixture.submit(accepted)
        let todo = try #require(fixture.base.io.capture.readTodos().first)
        let newID = accepted.tagCreationIDs["新建"]
        let expected: [UUID]
        switch operation {
        case .add: expected = try [live.id, removed.id, #require(newID), other.id]
        case .remove: expected = try [live.id, #require(newID)]
        case .replaceAll: expected = [other.id, live.id]
        case .clear: expected = []
        default: expected = try [live.id, removed.id, #require(newID)]
        }
        #expect(TagIDList.parse(todo.tagIDs) == expected)
        let tags = try fixture.tags()
        #expect(tags.count == ((operation == .replaceAll || operation == .clear) ? 3 : 4))
        #expect(tags.first { $0.id == removed.id }?.deletedAt == (expected.contains(removed.id) ? nil : Date(timeIntervalSince1970: 100)))
        #expect(accepted.tagCreationIDs.count == (newID == nil ? 0 : 1))
        #expect(fixture.base.count("save") == 1 && fixture.base.count("ui") == 1)
    }

    @Test func clearAndCancelUseNewTaskDefaultsAndNoOldCaptureReplay() throws {
        let fixture = try Fixture()
        let preview = try fixture.preview("任务 #不会创建", extra: [
            .init(parameter: .tags, operation: .clear), .init(parameter: .priority, operation: .clear),
            .init(parameter: .time, operation: .cancelReminder)
        ])
        let accepted = try fixture.accept(preview)
        let facts = try fixture.submit(accepted)
        let todo = try #require(fixture.base.io.capture.readTodos().first)
        #expect(todo.title == "任务" && todo.tagIDs.isEmpty && todo.remindMinutes == nil)
        #expect(!todo.isImportant && !todo.isUrgent && todo.notes.isEmpty)
        #expect(try fixture.tags().isEmpty && accepted.tagCreationIDs.isEmpty)
        #expect(facts.authorizationRequest == .notCalled && facts.authorizationResult == .unknown)
    }

    @Test(arguments: ["#元数据", "@00:00", "!p1", "!p2", "!p3"])
    func supportedMetadataFormsPersistRealFields(title: String) throws {
        let fixture = try Fixture()
        let preview = try fixture.preview(title)
        let accepted = try fixture.accept(preview)
        _ = try fixture.submit(accepted)
        let todo = try #require(fixture.base.io.capture.readTodos().first)
        #expect(todo.title.isEmpty && todo.notes.isEmpty)
        #expect(!todo.tagIDs.isEmpty || todo.remindMinutes != nil || todo.isImportant || todo.isUrgent)
    }

    @Test func defaultAdapterAndOldSubmitStayMinimalEvenWithExpandedInstance() throws {
        let fixture = try Fixture()
        let preview = try fixture.preview()
        #expect(throws: TaskCreateCommandIssue.invalidInput) { try fixture.base.submit() }
        #expect(throws: TaskCreateCommandIssue.invalidInput) {
            try fixture.adapter.submit(plan: fixture.handoff.state().plan.stamp, expecting: fixture.handoff.owned().lease)
        }
        #expect(throws: TaskCreateCommandIssue.unassembled) { try fixture.base.adapter.accept(preview, expecting: fixture.handoff.owned().lease) }
        let accepted = try fixture.accept(preview)
        let request = try fixture.base.request()
        #expect(throws: TaskCreateCommandIssue.unassembled) { try fixture.base.adapter.execute(request) }
        #expect(!fixture.handoff.coordinator.taskCreations.wasInvoked(accepted.id))
        #expect(try fixture.adapter.execute(request).savedID == accepted.creationID)
        #expect(throws: (any Error).self) { try fixture.base.adapter.execute(request) }
        #expect(fixture.base.count("save") == 1)
    }

    @Test(arguments: [false, true])
    func minimalAndComposedPreparationsAreMutuallyExclusive(composedFirst: Bool) throws {
        let fixture = try Fixture()
        let preview = try fixture.preview("纯标题")
        if composedFirst {
            let accepted = try fixture.accept(preview)
            #expect(throws: TaskCreateCommandIssue.stale) { try fixture.base.prepare() }
            #expect(try fixture.submit(accepted).savedID == accepted.creationID)
        } else {
            let minimal = try fixture.base.prepare()
            #expect(throws: TaskCreateCommandIssue.stale) { try fixture.accept(preview) }
            #expect(try fixture.base.submit().savedID == minimal.creationID)
        }
        #expect(try fixture.base.io.capture.readTodos().count == 1 && fixture.tags().isEmpty)
        #expect(fixture.handoff.coordinator.taskCreations.preparations.count == 1 && fixture.base.count("save") == 1)
    }
}
