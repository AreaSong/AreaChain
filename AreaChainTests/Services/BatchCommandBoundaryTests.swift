import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct BatchCommandBoundaryTests {
    @Test(arguments: Array(0...8)) func staleOrIneligibleMemberRejectsWholeBatch(kind: Int) throws {
        let f = try BatchCommandFixture()
        try f.queue("batch.tags", argument: f.tagArgument(.add, index: 1), targets: f.mixedTargets)
        let accepted = try f.accept()
        switch kind {
        case 0: f.context.delete(f.todos[1])
        case 1: f.todos[1].deletedAt = .now
        case 2: f.context.insert(TodoItem(id: f.todos[1].id, title: "duplicate", dayKey: "2026-10-05"))
        case 3: f.todos[1].tagIDs = f.tags[0].id.uuidString
        case 4: f.sourceRevision = UUID()
        case 5: f.tags[1].name = "Changed catalog"
        case 6: f.tags[1].deletedAt = .now
        case 7: f.sourceOverride[f.taskTargets[1]] = .init(revision: UUID(), protection: .ordinary, notes: .present)
        default: f.sourceOverride[f.taskTargets[1]] = .init(revision: UUID(), protection: .required, notes: .absent)
        }
        try f.context.save()
        let before = f.todos[0].snapshot
        #expect(throws: (any Error).self) { try f.submit(accepted) }
        #expect(f.count("save") == 0 && f.count("ui") == 0 && f.todos[0].snapshot == before)
        #expect(try f.handoff.state().plan.items.first?.draft.targets == accepted.preview.targets)
    }

    @Test(arguments: [0, 1, 2, 3]) func removeCannotBypassD3AndSelectedTombstoneIsNeverRestored(kind: Int) throws {
        let f = try BatchCommandFixture()
        switch kind {
        case 0: f.tags[0].isPrivateDiary = true
        case 1: f.todos[0].tagIDs = UUID().uuidString
        case 2: f.todos[0].tagIDs = "unknown-encoding"
        default: break
        }
        try f.context.save()
        try f.queue("batch.tags", argument: f.tagArgument(.remove, index: kind == 3 ? 2 : 0))
        #expect(throws: (any Error).self) { try f.accept() }
        #expect(f.count("save") == 0 && f.tags[2].deletedAt != nil)
    }

    @Test func mixedMoveAndMultiplePlansAreRejectedWithoutFiltering() throws {
        let f = try BatchCommandFixture()
        try f.queue(targets: f.mixedTargets)
        #expect(throws: CommandBatchIssue.invalidArguments) { try f.accept() }
        #expect(try f.handoff.state().plan.items[0].draft.targets.objects == f.mixedTargets)
        try f.queue("batch.tags", argument: f.tagArgument(), targets: f.mixedTargets)
        #expect(throws: CommandBatchIssue.unsupportedPlan) { try f.accept() }
        #expect(f.count("save") == 0)
    }

    @Test func dirtyContextAndFinalCallbackChangesAreRejected() throws {
        let f = try BatchCommandFixture()
        try f.queue()
        let accepted = try f.accept()
        f.other.title = "Unrelated draft"
        #expect(throws: TaskTitleCommandIssue.dirtyContext) { try f.submit(accepted) }
        #expect(f.other.title == "Unrelated draft" && f.context.hasChanges)
        try f.context.save()
        f.beforeTransaction = { f.todos[1].dayKey = "2026-10-07"; try f.context.save() }
        #expect(throws: (any Error).self) { try f.submit(accepted) }
        #expect(f.todos[2].dayKey == "2026-10-05" && f.count("save") == 0)
        #expect(try f.handoff.state().execution?.units.first?.batch?.state == .notSubmitted)
    }

    @Test func everyReentrantBoundaryHasOneInvocation() throws {
        let f = try BatchCommandFixture()
        try f.queue()
        let accepted = try f.accept()
        let request = try f.request()
        var rejected = 0
        let reenter = {
            do { _ = try f.adapter.execute(request) }
            catch { rejected += 1 }
        }
        f.sourceRead = reenter
        f.beforeTransaction = reenter
        f.afterApply = { _ in reenter() }
        f.onSave = reenter
        f.afterRegistration = reenter
        f.environment.beforePublication = reenter
        let facts = try f.adapter.execute(request)
        #expect(facts.state == .saved && rejected >= 8 && f.count("save") == 1 && f.count("ui") == 1)
        #expect(facts.targets == accepted.preview.targets)
    }

    @Test func fakeBaselineAndReplacementEnvironmentDoNotGrantAcceptance() throws {
        let f = try BatchCommandFixture()
        try f.queue()
        let preview = try f.preview()
        let replacement = try BatchCommandFixture()
        let adapter = BatchCommandAdapter(coordinator: f.handoff.coordinator, environment: replacement.environment)
        #expect(throws: (any Error).self) { try adapter.accept(preview, expecting: f.handoff.owned().lease) }
        let bad = CommandBatchPreview(lease: preview.lease, plan: preview.plan, item: preview.item, draft: preview.draft,
            arguments: preview.arguments, targets: preview.targets, edit: preview.edit, environmentID: preview.environmentID,
            contextID: preview.contextID, storageID: preview.storageID, catalog: preview.catalog, impacts: Array(preview.impacts.prefix(1)))
        #expect(throws: (any Error).self) { try f.adapter.accept(bad, expecting: f.handoff.owned().lease) }
        #expect(f.count("save") == 0)
    }

    @Test(arguments: [0, 1, 2]) func moveFailureRollsBackAllMembers(index: Int) throws {
        let f = try BatchCommandFixture()
        let before = f.todos.map(\.snapshot)
        try f.queue(argument: .init(parameter: .day, operation: .assign, value: .day("2026-10-10")))
        let accepted = try f.accept()
        var applied = 0
        f.afterApply = { _ in
            defer { applied += 1 }
            if applied == index { throw TaskCreateCommandIO.Failure.injected }
        }
        let facts = try f.submit(accepted)
        #expect(facts.state == .notSubmitted && facts.rollback == .returned)
        #expect(f.todos.map(\.snapshot) == before && f.count("save") == 0 && f.count("ui") == 0)
    }

    @Test func repositoryContextAndNestedTransactionsAreRejected() throws {
        let f = try BatchCommandFixture()
        let other = try TaskCaptureFixture()
        let dependencies = BatchCommandEnvironment.Dependencies(tasks: SwiftDataTaskRepository(context: other.context),
            routines: SwiftDataRoutineRepository(context: f.context), transaction: f.io.boundary)
        #expect(throws: CommandBatchIssue.invalidRepository) {
            try BatchCommandEnvironment(context: f.context, center: f.io.center, dependencies: dependencies,
                source: f.environment.source, refresh: f.environment.refresh)
        }
        try f.queue()
        #expect(throws: TaskTitleCommandIssue.nestedTransaction) {
            try ModelChanges.transaction(in: f.context, boundary: f.io.boundary) { _ = try f.preview() }
        }
        #expect(f.count("save") == 0 && f.count("ui") == 0)
    }

    @Test(arguments: [3, 200]) func boundedSyntheticCostSample(count: Int) throws {
        let f = try BatchCommandFixture(count: count, tagCount: 30)
        try f.queue("batch.tags", argument: f.tagArgument(.add, index: 1), targets: f.mixedTargets)
        let start = ContinuousClock.now
        let preview = try f.preview()
        let prepared = ContinuousClock.now
        let accepted = try f.adapter.accept(preview, expecting: f.handoff.owned().lease)
        let submitting = ContinuousClock.now
        let facts = try f.submit(accepted)
        let finished = ContinuousClock.now
        #expect(facts.state == .saved && facts.changedCount == count + 1 && f.count("save") == 1)
        print("BM1 sample targets=\(count + 1) tags=30 Debug warm-process fresh-in-memory-store prepare=\(start.duration(to: prepared)) submit=\(submitting.duration(to: finished))")
    }
}
