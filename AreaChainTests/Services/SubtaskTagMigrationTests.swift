import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct SubtaskTagMigrationTests {
    @Test func existingDiskStoreUpgradesWithoutLosingContentsAndBackupRemainsReadable() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AreaChain-migration-" + UUID().uuidString)
        let working = root.appendingPathComponent("working")
        let backup = root.appendingPathComponent("backup")
        try FileManager.default.createDirectory(at: working, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let parentID = UUID()
        let childID = UUID()
        let legacyProjectID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let storeURL = working.appendingPathComponent("fixture.store")
        try autoreleasepool {
            try writeLegacyStore(at: storeURL, parentID: parentID, childID: childID, projectID: legacyProjectID)
        }
        // 复制整个已关闭的临时库目录，包含 SQLite sidecar；不接触用户的真实存储。
        try FileManager.default.copyItem(at: working, to: backup)

        try autoreleasepool {
            let schema = Schema(AreaChainSchema.models)
            let configuration = ModelConfiguration("Fixture", schema: schema, url: storeURL, cloudKitDatabase: .none)
            let store = try ModelContainer(for: schema, configurations: configuration)
            let context = store.mainContext
            let parent = try #require(context.fetch(FetchDescriptor<AreaChain.TodoItem>()).first)
            let child = try #require(context.fetch(FetchDescriptor<AreaChain.SubtaskItem>()).first)
            #expect(parent.id == parentID && parent.title == "升级前任务")
            #expect(parent.notes == "原始备注" && parent.remindMinutes == 900)
            #expect(child.id == childID && child.todo?.id == parentID)
            #expect(child.title == "升级前子任务" && child.isDone && child.tagIDs.isEmpty)
            let tags = try context.fetch(FetchDescriptor<TagItem>())
            #expect(!tags.contains { $0.id == legacyProjectID || $0.name == "旧项目" })
            #expect(try context.fetchCount(FetchDescriptor<DiaryEntry>()) == 1)
            #expect(try context.fetchCount(FetchDescriptor<DailyRoutine>()) == 1)
            try SwiftDataTaskRepository(container: store).editSubtask(id: child.id, title: "升级后子任务 #今日")
            #expect(TagIDList.parse(child.tagIDs).count == 1)
            #expect(parent.tagIDs.isEmpty)
        }

        try autoreleasepool {
            let schema = legacySchema()
            let configuration = ModelConfiguration(
                "Fixture", schema: schema, url: backup.appendingPathComponent("fixture.store"), cloudKitDatabase: .none
            )
            let store = try ModelContainer(for: schema, configurations: configuration)
            let child = try #require(store.mainContext.fetch(FetchDescriptor<LegacyInputStore.SubtaskItem>()).first)
            #expect(child.id == childID && child.title == "升级前子任务")
        }
    }

    private func legacySchema() -> Schema {
        Schema([
            LegacyInputStore.TodoItem.self, LegacyInputStore.SubtaskItem.self,
            DailyRoutine.self, RoutineCheck.self, DiaryEntry.self, TagItem.self, AttachmentItem.self
        ])
    }

    private func writeLegacyStore(at url: URL, parentID: UUID, childID: UUID, projectID: UUID) throws {
        let schema = legacySchema()
        let configuration = ModelConfiguration("Fixture", schema: schema, url: url, cloudKitDatabase: .none)
        let store = try ModelContainer(for: schema, configurations: configuration)
        let parent = LegacyInputStore.TodoItem(id: parentID)
        parent.projectID = projectID
        let child = LegacyInputStore.SubtaskItem(id: childID, todo: parent)
        store.mainContext.insert(parent)
        store.mainContext.insert(child)
        store.mainContext.insert(DiaryEntry(text: "升级前手记", dayKey: "2026-09-13"))
        store.mainContext.insert(DailyRoutine(title: "升级前习惯", sortOrder: 0))
        try store.mainContext.save()
    }
}

/// 仅冻结此次升级前发生变化的两个实体；其余六个实体仍使用未改动的生产模型。
private enum LegacyInputStore {
    @Model
    final class TodoItem {
        var id: UUID
        var title: String
        var isDone: Bool
        var dayKey: String
        var createdAt: Date
        var remindMinutes: Int?
        var deletedAt: Date?
        var projectID: UUID?
        var tagIDs: String = ""
        var isImportant: Bool = false
        var isUrgent: Bool = false
        var sourceBundleID: String = ""
        var calendarEventID: String = ""
        var notes: String = ""
        @Relationship(deleteRule: .cascade, inverse: \SubtaskItem.todo)
        var subtasks: [SubtaskItem]

        init(id: UUID) {
            self.id = id
            title = "升级前任务"
            isDone = false
            dayKey = "2026-09-13"
            createdAt = Date(timeIntervalSince1970: 100)
            remindMinutes = 900
            notes = "原始备注"
            subtasks = []
        }
    }

    @Model
    final class SubtaskItem {
        var id: UUID
        var title: String
        var isDone: Bool
        var sortOrder: Int
        var createdAt: Date
        var deletedAt: Date?
        var todo: TodoItem?

        init(id: UUID, todo: TodoItem) {
            self.id = id
            title = "升级前子任务"
            isDone = true
            sortOrder = 0
            createdAt = Date(timeIntervalSince1970: 100)
            self.todo = todo
        }
    }
}
