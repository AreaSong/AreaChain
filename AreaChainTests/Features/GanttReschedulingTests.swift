import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct GanttReschedulingTests {
    @Test func multipleDatesAreSavedAndNotifiedAsOneOperation() throws {
        let (container, todos) = try fixture()
        let context = container.mainContext
        var saves = 0
        var notifications = 0
        let observer = NotificationCenter.default.addObserver(forName: .boardDidChange, object: nil, queue: .main) { _ in
            notifications += 1
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        #expect(GanttRescheduling.commit(moves(todos), todos: todos, context: context) {
            saves += 1
            try $0.save()
        })
        #expect(saves == 1)
        #expect(notifications == 1)
        #expect(todos.map(\.dayKey) == ["2026-09-12", "2026-09-16", "2026-09-20"])
        let saved = try ModelContext(container).fetch(FetchDescriptor<TodoItem>())
        #expect(saved.first { $0.id == todos[0].id }?.dayKey == "2026-09-12")
        #expect(saved.first { $0.id == todos[1].id }?.dayKey == "2026-09-16")
    }

    @Test func failedSaveRestoresEveryDateAndPublishesNoChange() throws {
        let (container, todos) = try fixture()
        let context = container.mainContext
        var notifications = 0
        let observer = NotificationCenter.default.addObserver(forName: .boardDidChange, object: nil, queue: .main) { _ in
            notifications += 1
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        let failures = MutationFeedback.shared.failureCount
        #expect(!GanttRescheduling.commit(moves(todos), todos: todos, context: context) { _ in
            throw CocoaError(.fileWriteNoPermission)
        })
        #expect(todos.map(\.dayKey) == ["2026-09-10", "2026-09-14", "2026-09-20"])
        #expect(!context.hasChanges)
        #expect(notifications == 0)
        #expect(MutationFeedback.shared.failureCount == failures + 1)
    }

    @Test(arguments: ["moved", "done", "deleted", "missing"])
    func staleDragNeverPartiallyReschedulesOtherTasks(change: String) throws {
        let (container, todos) = try fixture()
        let pending = moves(todos)
        switch change {
        case "moved": todos[1].dayKey = "2026-09-18"
        case "done": todos[1].isDone = true
        case "deleted": todos[1].deletedAt = .now
        default: break
        }
        try container.mainContext.save()
        let current = change == "missing" ? [todos[0], todos[2]] : todos
        #expect(!GanttRescheduling.commit(pending, todos: current, context: container.mainContext))
        #expect(todos[0].dayKey == "2026-09-10")
        #expect(todos[1].dayKey == (change == "moved" ? "2026-09-18" : "2026-09-14"))
        #expect(!container.mainContext.hasChanges)
    }

    @Test func zeroOffsetDoesNotSaveOrNotify() throws {
        let (container, todos) = try fixture()
        var saves = 0
        #expect(GanttRescheduling.commit([], todos: todos, context: container.mainContext) { _ in saves += 1 })
        #expect(saves == 0)
    }

    private func fixture() throws -> (ModelContainer, [TodoItem]) {
        let container = try ModelContainer(
            for: Schema(AreaChainSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let todos = ["2026-09-10", "2026-09-14", "2026-09-20"].map { TodoItem(title: "测试安排", dayKey: $0) }
        todos.forEach { container.mainContext.insert($0) }
        try container.mainContext.save()
        return (container, todos)
    }

    private func moves(_ todos: [TodoItem]) -> [GanttTodoMove] {
        zip(todos.prefix(2), ["2026-09-12", "2026-09-16"]).map {
            GanttTodoMove(id: $0.0.id, originalDay: $0.0.dayKey, destinationDay: $0.1)
        }
    }
}
