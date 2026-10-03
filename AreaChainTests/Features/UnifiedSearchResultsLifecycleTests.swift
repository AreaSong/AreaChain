import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchResultsLifecycleTests {
    @Test func newPublicationPreservesIdentityAndDisappearanceReturnsInput() async throws {
        let fixture = try UnifiedSearchResultsFixture(QueryPaginationFixture.flat(4), pageSize: 4)
        defer { fixture.stop() }
        _ = try await fixture.publish()
        let host = UnifiedSearchTestHost(results: fixture.controller)
        defer { host.close() }
        try await host.start()
        try await host.key(125, "\u{f701}")
        let old = try fixture.page
        let active = try #require(old.browse.active)
        fixture.controller.browse(.init(version: old.snapshot.version, action: .select(active, true)), source: fixture.controller.buffer)
        var rows = try #require(fixture.batch.snapshots.todos.values)
        rows.reverse()
        rows[0].createdAt = rows[0].createdAt.addingTimeInterval(3600)
        fixture.batch.snapshots.todos = .complete(rows)
        fixture.controller.refresh()
        try await host.settle()
        #expect(try fixture.page.browse.active == active)
        #expect(try fixture.page.browse.selected == [active])
        fixture.controller.browse(.init(version: old.snapshot.version, action: .activate(old.snapshot.visible.last!)),
                                  source: fixture.controller.buffer)
        #expect(try fixture.page.browse.active == active)
        fixture.batch.snapshots.todos = .complete(rows.filter { $0.id != active.id })
        fixture.controller.refresh()
        try await host.settle()
        #expect(try fixture.page.browse.active == nil && fixture.page.browse.selected.isEmpty)
        #expect(host.window.firstResponder === (try host.editor))
    }

    @Test func isolatedStoredDiaryThroughGatedPublicExpansion() async throws {
        let fixture = try SearchReadFixture(bodyMode: true)
        defer { fixture.session.detach() }
        fixture.data.diary(String(repeating: "合成公开手记 résumé 👨‍👩‍👧‍👦，用于原生只读布局验证。", count: 30))
        let controller = UnifiedSearchController(session: fixture.session, coordinator: fixture.handoff.coordinator,
            buffer: .init(lease: try fixture.lease, version: 0, text: "/diaries"), read: {
                let handle = try fixture.session.prepareBodies(observation: RoutineContentQueryFixture.observation())
                try fixture.session.evaluate(handle)
                return try await fixture.session.publish(handle)
            }, recordOpen: { _ in Issue.record("此场景不得请求真实打开") })
        defer { controller.detach() }
        let host = UnifiedSearchTestHost(layout: .compact, width: 380, locale: "zh-Hans", results: controller)
        defer { host.close() }
        try await host.start()
        controller.refresh()
        try await host.settle()
        let page = try fixture.session.presentation().pagination
        let row = try #require(page.snapshot.source.rows.first { !$0.expansion.isEmpty })
        #expect(row.summary != nil && row.id.type == .diary)
        try await host.key(53, "\u{1b}")
        let summary = try #require(host.resultNode("unified.summary." + row.id.searchIdentifier) as? SearchFragmentLabel)
        #expect(summary.bounds.height <= 36 && summary.maximumNumberOfLines == 2)
        try await host.clickResult("unified.expand." + row.id.searchIdentifier + ".diaryBody")
        let text = try #require(SettingsButtonTestSupport.elements(host.window.contentView).compactMap { $0 as? SearchReadOnlyEditor }.first)
        #expect(!text.isEditable && !text.string.isEmpty)
        try host.snapshot("results-public-diary-expanded")
        fixture.vault.lock()
        #expect(text.string.isEmpty && text.window == nil)
    }

    @Test func actualWindowBlurRevokesWithoutClearingQuery() async throws {
        let fixture = try UnifiedSearchResultsFixture(UnifiedSearchResultsFixture.longText())
        defer { fixture.stop() }
        _ = try await fixture.publish()
        let host = UnifiedSearchTestHost(results: fixture.controller)
        defer { host.close() }
        try await host.start()
        let buffer = fixture.controller.buffer
        let other = NSWindow(contentRect: .init(x: 10, y: 10, width: 100, height: 100),
                             styleMask: [.titled], backing: .buffered, defer: false)
        other.isReleasedWhenClosed = false
        defer { SystemPageHost.release(other) }
        other.makeKeyAndOrderFront(nil)
        try await SystemPageHost.settle(other)
        #expect(fixture.session.isMasked && !fixture.session.hasRetainedPresentation)
        #expect(fixture.controller.buffer == buffer)
        host.window.makeKeyAndOrderFront(nil)
        try await host.settle()
        #expect(throws: ContentQueryReadSessionError.self) { try fixture.session.presentation() }
        try host.snapshot("results-blur-mask")
    }

    @Test func removedExpandedObjectReturnsToInputWithoutAnActiveHit() async throws {
        let fixture = try UnifiedSearchResultsFixture(UnifiedSearchResultsFixture.longText())
        defer { fixture.stop() }
        let host = UnifiedSearchTestHost(results: fixture.controller)
        defer { host.close() }
        try await host.start()
        _ = try await fixture.publish()
        try await host.settle()
        let row = try #require(fixture.page.snapshot.source.rows.first)
        try await host.clickResult("unified.expand." + row.id.searchIdentifier + ".notes")
        let body = try #require(SettingsButtonTestSupport.elements(host.window.contentView).compactMap { $0 as? SearchReadOnlyEditor }.first)
        host.window.makeFirstResponder(body)
        #expect(try fixture.page.browse.active == nil)
        #expect(fixture.session.displayUpdates.focusedControl == .body(row.id, .notes))
        fixture.batch.snapshots.todos = .complete([])
        fixture.controller.refresh()
        try await host.settle()
        #expect(host.window.firstResponder === (try host.editor))
        #expect(try fixture.page.browse.expanded.isEmpty)
    }
}
