import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct PendingCompletionTimingTests {
    @Test func delayedCommitWaitsThenPersists() async {
        let manager = PendingCompletionManager()
        manager.skipDelayOverride = false
        let id = UUID()
        var committed = 0
        manager.toggle(id: id, currentlyDone: false) { committed += 1 }
        #expect(committed == 0)
        #expect(manager.pendingDoneIDs.contains(id))
        try? await Task.sleep(nanoseconds: 500_000_000)
        #expect(committed == 1)
        #expect(!manager.pendingDoneIDs.contains(id))
    }

    @Test func secondToggleDuringDelayCancelsCommit() async {
        let manager = PendingCompletionManager()
        manager.skipDelayOverride = false
        let id = UUID()
        var committed = 0
        manager.toggle(id: id, currentlyDone: false) { committed += 1 }
        #expect(manager.pendingDoneIDs.contains(id))
        manager.toggle(id: id, currentlyDone: false) { committed += 1 }
        try? await Task.sleep(nanoseconds: 500_000_000)
        #expect(committed == 0)
        #expect(!manager.pendingDoneIDs.contains(id))
    }

    @Test func reduceMotionStillCommitsImmediately() {
        let manager = PendingCompletionManager()
        manager.skipDelayOverride = false
        var committed = false
        manager.toggle(id: UUID(), currentlyDone: false, reduceMotion: true) { committed = true }
        #expect(committed)
        #expect(manager.pendingDoneIDs.isEmpty)
    }

    @Test func delayedBatchCommitWaitsThenPersists() async {
        let manager = PendingCompletionManager()
        manager.skipDelayOverride = false
        let ids: Set = [UUID(), UUID()]
        var committed = 0
        manager.toggleBatch(ids: ids, markDone: true) { committed += 1 }
        #expect(committed == 0)
        #expect(ids.isSubset(of: manager.pendingDoneIDs))
        try? await Task.sleep(nanoseconds: 500_000_000)
        #expect(committed == 1)
        #expect(manager.pendingDoneIDs.isEmpty)
    }
}
