import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct PrivacyMigrationTests {
    private let sentinel = "LEGACY_PRIVATE_STORAGE_SENTINEL_3749"

    @Test func realLegacySchemaUpgradesAndColdRebuildRemovesPlaintext() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "AreaChain-private-migration-\(UUID())")
        let images = root.appending(path: "images")
        try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "fixture.store")
        let tagID = UUID(), diaryID = UUID(), imageID = UUID()
        try autoreleasepool { try writeLegacy(at: url, tagID: tagID, diaryID: diaryID, imageID: imageID) }
        let imageBytes = Data("LEGACY_PRIVATE_IMAGE_SENTINEL".utf8)
        try imageBytes.write(to: images.appending(path: imageID.uuidString))
        let config = FileVaultConfigurationStore(url: root.appending(path: "vault.json"))
        let vault = PrivacyVault(store: config, systemKeys: FakeSystemVaultKeys())
        try await vault.create(password: "migration-master-password", systemUnlock: false)
        let files = AttachmentStore(keys: vault.keys)
        try autoreleasepool {
            let container = try openCurrent(url)
            let context = container.mainContext
            let note = try #require(try context.fetch(FetchDescriptor<AreaChain.DiaryEntry>()).first)
            #expect(note.id == diaryID && note.text == sentinel && !note.hasProtectedContent)
            let tag = try #require(try context.fetch(FetchDescriptor<AreaChain.TagItem>()).first)
            #expect(tag.id == tagID && !tag.isPrivateDiary)
            let capture = try PrivateBackupCapture.capture(context: context, vault: vault, additionalPrivateTags: [tagID])
            let backup = try PrivateBackupFile.write(capture, password: "migration-backup-password",
                                                     to: root.appending(path: "migration.areachainbackup")) {
                try files.read(reference: $0, root: images)
            }
            let environment = PrivacyPersistence(context: context, vault: vault, attachments: files, root: images)
            try DiaryProtection.applyTags([tagID], in: environment, backup: backup)
            #expect(note.text.isEmpty && note.hasProtectedContent)
            #expect(PrivacyStoreMaintenance.isPending(context))
            #expect(!FileManager.default.fileExists(atPath: images.appending(path: imageID.uuidString).path))
        }
        // 此时没有活跃 ModelContainer，模拟下次启动打开库之前的清理步骤。
        try PrivacyStoreMaintenance.finish(at: url)
        #expect(!FileManager.default.fileExists(atPath: PrivacyStoreMaintenance.marker(for: url).path))
        for suffix in ["", "-wal", "-shm"] {
            let path = URL(fileURLWithPath: url.path + suffix)
            if FileManager.default.fileExists(atPath: path.path) {
                #expect(try Data(contentsOf: path).range(of: Data(sentinel.utf8)) == nil)
            }
        }
        vault.lock()
        let reopened = PrivacyVault(store: config, systemKeys: FakeSystemVaultKeys())
        #expect(!reopened.isUnlocked)
        try await reopened.unlockWithPassword("migration-master-password")
        try autoreleasepool {
            let container = try openCurrent(url)
            let note = try #require(try container.mainContext.fetch(FetchDescriptor<AreaChain.DiaryEntry>()).first)
            let image = try #require(try container.mainContext.fetch(FetchDescriptor<AreaChain.AttachmentItem>()).first)
            #expect(try DiaryContent.read(note, vault: reopened) == sentinel)
            #expect(note.tagIDs == tagID.uuidString && note.isPinned)
            #expect(try AttachmentStore(keys: reopened.keys).read(reference: image.reference, root: images) == imageBytes)
            #expect(try container.mainContext.fetchCount(FetchDescriptor<TodoItem>()) == 1)
            #expect(try container.mainContext.fetchCount(FetchDescriptor<DailyRoutine>()) == 1)
        }
    }

    private func openCurrent(_ url: URL) throws -> ModelContainer {
        let schema = Schema(AreaChainSchema.models)
        return try ModelContainer(for: schema, configurations:
            ModelConfiguration("PrivateFixture", schema: schema, url: url, cloudKitDatabase: .none))
    }

    private func writeLegacy(at url: URL, tagID: UUID, diaryID: UUID, imageID: UUID) throws {
        let schema = Schema([
            TodoItem.self, SubtaskItem.self, DailyRoutine.self, RoutineCheck.self,
            LegacyPrivacyStore.DiaryEntry.self, LegacyPrivacyStore.TagItem.self, LegacyPrivacyStore.AttachmentItem.self
        ])
        let container = try ModelContainer(for: schema, configurations:
            ModelConfiguration("PrivateFixture", schema: schema, url: url, cloudKitDatabase: .none))
        let context = container.mainContext
        context.insert(LegacyPrivacyStore.TagItem(id: tagID))
        context.insert(LegacyPrivacyStore.DiaryEntry(id: diaryID, text: sentinel, tagID: tagID))
        context.insert(LegacyPrivacyStore.AttachmentItem(id: imageID, ownerID: diaryID))
        context.insert(TodoItem(title: "保留普通任务", dayKey: "2026-09-15"))
        context.insert(DailyRoutine(title: "保留普通习惯", sortOrder: 0))
        try context.save()
    }
}

/// 冻结真正的升级前实体，不能用已经新增密文字段的生产类型充当“旧库”。
private enum LegacyPrivacyStore {
    @Model final class DiaryEntry {
        var id: UUID
        var text: String
        var dayKey: String
        var createdAt: Date
        var deletedAt: Date?
        var tagIDs: String = ""
        var isPinned: Bool = false

        init(id: UUID, text: String, tagID: UUID) {
            self.id = id
            self.text = text
            dayKey = "2026-09-15"
            createdAt = Date(timeIntervalSince1970: 100)
            tagIDs = tagID.uuidString
            isPinned = true
        }
    }

    @Model final class TagItem {
        var id: UUID
        var name: String
        var sortOrder: Int
        var deletedAt: Date?

        init(id: UUID) { self.id = id; name = "密码"; sortOrder = 0 }
    }

    @Model final class AttachmentItem {
        var id: UUID
        var ownerKind: String
        var ownerID: UUID
        var filename: String
        var createdAt: Date
        var deletedAt: Date?

        init(id: UUID, ownerID: UUID) {
            self.id = id
            ownerKind = "diary"
            self.ownerID = ownerID
            filename = "legacy.png"
            createdAt = Date(timeIntervalSince1970: 100)
        }
    }
}
