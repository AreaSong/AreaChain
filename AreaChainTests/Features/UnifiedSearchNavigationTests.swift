import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchNavigationTests {
    @Test func allSixteenMappingsAndUnassembledRejection() throws {
        let ids = ["dashboard", "today", "pending", "allItems", "calendar", "quadrant", "gantt", "diaries",
                   "images", "clipboard", "tags", "privacy", "backup", "trash", "settings", "shortcuts"]
        let tabs: [WorkspaceTab] = [.dashboard, .today, .pending, .allItems, .calendar, .quadrant, .gantt, .diary,
                                   .attachments, .clipboard, .tags, .privacy, .dataBackup, .trash, .settings, .shortcuts]
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        for (id, tab) in zip(ids, tabs) {
            #expect(WorkspaceNavigationDestination.page(command: .init(rawValue: "go." + id)) == tab)
            let command = try #require(CommandCatalog.standard.command(id: .init(rawValue: "go." + id)))
            _ = fixture.controller.navigationInput(command.path)
            fixture.controller.executeNavigation(source: fixture.controller.buffer)
            #expect(fixture.controller.navigationMessage == "unified.navigation.unassembled")
            #expect(try fixture.handoff.state().operations.active == nil)
        }
        #expect(WorkspaceNavigationDestination.page(command: .init(rawValue: "go.tagList")) == nil)
    }

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
        let commands = CommandCatalog.standard.entries.filter {
            WorkspaceNavigationDestination.page(command: $0.id) != nil
        }
        for command in commands {
            try await fixture.go(command.path)
            #expect(fixture.router.outcome == .displayed, "真实页面：\(command.id.rawValue)")
            #expect(!fixture.context.hasChanges)
        }
        #expect(commands.count == 16)
        #expect(fixture.saves == 0 && fixture.publications == 0)
        #expect(try fixture.context.fetchCount(FetchDescriptor<TagItem>()) == 0)
        #expect(try fixture.context.fetchCount(FetchDescriptor<RoutineCheck>()) == 0)
        #expect(try fixture.handoff.state().plan.items.isEmpty)
        #expect(try fixture.handoff.state().execution == nil)
    }
}
