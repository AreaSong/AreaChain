import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct WorkspaceLegacySearchRoutingTests {
    @Test(arguments: [0, 1, 2]) func menuResultStillOpensActualCalendarAndOriginalIdentity(_ kind: Int) async throws {
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        try await fixture.start(unified: false)
        let objectID = kind == 2 ? fixture.routine.id : fixture.todo.id
        let hit = BoardSearchHit(id: kind == 1 ? fixture.child.id : objectID,
            kind: kind == 1 ? .subtask : (kind == 2 ? .routine : .todo), title: "Legacy navigation result",
            dayKey: fixture.day, createdAt: .now, parentID: kind == 1 ? fixture.todo.id : nil)
        var shows = 0
        let opening = AppWindows.WorkspaceOpening(navigation: fixture.navigation, dismissOverlay: {}, activate: {}, show: {
            shows += 1
            fixture.window?.makeKeyAndOrderFront(nil)
        })
        let content = SearchResultsView(hits: [hit], resultIndex: .constant(nil), onLeaveToField: {}, workspaceOpening: opening)
            .environment(\.modelContext, fixture.context)
        let menu = SystemPageHost.window(content, container: fixture.data.container, scheme: .light, locale: "en",
                                         size: NSSize(width: 440, height: 280), prefs: fixture.prefs)
        defer { SystemPageHost.release(menu) }
        try await NativeSyntaxUI.prepareFocus(in: menu)
        try await SystemPageHost.settle(menu)
        let nodes = SettingsButtonTestSupport.elements(menu.contentView)
        let button = try #require(nodes.first {
            SettingsButtonTestSupport.value($0, "accessibilityRole") as? String == "AXButton"
                && String(describing: SettingsButtonTestSupport.value($0, "accessibilityLabel") ?? "").contains(hit.title)
        })
        try await SettingsButtonTestSupport.click(button, in: menu)
        try await fixture.settle()
        #expect(shows == 1)
        #expect(fixture.navigation.selectedTab == .calendar)
        #expect(fixture.navigation.selectedTaskID == objectID && fixture.navigation.inspectingDayKey == fixture.day)
        #expect(fixture.navigation.isInspectorPresented && fixture.navigation.canInspectSelectedTask)
        #expect(SettingsButtonTestSupport.elements(fixture.window?.contentView).contains {
            guard let editor = $0 as? NSTextView else { return false }
            return !editor.isFieldEditor && editor.isEditable
        })
        #expect(fixture.saves == 0 && !fixture.context.hasChanges)
    }
}
