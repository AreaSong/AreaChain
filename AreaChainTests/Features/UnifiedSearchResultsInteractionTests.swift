import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchResultsInteractionTests {
    @Test func inputPublicationNavigationAndOpenIntent() async throws {
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        let host = UnifiedSearchTestHost(results: fixture.controller)
        defer { host.close() }
        try await host.start()
        let editor = try host.editor
        editor.insertText("batch", replacementRange: editor.selectedRange())
        try await host.settle()
        let page = try fixture.page
        #expect(!page.snapshot.visible.isEmpty && fixture.reads == 1)
        try await host.key(125, "\u{f701}")
        #expect(try fixture.page.browse.active == page.snapshot.visible.first)
        #expect(host.window.firstResponder is UnifiedSearchResultsBoundary)
        try await host.key(36, "\r")
        #expect(fixture.opens.count == 1 && fixture.opens[0].object == page.snapshot.visible.first)
        #expect(fixture.opens[0].requiresFreshBusinessValidation)
        try await host.key(36, "\r", flags: .command)
        #expect(fixture.opens.count == 1)
        try await host.key(53, "\u{1b}")
        #expect(host.window.firstResponder === (try host.editor))
        let before = try fixture.page.snapshot.version
        (try host.editor).insertText("/", replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        #expect(try host.state.suggestions.isActive)
        try await host.key(125, "\u{f701}")
        #expect(try host.state.suggestions.selectedIndex == 1)
        #expect(try fixture.page.snapshot.version == before)
        #expect(fixture.reads == 1)
        try host.snapshot("results-command-context")
    }

    @Test func paginationTwoSelectionsAndOldButtons() async throws {
        let fixture = try UnifiedSearchResultsFixture(QueryPaginationFixture.flat(7), pageSize: 2)
        defer { fixture.stop() }
        _ = try await fixture.publish()
        let host = UnifiedSearchTestHost(results: fixture.controller)
        defer { host.close() }
        try await host.start()
        let old = try fixture.page
        let source = fixture.controller.buffer
        try await host.clickResult("unified.results.selectVisible")
        #expect(try fixture.page.browse.selected.count == 2)
        try await host.clickResult("unified.load.units")
        #expect(try fixture.page.status.hits.displayed == 4)
        #expect(try fixture.page.browse.selected.count == 2)
        fixture.controller.load(.init(stamp: old.stamp, action: .loadMoreUnits), source: source)
        fixture.controller.browse(.init(version: old.snapshot.version, action: .selectAllKnown), source: source)
        #expect(try fixture.page.status.hits.displayed == 4 && fixture.page.browse.selected.count == 2)
        try await host.clickResult("unified.results.selectKnown")
        #expect(try fixture.page.browse.selected.count == 7)
        try await host.clickResult("unified.load.units")
        try await host.clickResult("unified.load.units")
        #expect(try fixture.page.status.hits.displayed == 7)
        #expect(fixture.reads == 1)
        #expect(!SettingsButtonTestSupport.elements(host.window.contentView).contains {
            SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String == "unified.load.units"
        })
    }

    @Test func trashMembersContextsDoNotSelectOrCount() async throws {
        let fixture = try UnifiedSearchResultsFixture(QueryPaginationFixture.grouped(groups: 2, hits: 45, contexts: 24), pageSize: 2)
        defer { fixture.stop() }
        _ = try await fixture.publish()
        let host = UnifiedSearchTestHost(results: fixture.controller)
        defer { host.close() }
        try await host.start()
        let first = try #require(fixture.page.snapshot.units.first)
        let group = try #require(first.sourceGroup)
        #expect(try fixture.page.browse.expanded.isEmpty)
        try await host.clickResult("unified.contextToggle." + group.searchIdentifier)
        #expect(try fixture.page.status.hits.displayed == 4)
        try await host.clickResult("unified.load.contexts." + group.searchIdentifier)
        #expect(try fixture.page.status.hits.displayed == 4)
        #expect(try fixture.page.status.groups.first?.contexts.displayed == 4)
        try await host.clickResult("unified.load.members." + first.bestMatch.searchIdentifier)
        #expect(try fixture.page.status.hits.displayed == 6)
        try await host.clickResult("unified.results.selectKnown")
        #expect(try fixture.page.browse.selected.count == 90)
        #expect(try fixture.page.browse.selected.isDisjoint(with: Set(first.context.map(\.object))))
        let context = try #require(fixture.page.snapshot.visibleContext(in: first).first)
        try await SettingsButtonTestSupport.reveal(host.resultNode("unified.context." + context.object.searchIdentifier), in: host.window)
        try host.snapshot("results-trash-expanded")
    }

    @Test func readonlyExpansionKeepsSelectionAndCollapseFocus() async throws {
        let fixture = try UnifiedSearchResultsFixture(UnifiedSearchResultsFixture.longText())
        defer { fixture.stop() }
        let host = UnifiedSearchTestHost(width: 500, results: fixture.controller)
        defer { host.close() }
        try await host.start()
        _ = try await fixture.publish()
        try await host.settle()
        let row = try #require(fixture.page.snapshot.source.rows.first)
        let reference = try #require(row.expansion.first { $0.field == .notes })
        let toggleID = "unified.expand." + row.id.searchIdentifier + ".notes"
        let before = host.window.firstResponder
        fixture.controller.browse(.init(version: try fixture.page.snapshot.version,
            action: .expand(.bodyToggle(reference.object, reference.field))), source: fixture.controller.buffer)
        try await host.settle()
        #expect(host.window.firstResponder === before)
        let native = try #require(SettingsButtonTestSupport.elements(host.window.contentView)
            .compactMap { $0 as? SearchReadOnlyEditor }.first)
        #expect(!native.isEditable && native.isSelectable && native.string.contains("needle"))
        host.window.makeFirstResponder(native)
        native.setSelectedRange(NSRange(location: 0, length: 6))
        let active = try fixture.page.browse.active
        try await host.key(125, "\u{f701}")
        #expect(try fixture.page.browse.active == active)
        #expect(host.window.firstResponder === native)
        try await host.key(53, "\u{1b}")
        #expect(try !fixture.page.browse.expanded.contains(.bodyToggle(reference.object, reference.field)))
        #expect(!(host.window.firstResponder is SearchReadOnlyEditor))
        _ = try host.resultNode(toggleID)
        try host.snapshot("results-collapse-focus")
        try await host.key(49, " ")
        #expect(try fixture.page.browse.expanded.contains(.bodyToggle(reference.object, reference.field)))
    }

    @Test func synchronousLockClearsInputResultsAndExpandedStorage() async throws {
        let fixture = try UnifiedSearchResultsFixture(UnifiedSearchResultsFixture.longText())
        defer { fixture.stop() }
        _ = try await fixture.publish()
        let host = UnifiedSearchTestHost(results: fixture.controller)
        defer { host.close() }
        try await host.start()
        let state = try host.state
        let editor = try host.editor
        let oldSource = fixture.controller.buffer
        let old = try fixture.page
        let row = try #require(old.snapshot.source.rows.first)
        let ref = try #require(row.expansion.first)
        fixture.controller.browse(.init(version: old.snapshot.version, action: .expand(.bodyToggle(ref.object, ref.field))),
                                  source: oldSource)
        try await host.settle()
        let body = try #require(SettingsButtonTestSupport.elements(host.window.contentView).compactMap { $0 as? SearchReadOnlyEditor }.first)
        editor.undoManager?.registerUndo(withTarget: editor) { $0.string = "synthetic stale input" }
        editor.setMarkedText("合成", selectedRange: NSRange(location: 2, length: 0), replacementRange: editor.selectedRange())
        NotificationCenter.default.post(name: .privacyWillLock, object: fixture.vault)
        // 故意不 settle：同一个通知栈内必须已经撤下旧原生树和字段 storage。
        #expect(editor.string.isEmpty && !editor.hasMarkedText() && editor.undoManager?.canUndo == false)
        #expect(body.string.isEmpty && body.window == nil)
        #expect(state.completion == nil && !state.suggestions.isActive)
        #expect(fixture.controller.buffer.privacyRevision == oldSource.privacyRevision + 1)
        #expect(!fixture.session.hasRetainedPresentation)
        fixture.controller.browse(.init(version: old.snapshot.version, action: .activate(row.id)), source: oldSource)
        #expect(fixture.opens.isEmpty)
        try await host.settle()
        try host.snapshot("results-locked")
    }

    @Test func blurMasksAndRefocusRequiresRead() async throws {
        let fixture = try UnifiedSearchResultsFixture(UnifiedSearchResultsFixture.longText())
        defer { fixture.stop() }
        _ = try await fixture.publish()
        let host = UnifiedSearchTestHost(results: fixture.controller)
        defer { host.close() }
        try await host.start()
        let source = fixture.controller.buffer
        fixture.focus.post(name: UnifiedSearchResultsFixture.focusLost, object: fixture.focusObject)
        #expect(fixture.session.isMasked && !fixture.session.hasRetainedPresentation)
        #expect(fixture.controller.buffer == source)
        try fixture.session.resumeDisplay(expecting: source.lease)
        #expect(throws: ContentQueryReadSessionError.self) { try fixture.session.presentation() }
        _ = try await fixture.publish()
        #expect(try !fixture.page.snapshot.visible.isEmpty)
    }

    @Test func tabLeavesInputAndReachesVisibleSelectionButtons() async throws {
        let fixture = try UnifiedSearchResultsFixture(QueryPaginationFixture.flat(4), pageSize: 2)
        defer { fixture.stop() }
        let host = UnifiedSearchTestHost(results: fixture.controller)
        defer { host.close() }
        try await host.start()
        _ = try await fixture.publish()
        try await host.settle()
        let editor = try host.editor
        try await host.key(48, "\t")
        #expect(host.window.firstResponder !== editor)
        try await host.key(49, " ")
        #expect(try fixture.page.browse.selected.count == 2)
        try await host.key(48, "\t")
        try await host.key(49, " ")
        #expect(try fixture.page.browse.selected.count == 4)
    }
}
