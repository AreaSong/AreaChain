import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct SubtaskCommandBoundaryTests {
    typealias Fixture = SubtaskCommandFixture

    @Test(arguments: 0..<10) func changedIdentityRelationshipOrFieldsRejectOldAcceptance(kind: Int) throws {
        let fixture = try Fixture()
        let accepted = try fixture.accept("subtask.title", [Fixture.title("新标题")])
        switch kind {
        case 0: fixture.base.todo.deletedAt = TaskTitleFixture.deletion
        case 1: fixture.child.deletedAt = TaskTitleFixture.deletion
        case 2: fixture.context.insert(SubtaskItem(id: fixture.child.id, title: "duplicate", deletedAt: TaskTitleFixture.deletion))
        case 3: fixture.context.insert(TodoItem(id: fixture.base.todo.id, title: "duplicate", dayKey: "2026-10-05"))
        case 4: fixture.child.todo = nil
        case 5:
            let parent = TodoItem(title: "new parent", dayKey: "2026-10-05")
            fixture.context.insert(parent)
            fixture.child.todo = parent
        case 6: fixture.child.title = "并发标题"
        case 7: fixture.child.tagIDs = ""
        case 8: fixture.base.todo.sourceBundleID = "qa.changed"
        default:
            let id = fixture.child.id
            fixture.context.delete(fixture.child)
            fixture.context.insert(SubtaskItem(id: id, title: "子标题", todo: fixture.base.todo))
        }
        try fixture.context.save()
        #expect(throws: (any Error).self) { try fixture.submit(accepted) }
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0)
        #expect(try fixture.handoff.state().plan.items.first?.draft.arguments == accepted.preview.arguments)
    }

    @Test(arguments: 0..<5) func creationRechecksActualSiblingOrderAndIdentity(kind: Int) throws {
        let fixture = try Fixture()
        let accepted = try fixture.accept("subtask.create", fixture.createArguments())
        switch kind {
        case 0: fixture.child.sortOrder = 42
        case 1: fixture.sibling.deletedAt = TaskTitleFixture.deletion
        case 2: fixture.context.insert(SubtaskItem(title: "late", sortOrder: 55, todo: fixture.base.todo))
        case 3: fixture.context.insert(SubtaskItem(id: accepted.object.id, title: "collision", deletedAt: TaskTitleFixture.deletion))
        default: fixture.context.insert(SubtaskItem(id: fixture.sibling.id, title: "duplicate", todo: fixture.base.todo))
        }
        try fixture.context.save()
        if kind == 3 {
            #expect(throws: SubtaskCommandIssue.identityCollision) { try fixture.submit(accepted) }
            #expect(try fixture.unit().subtask?.state == .notSubmitted)
        } else { #expect(throws: (any Error).self) { try fixture.submit(accepted) } }
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0)
    }

    @Test(arguments: 0..<9) func parentChildAndInputNeedIndependentCurrentProof(kind: Int) throws {
        let fixture = try Fixture()
        let accepted = try fixture.accept("subtask.completion", [TaskTM2Fixture.completion(true)])
        switch kind {
        case 0: fixture.parentProtection = .unknown
        case 1: fixture.childProtection = .unknown
        case 2: fixture.childProtection = nil
        case 3: fixture.inputProtection = .unknown
        case 4: fixture.notes = .present
        case 5: fixture.parentRevision = UUID()
        case 6: fixture.childRevision = UUID()
        case 7: fixture.inputRevision = UUID()
        default: fixture.sourceRead = { throw CocoaError(.fileReadUnknown) }
        }
        #expect(throws: (any Error).self) { try fixture.submit(accepted) }
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0)
        #expect(fixture.sourceTargets.first! == accepted.object)
    }

    @Test(arguments: 0..<7, [CommandFieldOperation.clear, .remove])
    func protectedUnknownOrChangedTagsCannotBeRemoved(kind: Int, mode: CommandFieldOperation) throws {
        let fixture = try Fixture()
        let accepted = try fixture.accept("subtask.tags", [TaskTM2Fixture.tags(mode, [fixture.base.live.id])])
        switch kind {
        case 0: fixture.base.live.isPrivateDiary = true
        case 1: fixture.context.delete(fixture.base.live)
        case 2: fixture.context.insert(TagItem(id: fixture.base.live.id, name: "duplicate", sortOrder: 2))
        case 3: fixture.context.insert(TagItem(name: "work", sortOrder: 2))
        case 4: fixture.child.tagIDs = "invalid-id"
        case 5: fixture.child.tagIDs = UUID().uuidString
        default: fixture.base.deleted.deletedAt = nil
        }
        try fixture.context.save()
        #expect(throws: (any Error).self) { try fixture.submit(accepted) }
        if kind != 6 { #expect(throws: (any Error).self) { try fixture.preview() } }
        #expect(!fixture.child.tagIDs.isEmpty && fixture.count("save") == 0 && fixture.count("ui") == 0)
    }

    @Test(arguments: ["", "   ", "one\ntwo", "one\rtwo", "#密码", "#日记", "#小巧思"])
    func invalidOrProtectedRawTextIsNotSilentlyChanged(raw: String) throws {
        let fixture = try Fixture()
        try fixture.queue("subtask.create", fixture.createArguments(raw))
        #expect(throws: (any Error).self) { try fixture.preview() }
        #expect(try fixture.handoff.state().plan.items.first?.draft.arguments.last?.value == .shortText(raw))
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0)
    }

    @Test func dirtyAndNestedContextsDoNotPreSave() throws {
        let fixture = try Fixture()
        try fixture.queue("subtask.completion", [TaskTM2Fixture.completion(true)])
        fixture.base.todo.title = "唯一未保存编辑"
        #expect(throws: TaskTitleCommandIssue.dirtyContext) { try fixture.preview() }
        #expect(fixture.context.hasChanges && fixture.base.todo.title == "唯一未保存编辑")
        fixture.context.rollback()
        try ModelChanges.transaction(in: fixture.context, boundary: fixture.base.io.boundary) {
            #expect(throws: TaskTitleCommandIssue.nestedTransaction) { try fixture.preview() }
            #expect(fixture.count("preSave") == 0 && fixture.count("save") == 0)
        }
    }

    @Test func lastValidationAndSourceCallbackCannotMoveTarget() throws {
        let fixture = try Fixture()
        let accepted = try fixture.accept("subtask.title", [Fixture.title("New")])
        var calls = 0
        fixture.beforeTransaction = {
            calls += 1
            if calls == 2 { fixture.child.title = "Late"; try fixture.context.save() }
        }
        let facts = try fixture.submit(accepted)
        #expect(facts.state == .notSubmitted && facts.conflict)
        #expect(try fixture.storedChild().title == "Late" && fixture.count("save") == 0)
    }

    @Test func foreignRepositoryContextIsRejectedBeforeAnyMutation() throws {
        let fixture = try Fixture()
        let foreign = ModelContext(fixture.context.container)
        foreign.autosaveEnabled = false
        fixture.repository = { _ in SwiftDataTaskRepository(context: foreign) }
        let accepted = try fixture.accept("subtask.create", fixture.createArguments())
        #expect(throws: SubtaskCommandIssue.invalidFamily) { try fixture.submit(accepted) }
        #expect(try fixture.children().count == 3 && fixture.count("save") == 0)
    }

    @Test func unrepresentableAppendOrderFailsBeforeAccepting() throws {
        let fixture = try Fixture()
        fixture.child.sortOrder = Int.max
        try fixture.context.save()
        try fixture.queue("subtask.create", fixture.createArguments())
        #expect(throws: SubtaskCommandIssue.invalidFamily) { try fixture.preview() }
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0)
    }
}
