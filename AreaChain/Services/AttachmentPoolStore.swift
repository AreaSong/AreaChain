import AppKit
import CryptoKit
import Foundation
import ImageIO
import SwiftData

/// 管理工作台附件中心的未关联（待索引）附件池、SHA-256 内容去重、跨宿主唯一重命名及批量回收站清理。
@MainActor
enum AttachmentPoolStore {
    private static let poolIndexFilename = "unlinked-pool.json"
    private static var hashCache: [String: String] = [:]
    private static var sizeCache: [String: Int] = [:]
    private static var unlinkedCache: [String: (modDate: Date, items: [UnlinkedAttachmentEntry])] = [:]
    private static let imageCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 256
        return cache
    }()

    static func poolFileURL(store: AttachmentStore = .shared, root: URL? = nil) -> URL {
        (root ?? store.directory()).appending(path: poolIndexFilename)
    }

    static func contentHash(for data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func contentHashes(
        for storageIDs: [UUID],
        store: AttachmentStore = .shared,
        root: URL? = nil,
        matchingSize: Int? = nil
    ) -> [UUID: String] {
        let uniqueIDs = Array(Set(storageIDs))
        if matchingSize == nil && uniqueIDs.count <= 1 { return [:] }
        let folder = (root ?? store.directory()).standardizedFileURL
        var idsBySize: [Int: [UUID]] = [:]

        for id in uniqueIDs {
            let key = "\(folder.path)|\(id.uuidString)"
            let size: Int
            if let cachedSize = sizeCache[key] {
                size = cachedSize
            } else {
                let url = store.fileURL(id: id, root: folder)
                guard let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize,
                      fileSize > 0 else {
                    continue
                }
                sizeCache[key] = fileSize
                size = fileSize
            }
            if let matchingSize, size != matchingSize { continue }
            idsBySize[size, default: []].append(id)
        }

        var result: [UUID: String] = [:]
        for (_, group) in idsBySize {
            if matchingSize == nil && group.count < 2 { continue }
            for id in group {
                let key = "\(folder.path)|\(id.uuidString)"
                if let cached = hashCache[key] {
                    result[id] = cached
                    continue
                }
                let url = store.fileURL(id: id, root: folder)
                guard let data = try? Data(contentsOf: url),
                      !data.starts(with: VaultCrypto.attachmentMagic) else {
                    continue
                }
                let digest = contentHash(for: data)
                hashCache[key] = digest
                result[id] = digest
            }
        }
        return result
    }

    static func cachedImage(
        for reference: AttachmentRef,
        maxPixelSize: Int? = 360,
        store: AttachmentStore = .shared,
        root: URL? = nil,
        useOrdinaryRead: Bool = false
    ) -> NSImage? {
        let folder = (root ?? store.directory()).standardizedFileURL
        let storageID = reference.storageID ?? reference.id
        let sizeTag = maxPixelSize.map(String.init) ?? "full"
        let cacheKey = "\(folder.path)|\(storageID.uuidString)|\(sizeTag)" as NSString
        if let cached = imageCache.object(forKey: cacheKey) {
            return cached
        }
        let data: Data?
        if useOrdinaryRead {
            data = try? store.readOrdinary(reference: reference, root: folder)
        } else {
            data = try? store.read(reference: reference, root: folder)
        }
        guard let data else { return nil }
        if let maxPixelSize,
           let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
           let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, [
               kCGImageSourceCreateThumbnailFromImageAlways: true,
               kCGImageSourceShouldCacheImmediately: true,
               kCGImageSourceCreateThumbnailWithTransform: true,
               kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
           ] as CFDictionary) {
            let thumb = NSImage(cgImage: cgThumb, size: NSSize(width: cgThumb.width, height: cgThumb.height))
            imageCache.setObject(thumb, forKey: cacheKey)
            return thumb
        }
        guard let image = NSImage(data: data) else { return nil }
        imageCache.setObject(image, forKey: cacheKey)
        return image
    }

    static func unlinkedItems(store: AttachmentStore = .shared, root: URL? = nil) -> [UnlinkedAttachmentEntry] {
        let url = poolFileURL(store: store, root: root).standardizedFileURL
        guard let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate else {
            unlinkedCache.removeValue(forKey: url.path)
            return []
        }
        if let cached = unlinkedCache[url.path], cached.modDate == modDate {
            return cached.items
        }
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([UnlinkedAttachmentEntry].self, from: data) else {
            return []
        }
        let filtered = decoded.filter { entry in
            FileManager.default.fileExists(atPath: store.fileURL(id: entry.id, root: root).path)
        }
        unlinkedCache[url.path] = (modDate, filtered)
        return filtered
    }

    @discardableResult
    static func saveUnlinked(
        data: Data,
        filename: String,
        context: ModelContext? = nil,
        store: AttachmentStore = .shared,
        root: URL? = nil,
        id: UUID = UUID(),
        createdAt: Date = .now
    ) throws -> UnlinkedAttachmentEntry {
        guard NSImage(data: data) != nil else {
            throw RepositoryError.invalidArgument("图像数据无法解码")
        }
        let folder = root ?? store.directory()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let digest = contentHash(for: data)
        if let existing = findExistingByHash(digest, byteCount: data.count, in: context, store: store, root: folder) {
            BoardEvents.changedLocally()
            return UnlinkedAttachmentEntry(
                id: existing.storageID,
                filename: existing.filename,
                createdAt: existing.createdAt
            )
        }
        let existingNames = allKnownFilenames(in: context, store: store, root: folder)
        let resolvedName = AttachmentSyntax.uniqueFilename(base: filename, existing: existingNames)
        try data.write(to: store.fileURL(id: id, root: folder), options: .atomic)
        let cacheKey = "\(folder.standardizedFileURL.path)|\(id.uuidString)"
        hashCache[cacheKey] = digest
        sizeCache[cacheKey] = data.count
        var current = unlinkedItems(store: store, root: folder)
        let entry = UnlinkedAttachmentEntry(id: id, filename: resolvedName, createdAt: createdAt)
        current.removeAll { $0.id == id }
        current.append(entry)
        try writeUnlinked(current, store: store, root: folder)
        BoardEvents.changedLocally()
        return entry
    }

    @discardableResult
    static func saveOrLink(
        data: Data,
        filename: String,
        ownerKind: AttachmentOwner,
        ownerID: UUID,
        context: ModelContext,
        store: AttachmentStore = .shared,
        root: URL? = nil,
        id: UUID = UUID(),
        createdAt: Date = .now
    ) throws -> AttachmentItem {
        let folder = root ?? store.directory()
        if try isProtectedDiaryOwner(ownerKind: ownerKind, ownerID: ownerID, in: context) {
            let existingNames = allKnownFilenames(in: context, store: store, root: folder)
            let resolvedName = AttachmentSyntax.uniqueFilename(base: filename, existing: existingNames)
            return try store.save(
                data: data, filename: resolvedName, ownerKind: ownerKind,
                ownerID: ownerID, context: context, root: folder, id: id, createdAt: createdAt
            )
        }
        let digest = contentHash(for: data)
        if let match = findExistingByHash(digest, byteCount: data.count, in: context, store: store, root: folder) {
            return linkExistingMatch(
                match, ownerKind: ownerKind, ownerID: ownerID,
                context: context, store: store, folder: folder, id: id, createdAt: createdAt
            )
        }
        let existingNames = allKnownFilenames(in: context, store: store, root: folder)
        let resolvedName = AttachmentSyntax.uniqueFilename(base: filename, existing: existingNames)
        let item = try store.save(
            data: data, filename: resolvedName, ownerKind: ownerKind,
            ownerID: ownerID, context: context, root: folder, id: id, createdAt: createdAt
        )
        item.storageID = item.id
        let cacheKey = "\(folder.standardizedFileURL.path)|\(id.uuidString)"
        hashCache[cacheKey] = digest
        sizeCache[cacheKey] = data.count
        return item
    }

    static func removeUnlinkedEntry(id: UUID, store: AttachmentStore = .shared, root: URL? = nil) {
        let folder = root ?? store.directory()
        var current = unlinkedItems(store: store, root: folder)
        let before = current.count
        current.removeAll { $0.id == id }
        guard current.count != before else { return }
        try? writeUnlinked(current, store: store, root: folder)
    }

    @discardableResult
    static func rename(
        item: AttachmentLibraryItem,
        newFilename: String,
        context: ModelContext,
        store: AttachmentStore = .shared,
        root: URL? = nil
    ) -> Bool {
        let sanitized = AttachmentSyntax.sanitizedFilename(newFilename, fallback: item.filename)
        guard !sanitized.isEmpty,
              AttachmentSyntax.normalizedName(sanitized) != AttachmentSyntax.normalizedName(item.filename) else {
            return false
        }
        let folder = root ?? store.directory()
        let targetStorageIDs = Set(item.allStorageIDs + [item.storageID])
        let targetRowIDs = Set(item.attachmentItemIDs)
        let otherNames = otherFilenames(
            excludingStorageIDs: targetStorageIDs,
            excludingRowIDs: targetRowIDs,
            in: context, store: store, root: folder
        )
        let resolvedName = AttachmentSyntax.uniqueFilename(base: sanitized, existing: otherNames)
        let saved = ModelChanges.perform(in: context) {
            let all = try OwnedAttachments.all(in: context)
            for row in all where targetStorageIDs.contains(row.storageID ?? row.id) || targetRowIDs.contains(row.id) {
                row.filename = resolvedName
            }
        }
        var pool = unlinkedItems(store: store, root: folder)
        var poolChanged = false
        for idx in pool.indices where targetStorageIDs.contains(pool[idx].id) {
            pool[idx].filename = resolvedName
            poolChanged = true
        }
        if poolChanged {
            try? writeUnlinked(pool, store: store, root: folder)
            if !saved { BoardEvents.changedLocally() }
            return true
        }
        return saved
    }

    @discardableResult
    static func trashItems(
        _ items: [AttachmentLibraryItem],
        context: ModelContext,
        store: AttachmentStore = .shared,
        root: URL? = nil
    ) -> Bool {
        guard !items.isEmpty else { return false }
        let targetRowIDs = Set(items.flatMap(\.attachmentItemIDs))
        let targetStorageIDs = Set(items.flatMap { $0.allStorageIDs + [$0.storageID] })
        var didMutate = false
        if !targetRowIDs.isEmpty {
            let stamp = SoftDelete.stamp()
            didMutate = ModelChanges.perform(in: context) {
                let all = try OwnedAttachments.all(in: context)
                for row in all where targetRowIDs.contains(row.id) && row.deletedAt == nil {
                    row.deletedAt = stamp
                }
            }
        }
        let folder = root ?? store.directory()
        var pool = unlinkedItems(store: store, root: folder)
        let removedPoolIDs = Set(pool.filter { targetStorageIDs.contains($0.id) }.map(\.id))
        if !removedPoolIDs.isEmpty {
            pool.removeAll { removedPoolIDs.contains($0.id) }
            try? writeUnlinked(pool, store: store, root: folder)
            let remainingRows = (try? OwnedAttachments.all(in: context)) ?? []
            let referencedStorageIDs = Set(remainingRows.map { $0.storageID ?? $0.id })
            for poolID in removedPoolIDs where !referencedStorageIDs.contains(poolID) {
                store.removeFile(id: poolID, root: folder)
            }
            if !didMutate { BoardEvents.changedLocally() }
            didMutate = true
        }
        return didMutate
    }

    static func availableFilenames(
        in context: ModelContext,
        store: AttachmentStore = .shared,
        root: URL? = nil
    ) -> [String] {
        let attachments = (try? context.fetch(FetchDescriptor<AttachmentItem>(predicate: SoftDelete.liveAttachments))) ?? []
        let tags = (try? context.fetch(FetchDescriptor<TagItem>())) ?? []
        let owners = (try? AttachmentAccess.ownerIndex(context: context, keys: attachments.compactMap(\.ownerKey))) ?? .empty
        let unlinked = unlinkedItems(store: store, root: root)
        let storageIDs = attachments.map { $0.storageID ?? $0.id } + unlinked.map(\.id)
        let hashes = contentHashes(for: storageIDs, store: store, root: root)
        return AttachmentLibraryProjection.availableFilenames(
            attachments: attachments,
            unlinked: unlinked,
            owners: owners,
            tags: tags,
            contentHashes: hashes
        )
    }

    static func allKnownFilenames(
        in context: ModelContext?,
        store: AttachmentStore = .shared,
        root: URL? = nil
    ) -> [String] {
        let rows = (try? context?.fetch(FetchDescriptor<AttachmentItem>(predicate: SoftDelete.liveAttachments))) ?? []
        let pool = unlinkedItems(store: store, root: root)
        return rows.map(\.filename) + pool.map(\.filename)
    }

    private struct ExistingHashMatch {
        let storageID: UUID
        let filename: String
        let createdAt: Date
        let fromUnlinkedPool: Bool
    }

    private static func findExistingByHash(
        _ digest: String,
        byteCount: Int,
        in context: ModelContext?,
        store: AttachmentStore,
        root: URL
    ) -> ExistingHashMatch? {
        let rows = ((try? context?.fetch(FetchDescriptor<AttachmentItem>(predicate: SoftDelete.liveAttachments))) ?? [])
            .filter { $0.privacyVaultID == nil }
            .sorted { $0.createdAt < $1.createdAt }
        let pool = unlinkedItems(store: store, root: root).sorted { $0.createdAt < $1.createdAt }
        let allIDs = rows.map { $0.storageID ?? $0.id } + pool.map(\.id)
        let hashes = contentHashes(for: allIDs, store: store, root: root, matchingSize: byteCount)
        if let row = rows.first(where: { hashes[$0.storageID ?? $0.id] == digest }) {
            return ExistingHashMatch(
                storageID: row.storageID ?? row.id,
                filename: row.filename,
                createdAt: row.createdAt,
                fromUnlinkedPool: false
            )
        }
        if let entry = pool.first(where: { hashes[$0.id] == digest }) {
            return ExistingHashMatch(
                storageID: entry.id,
                filename: entry.filename,
                createdAt: entry.createdAt,
                fromUnlinkedPool: true
            )
        }
        return nil
    }

    private static func linkExistingMatch(
        _ match: ExistingHashMatch,
        ownerKind: AttachmentOwner,
        ownerID: UUID,
        context: ModelContext,
        store: AttachmentStore,
        folder: URL,
        id: UUID,
        createdAt: Date
    ) -> AttachmentItem {
        let rows = (try? context.fetch(FetchDescriptor<AttachmentItem>(predicate: SoftDelete.liveAttachments))) ?? []
        if let sameOwnerRow = rows.first(where: {
            $0.ownerKind == ownerKind.rawValue && $0.ownerID == ownerID && ($0.storageID ?? $0.id) == match.storageID
        }) {
            if match.fromUnlinkedPool {
                removeUnlinkedEntry(id: match.storageID, store: store, root: folder)
            }
            return sameOwnerRow
        }
        let item = AttachmentItem(
            id: id,
            ownerKind: ownerKind.rawValue,
            ownerID: ownerID,
            filename: match.filename,
            createdAt: createdAt
        )
        item.storageID = match.storageID
        context.insert(item)
        if match.fromUnlinkedPool {
            removeUnlinkedEntry(id: match.storageID, store: store, root: folder)
        }
        return item
    }

    private static func isProtectedDiaryOwner(
        ownerKind: AttachmentOwner,
        ownerID: UUID,
        in context: ModelContext
    ) throws -> Bool {
        guard ownerKind == .diary else { return false }
        let matches = try AttachmentAccess.fetchDiaries(id: ownerID, in: context)
        guard matches.count == 1, let owner = matches.first, owner.deletedAt == nil else {
            throw RepositoryError.invalidArgument("附件拥有者不可用")
        }
        return owner.hasProtectedContent
    }

    private static func otherFilenames(
        excludingStorageIDs: Set<UUID>,
        excludingRowIDs: Set<UUID>,
        in context: ModelContext,
        store: AttachmentStore,
        root: URL
    ) -> [String] {
        let rows = (try? context.fetch(FetchDescriptor<AttachmentItem>(predicate: SoftDelete.liveAttachments))) ?? []
        let rowNames = rows
            .filter { !excludingStorageIDs.contains($0.storageID ?? $0.id) && !excludingRowIDs.contains($0.id) }
            .map(\.filename)
        let poolNames = unlinkedItems(store: store, root: root)
            .filter { !excludingStorageIDs.contains($0.id) }
            .map(\.filename)
        return rowNames + poolNames
    }

    private static func writeUnlinked(
        _ entries: [UnlinkedAttachmentEntry],
        store: AttachmentStore,
        root: URL
    ) throws {
        let url = poolFileURL(store: store, root: root).standardizedFileURL
        unlinkedCache.removeValue(forKey: url.path)
        if entries.isEmpty {
            try? FileManager.default.removeItem(at: url)
            return
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let encoded = try JSONEncoder().encode(entries)
        try encoded.write(to: url, options: .atomic)
    }
}
