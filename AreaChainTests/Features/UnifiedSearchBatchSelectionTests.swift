import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchBatchSelectionTests {
    @Test(arguments: [false, true]) func completeResultsAndKnownSubsetStayDistinct(incomplete: Bool) async throws {
        var batch = ContentQueryBatch.objectBatch()
        if incomplete { batch.snapshots.routines = .failed }
        let f = try UnifiedSearchResultsFixture(batch, pageSize: 2)
        defer { f.stop() }
        try f.startOperation("batch.move")
        let picker = try await f.chooseObjects()
        #expect(picker.browse.snapshot.known.count == 6 && picker.browse.snapshot.visible.count == 2)
        #expect(f.session.allObjectResultsComplete(sourceID: picker.browse.snapshot.sourceID) == !incomplete)
        f.controller.selectAllObjectResults(picker.stamp)
        if incomplete {
            #expect(f.controller.objectSelectionMessage == "unified.objects.incompleteAll")
            #expect(f.controller.objectSelection?.objects.isEmpty == true)
            f.controller.browseObjects(.selectAllKnown, stamp: picker.stamp)
        }
        try #require(f.controller.acceptObjects(picker.stamp))
        await f.controller.objectSelectionTask?.value
        let fixed = try f.draft.targets
        #expect(fixed.selection == (incomplete ? .selected : .allResults) && fixed.objects.count == 6)
        f.batch = .objectBatch(count: 9)
        _ = try await f.publish()
        #expect(try f.draft.targets == fixed)
    }

    @Test func budgetRemainderCannotBeAcceptedAsAllResults() async throws {
        var batch = QueryBatchFixture.occurrences("date:2026-10-01..2026-10-10")
        batch.snapshots.diaries = .complete([])
        batch.options.occurrenceBudget.maxResults = 2
        let f = try UnifiedSearchResultsFixture(batch, pageSize: 1)
        defer { f.stop() }
        try f.startOperation("batch.tags")
        let picker = try await f.chooseObjects()
        #expect(!picker.browse.snapshot.known.isEmpty)
        #expect(!f.session.allObjectResultsComplete(sourceID: picker.browse.snapshot.sourceID))
        f.controller.browseObjects(.selectAllKnown, stamp: picker.stamp)
        f.controller.objectSelection?.selection = .allResults
        #expect(!f.controller.acceptObjects(picker.stamp))
        #expect(f.controller.objectSelectionMessage == "unified.objects.incompleteAll")
        #expect(f.controller.objectSelection?.selection == .allResults)
        #expect(try f.draft.targets == .none)
    }

    @Test func oldNativeKeyboardSourceCannotOperateNewCandidatePage() async throws {
        let f = try UnifiedSearchResultsFixture(.objectBatch(), pageSize: 2)
        defer { f.stop() }
        try f.startOperation("batch.move")
        let picker = try await f.chooseObjects()
        let old = f.controller.buffer
        f.controller.loadObjectCandidates(picker.stamp)
        let current = try #require(f.controller.objectSelection)
        #expect(current.stamp != picker.stamp && f.controller.buffer != old)
        for intent in [UnifiedSearchIntent.open, .selectActive, .results(1)] { f.controller.intent(intent, source: old) }
        #expect(f.controller.objectSelection?.stamp == current.stamp)
        #expect(f.controller.objectSelection?.browse.selected.isEmpty == true)
        #expect(try f.draft.targets == .none)
    }

    @Test func batchSelectionNeverReceivesSyntheticBaseline() async throws {
        let f = try UnifiedSearchResultsFixture(.objectBatch())
        defer { f.stop() }
        f.controller.syntheticBaselines[.init(rawValue: "batch.move")] = .init([
            .init(subject: .object(.object(0)), parameter: .day): .uniform(.day("2000-01-01"))])
        try f.startOperation("batch.move")
        try await f.acceptObjects([.object(0), .object(1)])
        #expect(try f.draft.baseline.values.isEmpty)
    }
}
