import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchNavigationBoundaryTests {
    @Test func liveIdentityRejectsDeletedDuplicateRelationsAndEligibility() throws {
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        let todo = CommandObjectReference(type: .todo, id: fixture.todo.id)
        let child = CommandObjectReference(type: .subtask, id: fixture.child.id)
        let open = ContentQueryBrowseOpen(object: todo, parent: nil, viewingTrash: false)
        let denied = WorkspaceObjectNavigation(context: fixture.context, calendar: .current, allows: { _ in false })
        #expect(throws: WorkspaceOpenFailure.invalidTarget) { try denied.resolve(open) }
        let reader = fixture.router.objects
        fixture.todo.dayKey = "2026-10-12"
        #expect(try reader.resolve(open).dayKey == "2026-10-12")
        #expect(throws: WorkspaceOpenFailure.invalidTarget) {
            try reader.resolve(.init(object: child, parent: .init(type: .todo, id: UUID()), viewingTrash: false))
        }
        fixture.todo.deletedAt = .now
        #expect(throws: WorkspaceOpenFailure.invalidTarget) { try reader.resolve(open) }
        fixture.todo.deletedAt = nil
        let duplicate = fixture.data.todo()
        duplicate.id = fixture.todo.id
        #expect(throws: WorkspaceOpenFailure.invalidTarget) { try reader.resolve(open) }
        #expect(throws: WorkspaceOpenFailure.unsupported) {
            try reader.resolve(.init(object: .init(type: .routine, id: fixture.routine.id), parent: nil, viewingTrash: false))
        }
    }

    @Test func nativeCompletionAndCommandReturnNeverSubmitBackgroundPlan() async throws {
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        try fixture.handoff.queue(HandoffFixture.setting())
        _ = fixture.controller.publishOperation(text: "needle")
        try await fixture.start()
        let original = try fixture.handoff.state()
        try await fixture.typeNative("/go/settings")
        try await fixture.key(36, "\r", flags: .command)
        #expect(try fixture.handoff.state() == original)
        try await fixture.key(48, "\t")
        #expect(fixture.controller.returnSearch == nil)
        try await fixture.key(36, "\r")
        await fixture.controller.navigationTask?.value
        #expect(fixture.router.outcome == .displayed)
        #expect(try fixture.handoff.state() == original)
        try await fixture.key(33, "[", flags: .command)
        try await fixture.settle()
        #expect(fixture.controller.buffer.text == "needle")
        #expect(try fixture.handoff.state() == original)
    }

    @Test func markedTextAndEscapeKeepInputAndPreventNavigation() async throws {
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        try await fixture.start()
        try await fixture.typeNative("/go/settings")
        let editor = try fixture.editor
        editor.setMarkedText("组合", selectedRange: .init(location: 2, length: 0), replacementRange: editor.selectedRange())
        fixture.controller.executeNavigation(source: fixture.controller.buffer)
        #expect(fixture.controller.returnSearch == nil)
        #expect(editor.hasMarkedText())
        #expect(editor.string.contains("组合"))
        editor.unmarkText()
        try await fixture.typeNative("/go/settings")
        try await fixture.key(53, "\u{1b}")
        #expect(fixture.controller.returnSearch == nil)
        try await fixture.key(53, "\u{1b}")
        #expect(fixture.controller.buffer.text == "needle")
        #expect(!fixture.context.hasChanges)
    }

    @Test func insufficientSpaceLocatesAndDoesNotReopenAutomatically() async throws {
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        try await fixture.start(style: 2)
        try await fixture.open(.init(type: .todo, id: fixture.todo.id))
        #expect(fixture.router.outcome == .locatedWithoutInspector)
        #expect(fixture.navigation.selectedTaskID == fixture.todo.id)
        #expect(!fixture.navigation.isInspectorPresented)
        fixture.window?.setContentSize(NSSize(width: 1300, height: 800))
        try await fixture.settle()
        #expect(!fixture.navigation.isInspectorPresented)
        #expect(fixture.navigation.canPresentInspector)
        fixture.navigation.isInspectorPresented = true
        try await fixture.settle()
        #expect(fixture.router.mounted("object." + fixture.todo.id.uuidString))
    }

    @Test func removedSelectionAndStaleOpenStayRecoverable() async throws {
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        try await fixture.start()
        let id = CommandObjectReference(type: .todo, id: fixture.todo.id)
        let page = try fixture.session.presentation().pagination
        fixture.controller.browse(.init(version: page.snapshot.version, action: .activate(id)), source: fixture.controller.buffer)
        try await fixture.go("/go/settings")
        fixture.todo.deletedAt = .now
        try fixture.session.modelDidChange(expecting: fixture.controller.buffer.lease.ownership)
        try await fixture.back()
        #expect(fixture.controller.navigationMessage == "unified.navigation.missing")
        #expect(try fixture.session.presentation().pagination.browse.active == nil)
        fixture.controller.browse(.init(version: page.snapshot.version, action: .open(inputEditing: false)), source: fixture.controller.buffer)
        #expect(fixture.controller.returnSearch == nil)
        #expect(fixture.navigation.isSearching)
    }

    @Test func ordinaryTabsUseOriginalPageConditionsAndDiscardOldReturn() async throws {
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        try await fixture.start()
        try await fixture.go("/go/settings")
        let ticket = try #require(fixture.controller.returnSearch)
        fixture.navigation.revealTab(.today)
        try await fixture.settle()
        #expect(fixture.controller.returnSearch == nil)
        #expect(try fixture.handoff.state().query.page.page == .today(fixture.hostContext.filters.filters.tasks))
        let query = try fixture.handoff.state().query
        await fixture.controller.returnToSearch(ticket.id)
        #expect(try fixture.handoff.state().query == query)
    }

    @Test func realInspectorDraftsSurviveNavigationWithoutBlurSave() async throws {
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        try await fixture.start()
        let titleKey = "todo-\(fixture.todo.id)"
        fixture.drafts.titles[titleKey] = "unsubmitted title"
        fixture.drafts.titles["subtask-new-\(fixture.todo.id)"] = "unsubmitted child"
        try await fixture.open(.init(type: .todo, id: fixture.todo.id))
        let noteEditor = try #require(SettingsButtonTestSupport.elements(fixture.window?.contentView)
            .compactMap { $0 as? NSTextView }.first { !$0.isFieldEditor && $0.isEditable })
        fixture.window?.makeFirstResponder(noteEditor)
        noteEditor.insertText("unsubmitted note", replacementRange: .init(location: 0, length: noteEditor.string.utf16.count))
        try await fixture.settle()
        try await fixture.go("/go/settings")
        #expect(fixture.router.outcome == .displayed)
        #expect(fixture.drafts.titles[titleKey] == "unsubmitted title")
        #expect(fixture.drafts.notes[titleKey] == "unsubmitted note")
        #expect(fixture.drafts.titles["subtask-new-\(fixture.todo.id)"] == "unsubmitted child")
        #expect(fixture.todo.title == "needle parent" && fixture.todo.notes.isEmpty)
        #expect(fixture.saves == 0 && !fixture.context.hasChanges)
        try await fixture.back()
        try await fixture.open(.init(type: .todo, id: fixture.todo.id))
        #expect(fixture.router.outcome == .displayed)
        #expect(fixture.drafts.notes[titleKey] == "unsubmitted note")
        #expect(fixture.saves == 0)
        try await fixture.snapshot("drafts-retained")
    }

    @Test func validSnapshotRestoresActualScrollAndSelection() async throws {
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        for index in 0..<50 {
            let todo = fixture.data.todo("needle row \(index)")
            todo.notes = String(repeating: "Synthetic needle expansion. ", count: 40)
        }
        try fixture.context.save()
        fixture.saves = 0
        try await fixture.start()
        let page = try fixture.session.presentation().pagination
        let object = try #require(page.snapshot.visible.first)
        let expanded = try #require(page.browse.toggleControls.first)
        fixture.controller.browse(.init(version: page.snapshot.version, action: .expand(expanded)), source: fixture.controller.buffer)
        fixture.controller.browse(.init(version: page.snapshot.version, action: .activate(object)), source: fixture.controller.buffer)
        fixture.controller.browse(.init(version: page.snapshot.version, action: .select(object, true)), source: fixture.controller.buffer)
        try await fixture.settle()
        let boundaries = SettingsButtonTestSupport.elements(fixture.window?.contentView).compactMap { $0 as? UnifiedSearchResultsBoundary }
        let boundary = try #require(boundaries.first)
        let scroll = try #require(SettingsButtonTestSupport.elements(boundary).compactMap { $0 as? NSScrollView }.first)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 300))
        scroll.reflectScrolledClipView(scroll.contentView)
        try await fixture.settle()
        let before = try #require(fixture.controller.captureSearchScroll?())
        #expect(before.y > 0)
        try await fixture.go("/go/settings")
        let saved = try #require(fixture.controller.returnSearch?.scroll)
        #expect(abs(saved.y - before.y) < 1)
        try await fixture.back()
        try await fixture.settle()
        let after = try #require(fixture.controller.captureSearchScroll?())
        #expect(abs(after.y - before.y) < 1)
        #expect(try fixture.session.presentation().pagination.browse.selected == [object])
        #expect(try fixture.session.presentation().pagination.browse.expanded.contains(expanded))
        #expect(fixture.saves == 0)
    }

}
