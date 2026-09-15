import Foundation
import SwiftData
import CryptoKit

/// 先写新的密文文件，提交元数据后才允许清理原文件。数据库失败时原图始终可用。
@MainActor
final class PrivacyAttachmentBatch {
    struct Change {
        let item: AttachmentItem
        let storageID: UUID
        let originalID: UUID
        let vaultID: UUID?
    }
    private(set) var changes: [Change] = []
    let store: AttachmentStore
    let root: URL?

    init(store: AttachmentStore = .shared, root: URL? = nil) {
        self.store = store
        self.root = root
    }

    func prepare(_ attachments: [AttachmentItem], vault: PrivacyVault, protecting: Bool = true,
                 expectedDigests: [UUID: Data]? = nil) throws {
        guard vault.isUnlocked, let vaultID = vault.configuration?.vaultID else { throw PrivacyError.locked }
        let input = try inputs(attachments, protecting: protecting)
        let options = AttachmentStaging.Options(vaultID: vaultID, keys: vault.keys, protecting: protecting, expectedDigests: expectedDigests)
        let files = try AttachmentStaging.write(input.values, options: options, store: store, root: root)
        accept(files, models: input.models)
    }

    func prepareAsync(_ attachments: [AttachmentItem], vault: PrivacyVault,
                      expectedDigests: [UUID: Data]? = nil) async throws {
        guard vault.isUnlocked, let vaultID = vault.configuration?.vaultID else { throw PrivacyError.locked }
        let input = try inputs(attachments, protecting: true)
        let values = input.values
        let options = AttachmentStaging.Options(vaultID: vaultID, keys: vault.keys, protecting: true, expectedDigests: expectedDigests)
        let store = store, root = root
        let files = try await Task.detached(priority: .userInitiated) {
            try AttachmentStaging.write(values, options: options, store: store, root: root)
        }.value
        accept(files, models: input.models)
    }

    private func inputs(_ items: [AttachmentItem], protecting: Bool) throws
        -> (values: [AttachmentStaging.Input], models: [UUID: AttachmentItem]) {
        guard Set(items.map(\.id)).count == items.count else { throw PrivacyError.corruptData }
        // 前一次清理失败时保留原始文件指针，不能用下一代转换覆盖它。
        guard items.allSatisfy({ $0.retiredStorageID == nil }) else { throw PrivacyError.storageFailure }
        let selected = items.filter { protecting ? $0.privacyVaultID == nil : $0.privacyVaultID != nil }
        let values = selected.map {
            AttachmentStaging.Input(reference: $0.reference, ownerID: $0.ownerID, ownerKind: $0.ownerKind)
        }
        return (values, Dictionary(uniqueKeysWithValues: selected.map { ($0.id, $0) }))
    }

    private func accept(_ files: [AttachmentStaging.Output], models: [UUID: AttachmentItem]) {
        changes = files.compactMap { file in
            models[file.id].map { Change(item: $0, storageID: file.storageID,
                                         originalID: file.originalID, vaultID: file.vaultID) }
        }
    }

    func apply() {
        for change in changes {
            change.item.storageID = change.storageID
            change.item.privacyVaultID = change.vaultID
            change.item.retiredStorageID = change.originalID
        }
    }

    func rollback() {
        for change in changes { store.removeFile(id: change.storageID, root: root) }
        changes = []
    }

    /// 失败会保留退休文件的标识，后续可重试，不能把清理失败当成迁移完成。
    static func cleanup(_ items: [AttachmentItem], context: ModelContext,
                        store: AttachmentStore = .shared, root: URL? = nil) throws {
        let retired = items.filter { $0.retiredStorageID != nil }
        for item in retired {
            guard let id = item.retiredStorageID, id != item.storageID else { throw PrivacyError.corruptData }
            let url = store.fileURL(id: id, root: root)
            do { try FileManager.default.removeItem(at: url) }
            catch let error as CocoaError where error.code == .fileNoSuchFile {}
            item.retiredStorageID = nil
        }
        if !retired.isEmpty { try context.save() }
    }
}

private enum AttachmentStaging {
    struct Input: Sendable {
        let reference: AttachmentRef
        let ownerID: UUID
        let ownerKind: String
    }
    struct Options: Sendable {
        let vaultID: UUID
        let keys: VaultKeyAccess
        let protecting: Bool
        let expectedDigests: [UUID: Data]?
    }
    struct Output: Sendable {
        let id: UUID
        let storageID: UUID
        let originalID: UUID
        let vaultID: UUID?
    }

    static func write(_ inputs: [Input], options: Options, store: AttachmentStore, root: URL?) throws -> [Output] {
        var written: [Output] = []
        do {
            for input in inputs {
                try Task.checkCancellation()
                guard input.ownerKind == AttachmentOwner.diary.rawValue else { throw PrivacyError.corruptData }
                let ref = input.reference
                let raw = try store.read(reference: ref, root: root, maximumBytes: VaultCrypto.maximumAttachmentBytes)
                if let expected = options.expectedDigests, expected[ref.id] != Data(SHA256.hash(data: raw)) {
                    throw PrivacyError.staleOperation
                }
                let bytes = options.protecting
                    ? try PrivateAttachments.encode(raw, attachmentID: ref.id, ownerID: input.ownerID,
                                                    vaultID: options.vaultID, keys: options.keys) : raw
                let id = UUID()
                try FileManager.default.createDirectory(at: root ?? store.directory(), withIntermediateDirectories: true)
                try bytes.write(to: store.fileURL(id: id, root: root), options: .atomic)
                written.append(Output(id: ref.id, storageID: id, originalID: ref.storageID ?? ref.id,
                                       vaultID: options.protecting ? options.vaultID : nil))
            }
            return written
        } catch {
            written.forEach { store.removeFile(id: $0.storageID, root: root) }
            throw error
        }
    }
}
