import AppKit
import Foundation
import SwiftData
import UniformTypeIdentifiers

enum AttachmentStore {
    static func directory(fileManager: FileManager = .default) -> URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "areachain-attachments", directoryHint: .isDirectory)
    }

    static func fileURL(id: UUID, root: URL? = nil) -> URL {
        (root ?? directory()).appending(path: id.uuidString)
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

    static func loadData(id: UUID, root: URL? = nil) -> Data? {
        try? Data(contentsOf: fileURL(id: id, root: root))
    }

    static func image(id: UUID, root: URL? = nil) -> NSImage? {
        guard let data = loadData(id: id, root: root) else { return nil }
        return NSImage(data: data)
    }

    static func removeFile(id: UUID, root: URL? = nil) {
        try? FileManager.default.removeItem(at: fileURL(id: id, root: root))
    }

    static func purge(
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

    static func resetDirectory(fileManager: FileManager = .default) {
        try? fileManager.removeItem(at: directory(fileManager: fileManager))
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

@MainActor
enum AttachmentActions {
    static func pickImage(
        ownerKind: AttachmentOwner,
        ownerID: UUID,
        context: ModelContext
    ) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .gif, .tiff, .webP]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            guard let data = try? Data(contentsOf: url) else { return }
            persist {
                _ = try? AttachmentStore.save(
                    data: data,
                    filename: url.lastPathComponent,
                    ownerKind: ownerKind,
                    ownerID: ownerID,
                    context: context
                )
            }
        }
    }

    static func pasteImage(
        ownerKind: AttachmentOwner,
        ownerID: UUID,
        context: ModelContext
    ) -> Bool {
        guard let image = ImageBytes.pasteboardImage(), let data = ImageBytes.png(from: image) else {
            NSSound.beep()
            return false
        }
        persist {
            _ = try? AttachmentStore.save(
                data: data,
                filename: "paste.png",
                ownerKind: ownerKind,
                ownerID: ownerID,
                context: context
            )
        }
        return true
    }

    static func captureScreen(
        ownerKind: AttachmentOwner,
        ownerID: UUID,
        context: ModelContext
    ) {
        Task { @MainActor in
            guard let data = await ScreenCapture.pngData() else { return }
            persist {
                _ = try? AttachmentStore.save(
                    data: data,
                    filename: "screen.png",
                    ownerKind: ownerKind,
                    ownerID: ownerID,
                    context: context
                )
            }
        }
    }

    static func trash(_ item: AttachmentItem) {
        persist { item.deletedAt = .now }
    }

    private static func persist(_ work: () -> Void) {
        work()
        BoardEvents.changed()
    }
}
