import AppKit
import Foundation
import SwiftData

/// 本地存储目录配置，支持测试注入隔离临时目录，避免读取或修改真实用户数据。
struct LocalStoragePaths: Equatable, Sendable {
    var supportRoot: URL
    var attachmentsRoot: URL
    var clipboardRoot: URL

    static func current(fileManager: FileManager = .default) -> LocalStoragePaths {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            let tempRoot = fileManager.temporaryDirectory
                .appending(path: "areachain-storage-preview", directoryHint: .isDirectory)
            return LocalStoragePaths(
                supportRoot: tempRoot,
                attachmentsRoot: tempRoot.appending(path: "areachain-attachments", directoryHint: .isDirectory),
                clipboardRoot: tempRoot.appending(path: "areachain-clipboard", directoryHint: .isDirectory)
            )
        }
        let support = URL.applicationSupportDirectory
        return LocalStoragePaths(
            supportRoot: support,
            attachmentsRoot: AttachmentStore.shared.directory(fileManager: fileManager),
            clipboardRoot: support.appending(path: "areachain-clipboard", directoryHint: .isDirectory)
        )
    }
}

/// 字节数值与单位拆分格式化器，供圆环中心及三张卡片展示「大数字 + 单位」排版。
enum StorageByteFormat {
    struct Parts: Equatable, Sendable {
        let number: String
        let unit: String
        var combined: String { "\(number) \(unit)" }
    }

    static func split(_ bytes: Int64) -> Parts {
        let clamped = max(0, bytes)
        let kb = 1_024.0
        let mb = kb * 1_024.0
        let gb = mb * 1_024.0
        let value = Double(clamped)
        if clamped == 0 {
            return Parts(number: "0", unit: "KB")
        }
        if value < kb {
            return Parts(number: "\(clamped)", unit: "B")
        }
        if value < mb {
            let num = value / kb
            return Parts(number: num >= 100 ? String(format: "%.0f", num) : String(format: "%.1f", num), unit: "KB")
        }
        if value < gb {
            let num = value / mb
            return Parts(number: num >= 100 ? String(format: "%.1f", num) : String(format: "%.2f", num), unit: "MB")
        }
        let num = value / gb
        return Parts(number: String(format: "%.2f", num), unit: "GB")
    }
}

/// 工作台「数据与备份」页的本地存储空间统计快照。
struct LocalStorageSnapshot: Equatable, Sendable {
    var attachmentsBytes: Int64 = 0
    var attachmentsCount: Int = 0
    var cacheAndCleanableBytes: Int64 = 0
    var reclaimableBytes: Int64 = 0
    var orphanClipboardCount: Int = 0
    var trashItemCount: Int = 0
    var databaseAndOtherBytes: Int64 = 0
    var volumeTotalBytes: Int64 = 0
    var volumeAvailableBytes: Int64 = 0

    var appTotalBytes: Int64 {
        attachmentsBytes + cacheAndCleanableBytes + databaseAndOtherBytes
    }

    var volumeUsedOtherBytes: Int64 {
        let usedTotal = max(0, volumeTotalBytes - volumeAvailableBytes)
        return max(0, usedTotal - appTotalBytes)
    }

    var hasCleanableItems: Bool {
        reclaimableBytes > 0 || orphanClipboardCount > 0 || trashItemCount > 0
    }

    /// 供圆环图绘制的三段归一化比例：(AreaChain 已用, 电脑其他已用, 电脑可用)。
    var ringFractions: (app: Double, systemUsed: Double, available: Double) {
        guard volumeTotalBytes > 0 else {
            return appTotalBytes > 0 ? (1.0, 0.0, 0.0) : (0.0, 0.0, 1.0)
        }
        let total = Double(volumeTotalBytes)
        let rawApp = min(1.0, max(0.0, Double(appTotalBytes) / total))
        let rawUsed = min(1.0 - rawApp, max(0.0, Double(volumeUsedOtherBytes) / total))
        // 当应用有实际占用但占整盘比例极小时，赋予最小可见视觉弧度（约 2.5%），避免圆环上看不见应用色块。
        let visualApp = appTotalBytes > 0 ? max(rawApp, 0.025) : 0.0
        let visualUsed = max(0.0, min(1.0 - visualApp, rawUsed))
        let visualFree = max(0.0, 1.0 - visualApp - visualUsed)
        return (visualApp, visualUsed, visualFree)
    }

    func usageRatioText(locale: Locale) -> String {
        guard volumeTotalBytes > 0, appTotalBytes > 0 else {
            return L10n.format("dataBackup.storage.ring.subtitle", locale: locale, "0%")
        }
        let percentage = (Double(appTotalBytes) / Double(volumeTotalBytes)) * 100.0
        let formatted: String
        if percentage < 0.1 {
            formatted = "< 0.1%"
        } else {
            formatted = String(format: "%.1f%%", percentage)
        }
        return L10n.format("dataBackup.storage.ring.subtitle", locale: locale, formatted)
    }
}

/// 清理结果回执，用于顶部状态栏提示释放了多少空间与条目。
struct LocalStorageCleanupResult: Equatable, Sendable {
    let freedBytes: Int64
    let removedOrphanFiles: Int
    let purgedTrashItems: Int
}

/// 检索本机存储占用并执行安全的缓存/回收站清理。
@MainActor
enum LocalStorageInspector {
    static func inspect(
        context: ModelContext,
        paths: LocalStoragePaths? = nil,
        fileManager: FileManager = .default
    ) -> LocalStorageSnapshot {
        let resolvedPaths = paths ?? .current(fileManager: fileManager)
        let attachmentStats = inspectAttachments(context: context, root: resolvedPaths.attachmentsRoot, fileManager: fileManager)
        let clipboardStats = inspectClipboard(root: resolvedPaths.clipboardRoot, fileManager: fileManager)
        let trashCount = countTrashItems(in: context)
        let dbBytes = inspectDatabaseAndConfigs(
            supportRoot: resolvedPaths.supportRoot,
            attachmentsRoot: resolvedPaths.attachmentsRoot,
            fileManager: fileManager
        )
        let volume = inspectVolumeCapacity(at: resolvedPaths.supportRoot)
        let cacheTotal = clipboardStats.totalBytes + attachmentStats.trashOnlyBytes
        let reclaimable = clipboardStats.orphanBytes + attachmentStats.trashOnlyBytes
        return LocalStorageSnapshot(
            attachmentsBytes: attachmentStats.activeBytes,
            attachmentsCount: attachmentStats.activeCount,
            cacheAndCleanableBytes: cacheTotal,
            reclaimableBytes: reclaimable,
            orphanClipboardCount: clipboardStats.orphanCount,
            trashItemCount: trashCount,
            databaseAndOtherBytes: dbBytes,
            volumeTotalBytes: volume.total,
            volumeAvailableBytes: volume.available
        )
    }

    @discardableResult
    static func cleanReclaimableData(
        context: ModelContext,
        paths: LocalStoragePaths? = nil,
        fileManager: FileManager = .default
    ) throws -> LocalStorageCleanupResult {
        let resolvedPaths = paths ?? .current(fileManager: fileManager)
        let before = inspect(context: context, paths: resolvedPaths, fileManager: fileManager)
        let removedOrphans = cleanClipboardOrphans(root: resolvedPaths.clipboardRoot, fileManager: fileManager)
        let attachmentsRoot = resolvedPaths.attachmentsRoot
        let purgedTrash = try emptyAllTrash(in: context) { fileID in
            try AttachmentStore.removeFiles([fileID], root: attachmentsRoot)
        }
        let after = inspect(context: context, paths: resolvedPaths, fileManager: fileManager)
        let freed = max(0, before.appTotalBytes - after.appTotalBytes)
        if purgedTrash > 0 || removedOrphans > 0 {
            BoardEvents.changed()
        }
        return LocalStorageCleanupResult(
            freedBytes: freed,
            removedOrphanFiles: removedOrphans,
            purgedTrashItems: purgedTrash
        )
    }

    /// 与回收站「清空回收站」共用同一套父项与物理附件清理顺序。
    @discardableResult
    static func emptyAllTrash(
        in context: ModelContext,
        removeFile: (UUID) throws -> Void = { try AttachmentStore.removeFiles([$0]) }
    ) throws -> Int {
        let deletedRoutines = (try? context.fetch(FetchDescriptor<DailyRoutine>(predicate: SoftDelete.deletedRoutines))) ?? []
        let deletedTodos = (try? context.fetch(FetchDescriptor<TodoItem>(predicate: SoftDelete.deletedTodos))) ?? []
        let deletedDiaries = (try? context.fetch(FetchDescriptor<DiaryEntry>(predicate: SoftDelete.deletedDiaries))) ?? []
        let deletedAttachments = (try? context.fetch(FetchDescriptor<AttachmentItem>(predicate: SoftDelete.deletedAttachments))) ?? []
        let allTags = (try? context.fetch(FetchDescriptor<TagItem>())) ?? []
        let deletedTags = allTags.filter { $0.deletedAt != nil }
        let totalCount = deletedRoutines.count + deletedTodos.count + deletedDiaries.count
            + deletedAttachments.count + deletedTags.count
        guard totalCount > 0 else { return 0 }

        var purgedOwners = Set<AttachmentOwnerKey>()
        for item in deletedRoutines { purgedOwners.insert(AttachmentOwnerKey(kind: .routine, id: item.id)) }
        for item in deletedTodos { purgedOwners.insert(AttachmentOwnerKey(kind: .todo, id: item.id)) }
        for item in deletedDiaries { purgedOwners.insert(AttachmentOwnerKey(kind: .diary, id: item.id)) }
        let listedFileIDs = deletedAttachments.map(\.id)

        let succeeded = try AttachmentCleanup.emptyListed(
            listedFileIDs: listedFileIDs,
            purgedOwners: purgedOwners,
            context: context,
            removeParents: { ctx in
                for routine in deletedRoutines {
                    try DayBoardMutations.routineRepo(for: ctx).deleteRoutine(id: routine.id, soft: false)
                }
                for todo in deletedTodos {
                    try DayBoardMutations.taskRepo(for: ctx).deleteTodo(id: todo.id, soft: false)
                }
                for diary in deletedDiaries {
                    try DayBoardMutations.diaryRepo(for: ctx).deleteDiary(id: diary.id, soft: false)
                }
                for tag in deletedTags {
                    try DayBoardMutations.catalogRepo(for: ctx).deleteTag(id: tag.id, soft: false)
                }
            },
            removeFile: removeFile
        )
        guard succeeded else { return 0 }
        for owner in purgedOwners { EditDrafts.shared.discard(owner: owner) }
        return totalCount
    }

    static func revealSupportDirectory(paths: LocalStoragePaths? = nil, fileManager: FileManager = .default) {
        let resolved = paths ?? .current(fileManager: fileManager)
        let dbFile = resolved.supportRoot.appending(path: "areachain.store")
        if fileManager.fileExists(atPath: dbFile.path) {
            NSWorkspace.shared.activateFileViewerSelecting([dbFile])
        } else {
            NSWorkspace.shared.open(resolved.supportRoot)
        }
    }
}

// MARK: - 内部扫描与清理辅助

private extension LocalStorageInspector {
    struct AttachmentBreakdown {
        var activeBytes: Int64 = 0
        var activeCount: Int = 0
        var trashOnlyBytes: Int64 = 0
    }

    struct ClipboardBreakdown {
        var totalBytes: Int64 = 0
        var orphanBytes: Int64 = 0
        var orphanCount: Int = 0
    }

    static func inspectAttachments(
        context: ModelContext,
        root: URL,
        fileManager: FileManager
    ) -> AttachmentBreakdown {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return AttachmentBreakdown()
        }
        let allRows = (try? OwnedAttachments.all(in: context)) ?? []
        let deletedOwnerKeys = fetchDeletedOwnerKeys(in: context)
        var activeStorageIDs = Set<String>()
        var trashStorageIDs = Set<String>()
        for row in allRows {
            let storageName = (row.storageID ?? row.id).uuidString
            let isOwnerDeleted = row.ownerKey.map { deletedOwnerKeys.contains($0) } ?? false
            if row.deletedAt == nil && !isOwnerDeleted {
                activeStorageIDs.insert(storageName)
            } else {
                trashStorageIDs.insert(storageName)
            }
            if let retired = row.retiredStorageID {
                trashStorageIDs.insert(retired.uuidString)
            }
        }
        for entry in AttachmentPoolStore.unlinkedItems(root: root) {
            activeStorageIDs.insert(entry.id.uuidString)
        }
        var breakdown = AttachmentBreakdown()
        for url in urls where url.lastPathComponent != "unlinked-pool.json" {
            let size = fileSize(at: url)
            let name = url.lastPathComponent
            if trashStorageIDs.contains(name) && !activeStorageIDs.contains(name) {
                breakdown.trashOnlyBytes += size
            } else {
                breakdown.activeBytes += size
                breakdown.activeCount += 1
            }
        }
        return breakdown
    }

    static func fetchDeletedOwnerKeys(in context: ModelContext) -> Set<AttachmentOwnerKey> {
        let routines = (try? context.fetch(FetchDescriptor<DailyRoutine>(predicate: SoftDelete.deletedRoutines))) ?? []
        let todos = (try? context.fetch(FetchDescriptor<TodoItem>(predicate: SoftDelete.deletedTodos))) ?? []
        let diaries = (try? context.fetch(FetchDescriptor<DiaryEntry>(predicate: SoftDelete.deletedDiaries))) ?? []
        var keys = Set<AttachmentOwnerKey>()
        for item in routines { keys.insert(AttachmentOwnerKey(kind: .routine, id: item.id)) }
        for item in todos { keys.insert(AttachmentOwnerKey(kind: .todo, id: item.id)) }
        for item in diaries { keys.insert(AttachmentOwnerKey(kind: .diary, id: item.id)) }
        return keys
    }

    static func inspectClipboard(root: URL, fileManager: FileManager) -> ClipboardBreakdown {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return ClipboardBreakdown()
        }
        let store = ClipboardHistoryStore(root: root, fileManager: fileManager)
        let referencedImages = Set(store.load().compactMap(\.imageFile))
        var breakdown = ClipboardBreakdown()
        for url in urls {
            let size = fileSize(at: url)
            breakdown.totalBytes += size
            let name = url.lastPathComponent
            let isOrphanPNG = url.pathExtension.lowercased() == "png" && !referencedImages.contains(name)
            let isTempFile = name.hasSuffix(".tmp")
            if isOrphanPNG || isTempFile {
                breakdown.orphanBytes += size
                breakdown.orphanCount += 1
            }
        }
        return breakdown
    }

    static func cleanClipboardOrphans(root: URL, fileManager: FileManager) -> Int {
        guard let urls = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else {
            return 0
        }
        let store = ClipboardHistoryStore(root: root, fileManager: fileManager)
        let referenced = Set(store.load().compactMap(\.imageFile))
        var removed = 0
        for url in urls {
            let name = url.lastPathComponent
            let isOrphanPNG = url.pathExtension.lowercased() == "png" && !referenced.contains(name)
            let isTemp = name.hasSuffix(".tmp")
            if isOrphanPNG || isTemp {
                if (try? fileManager.removeItem(at: url)) != nil {
                    removed += 1
                }
            }
        }
        store.pruneImages(keeping: referenced)
        return removed
    }

    static func countTrashItems(in context: ModelContext) -> Int {
        let routines = (try? context.fetchCount(FetchDescriptor<DailyRoutine>(predicate: SoftDelete.deletedRoutines))) ?? 0
        let todos = (try? context.fetchCount(FetchDescriptor<TodoItem>(predicate: SoftDelete.deletedTodos))) ?? 0
        let diaries = (try? context.fetchCount(FetchDescriptor<DiaryEntry>(predicate: SoftDelete.deletedDiaries))) ?? 0
        let attachments = (try? context.fetchCount(FetchDescriptor<AttachmentItem>(predicate: SoftDelete.deletedAttachments))) ?? 0
        let tags = ((try? context.fetch(FetchDescriptor<TagItem>())) ?? []).filter { $0.deletedAt != nil }.count
        return routines + todos + diaries + attachments + tags
    }

    static func inspectDatabaseAndConfigs(
        supportRoot: URL,
        attachmentsRoot: URL,
        fileManager: FileManager
    ) -> Int64 {
        let knownNames = [
            "areachain.store",
            "areachain.store-wal",
            "areachain.store-shm",
            CalendarSyncStorage.ledgerFilename,
            "areachain-privacy.json",
            "areachain-preferences.json"
        ]
        var total: Int64 = 0
        for name in knownNames {
            let url = supportRoot.appending(path: name)
            if fileManager.fileExists(atPath: url.path) {
                total += fileSize(at: url)
            }
        }
        let poolIndex = attachmentsRoot.appending(path: "unlinked-pool.json")
        if fileManager.fileExists(atPath: poolIndex.path) {
            total += fileSize(at: poolIndex)
        }
        return total
    }

    static func inspectVolumeCapacity(at url: URL) -> (total: Int64, available: Int64) {
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]
        let target = FileManager.default.fileExists(atPath: url.path) ? url : URL(fileURLWithPath: "/")
        guard let values = try? target.resourceValues(forKeys: keys) else {
            return (0, 0)
        }
        let total = Int64(values.volumeTotalCapacity ?? 0)
        let available = values.volumeAvailableCapacityForImportantUsage
            ?? Int64(values.volumeAvailableCapacity ?? 0)
        return (max(0, total), max(0, available))
    }

    static func fileSize(at url: URL) -> Int64 {
        if let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
            return Int64(max(0, size))
        }
        if let num = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? NSNumber {
            return max(0, num.int64Value)
        }
        return 0
    }
}
