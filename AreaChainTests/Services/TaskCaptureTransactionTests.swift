import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct TaskCaptureTransactionTests {
    @Test(arguments: [false, true])
    func nestedCreationWaitsForOutermostCommit(fail: Bool) throws {
        let fixture = try TaskCaptureFixture()
        var result: TaskMutationService.Creation?
        var boundary = fixture.boundary
        if fail { boundary.save = { _ in throw CocoaError(.fileWriteNoPermission) } }
        var inner = fixture.dependencies
        inner.transaction.save = { _ in Issue.record("不应调用内层 save") }
        inner.transaction.publish = { Issue.record("不应调用内层 publish") }
        do {
            try ModelChanges.transaction(in: fixture.context, boundary: boundary) {
                result = fixture.create("嵌套 @18:00 #新", dependencies: inner)
                #expect(result?.state == .pending && result?.savedID == nil)
                #expect(result?.candidateID != nil)
                let savedTodos = try fixture.readTodos()
                #expect(savedTodos.isEmpty)
                #expect(fixture.trace.isEmpty && fixture.authorizations.isEmpty)
            }
            #expect(!fail)
        } catch { #expect(fail) }
        #expect(result?.state == (fail ? .commitUnknown : .saved))
        #expect(try fixture.readTodos().count == (fail ? 0 : 1))
        #expect(fixture.authorizations == (fail ? [] : [1080]))
        #expect(fixture.trace.filter { $0 == "ui" }.count == (fail ? 0 : 1))
    }

    @Test func outerWorkFailureRollsBackBeforeSaveAndNeverPublishes() throws {
        let fixture = try TaskCaptureFixture()
        let old = TagItem(name: "旧", sortOrder: 0, deletedAt: Date(timeIntervalSince1970: 123))
        fixture.context.insert(old)
        try fixture.context.save()
        var result: TaskMutationService.Creation?
        #expect(throws: CocoaError.self) {
            try ModelChanges.transaction(in: fixture.context, boundary: fixture.boundary) {
                result = fixture.create("标题 #旧 #新")
                throw CocoaError(.fileWriteNoPermission)
            }
        }
        #expect(result?.state == .notSubmitted)
        #expect(result?.transaction?.save == .notCalled)
        #expect(result?.transaction?.rollback == .returned)
        #expect(try fixture.readTodos().isEmpty)
        #expect(try fixture.context.fetchCount(FetchDescriptor<TagItem>()) == 1)
        #expect(old.deletedAt != nil)
        #expect(fixture.trace.isEmpty && fixture.registered.isEmpty)
    }

    @Test func originalRecoveryErrorDoesNotMislabelSuccessfulRollback() throws {
        let fixture = try TaskCaptureFixture()
        var result: TaskMutationService.Creation?
        let original = ModelRecoveryError(original: CocoaError(.fileWriteNoPermission),
                                          recovery: CocoaError(.fileReadUnknown))
        #expect(throws: ModelRecoveryError.self) {
            try ModelChanges.transaction(in: fixture.context, boundary: fixture.boundary) {
                result = fixture.create("回滚事实 #新")
                throw original
            }
        }
        #expect(result?.transaction?.rollback == .returned)
        #expect(result?.transaction?.phase == .rolledBack)
        #expect(result?.state == .notSubmitted && result?.savedID == nil)
        #expect(try fixture.readTodos().isEmpty)
        #expect(try fixture.context.fetchCount(FetchDescriptor<TagItem>()) == 0)
        #expect(fixture.trace.isEmpty)
    }

    @Test func failedPresaveDoesNotEnterCreationOrDiscardPendingEdit() throws {
        let fixture = try TaskCaptureFixture()
        let pending = TodoItem(title: "未保存", dayKey: "2026-10-04")
        fixture.context.insert(pending)
        var dependencies = fixture.dependencies
        dependencies.transaction.preSave = { _ in throw CocoaError(.fileWriteNoPermission) }
        let result = fixture.create("不会创建 #新", dependencies: dependencies)
        #expect(result.candidateID == nil && result.state == .notSubmitted)
        #expect(result.transaction?.preSave == .called && result.transaction?.save == .notCalled)
        #expect(fixture.context.hasChanges && pending.title == "未保存")
        #expect(try fixture.readTodos().isEmpty)
        #expect(fixture.trace.isEmpty && fixture.failures == 1)
    }

    @Test func localFactReadsSavedModelBeforeAnyEvent() throws {
        let fixture = try TaskCaptureFixture()
        var dependencies = fixture.dependencies
        dependencies.registerLocalCreation = { id in
            let savedIDs = try fixture.readTodos().map(\.id)
            #expect(savedIDs == [id])
            #expect(fixture.trace == ["save", "saved"])
            fixture.trace.append("fact")
        }
        #expect(fixture.create("已创建", dependencies: dependencies).saved)
        #expect(fixture.trace == ["save", "saved", "fact", "ui", "reminderRefresh", "calendarRefresh"])
    }

    @Test func boundariesDoNotLeakAcrossContextsOrFollowingTransactions() throws {
        let first = try TaskCaptureFixture()
        let second = try TaskCaptureFixture()
        try ModelChanges.transaction(in: first.context, boundary: first.boundary) {
            #expect(first.create("一").state == .pending)
            #expect(second.create("二").saved)
            #expect(first.trace.isEmpty)
        }
        #expect(first.trace == second.trace)
        first.trace = []
        var dependencies = first.dependencies
        dependencies.transaction.publish = { first.trace.append("newPublisher") }
        #expect(first.create("三", dependencies: dependencies).saved)
        #expect(first.trace == ["save", "saved", "fact", "newPublisher"])
    }

    @Test func legacySaveInjectionStillPresavesOutsideItsClosure() throws {
        let fixture = try TaskCaptureFixture()
        let pending = TodoItem(title: "预保存", dayKey: "2026-10-04")
        fixture.context.insert(pending)
        var calls = 0
        #expect(throws: CocoaError.self) {
            try ModelChanges.transaction(in: fixture.context, save: { _ in
                calls += 1
                throw CocoaError(.fileWriteNoPermission)
            }) {
                fixture.context.insert(TodoItem(title: "回滚", dayKey: "2026-10-05"))
            }
        }
        #expect(calls == 1)
        #expect(try fixture.readTodos().map(\.title) == ["预保存"])
    }

    @Test func oldUIInsideTransactionDoesNotClearUncommittedDraft() throws {
        let fixture = try TaskCaptureFixture()
        var draft = "草稿"
        try ModelChanges.transaction(in: fixture.context, boundary: fixture.boundary) {
            if DayBoardMutations.addCapturedTodo(text: draft, dayKey: "2026-10-05", context: fixture.context,
                                                dependencies: fixture.dependencies) { draft = "" }
            #expect(draft == "草稿")
        }
        #expect(try fixture.readTodos().count == 1)
    }
}
