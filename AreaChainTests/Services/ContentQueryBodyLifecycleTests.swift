import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct ContentQueryBodyLifecycleTests {
    @Test func lockBeforeReadPreventsProtectedDependency() async throws {
        let probe = BodyReadProbe()
        let f = try SearchReadFixture(bodyMode: true) { $0.observeContent = probe.observe }
        try await f.unlock()
        _ = try f.protectedDiary("needle")
        f.vault.lock()
        await f.settle()
        try f.handoff.send(.query(.enterPage(QuerySessionFixture.page(.diaries(tagID: nil), host: HandoffFixture.source))))
        _ = try await f.publishBodies("/diaries needle")
        #expect(probe.calls == 1)
        #expect(!f.vault.isUnlocked && !f.vault.isAuthenticating)
    }

    @Test(arguments: [false, true]) func lockReentryBeforeOrAfterReadCannotFreeze(after: Bool) async throws {
        let probe = BodyReadProbe()
        let f = try SearchReadFixture(bodyMode: true) { $0.observeContent = probe.observe }
        try await f.unlock()
        _ = try f.protectedDiary("needle")
        if after { probe.after = { f.vault.lock() } }
        else { probe.before = { f.vault.lock() } }
        #expect(throws: ContentQueryReadSessionError.self) { try f.prepareBodies() }
        try f.expectEmpty()
        probe.before = nil; probe.after = nil
        try await f.unlock()
        #expect(!f.session.hasPublicationPermit)
    }

    @Test(arguments: [false, true]) func lockAfterFreezeOrEvaluationRejectsLateHandle(evaluated: Bool) async throws {
        let f = try SearchReadFixture(bodyMode: true)
        try await f.unlock()
        _ = try f.protectedDiary("needle")
        let handle = try f.prepareBodies()
        if evaluated { try f.session.evaluate(handle) }
        f.vault.lock()
        #expect(throws: ContentQueryReadSessionError.self) { try f.session.evaluate(handle) }
        await #expect(throws: ContentQueryReadSessionError.self) { try await f.session.publish(handle) }
        try await f.unlock()
        await #expect(throws: ContentQueryReadSessionError.self) { try await f.session.publish(handle) }
        try f.expectEmpty()
    }

    @Test func protectionMutationInsideReadRejectsWholeBatchWithoutNotification() throws {
        let probe = BodyReadProbe()
        let f = try SearchReadFixture(bodyMode: true) { $0.observeContent = probe.observe }
        let tag = f.data.tags.tag("ordinary")
        probe.after = { tag.isPrivateDiary = true }
        #expect(throws: ContentQueryReadSessionError.stalePermit) { try f.prepareBodies() }
        #expect(!f.session.hasPublicationPermit)
    }

    @Test func modelSignalAfterReadAndMethodChangesRevoke() async throws {
        let f = try SearchReadFixture(bodyMode: true)
        try await f.unlock()
        _ = try f.protectedDiary("needle")
        _ = try await f.publishBodies("/diaries needle")
        try f.session.modelDidChange(expecting: f.lease.ownership)
        #expect(!f.session.hasRetainedPresentation)
        let handle = try f.prepareBodies()
        try f.session.evaluate(handle)
        try f.vault.beginMethodChange()
        f.vault.endMethodChange()
        await f.settle()
        await #expect(throws: ContentQueryReadSessionError.self) { try await f.session.publish(handle) }
        #expect(!f.session.hasPublicationPermit)
    }

    @Test func authenticationStartAndEndNeverRestoreBodyPermit() async throws {
        let f = try SearchReadFixture(bodyMode: true)
        try await f.unlock()
        _ = try f.protectedDiary("needle")
        _ = try await f.publishBodies("/diaries needle")
        await f.system.suspend()
        let authentication = Task { try await f.vault.unlockWithSystem(reason: "Synthetic isolated lifecycle") }
        for _ in 0..<200 where await f.system.pendingRead == nil { await Task.yield() }
        #expect(f.vault.isAuthenticating && !f.session.hasRetainedPresentation)
        #expect(throws: ContentQueryReadSessionError.self) { try f.prepareBodies() }
        await f.system.finishRead()
        try await authentication.value
        await f.settle()
        #expect(!f.session.hasPublicationPermit)
    }

    @Test func focusLossKeepsQueryButRejectsDisplayAndRequiresFreshRead() async throws {
        let f = try SearchReadFixture(bodyMode: true)
        try await f.unlock()
        _ = try f.protectedDiary("needle")
        let result = try await f.publishBodies("/diaries needle")
        let query = try f.query
        let event = ContentQueryPaginationEvent(stamp: result.pagination.stamp, action: .loadMoreUnits)
        f.focus.post(name: SearchReadFixture.focusLost, object: f.focusObject)
        #expect(try f.query == query)
        #expect(throws: ContentQueryReadSessionError.self) { try f.session.loadMore(event) }
        try f.session.resumeDisplay(expecting: f.lease)
        #expect(throws: ContentQueryReadSessionError.self) { try f.session.presentation() }
        #expect(!f.session.hasPublicationPermit)
        _ = try await f.publishBodies("/diaries needle")
        #expect(try f.session.loadMore(event).rejection != nil)
    }

    @Test func reentryDoesNotRestampOldBodyOrDestroyNewTask() throws {
        let probe = BodyReadProbe()
        let f = try SearchReadFixture(bodyMode: true) { $0.observeContent = probe.observe }
        var newer: ContentQueryReadHandle?
        probe.after = {
            probe.after = nil
            newer = try f.prepareBodies()
        }
        #expect(throws: ContentQueryReadSessionError.staleTask) { try f.prepareBodies() }
        try f.session.evaluate(#require(newer))
    }

    @Test func cancellationClearsBodySourceAndMetadataFallbackStillWorks() async throws {
        let f = try SearchReadFixture(bodyMode: true)
        _ = try await f.publishBodies()
        let handle = try f.prepareBodies()
        try f.session.cancel(handle)
        #expect(!f.session.hasRetainedPresentation && !f.session.hasPublicationPermit)
        await #expect(throws: ContentQueryReadSessionError.self) { try await f.session.publish(handle) }
        try await f.publish()
        let result = try SearchReadFixture.diaryResponse(f.session.presentation())
        #expect(result.matches.allSatisfy { if case .hiddenTitle = $0.presentation { return true }; return false })
    }

    @Test func externalBatchAndExternalOwnerCannotUpgradeToBodyRead() throws {
        let f = try SearchReadFixture()
        #expect(throws: ContentQueryReadSessionError.metadataOnlyRequired) { try f.prepareBodies() }
        let controlled = try SearchReadFixture(bodyMode: true)
        #expect(throws: ContentQueryReadSessionError.metadataOnlyRequired) {
            try controlled.session.prepare { query in
                var batch = controlled.batch(query)
                batch.snapshots.diaries = .complete([controlled.data.diary().snapshot])
                return batch
            }
        }
        #expect(!controlled.session.hasPublicationPermit)
    }
}
