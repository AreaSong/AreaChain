import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized, .enabled(if: MonthGridDropTestSupport.enabled)) @MainActor
struct CalendarMonthGridDropTests {
    @Test(arguments: [false, true])
    func productionPageDropUsesOriginalTransaction(fails: Bool) async throws {
        let fixture = try CalendarSpanTestSupport(day: "2026-08-19")
        defer { fixture.close() }
        let repository = MonthGridMoveRepository(fixture.context)
        repository.fails = fails
        let previous = DayBoardMutations.taskRepositoryProvider
        let failures = MutationFeedback.shared.failureCount
        defer {
            DayBoardMutations.taskRepositoryProvider = previous
        }
        DayBoardMutations.taskRepositoryProvider = { _ in repository }
        try await fixture.prepare()
        let target = try fixture.node("daybook.date.2026-08-18")
        #expect(MonthGridTestSupport.belongsToGrid(target))
        let todo = fixture.todos[0]
        try await MonthGridDropTestSupport.drop([TodoDragToken.encode(todo.id)], onto: target, in: fixture.window)
        #expect(repository.calls.count == 1)
        #expect(repository.calls.first?.0 == todo.id && repository.calls.first?.1 == "2026-08-18")
        let expected = fails ? "2026-08-19" : "2026-08-18"
        #expect(todo.dayKey == expected && fixture.selectedKey == expected)
        #expect(MutationFeedback.shared.failureCount == failures + (fails ? 1 : 0))
        let persisted = try ModelContext(fixture.fixture.container).fetch(FetchDescriptor<TodoItem>())
        #expect(persisted.first { $0.id == todo.id }?.dayKey == expected)
        #expect(!fixture.context.hasChanges)
        #expect(Array(fixture.todos.dropFirst()).map(\.snapshot) == Array(fixture.originalTodos.dropFirst()))
        if fails { try fixture.assertUnchanged() }
        let visibleTarget = try fixture.node("daybook.date.2026-08-18")
        for value in [TodoDragToken.encodeRoutine(todo.id), TodoDragToken.encode(UUID()), "invalid"] {
            try await MonthGridDropTestSupport.drop([value], onto: visibleTarget, in: fixture.window)
        }
        #expect(repository.calls.count == 1 && fixture.selectedKey == expected)
    }

    @Test func registeredNativeDestinationDecodesOnlyTodoAndKeepsSelection() async throws {
        let fixture = try SettingsButtonTestSupport()
        defer { fixture.cleanup() }
        let probe = MonthGridProbe()
        let window = fixture.window(MonthGridProbeView(probe: probe), size: NSSize(width: 360, height: 500))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let id = UUID(), other = UUID()
        let day = try MonthGridTestSupport.day("2026-08-18", in: window)
        try await MonthGridDropTestSupport.drop(["invalid", TodoDragToken.encode(id), TodoDragToken.encode(other)],
                                            onto: day, in: window, snapshot: "monthB-drop-today")
        #expect(probe.drops.count == 1)
        #expect(probe.drops.first?.0 == id && probe.drops.first?.1 == "2026-08-18")
        #expect(probe.selections.isEmpty && probe.dates.selectedKey == "2026-08-19")
        for input in ["invalid", id.uuidString, "areachain-todo:broken", TodoDragToken.encodeRoutine(id)] {
            try await MonthGridDropTestSupport.drop([input], onto: day, in: window)
        }
        #expect(probe.drops.count == 1 && probe.selections.isEmpty)
        probe.allowsDrop = false
        try await SystemPageHost.settle(window)
        try await MonthGridDropTestSupport.drop([TodoDragToken.encode(id)], onto: day, in: window)
        #expect(probe.drops.count == 1)
    }
}
