import Foundation
import Observation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct ContentQueryReadSessionLockTests {
    @Test func actualWillLockClearsBeforeGenerationChanges() async throws {
        let f = try SearchReadFixture()
        try await f.unlock()
        try await f.publish()
        try f.session.setCompletionBuffer("Synthetic completion", expecting: f.lease)
        let generation = f.vault.generation
        var witnessed = false
        withObservationTracking { _ = f.vault.generation } onChange: {
            // lock() 在 MainActor 同步执行；此回调是 generation setter 的 will-change。
            MainActor.assumeIsolated {
                witnessed = true
                #expect(f.vault.generation == generation && f.vault.isUnlocked)
                #expect(!f.session.hasPublicationPermit && !f.session.hasRetainedPresentation)
                #expect((try? QuerySessionFixture.source(f.query)) == "")
            }
        }
        f.vault.lock()
        #expect(witnessed && f.vault.generation == generation + 1)
        try f.expectEmpty()
    }

    @Test func lockInsidePreparationRejectsReturnedBatch() async throws {
        let f = try SearchReadFixture()
        try await f.unlock()
        try await f.publish()
        #expect(throws: ContentQueryReadSessionError.self) {
            try f.session.prepare { query in
                let batch = f.batch(query)
                f.vault.lock()
                return batch
            }
        }
        try f.expectEmpty()
    }

    @Test func lockAfterPrepareRejectsEvaluation() throws {
        let f = try SearchReadFixture()
        let task = try f.session.prepare(read: f.batch)
        f.vault.lock()
        #expect(throws: ContentQueryReadSessionError.self) { try f.session.evaluate(task) }
        try f.expectEmpty()
    }

    @Test func lockAfterEvaluationRejectsLatePublicationEvenAfterUnlock() async throws {
        let f = try SearchReadFixture()
        try await f.unlock()
        let task = try f.session.prepare(read: f.batch)
        try f.session.evaluate(task)
        f.vault.lock()
        await #expect(throws: ContentQueryReadSessionError.self) { try await f.session.publish(task) }
        try await f.unlock()
        try f.expectEmpty()
        await #expect(throws: ContentQueryReadSessionError.self) { try await f.session.publish(task) }
        #expect(throws: ContentQueryReadSessionError.pageContextRequired) { try f.session.prepare(read: f.batch) }
        // 解锁没有恢复查询；新页面/查询与新读取必须由宿主明确发出。
        try f.handoff.send(.query(.enterPage(QuerySessionFixture.page(.diaries(tagID: nil), host: HandoffFixture.source))))
        try await f.publish()
        #expect(try f.session.presentation().response.definiteMatchCount == 1)
    }

    @Test func noSourceStillClearsDisplayAndQueryReferences() async throws {
        let f = try SearchReadFixture()
        try await f.publish()
        try f.session.setCompletionBuffer("Synthetic completion", expecting: f.lease)
        try f.owner.invalidateSource(#require(f.owner.source))
        #expect(f.owner.source == nil && f.session.hasRetainedPresentation)
        f.vault.lock()
        try f.expectEmpty()
    }

    @Test func metadataOnlyActualReadPublishLockChain() async throws {
        let f = try SearchReadFixture()
        let hidden = f.data.diary("Synthetic protected fixture")
        hidden.isPrivate = true
        let handle = try f.session.prepare { query in
            let batch = f.batch(query)
            #expect(batch.snapshots.diaries.values?.allSatisfy { !$0.isContentAvailable && $0.text.isEmpty } == true)
            return batch
        }
        try f.session.evaluate(handle)
        try await f.session.publish(handle)
        #expect(try f.session.presentation().response.definiteMatchCount == 2)
        f.vault.lock()
        try f.expectEmpty()
        #expect(hidden.text == "Synthetic protected fixture" && f.data.context.hasChanges)
        #expect(await f.system.items.isEmpty)
    }

    @Test func readableDiaryBatchIsRejected() throws {
        let f = try SearchReadFixture()
        #expect(throws: ContentQueryReadSessionError.metadataOnlyRequired) {
            try f.session.prepare { query in
                var batch = f.batch(query)
                batch.snapshots.diaries = .complete([DiarySnapshot(
                    id: UUID(), text: "Synthetic ordinary body", dayKey: QuerySessionFixture.today,
                    createdAt: TodoQueryFixture.created)])
                return batch
            }
        }
        #expect(f.owner.source == nil)
    }
}
