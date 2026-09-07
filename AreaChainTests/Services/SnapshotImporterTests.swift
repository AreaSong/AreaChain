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
        #expect(todos.first?.remindMinutes == nil)
    }

    @Test func upsertRoutineRemindMinutes() throws {
        let schema = Schema([DailyRoutine.self, RoutineCheck.self, TodoItem.self, DiaryEntry.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let id = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        context.insert(DailyRoutine(id: id, title: "旧", sortOrder: 0, createdDayKey: "2026-09-01"))
        try context.save()

        let snapshot = ExportSnapshot(
            exportedAt: Date(timeIntervalSince1970: 1),
            routines: [
                ExportedRoutine(
                    id: id,
                    title: "新",
                    sortOrder: 2,
                    isEnabled: true,
                    createdDayKey: "2026-09-01",
                    createdAt: Date(timeIntervalSince1970: 9),
                    remindMinutes: 8 * 60
                )
            ],
            checks: [],
            todos: [],
            diaries: []
        )
        try SnapshotImporter.apply(snapshot, context: context)
        let routines = try context.fetch(FetchDescriptor<DailyRoutine>())
        #expect(routines.count == 1)
        #expect(routines.first?.title == "新")
        #expect(routines.first?.remindMinutes == 480)
        #expect(routines.first?.createdAt == Date(timeIntervalSince1970: 9))
        #expect(routines.first?.deletedAt == nil)
    }

    @Test func upsertPreservesDeletedAt() throws {
        let schema = Schema([DailyRoutine.self, RoutineCheck.self, TodoItem.self, DiaryEntry.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let id = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
        context.insert(TodoItem(id: id, title: "旧", dayKey: "2026-09-07"))
        try context.save()

        let deletedAt = Date(timeIntervalSince1970: 9)
        let snapshot = ExportSnapshot(
            exportedAt: Date(timeIntervalSince1970: 1),
            routines: [],
            checks: [],
            todos: [
                ExportedTodo(
                    id: id,
                    title: "旧",
                    isDone: false,
                    dayKey: "2026-09-07",
                    createdAt: Date(timeIntervalSince1970: 2),
                    deletedAt: deletedAt
                )
            ],
            diaries: []
        )
        try SnapshotImporter.apply(snapshot, context: context)
        let todos = try context.fetch(FetchDescriptor<TodoItem>())
        #expect(todos.first?.deletedAt == deletedAt)
        #expect(
            DayBoardLogic.openTodos(
                todos: todos.map(\.snapshot),
                dayKey: "2026-09-07"
            ).isEmpty
        )
    }
}
