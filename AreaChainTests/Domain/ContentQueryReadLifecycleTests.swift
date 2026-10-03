import Foundation
import Testing
@testable import AreaChain

struct ContentQueryReadLifecycleTests {
    @Test func busyDuplicateCalculationAndTicketReplayAreRejected() throws {
        let owner = try QueryReadFixture.owner()
        let budget = QueryReadFixture.budget(owner, results: 4)
        let task = try owner.continueReading(source: owner.source!, budget: budget)
        #expect(throws: ContentQueryReadError.busy) { try owner.continueReading(source: owner.source!, budget: budget) }
        let old = owner.published!.pagination.stamp
        let ticket = try owner.evaluate(task)
        #expect(owner.published!.pagination.stamp == old)
        #expect(throws: ContentQueryReadError.invalidPhase) { try owner.evaluate(task) }
        #expect(throws: ContentQueryReadError.busy) { try owner.continueReading(source: owner.source!, budget: budget) }
        try owner.publish(ticket)
        #expect(throws: ContentQueryReadError.staleTask) { try owner.publish(ticket) }
        #expect(throws: ContentQueryReadError.staleTask) { try owner.fail(task) }
    }

    @Test func cancellationRejectsLatePublicationWithoutClaimingSynchronousInterruption() throws {
        let owner = try QueryReadFixture.owner()
        let id = owner.published!.pagination.snapshot.visible[0]
        QueryReadFixture.browse(owner, .activate(id))
        QueryReadFixture.browse(owner, .select(id, true))
        let task = try owner.continueReading(source: owner.source!, budget: QueryReadFixture.budget(owner, results: 4))
        let ticket = try owner.evaluate(task)
        // 同步计算已返回；这里只验证取消发布，不把准备/完成事件模拟声称为中断正在执行的函数。
        #expect(owner.phase == .awaitingPublication)
        let before = owner.published!.pagination.stamp
        #expect(try owner.cancel(task).outcome == .publicationCancelled)
        #expect(throws: ContentQueryReadError.staleTask) { try owner.publish(ticket) }
        #expect(owner.published!.pagination.stamp == before)
        #expect(owner.published!.pagination.browse.active == id && owner.published!.pagination.browse.selected == [id])
        let next = try owner.continueReading(source: owner.source!, budget: QueryReadFixture.budget(owner, results: 5))
        #expect(next.source == task.source && next != task)
        #expect(throws: ContentQueryReadError.staleTask) { try owner.publish(ticket) }
        try owner.publish(owner.evaluate(next))
    }

    @Test func cancellationBeforeCalculationAndFailureKeepLastResult() throws {
        let owner = try QueryReadFixture.owner()
        let before = owner.published!.pagination.stamp
        let cancelled = try owner.continueReading(source: owner.source!, budget: QueryReadFixture.budget(owner, results: 3))
        try owner.cancel(cancelled)
        #expect(throws: ContentQueryReadError.staleTask) { try owner.evaluate(cancelled) }
        let failed = try owner.continueReading(source: owner.source!, budget: QueryReadFixture.budget(owner, results: 4))
        let ticket = try owner.evaluate(failed)
        #expect(try owner.fail(failed).outcome == .failed)
        #expect(throws: ContentQueryReadError.staleTask) { try owner.publish(ticket) }
        #expect(owner.published!.pagination.stamp == before && owner.outcome == .failed)
        #expect(owner.phase == .idle && owner.request == nil)
    }

    @Test func newSnapshotWithSameRequestIDRejectsOldSourceAndLateTask() throws {
        let owner = try QueryReadFixture.owner()
        let old = try owner.continueReading(source: owner.source!, budget: QueryReadFixture.budget(owner, results: 4))
        let ticket = try owner.evaluate(old)
        let replacement = try owner.begin(QueryPaginationFixture.flat(3))
        #expect(old.requestID == replacement.requestID && old.source != replacement.source)
        #expect(owner.published!.task.source == old.source)
        #expect(throws: ContentQueryReadError.staleSource) { try owner.publish(ticket) }
        #expect(throws: ContentQueryReadError.staleSource) { try owner.evaluate(old) }
        #expect(throws: ContentQueryReadError.staleSource) {
            try owner.continueReading(source: old.source, budget: .init())
        }
        try owner.publish(owner.evaluate(replacement))
        #expect(owner.published!.response.matches.allSatisfy { $0.id.type == .todo })
        #expect(throws: ContentQueryReadError.staleSource) { try owner.publish(ticket) }
    }

    @Test func replacingPreparedSourceAndFailureDoNotRelabelLastResultAsCurrentSource() throws {
        let owner = try QueryReadFixture.owner()
        let previous = owner.published!.task
        let replacement = try owner.begin(QueryBatchFixture.empty("/todos different"))
        try owner.fail(replacement)
        #expect(owner.published!.task == previous && owner.source != previous.source)
        #expect(throws: ContentQueryReadError.noPublishedResult) {
            try owner.continueReading(source: replacement.source, budget: .init())
        }
        #expect(throws: ContentQueryReadError.staleSource) {
            try owner.continueReading(source: previous.source, budget: .init())
        }
    }

    @Test func foreignOwnerCannotComputeOrPublishEvenWithIdenticalInputs() throws {
        let first = try QueryReadFixture.owner()
        let second = try QueryReadFixture.owner()
        let task = try first.continueReading(source: first.source!, budget: QueryReadFixture.budget(first, results: 4))
        let ticket = try first.evaluate(task)
        #expect(throws: ContentQueryReadError.staleSource) { try second.evaluate(task) }
        #expect(throws: ContentQueryReadError.staleSource) { try second.publish(ticket) }
    }

    @Test func protectionInvalidationDropsOwnerReferencesAndRejectsOldTokens() throws {
        let owner = try QueryReadFixture.owner()
        let task = try owner.continueReading(source: owner.source!, budget: QueryReadFixture.budget(owner, results: 4))
        let ticket = try owner.evaluate(task)
        try owner.invalidateSource(task.source)
        #expect(owner.published == nil && owner.source == nil && owner.request == nil && owner.attemptedBudget == nil)
        #expect(owner.outcome == .sourceInvalidated)
        #expect(throws: ContentQueryReadError.staleSource) { try owner.publish(ticket) }
        #expect(throws: ContentQueryReadError.staleSource) { try owner.continueReading(source: task.source, budget: .init()) }
        #expect(throws: ContentQueryReadError.staleSource) { try owner.invalidateSource(task.source) }
    }
}
