import AppKit
import Foundation
import SwiftData
import UniformTypeIdentifiers

/// 纯物理文件 I/O 与 SwiftData 元数据管理服务
final class AttachmentStore: AttachmentStorageProtocol, @unchecked Sendable {
    static let shared = AttachmentStore()

    init() {}

    func directory(fileManager: FileManager = .default) -> URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
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
        try data.write(to: fileURL(id: id, root: folder), options: .atomic)
        let item = AttachmentItem(
            id: id,
            ownerKind: ownerKind.rawValue,
            ownerID: ownerID,
            filename: filename,
            createdAt: createdAt
        )
        context.insert(item)
        return item
    }

    func loadData(id: UUID, root: URL? = nil) -> Data? {
        try? Data(contentsOf: fileURL(id: id, root: root))
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

    static func removeFile(id: UUID, root: URL? = nil) {
        shared.removeFile(id: id, root: root)
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
