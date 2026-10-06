import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchScrollOwnershipTests {
    @Test func resultsAndExpandedBodyKeepTheirOwnDecoration() async throws {
        let fixture = try UnifiedSearchResultsFixture(UnifiedSearchResultsFixture.longText())
        defer { fixture.stop() }
        let host = UnifiedSearchTestHost(results: fixture.controller)
        defer { host.close() }
        try await host.start()
        _ = try await fixture.publish()
        try await host.settle()
        let config = try onlyConfig(host.window)
        let target = try #require(config.currentScrollView)
        let overlay = try #require(config.currentOverlay)
        #expect(target === config.enclosingScrollView)
        let row = try #require(fixture.page.snapshot.source.rows.first)
        try await host.clickResult("unified.expand." + row.id.searchIdentifier + ".notes")
        try await host.settle()
        #expect(config.currentScrollView === target && config.currentOverlay === overlay)
        ScrollNativeEvidence.record(host.window, label: "search-results-expanded")
        fixture.controller.detach()
        try await host.settle()
        #expect(overlay.superview == nil)
    }

    @Test func operationAndCandidatesSwitchWithoutLeavingOldOverlay() async throws {
        let fixture = try UnifiedSearchResultsFixture(.objectBatch(count: 20))
        defer { fixture.stop() }
        try fixture.startOperation("todo.completion")
        let host = UnifiedSearchTestHost(results: fixture.controller, operations: true)
        defer { host.close() }
        try await host.start()
        ScrollNativeEvidence.record(host.window, label: "search-operation-initial")
        let config = try operationConfig(host.window)
        let old = try #require(config.currentOverlay)
        _ = try await fixture.chooseObjects()
        try await host.settle()
        #expect(old.superview == nil)
        ScrollNativeEvidence.record(host.window, label: "search-candidates")
        let current = try operationConfig(host.window)
        let overlay = try #require(current.currentOverlay)
        let target = try #require(current.currentScrollView)
        #expect(overlay.superview === target)
        #expect((target.documentView?.bounds.height ?? 0) > target.contentSize.height)
    }

    private func operationConfig(_ window: NSWindow) throws -> DaybookScrollerHostNSView {
        let configs = ScrollNativeEvidence.views(window).compactMap { $0 as? DaybookScrollerHostNSView }
            .filter { view in
                var node = view.superview
                while let parent = node {
                    if parent is UnifiedSearchOperationBoundary { return true }
                    node = parent.superview
                }
                return false
            }
        try #require(configs.count == 1)
        return try #require(configs.first)
    }

    private func onlyConfig(_ window: NSWindow) throws -> DaybookScrollerHostNSView {
        let configs = ScrollNativeEvidence.views(window).compactMap { $0 as? DaybookScrollerHostNSView }
        try #require(configs.count == 1)
        return try #require(configs.first)
    }
}
