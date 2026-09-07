import Foundation
import SwiftData
import Testing
@testable import AreaChain

struct SnapshotImporterTests {
    @Test func upsertTodoByID() throws {
        let schema = Schema([DailyRoutine.self, RoutineCheck.self, TodoItem.self, DiaryEntry.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let id = UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!
        context.insert(TodoItem(id: id, title: "旧", dayKey: "2026-09-06"))
        try context.save()

        let snapshot = ExportSnapshot(
            exportedAt: Date(timeIntervalSince1970: 1),
            routines: [],
            checks: [],
            todos: [
                ExportedTodo(
                    id: id,
                    title: "新",
                    isDone: true,
                    dayKey: "2026-09-07",
                    createdAt: Date(timeIntervalSince1970: 2)
                )
            ],
            diaries: []
        )
        try SnapshotImporter.apply(snapshot, context: context)
        let todos = try context.fetch(FetchDescriptor<TodoItem>())
        #expect(todos.count == 1)
        #expect(todos.first?.title == "新")
        #expect(todos.first?.dayKey == "2026-09-07")
        #expect(todos.first?.isDone == true)
    }
}
