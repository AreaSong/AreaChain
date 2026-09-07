import Foundation
import SwiftData
import Testing
@testable import AreaChain

struct SyncPortTests {
    @Test func encodeAndDecodeRoundTrip() throws {
        let snapshot = ExportSnapshot(
            exportedAt: Date(timeIntervalSince1970: 1_788_800_000),
            routines: [
                ExportedRoutine(
                    id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                    title: "写日报",
                    sortOrder: 0,
                    isEnabled: true,
                    createdDayKey: "2026-09-01"
                )
            ],
            checks: [],
            todos: [
                ExportedTodo(
                    id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
                    title: "修角标",
                    isDone: false,
                    dayKey: "2026-09-07",
                    createdAt: Date(timeIntervalSince1970: 1_788_800_100)
                )
            ],
            diaries: []
        )
        let data = try SyncPort.encode(snapshot)
        let decoded = try SyncPort.decode(data)
        #expect(decoded == snapshot)
    }

    @Test func decodeCheckWithoutSkippedDefaultsFalse() throws {
        let json = """
        {
          "exportedAt": "2026-09-07T00:00:00Z",
          "routines": [],
          "checks": [
            {
              "id": "cccccccc-cccc-cccc-cccc-cccccccccccc",
              "routineId": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
              "dayKey": "2026-09-07",
              "isDone": true
            }
          ],
          "todos": [],
          "diaries": []
        }
        """
        let decoded = try SyncPort.decode(Data(json.utf8))
        #expect(decoded.checks.first?.isSkipped == false)
        #expect(decoded.checks.first?.isDone == true)
    }
}

struct FirstLaunchSeederTests {
    @Test func seedsOnlyWhenEmptyAndNeverSeeded() {
        #expect(FirstLaunchSeeder.shouldSeed(existingCount: 0, alreadySeeded: false))
        #expect(!FirstLaunchSeeder.shouldSeed(existingCount: 2, alreadySeeded: false))
        #expect(!FirstLaunchSeeder.shouldSeed(existingCount: 0, alreadySeeded: true))
    }
}

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
