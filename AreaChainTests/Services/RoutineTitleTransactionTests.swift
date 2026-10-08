import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct RoutineTitleTransactionTests {
    typealias Fixture = RoutineCommandFixture
    typealias Modification = RoutineMutationService.Modification

    @Test(arguments: [0, 1, 2]) func nestedCallCompletionDoesNotClaimPersistence(failure: Int) throws {
        let fixture = try Fixture()
        let before = fixture.routine.snapshot
        let checks = try fixture.checks()
        var result: Modification?
        var outerFacts: ModelChanges.CommitFacts?
        var legacyAccepted = false
        let outer = fixture.environment.dependencies.transaction
        if failure == 2 { fixture.saveMode = .throwBefore }
        var inner = fixture.environment.dependencies
        inner.transaction = forbiddenBoundary()
        do {
            try ModelChanges.transaction(in: fixture.context, boundary: outer, observe: { outerFacts = $0 }) {
                legacyAccepted = DayBoardMutations.editRoutineWithSyntax(fixture.routine,
                    rawInput: "嵌套 #恢复 #新 !p3 @18:00 // 备注", dependencies: inner)
                result = RoutineMutationService.editTitle(fixture.other, rawInput: "另一修改", in: fixture.context, dependencies: inner)
                #expect(legacyAccepted && result?.callSucceeded == true && result?.state == .pending && result?.saved == false)
                #expect(result?.transaction === outerFacts && outerFacts?.phase == .working)
                #expect(outerFacts?.save == .notCalled && outerFacts?.publication == .notCalled)
                #expect(fixture.count("save") == 0 && fixture.count("ui") == 0 && fixture.base.io.registered.isEmpty)
                #expect(fixture.base.io.authorizations.isEmpty && fixture.routine.title == "嵌套")
                #expect(try fixture.stored().snapshot == before)
                if failure == 1 { throw TaskCreateCommandIO.Failure.injected }
            }
            #expect(failure == 0)
        } catch { #expect(failure != 0) }
        #expect(legacyAccepted && result?.callSucceeded == true)
        #expect(result?.state == (failure == 0 ? .saved : failure == 1 ? .notSubmitted : .unknown))
        #expect(result?.saved == (failure == 0) && outerFacts?.phase == (failure == 0 ? .finished : .rolledBack))
        #expect(fixture.count("save") == (failure == 1 ? 0 : 1) && fixture.count("ui") == (failure == 0 ? 1 : 0))
        #expect(fixture.base.io.registered.count == (failure == 0 ? 2 : 0))
        #expect(fixture.base.io.authorizations == (failure == 0 ? [1080] : []))
        #expect(try fixture.checks() == checks && fixture.tags().count == (failure == 0 ? 3 : 2))
        if failure == 0 {
            #expect(outerFacts?.save == .returned && outerFacts?.publication == .returned && outerFacts?.rollback == .notCalled)
            #expect(try fixture.stored().title == "嵌套" && fixture.stored().notes == "备注")
            #expect(result?.savedValues?[.title] == .text("另一修改") && fixture.base.deleted.deletedAt == nil)
        } else {
            #expect(outerFacts?.rollback == .returned && outerFacts?.publication == .notCalled)
            #expect(try fixture.stored().snapshot == before && fixture.routine.snapshot == before)
            #expect(fixture.other.title == "另一习惯" && fixture.base.deleted.deletedAt == TaskTitleFixture.deletion)
            #expect(result?.savedValues == nil)
        }
    }

    @Test(arguments: [false, true]) func innerThrowIsNotAcceptedEvenWhileOuterIsWorking(abort: Bool) throws {
        let fixture = try Fixture()
        let before = fixture.routine.snapshot
        var result: Modification?
        var inner = fixture.environment.dependencies
        inner.transaction = forbiddenBoundary()
        do {
            try ModelChanges.transaction(in: fixture.context, boundary: fixture.base.io.boundary) {
                // 非空原文解析为空标题，真实仓储抛错；不是把空白 guard 当作事务失败。
                result = RoutineMutationService.editTitle(fixture.routine, rawInput: "!p3", in: fixture.context, dependencies: inner)
                #expect(result?.transaction?.phase == .working && result?.transaction?.save == .notCalled)
                #expect(result?.callSucceeded == false && result?.state == .notSubmitted && result?.saved == false)
                #expect(!DayBoardMutations.editRoutineWithSyntax(fixture.routine, rawInput: "!p3", dependencies: inner))
                #expect(fixture.count("save") == 0 && fixture.count("ui") == 0 && fixture.base.io.failures == 2)
                if abort { throw TaskCreateCommandIO.Failure.injected }
            }
            #expect(!abort)
        } catch { #expect(abort) }
        #expect(result?.callSucceeded == false && result?.saved == false && result?.state == .notSubmitted)
        #expect(result?.transaction?.phase == (abort ? .rolledBack : .finished))
        #expect(fixture.count("save") == (abort ? 0 : 1) && fixture.count("ui") == (abort ? 0 : 1))
        #expect(try fixture.stored().snapshot == before && fixture.routine.snapshot == before)
        #expect(fixture.base.io.registered.isEmpty && fixture.base.io.authorizations.isEmpty)
    }

    @Test func pendingWithoutSuccessfulCallAndPreflightFailureAreNotAccepted() throws {
        let fixture = try Fixture()
        let uncalled = Modification(fixture.routine)
        #expect(uncalled.state == .pending && !uncalled.saved && !uncalled.callSucceeded)
        fixture.beforeTransaction = { throw TaskCreateCommandIO.Failure.injected }
        let result = RoutineMutationService.editTitle(fixture.routine, rawInput: "拒绝", in: fixture.context,
                                                       dependencies: fixture.environment.dependencies)
        #expect(!result.callSucceeded && result.state == .notSubmitted && result.transaction == nil)
        #expect(!DayBoardMutations.editRoutineWithSyntax(fixture.routine, rawInput: "拒绝",
                                                        dependencies: fixture.environment.dependencies))
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0 && fixture.base.io.failures == 2)
        #expect(try fixture.stored().title == "原习惯" && fixture.routine.title == "原习惯")
    }

    @Test(arguments: [false, true]) func realRowFactoryForwardsLegacyBool(fail: Bool) throws {
        let fixture = try Fixture()
        let before = fixture.routine.snapshot
        let row = TaskRowFactory.routine(.init(routine: fixture.routine,
            schedule: .init(todayKey: "2026-10-08", checkDayKey: "2026-10-08", checks: []),
            catalogs: .init(tags: [fixture.base.live], attachments: [], context: fixture.context),
            display: .init(isDone: false), actions: .init(onSelect: { _ in }, onDelete: {})))
        let saveTitle = try #require(row.onSaveTitle)
        do {
            try ModelChanges.transaction(in: fixture.context, boundary: fixture.base.io.boundary) {
                #expect(saveTitle("行标题 #Work !p3") && fixture.routine.title == "行标题")
                #expect(!saveTitle("!p3") && !saveTitle(" \n "))
                #expect(fixture.count("save") == 0 && fixture.count("ui") == 0 && fixture.base.io.failures == 1)
                if fail { throw TaskCreateCommandIO.Failure.injected }
            }
            #expect(!fail)
        } catch { #expect(fail) }
        #expect(fixture.count("save") == (fail ? 0 : 1) && fixture.count("ui") == (fail ? 0 : 1))
        if fail { #expect(try fixture.stored().snapshot == before && fixture.routine.snapshot == before) }
        else { #expect(try fixture.stored().title == "行标题" && fixture.routine.isUrgent && !fixture.routine.isImportant) }
    }

    @Test(arguments: [false, true]) func standaloneSaveFailureKeepsBoolFalseAndDraft(afterSave: Bool) throws {
        let fixture = try Fixture()
        let before = fixture.routine.snapshot
        fixture.saveMode = afterSave ? .throwAfter : .throwBefore
        let draft = "唯一草稿 #恢复 #新 !p3 @18:00 // 备注"
        var retained = draft
        if DayBoardMutations.editRoutineWithSyntax(fixture.routine, rawInput: draft,
            dependencies: fixture.environment.dependencies) { retained = "" }
        #expect(retained == draft && fixture.count("save") == 1 && fixture.count("ui") == 0)
        #expect(fixture.base.io.failures == 1 && fixture.base.io.registered.isEmpty && fixture.base.io.authorizations.isEmpty)
        if afterSave {
            #expect(try fixture.stored().title == "唯一草稿" && fixture.routine.title == "唯一草稿")
        } else {
            #expect(try fixture.stored().snapshot == before && fixture.routine.snapshot == before)
        }
        #expect(try fixture.tags().count == (afterSave ? 3 : 2))
        #expect(fixture.base.deleted.deletedAt == (afterSave ? nil : TaskTitleFixture.deletion))
    }

    @Test func failedPresaveKeepsPriorDraftAndDoesNotCompleteCall() throws {
        let fixture = try Fixture()
        fixture.routine.notes = "先前未保存备注"
        var dependencies = fixture.environment.dependencies
        var preSaves = 0
        dependencies.transaction.preSave = { _ in preSaves += 1; throw TaskCreateCommandIO.Failure.injected }
        let result = RoutineMutationService.editTitle(fixture.routine, rawInput: "不执行", in: fixture.context, dependencies: dependencies)
        #expect(!result.callSucceeded && result.state == .notSubmitted && !result.saved)
        #expect(result.transaction?.preSave == .called && result.transaction?.save == .notCalled)
        #expect(result.transaction?.rollback == .notCalled && fixture.context.hasChanges)
        #expect(!DayBoardMutations.editRoutineWithSyntax(fixture.routine, rawInput: "不执行", dependencies: dependencies))
        #expect(preSaves == 2 && fixture.count("save") == 0 && fixture.base.io.failures == 2)
        #expect(fixture.routine.notes == "先前未保存备注" && fixture.routine.title == "原习惯")
        #expect(try fixture.stored().notes.isEmpty && fixture.stored().title == "原习惯")
    }

    @Test(arguments: [false, true]) func postCommitFailureDoesNotEraseCallOrSavedFact(registration: Bool) throws {
        let fixture = try Fixture()
        var dependencies = fixture.environment.dependencies
        if registration { dependencies.registerLocalModification = { _ in throw TaskCreateCommandIO.Failure.injected } }
        else { dependencies.transaction.publish = { throw TaskCreateCommandIO.Failure.injected } }
        let result = RoutineMutationService.editTitle(fixture.routine, rawInput: "已保存", in: fixture.context, dependencies: dependencies)
        #expect(result.callSucceeded && result.saved && result.state == .saved && result.transaction?.save == .returned)
        #expect(result.registrationFailed == registration && result.transaction?.publicationFailed == !registration)
        #expect(DayBoardMutations.editRoutineWithSyntax(fixture.routine, rawInput: "再次保存", dependencies: dependencies))
        #expect(fixture.count("save") == 2 && fixture.count("ui") == (registration ? 2 : 0) && fixture.base.io.failures == 2)
        #expect(try fixture.stored().title == "再次保存")
    }

    @available(macOS 15, *)
    @Test func storeRecoveryFailureRemainsUnknown() throws {
        let configuration = RoutineRecoveryStore.Configuration()
        let container = try ModelContainer(for: Schema(AreaChainSchema.models), configurations: [configuration])
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let routine = DailyRoutine(title: "原习惯", sortOrder: 0)
        context.insert(routine)
        try context.save()
        configuration.rejectFetch = true
        var failures = 0
        var saves = 0
        let boundary = ModelChanges.Boundary(save: { _ in saves += 1 },
            publish: { Issue.record("恢复失败不能发布") }, reportFailure: { error in
                #expect(error is ModelRecoveryError)
                failures += 1
            })
        let dependencies = RoutineMutationService.Dependencies(repository: { SwiftDataRoutineRepository(context: $0) },
            transaction: boundary, registerLocalModification: { _ in Issue.record("恢复失败不能登记") },
            requestReminderAccessIfNeeded: { _ in Issue.record("恢复失败不能请求授权") })
        let result = RoutineMutationService.editTitle(routine, rawInput: "修改", in: context, dependencies: dependencies)
        #expect(!result.callSucceeded && !result.saved && result.state == .unknown)
        #expect(result.transaction?.phase == .recoveryFailed && result.transaction?.rollback == .called)
        #expect(result.transaction?.save == .notCalled && result.transaction?.publication == .notCalled && failures == 1)
        #expect(configuration.failedFetches == 2 && saves == 0)
        #expect(!DayBoardMutations.editRoutineWithSyntax(routine, rawInput: "修改", dependencies: dependencies))
        #expect(failures == 2 && configuration.failedFetches == 4 && saves == 0)
        configuration.rejectFetch = false
        let reader = ModelContext(container)
        #expect(try reader.fetch(FetchDescriptor<DailyRoutine>()).first?.title == "原习惯")
    }

    @Test func commandReceiptCannotPromotePendingOrRecoveryFailureToSaved() throws {
        let fixture = try Fixture()
        let accepted = try fixture.accept("routine.title", Fixture.title("修改"))
        let request = try fixture.request()
        var run = try #require(fixture.handoff.state().execution)
        let pending = CommandRoutineFacts(object: accepted.object)
        try run.recordRoutine(pending, attempt: request.attempt)
        #expect(run.units.first?.routine?.state == .pending && run.units.first?.local == .notSubmitted)
        #expect(run.units.first?.state == .running && fixture.count("save") == 0)
        var invalid = pending
        invalid.state = .saved
        #expect(throws: CommandExecutionError.invalidResult) { try run.recordRoutine(invalid, attempt: request.attempt) }
        var recovery = pending
        recovery.state = .unknown
        recovery.rollback = .called
        try run.recordRoutine(recovery, attempt: request.attempt)
        #expect(run.units.first?.routine?.state == .unknown && run.units.first?.routine?.save == .notCalled)
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0)
    }

    private func forbiddenBoundary() -> ModelChanges.Boundary {
        .init(preSave: { _ in Issue.record("内层不能替换预保存") }, save: { _ in Issue.record("内层不能替换提交者") },
              publish: { Issue.record("内层不能替换发布者") }, reportFailure: { _ in Issue.record("内层不能替换反馈者") })
    }
}
