import AppKit
import Foundation
import SwiftData
import UniformTypeIdentifiers

/// 纯物理文件 I/O 与 SwiftData 元数据管理服务
final class AttachmentStore: AttachmentStorageProtocol, @unchecked Sendable {
    static let shared = AttachmentStore()
    let keys: VaultKeyAccess
    private let root: URL?

    init(keys: VaultKeyAccess = .shared, root: URL? = nil) {
        self.keys = keys
        self.root = root
    }

    func directory(fileManager: FileManager = .default) -> URL {
        root ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "areachain-attachments", directoryHint: .isDirectory)
    }

    func fileURL(id: UUID, root: URL? = nil) -> URL {
        (root ?? directory()).appending(path: id.uuidString)
    }

    @discardableResult
    func save(
        data: Data,
        filename: String,
        ownerKind: AttachmentOwner,
        ownerID: UUID,
        context: ModelContext,
        root: URL? = nil,
        id: UUID = UUID(),
        createdAt: Date = .now
    ) throws -> AttachmentItem {
        let folder = root ?? directory()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var stored = data
        var vaultID: UUID?
        if ownerKind == .diary {
            let matches = try context.fetch(FetchDescriptor<DiaryEntry>()).filter { $0.id == ownerID }
            guard matches.count == 1, let owner = matches.first, owner.deletedAt == nil else {
                throw RepositoryError.invalidArgument("附件拥有者不可用")
            }
            if owner.hasProtectedContent {
                guard let ownerVaultID = owner.privacyVaultID else { throw PrivacyError.corruptData }
                vaultID = ownerVaultID
            }
        }
        if let vaultID {
            stored = try PrivateAttachments.encode(data, attachmentID: id, ownerID: ownerID, vaultID: vaultID, keys: keys)
        }
        try stored.write(to: fileURL(id: id, root: folder), options: .atomic)
        let item = AttachmentItem(
            id: id,
            ownerKind: ownerKind.rawValue,
            ownerID: ownerID,
            filename: filename,
            createdAt: createdAt
        )
        item.privacyVaultID = vaultID
        context.insert(item)
        return item
    }

    func loadData(id: UUID, root: URL? = nil) -> Data? {
        try? read(reference: AttachmentRef(id: id, filename: ""), root: root)
    }

    func read(reference: AttachmentRef, root: URL? = nil, maximumBytes: Int? = nil) throws -> Data {
        let url = fileURL(id: reference.storageID ?? reference.id, root: root)
        let limit = maximumBytes ?? (reference.privacyVaultID != nil ? VaultCrypto.maximumAttachmentBytes : nil)
        if let limit {
            let size = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
            let diskLimit = reference.privacyVaultID == nil ? limit : limit * 2
            guard size <= diskLimit else { throw PrivacyError.tooLarge }
        }
        let data = try Data(contentsOf: url)
        let decoded = try PrivateAttachments.decode(data, reference: reference, keys: keys)
        if let limit, decoded.count > limit { throw PrivacyError.tooLarge }
        return decoded
    }

    func image(reference: AttachmentRef, root: URL? = nil) -> NSImage? {
        guard let data = try? read(reference: reference, root: root) else { return nil }
        return NSImage(data: data)
    }

    func image(id: UUID, root: URL? = nil) -> NSImage? {
        guard let data = loadData(id: id, root: root) else { return nil }
        return NSImage(data: data)
    }

    func removeFile(id: UUID, root: URL? = nil) {
        try? FileManager.default.removeItem(at: fileURL(id: id, root: root))
    }

    func purge(
        ownerID: UUID,
        attachments: [AttachmentItem],
        context: ModelContext,
        root: URL? = nil
    ) {
        for item in attachments where item.ownerID == ownerID {
            removeFile(id: item.id, root: root)
            context.delete(item)
        }
    }

    func resetDirectory(fileManager: FileManager = .default) throws {
        try fileManager.removeItem(at: directory(fileManager: fileManager))
    }

    // MARK: - Backward-Compatible Static Proxies
    static func directory(fileManager: FileManager = .default) -> URL {
        shared.directory(fileManager: fileManager)
    }

    static func fileURL(id: UUID, root: URL? = nil) -> URL {
        shared.fileURL(id: id, root: root)
    }

    @discardableResult
    static func save(
        data: Data,
        filename: String,
        ownerKind: AttachmentOwner,
        ownerID: UUID,
        context: ModelContext,
        root: URL? = nil,
        id: UUID = UUID(),
        createdAt: Date = .now
    ) throws -> AttachmentItem {
        try shared.save(
            data: data,
            filename: filename,
            ownerKind: ownerKind,
            ownerID: ownerID,
            context: context,
            root: root,
            id: id,
            createdAt: createdAt
        )
    }

    static func loadData(id: UUID, root: URL? = nil) -> Data? {
        shared.loadData(id: id, root: root)
    }

    static func image(id: UUID, root: URL? = nil) -> NSImage? {
        shared.image(id: id, root: root)
    }

    static func image(reference: AttachmentRef, root: URL? = nil) -> NSImage? {
        shared.image(reference: reference, root: root)
    }

    static func removeFile(id: UUID, root: URL? = nil) {
        shared.removeFile(id: id, root: root)
    }

    /// 只有数据库删除成功后才移除物理文件；备份中的无二进制元数据允许重复清理。
    static func removeFiles(_ ids: [UUID], root: URL? = nil) throws {
        for id in ids {
            do {
                try FileManager.default.removeItem(at: fileURL(id: id, root: root))
            } catch let error as CocoaError where error.code == .fileNoSuchFile {
                continue
            }
        }
    }

    static func purge(
        ownerID: UUID,
        attachments: [AttachmentItem],
        context: ModelContext,
        root: URL? = nil
    ) {
        shared.purge(ownerID: ownerID, attachments: attachments, context: context, root: root)
    }

    static func resetDirectory(fileManager: FileManager = .default) {
        try? shared.resetDirectory(fileManager: fileManager)
    }
}

enum ImageBytes {
    static func png(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    static func pasteboardImage(_ board: NSPasteboard = .general) -> NSImage? {
        NSImage(pasteboard: board)
    }
}
