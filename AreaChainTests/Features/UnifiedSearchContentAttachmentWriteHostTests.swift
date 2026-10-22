import AppKit
import SwiftData
import Testing
@testable import AreaChain

/// M-5G：隔离宿主中附件的写入与删除只落宿主注入的存储；没有存储时写入与清除入口禁用。
/// 只用内存库、临时目录和私有命名剪贴板；不读写共享附件目录。界面用例纯程序化渲染，走后台轮。
@Suite(.serialized, .tags(.backgroundWindow)) @MainActor struct UnifiedSearchContentAttachmentWriteHostTests {
    private func nodes(_ window: NSWindow?) -> [NSObject] { SettingsButtonTestSupport.elements(window?.contentView) }

    /// 按无障碍标签或标识找按钮，返回每个按钮的可用状态；找不到就不是合法观察点。
    private func buttons(_ window: NSWindow?, label: String? = nil, identifier: String? = nil) -> [Bool?] {
        nodes(window).filter { node in
            guard SettingsButtonTestSupport.value(node, "accessibilityRole") as? String == "AXButton" else { return false }
            if let label, SettingsButtonTestSupport.value(node, "accessibilityLabel") as? String != label { return false }
            if let identifier, SettingsButtonTestSupport.value(node, "accessibilityIdentifier") as? String != identifier {
                return false
            }
            return true
        }.map { ($0.value(forKey: "accessibilityEnabled") as? NSNumber)?.boolValue }
    }

    private func english(_ key: String) -> String {
        L10n.string(String.LocalizationValue(stringLiteral: key), locale: Locale(identifier: "en"))
    }

    private func scrollToBottom(_ window: NSWindow?) {
        for scroll in nodes(window).compactMap({ $0 as? NSScrollView }) {
            guard let document = scroll.documentView else { continue }
            scroll.contentView.scroll(to: NSPoint(x: 0, y: max(0, document.frame.height - scroll.contentView.bounds.height)))
            scroll.reflectScrolledClipView(scroll.contentView)
        }
    }

    private static func temporaryStore() throws -> (AttachmentStore, URL) {
        let root = FileManager.default.temporaryDirectory.appending(path: "AreaChain-M5G-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return (AttachmentStore(keys: VaultKeyAccess(), root: root), root)
    }

    private static func container() throws -> ModelContainer {
        try ModelContainer(for: Schema(AreaChainSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    // MARK: - 无存储：写入与清除入口禁用（HEAD 上可用 → 红）

    @Test func inspectorWritesDisabledWithoutHostStore() async throws {
        let f = try UnifiedSearchNavigationFixture(); defer { f.stop() }
        try await f.start(unified: false)
        f.navigation.revealTab(.allItems, inspecting: f.todo.id, dayKey: f.day)
        try await f.settle()
        scrollToBottom(f.window)
        try await f.settle()
        for key in ["drawer.attachments.pick", "drawer.attachments.paste"] {
            let states = buttons(f.window, label: english(key))
            try #require(!states.isEmpty, "检查器附件按钮 \(key) 未进入无障碍树")
            #expect(states.allSatisfy { $0 == false }, "\(key): \(states)")
        }
    }

    @Test func diaryCardWritesDisabledWithoutHostStore() async throws {
        let f = try UnifiedSearchNavigationFixture(); defer { f.stop() }
        let entry = DiaryEntry(text: "M5G 合成手记", dayKey: f.day)
        entry.isPinned = true // 置顶让卡片操作按钮常显，不依赖悬停。
        f.context.insert(entry)
        try f.context.save()
        try await f.start(unified: false)
        f.navigation.revealTab(.diary)
        try await f.settle()
        let paste = buttons(f.window, identifier: "diary.paste")
        let attach = buttons(f.window, label: english("diary.attach"))
        try #require(!paste.isEmpty && !attach.isEmpty, "手记卡片附件按钮未进入无障碍树")
        #expect((paste + attach).allSatisfy { $0 == false }, "paste=\(paste) attach=\(attach)")
    }

    @Test func trashPurgeDisabledWithoutHostStore() async throws {
        let f = try UnifiedSearchNavigationFixture(); defer { f.stop() }
        let todo = TodoItem(title: "M5G 回收站任务", dayKey: f.day)
        todo.deletedAt = .now
        f.context.insert(todo)
        try f.context.save()
        try await f.start(unified: false)
        f.navigation.revealTab(.trash)
        try await f.settle()
        let restore = buttons(f.window, label: english("trash.restore"))
        let purge = buttons(f.window, label: english("trash.purge"))
        try #require(!restore.isEmpty && !purge.isEmpty, "回收站行按钮未进入无障碍树")
        // 恢复不碰附件文件，照常可用；清除会级联删附件文件，没有宿主存储就禁用。
        #expect(restore.contains { $0 != false })
        #expect(purge.allSatisfy { $0 == false }, "\(purge)")
    }

    @Test func taskRowAttachmentMenuWritableFollowsStorage() throws {
        let container = try Self.container(); let context = container.mainContext
        let (store, root) = try Self.temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let owner = UUID()
        let production = TaskCatalogContext(tags: [], attachments: [], context: context)
        #expect(production.attachments(ownerKind: .todo, ownerID: owner).canWrite)
        let isolated = TaskCatalogContext(tags: [], attachments: [], context: context,
            attachmentStorage: .init(store: store, root: root, ordinaryOnly: true))
        #expect(isolated.attachments(ownerKind: .todo, ownerID: owner).canWrite)
        let missing = TaskCatalogContext(tags: [], attachments: [], context: context, attachmentStorage: nil)
        #expect(!missing.attachments(ownerKind: .todo, ownerID: owner).canWrite)
    }

    // MARK: - 有存储：删除只落宿主存储（HEAD 行为删共享路径，临时文件仍在 → 红）

    @Test(arguments: [AttachmentOwner.todo, .routine, .diary])
    func ownerPurgeRemovesFilesFromHostStore(kind: AttachmentOwner) throws {
        let container = try Self.container(); let context = container.mainContext
        let (store, root) = try Self.temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let ownerID: UUID
        switch kind {
        case .todo:
            let todo = TodoItem(title: "M5G 任务", dayKey: "2026-10-07", deletedAt: .now)
            context.insert(todo); ownerID = todo.id
        case .routine:
            let routine = DailyRoutine(title: "M5G 习惯", sortOrder: 0, createdDayKey: "2026-10-07")
            routine.deletedAt = .now
            context.insert(routine); ownerID = routine.id
        case .diary:
            let diary = DiaryEntry(text: "M5G 手记", dayKey: "2026-10-07", deletedAt: .now)
            context.insert(diary); ownerID = diary.id
        }
        let image = AttachmentItem(ownerKind: kind.rawValue, ownerID: ownerID, filename: "m5g.png", deletedAt: .now)
        context.insert(image)
        try context.save()
        try Data("m5g".utf8).write(to: store.fileURL(id: image.id))
        let row: TrashRow
        switch kind {
        case .todo:
            let todo = try #require(try context.fetch(FetchDescriptor<TodoItem>()).first)
            row = try #require(TrashRow.todo(todo, attachments: [image], attachmentStore: store))
        case .routine:
            let routine = try #require(try context.fetch(FetchDescriptor<DailyRoutine>()).first)
            row = try #require(TrashRow.resident(routine, attachments: [image], attachmentStore: store))
        case .diary:
            let diary = try #require(try context.fetch(FetchDescriptor<DiaryEntry>()).first)
            row = try #require(TrashRow.diary(diary, attachments: [image], tags: { [] }, locale: .current,
                                              attachmentStore: store))
        }
        #expect(row.purge())
        #expect(try context.fetchCount(FetchDescriptor<AttachmentItem>()) == 0)
        #expect(!FileManager.default.fileExists(atPath: store.fileURL(id: image.id).path))
    }

    @Test func attachmentRowPurgeRemovesFileFromHostStore() throws {
        let container = try Self.container(); let context = container.mainContext
        let (store, root) = try Self.temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let image = AttachmentItem(ownerKind: "todo", ownerID: UUID(), filename: "m5g.png", deletedAt: .now)
        context.insert(image)
        try context.save()
        try Data("m5g".utf8).write(to: store.fileURL(id: image.id))
        let row = try #require(TrashRow.attachment(image, ownerDeleted: true, attachmentStore: store))
        #expect(row.purge())
        #expect(try context.fetchCount(FetchDescriptor<AttachmentItem>()) == 0)
        #expect(!FileManager.default.fileExists(atPath: store.fileURL(id: image.id).path))
    }

    @Test func emptyTrashRemovesFilesFromHostStore() throws {
        let container = try Self.container(); let context = container.mainContext
        let (store, root) = try Self.temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let todo = TodoItem(title: "M5G 清空", dayKey: "2026-10-07", deletedAt: .now)
        let owned = AttachmentItem(ownerKind: "todo", ownerID: todo.id, filename: "owned.png", deletedAt: .now)
        let loose = AttachmentItem(ownerKind: "todo", ownerID: UUID(), filename: "loose.png", deletedAt: .now)
        context.insert(todo); context.insert(owned); context.insert(loose)
        try context.save()
        for id in [owned.id, loose.id] { try Data("m5g".utf8).write(to: store.fileURL(id: id)) }
        let ids = [owned.id, loose.id]
        #expect(try LocalStorageInspector.emptyAllTrash(in: context, store: store) == 3)
        #expect(try context.fetchCount(FetchDescriptor<AttachmentItem>()) == 0)
        for id in ids { #expect(!FileManager.default.fileExists(atPath: store.fileURL(id: id).path)) }
    }

    /// 回归护栏：保留集合读宿主自己的未关联池；若只改了删除而池仍读共享目录，池中文件会被误删。
    @Test func purgeKeepsFilesStillListedInHostPool() throws {
        let container = try Self.container(); let context = container.mainContext
        let (store, root) = try Self.temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let pooled = try AttachmentPoolStore.saveUnlinked(data: try UnifiedSearchContentFixture.png(),
                                                          filename: "pool.png", store: store, root: root)
        let image = AttachmentItem(ownerKind: "todo", ownerID: UUID(), filename: "pool.png", deletedAt: .now)
        image.storageID = pooled.id
        context.insert(image)
        try context.save()
        let row = try #require(TrashRow.attachment(image, ownerDeleted: true, attachmentStore: store))
        #expect(row.purge())
        #expect(FileManager.default.fileExists(atPath: store.fileURL(id: pooled.id).path))
    }

    // MARK: - 有存储：写入只落宿主存储（只做修复后的绿轮：红轮会写真实共享目录）

    @Test func diaryCardSessionSavesIntoHostStore() throws {
        let f = try UnifiedSearchNavigationFixture(); defer { f.stop() }
        let (store, root) = try Self.temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let entry = DiaryEntry(text: "M5G 卡片编辑", dayKey: f.day)
        f.context.insert(entry)
        try f.context.save()
        let board = NSPasteboard(name: .init("AreaChain-M5G-" + UUID().uuidString))
        defer { board.releaseGlobally() }
        board.clearContents()
        board.setData(try UnifiedSearchContentFixture.png(), forType: .png)
        let session = DiaryCardDrafts().begin(entry, context: f.context, vault: f.vault, attachmentStore: store)
        #expect(session.pasteAttachment(from: board))
        #expect(session.save())
        let saved = try f.context.fetch(FetchDescriptor<AttachmentItem>()).filter { $0.ownerID == entry.id }
        #expect(saved.count == 1)
        for item in saved {
            #expect(FileManager.default.fileExists(atPath: store.fileURL(id: item.storageID ?? item.id).path))
        }
    }

    @Test func trashRowWithoutStoreRefusesPurge() throws {
        let container = try Self.container(); let context = container.mainContext
        let todo = TodoItem(title: "M5G 无存储", dayKey: "2026-10-07", deletedAt: .now)
        context.insert(todo)
        try context.save()
        let row = try #require(TrashRow.todo(todo, attachments: [], attachmentStore: nil))
        #expect(!row.canPurge && !row.purge())
        #expect(try context.fetchCount(FetchDescriptor<TodoItem>()) == 1)
        #expect(try #require(TrashRow.todo(todo, attachments: [])).canPurge)
    }

    // MARK: - 生产等价：默认参数沿用共享存储与默认 root

    @Test func instanceRemovalMatchesStaticProxy() throws {
        let (store, root) = try Self.temporaryStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let viaStatic = UUID(), viaShared = UUID(), viaStore = UUID()
        for id in [viaStatic, viaShared, viaStore] { try Data("m5g".utf8).write(to: store.fileURL(id: id)) }
        try AttachmentStore.removeFiles([viaStatic], root: root)
        try AttachmentStore.shared.removeFiles([viaShared], root: root)
        try store.removeFiles([viaStore])
        for id in [viaStatic, viaShared, viaStore] { #expect(!FileManager.default.fileExists(atPath: store.fileURL(id: id).path)) }
        // 与静态入口相同：文件不存在时忽略，不抛错。
        try store.removeFiles([UUID()])
        #expect(store.directory() == root)
    }
}
