import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized, .tags(.backgroundWindow)) @MainActor struct UnifiedSearchNavigationTests {
    @Test func unassembledRejection() async throws {
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        for tab in WorkspaceTab.allCases {
            await fixture.controller.navigate(.page(tab), source: fixture.controller.buffer)
            #expect(fixture.controller.navigationMessage == "unified.navigation.unassembled")
        }
    }

    @Test func realTaskAndChildIdentityAndStaleReturn() async throws {
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        try await fixture.start()
        let child = CommandObjectReference(type: .subtask, id: fixture.child.id)
        try await fixture.open(.init(type: .todo, id: fixture.todo.id))
        #expect(fixture.router.outcome == .displayed)
        #expect(fixture.navigation.selectedTaskID == fixture.todo.id)
        #expect(fixture.navigation.inspectingDayKey == fixture.todo.dayKey)
        try await fixture.snapshot("todo")
        try await fixture.back()
        let page = try fixture.session.presentation().pagination
        fixture.controller.browse(.init(version: page.snapshot.version, action: .activate(child)), source: fixture.controller.buffer)
        try await fixture.go("/inspector/open")
        #expect(fixture.router.outcome == .displayed)
        #expect(fixture.navigation.navigationObject?.object == child)
        #expect(fixture.navigation.navigationObject?.parent?.id == fixture.todo.id)
        #expect(fixture.router.mounted("object." + fixture.child.id.uuidString))
        try await fixture.snapshot("subtask")
        let reads = fixture.reads
        fixture.todo.title = "needle changed"
        try fixture.session.modelDidChange(expecting: fixture.controller.buffer.lease.ownership)
        try await fixture.back()
        #expect(fixture.reads == reads + 1)
        #expect(try fixture.session.presentation().pagination.browse.active == child)
        #expect(fixture.todo.title == "needle changed")
    }

    @Test func occurrenceKeepsExplicitDayAndDoesNotCreateCheck() async throws {
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        try await fixture.start()
        try fixture.session.modelDidChange(expecting: fixture.controller.buffer.lease.ownership)
        try fixture.handoff.send(.query(.setInput("date:2026-10-07")))
        try fixture.handoff.send(.query(.addCondition(.scope(.routineOccurrences))))
        _ = fixture.controller.publishOperation(text: "date:2026-10-07")
        _ = try await fixture.read()
        let object = CommandObjectReference(type: .routineOccurrence, id: fixture.routine.id, dayKey: fixture.day)
        try await fixture.open(object)
        #expect(fixture.router.outcome == .displayed)
        #expect(fixture.navigation.navigationObject?.object == object)
        #expect(fixture.navigation.inspectingDayKey == fixture.day)
        #expect(try fixture.context.fetchCount(FetchDescriptor<RoutineCheck>()) == 0)
        #expect(!fixture.context.hasChanges)
        try await fixture.snapshot("occurrence")
        try await fixture.back()
    }

    @Test func continuousNavigationNewQueryAndLockRevokeTicket() async throws {
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        try await fixture.start()
        try await fixture.go("/go/settings")
        let ticket = try #require(fixture.controller.returnSearch)
        try await fixture.go("/go/calendar")
        #expect(fixture.controller.returnSearch?.id == ticket.id)
        try await fixture.enter("new query")
        #expect(fixture.controller.returnSearch == nil)
        await fixture.controller.returnToSearch(ticket.id)
        #expect(fixture.controller.buffer.text == "new query")
        try await fixture.go("/go/settings")
        let locked = try #require(fixture.controller.returnSearch)
        fixture.vault.lock()
        await fixture.controller.returnToSearch(locked.id)
        #expect(fixture.controller.returnSearch == nil)
        #expect(fixture.controller.buffer.text.isEmpty)
        #expect(!fixture.session.hasRetainedPresentation)
        #expect(fixture.navigation.navigationObject == nil)
    }

    @Test func allRealPagesHaveZeroInitializationWrites() async throws {
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        try await fixture.start()
        let paths = ["/go/dashboard", "/go/today", "/go/pending", "/go/all", "/go/calendar", "/go/quadrant",
                     "/go/gantt", "/go/diaries", "/go/images", "/go/clipboard", "/go/tags", "/go/privacy",
                     "/go/backup", "/go/trash", "/go/settings", "/go/shortcuts"]
        for path in paths {
            try await fixture.go(path)
            #expect(fixture.router.outcome == .displayed, "真实页面：\(path)")
            #expect(!fixture.context.hasChanges)
        }
        #expect(paths.count == 16)
        #expect(fixture.saves == 0 && fixture.publications == 0)
        #expect(try fixture.context.fetchCount(FetchDescriptor<TagItem>()) == 0)
        #expect(try fixture.context.fetchCount(FetchDescriptor<RoutineCheck>()) == 0)
    }
}

/// 需要真实点击（前台 key window），与后台轮的 UnifiedSearchNavigationTests 分开，留在前台轮。
@Suite(.serialized) @MainActor struct UnifiedSearchNavigationClickTests {
    @Test(arguments: [0, 1, 2, 3]) func settingsDateAndReturnUseRealWorkspace(_ style: Int) async throws {
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        try await fixture.start(style: style)
        let original = try fixture.handoff.state().query
        let version = try fixture.session.presentation().pagination.snapshot.version
        let reads = fixture.reads
        try await fixture.go("/go/settings")
        #expect(fixture.router.outcome == .displayed)
        #expect(fixture.router.mounted("page.settings"))
        #expect(!fixture.navigation.isSearching)
        #expect(try fixture.handoff.state().query == original)
        #expect(SettingsButtonTestSupport.elements(fixture.window?.contentView).contains {
            SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String == "settings.preferences"
        })
        try await fixture.snapshot("settings-\(style)")
        try await fixture.click("unified.navigation.return")
        #expect(fixture.navigation.isSearching)
        #expect(fixture.controller.buffer.text == "needle")
        #expect(try fixture.session.presentation().pagination.snapshot.version == version)
        #expect(fixture.reads == reads)
        try await fixture.go("/inspector/day/2026-10-07")
        #expect(fixture.router.outcome == .displayed)
        #expect(fixture.router.mounted("page.calendar"))
        #expect(fixture.navigation.inspectingDayKey == fixture.day)
        try await fixture.snapshot("date-\(style)")
        try await fixture.back()
        #expect(try fixture.handoff.state().query == original)
        #expect(!fixture.context.hasChanges)
        #expect(try fixture.context.fetchCount(FetchDescriptor<RoutineCheck>()) == 0)
    }
}
