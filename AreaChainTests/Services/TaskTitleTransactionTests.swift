import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TaskTitleTransactionTests {
    @Test(arguments: [false, true])
    func titleAndTagCreationRestorationShareTransaction(fail: Bool) throws {
        let fixture = try TaskTitleFixture()
        let before = try fixture.fields()
        var dependencies = fixture.dependencies
        if fail { dependencies.transaction.save = { _ in throw CocoaError(.fileWriteNoPermission) } }
        let result = fixture.edit("新标题 #恢复 #新 !p3 @18:00 // 新备注", dependencies: dependencies)
        #expect(result.state == (fail ? .commitUnknown : .saved))
        if fail {
            #expect(try fixture.fields() == before)
            #expect(result.transaction?.save == .called && result.transaction?.rollback == .returned)
            #expect(fixture.io.trace.isEmpty && fixture.io.registered.isEmpty && fixture.io.authorizations.isEmpty)
        } else {
            #expect(fixture.deleted.deletedAt == nil)
            #expect(try fixture.fields().tags == ["Work", "恢复", "新"])
            #expect(fixture.todo.title == "新标题" && fixture.todo.notes == "新备注")
            #expect(fixture.io.trace.filter { $0 == "save" }.count == 1)
        }
    }

    @Test func savingThenThrowingStaysUnknown() throws {
        let fixture = try TaskTitleFixture()
        var dependencies = fixture.dependencies
        dependencies.transaction.save = { context in try context.save(); throw CocoaError(.fileWriteUnknown) }
        let result = fixture.edit("已落盘 #恢复 #新 @18:00", dependencies: dependencies)
        #expect(result.state == .commitUnknown && !result.saved)
        #expect(result.transaction?.save == .called && result.transaction?.rollback == .returned)
        #expect(try fixture.io.readTodos().first?.title == "已落盘")
        #expect(try fixture.fields().tags == ["Work", "恢复", "新"])
        #expect(fixture.io.registered.isEmpty && fixture.io.trace.isEmpty && fixture.io.authorizations.isEmpty)
    }

    @Test(arguments: [false, true])
    func postCommitFailureDoesNotUndoModification(registration: Bool) throws {
        let fixture = try TaskTitleFixture()
        var dependencies = fixture.dependencies
        if registration { dependencies.registerLocalModification = { _ in throw CocoaError(.fileWriteUnknown) } }
        else { dependencies.transaction.publish = { throw CocoaError(.fileWriteUnknown) } }
        let result = fixture.edit("已保存 @18:00", dependencies: dependencies)
        #expect(result.saved && result.registrationFailed == registration)
        #expect(result.transaction?.publicationFailed == !registration)
        #expect(try fixture.io.readTodos().first?.title == "已保存")
        #expect(fixture.io.failures == 1 && fixture.io.authorizations == [1080])
    }

    @Test(arguments: [false, true])
    func nestedModificationWaitsForOuterBoundary(fail: Bool) throws {
        let fixture = try TaskTitleFixture()
        var result: TaskMutationService.TitleModification?
        var inner = fixture.dependencies
        inner.transaction.save = { _ in Issue.record("内层不得保存") }
        inner.transaction.publish = { Issue.record("内层不得发布") }
        do {
            try ModelChanges.transaction(in: fixture.io.context, boundary: fixture.io.boundary) {
                result = fixture.edit("嵌套 #恢复 #新 @18:00", dependencies: inner)
                #expect(result?.state == .pending && result?.saved == false)
                #expect(try fixture.io.readTodos().first?.title == "原标题")
                #expect(fixture.io.trace.isEmpty)
                if fail { throw CocoaError(.fileWriteNoPermission) }
            }
            #expect(!fail)
        } catch { #expect(fail) }
        #expect(result?.state == (fail ? .notSubmitted : .saved))
        #expect(fixture.io.authorizations == (fail ? [] : [1080]))
        #expect(fixture.deleted.deletedAt == (fail ? TaskTitleFixture.deletion : nil))
        if fail { #expect(result?.transaction?.save == .notCalled && result?.transaction?.rollback == .returned) }
    }

    @Test func presavePolicyAndFailedPresaveKeepPriorPendingChanges() throws {
        let fixture = try TaskTitleFixture()
        fixture.todo.notes = "先前未保存的备注"
        var dependencies = fixture.dependencies
        dependencies.transaction.preSave = { _ in throw CocoaError(.fileWriteNoPermission) }
        let rejected = fixture.edit("不执行 #新", dependencies: dependencies)
        #expect(rejected.state == .notSubmitted && fixture.io.context.hasChanges)
        #expect(fixture.todo.notes == "先前未保存的备注" && fixture.todo.title == "原标题")
        dependencies = fixture.dependencies
        dependencies.transaction.save = { _ in throw CocoaError(.fileWriteNoPermission) }
        let unknown = fixture.edit("回滚 #新", dependencies: dependencies)
        #expect(unknown.state == .commitUnknown && unknown.transaction?.preSave == .returned)
        #expect(try fixture.io.readTodos().first?.notes == "先前未保存的备注")
        #expect(fixture.todo.title == "原标题" && fixture.io.trace == ["preSave"])
    }

    @Test func legacyBoolPreservesOnlyDraftOnFailure() throws {
        let fixture = try TaskTitleFixture()
        var dependencies = fixture.dependencies
        dependencies.transaction.save = { _ in throw CocoaError(.fileWriteNoPermission) }
        var draft = "唯一草稿 #新"
        if DayBoardMutations.editTodoWithSyntax(fixture.todo, rawInput: draft, dependencies: dependencies) { draft = "" }
        #expect(draft == "唯一草稿 #新")
        dependencies = fixture.dependencies
        dependencies.transaction.publish = { throw CocoaError(.fileWriteUnknown) }
        if DayBoardMutations.editTodoWithSyntax(fixture.todo, rawInput: draft, dependencies: dependencies) { draft = "" }
        #expect(draft.isEmpty && fixture.todo.title == "唯一草稿")
    }
}
