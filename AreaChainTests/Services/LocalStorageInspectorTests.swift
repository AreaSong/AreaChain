import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor
struct LocalStorageInspectorTests {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeTempPaths() throws -> LocalStoragePaths {
        let base = FileManager.default.temporaryDirectory
            .appending(path: "LocalStorageInspectorTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let paths = LocalStoragePaths(
            supportRoot: base,
            attachmentsRoot: base.appending(path: "attachments", directoryHint: .isDirectory),
            clipboardRoot: base.appending(path: "clipboard", directoryHint: .isDirectory)
        )
        try FileManager.default.createDirectory(at: paths.supportRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: paths.attachmentsRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: paths.clipboardRoot, withIntermediateDirectories: true)
        return paths
    }

    @Test func byteFormatSplitsAcrossUnitsCleanly() {
        #expect(StorageByteFormat.split(0) == StorageByteFormat.Parts(number: "0", unit: "KB"))
        #expect(StorageByteFormat.split(512) == StorageByteFormat.Parts(number: "512", unit: "B"))
        #expect(StorageByteFormat.split(2048) == StorageByteFormat.Parts(number: "2.0", unit: "KB"))
        #expect(StorageByteFormat.split(150 * 1024) == StorageByteFormat.Parts(number: "150", unit: "KB"))
        #expect(StorageByteFormat.split(3_670_016) == StorageByteFormat.Parts(number: "3.50", unit: "MB"))
        #expect(StorageByteFormat.split(2_147_483_648) == StorageByteFormat.Parts(number: "2.00", unit: "GB"))
    }

    @Test func inspectSeparatesActiveAttachmentsCacheTrashAndDatabaseBytes() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let paths = try makeTempPaths()
        defer { try? FileManager.default.removeItem(at: paths.supportRoot) }

        let liveAttachmentID = UUID()
        let trashAttachmentID = UUID()
        let unlinkedFileID = UUID()

        try Data(repeating: 0x11, count: 1200)
            .write(to: paths.attachmentsRoot.appending(path: liveAttachmentID.uuidString))
        try Data(repeating: 0x22, count: 800)
            .write(to: paths.attachmentsRoot.appending(path: trashAttachmentID.uuidString))
        try Data(repeating: 0x33, count: 500)
            .write(to: paths.attachmentsRoot.appending(path: unlinkedFileID.uuidString))

        let liveTodo = TodoItem(title: "在用任务", dayKey: "2026-10-13")
        let trashTodo = TodoItem(title: "已删除任务", dayKey: "2026-10-13", deletedAt: .now)
        let liveAtt = AttachmentItem(
            id: liveAttachmentID, ownerKind: AttachmentOwner.todo.rawValue,
            ownerID: liveTodo.id, filename: "live.png"
        )
        let trashAtt = AttachmentItem(
            id: trashAttachmentID, ownerKind: AttachmentOwner.todo.rawValue,
            ownerID: trashTodo.id, filename: "trash.png", deletedAt: .now
        )
        context.insert(liveTodo)
        context.insert(trashTodo)
        context.insert(liveAtt)
        context.insert(trashAtt)
        try context.save()

        try Data(repeating: 0x44, count: 300)
            .write(to: paths.clipboardRoot.appending(path: "orphan.png"))
        try Data(repeating: 0x55, count: 100)
            .write(to: paths.clipboardRoot.appending(path: "history.json.tmp"))
        try Data(repeating: 0x66, count: 4096)
            .write(to: paths.supportRoot.appending(path: "areachain.store"))
        try Data(repeating: 0x77, count: 1024)
            .write(to: paths.supportRoot.appending(path: "areachain.store-wal"))

        let snapshot = LocalStorageInspector.inspect(context: context, paths: paths)

        #expect(snapshot.attachmentsBytes == 1700)
        #expect(snapshot.attachmentsCount == 2)
        #expect(snapshot.cacheAndCleanableBytes == 1200)
        #expect(snapshot.reclaimableBytes == 1200)
        #expect(snapshot.databaseAndOtherBytes == 5120)
        #expect(snapshot.appTotalBytes == 8020)
        #expect(snapshot.trashItemCount == 2)
        #expect(snapshot.orphanClipboardCount == 2)
        #expect(snapshot.hasCleanableItems)
    }

    @Test func cleanReclaimableDataRemovesOrphanCacheAndTrashWhilePreservingLiveFiles() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let paths = try makeTempPaths()
        defer { try? FileManager.default.removeItem(at: paths.supportRoot) }

        let liveID = UUID()
        let trashID = UUID()
        let liveFileURL = paths.attachmentsRoot.appending(path: liveID.uuidString)
        let trashFileURL = paths.attachmentsRoot.appending(path: trashID.uuidString)
        try Data(repeating: 0xAA, count: 1024).write(to: liveFileURL)
        try Data(repeating: 0xBB, count: 2048).write(to: trashFileURL)

        let orphanClipURL = paths.clipboardRoot.appending(path: "orphan.png")
        let tempClipURL = paths.clipboardRoot.appending(path: "clipboard.tmp")
        try Data(repeating: 0xCC, count: 512).write(to: orphanClipURL)
        try Data(repeating: 0xDD, count: 256).write(to: tempClipURL)

        let liveTodo = TodoItem(title: "保留", dayKey: "2026-10-13")
        let trashedDiary = DiaryEntry(text: "待清理手记", dayKey: "2026-10-13", deletedAt: .now)
        let liveAtt = AttachmentItem(
            id: liveID, ownerKind: AttachmentOwner.todo.rawValue,
            ownerID: liveTodo.id, filename: "keep.png"
        )
        let trashAtt = AttachmentItem(
            id: trashID, ownerKind: AttachmentOwner.diary.rawValue,
            ownerID: trashedDiary.id, filename: "drop.png", deletedAt: .now
        )
        context.insert(liveTodo)
        context.insert(trashedDiary)
        context.insert(liveAtt)
        context.insert(trashAtt)
        try context.save()

        let result = try LocalStorageInspector.cleanReclaimableData(context: context, paths: paths)

        #expect(result.removedOrphanFiles == 2)
        #expect(result.purgedTrashItems == 2)
        #expect(result.freedBytes == 2816)
        #expect(FileManager.default.fileExists(atPath: liveFileURL.path))
        #expect(!FileManager.default.fileExists(atPath: trashFileURL.path))
        #expect(!FileManager.default.fileExists(atPath: orphanClipURL.path))
        #expect(!FileManager.default.fileExists(atPath: tempClipURL.path))
        #expect(try context.fetchCount(FetchDescriptor<DiaryEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<TodoItem>()) == 1)
    }
}
