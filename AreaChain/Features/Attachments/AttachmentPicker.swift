import AppKit
import Foundation
import SwiftData
import UniformTypeIdentifiers

@MainActor
enum AttachmentPicker {
    static func pickImage(
        ownerKind: AttachmentOwner, ownerID: UUID, context: ModelContext,
        store: any AttachmentStorageProtocol = AttachmentStore.shared,
        canAttach: @escaping () -> Bool = { true }
    ) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .gif, .tiff, .webP]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url, canAttach() else { return }
            do {
                let data = try Data(contentsOf: url)
                _ = saveImage(data: data, filename: url.lastPathComponent,
                              owner: AttachmentOwnerKey(kind: ownerKind, id: ownerID), context: context, store: store)
            } catch {
                MutationFeedback.shared.reportFailure(error)
            }
        }
    }

    @discardableResult
    static func pasteImage(
        ownerKind: AttachmentOwner, ownerID: UUID, context: ModelContext,
        store: any AttachmentStorageProtocol = AttachmentStore.shared,
        pasteboard: NSPasteboard = .general
    ) -> Bool {
        guard let image = ImageBytes.pasteboardImage(pasteboard), let data = ImageBytes.png(from: image) else {
            NSSound.beep()
            return false
        }
        return saveImage(data: data, filename: "paste.png",
                         owner: AttachmentOwnerKey(kind: ownerKind, id: ownerID), context: context, store: store)
    }

    /// 文件和元数据属于同一次捕获；写入失败时清理仅属于本次操作的新文件。
    @discardableResult
    static func saveImage(
        data: Data, filename: String, owner: AttachmentOwnerKey, context: ModelContext,
        store: any AttachmentStorageProtocol = AttachmentStore.shared
    ) -> Bool {
        let id = UUID()
        let saved = ModelChanges.perform(in: context) {
            guard NSImage(data: data) != nil, try ownerIsLive(owner, context: context) else {
                throw RepositoryError.invalidArgument("附件拥有者不可用，或图像无法解码")
            }
            _ = try store.save(data: data, filename: filename, ownerKind: owner.kind,
                               ownerID: owner.id, context: context, id: id)
        }
        if !saved { store.removeFile(id: id) }
        return saved
    }

    static func captureScreen(
        ownerKind: AttachmentOwner, ownerID: UUID, context: ModelContext,
        store: any AttachmentStorageProtocol = AttachmentStore.shared
    ) {
        Task { @MainActor in
            switch await ScreenCapture.pngData() {
            case .success(let data):
                _ = saveImage(data: data, filename: "screen.png",
                              owner: AttachmentOwnerKey(kind: ownerKind, id: ownerID), context: context, store: store)
            case .failure(let failure):
                NSSound.beep()
                let alert = NSAlert()
                alert.messageText = L10n.string(
                    String.LocalizationValue(stringLiteral: failure.messageKey),
                    locale: AppPreferences.shared.resolvedLocale
                )
                alert.alertStyle = .informational
                alert.runModal()
            }
        }
    }

    @discardableResult
    static func trash(_ item: AttachmentItem) -> Bool {
        DayBoardMutations.persist(context: item.modelContext) { item.deletedAt = .now }
    }

    private static func ownerIsLive(_ owner: AttachmentOwnerKey, context: ModelContext) throws -> Bool {
        switch owner.kind {
        case .todo:
            return try context.fetch(FetchDescriptor<TodoItem>()).contains { $0.id == owner.id && $0.deletedAt == nil }
        case .routine:
            return try context.fetch(FetchDescriptor<DailyRoutine>()).contains { $0.id == owner.id && $0.deletedAt == nil }
        case .diary:
            return try context.fetch(FetchDescriptor<DiaryEntry>()).contains { $0.id == owner.id && $0.deletedAt == nil }
        }
    }
}

typealias AttachmentActions = AttachmentPicker
