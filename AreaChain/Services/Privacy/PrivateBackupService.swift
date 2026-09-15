import Foundation
import SwiftData

@MainActor
enum PrivateBackupService {
    static func export(to url: URL, password: String, environment: PrivacyPersistence,
                       additionalPrivateTags: Set<UUID> = []) async throws -> VerifiedPrivateBackup {
        guard !StoreHealth.shared.isUsingMemoryFallback else { throw PrivacyError.storageFailure }
        if environment.vault.isConfigured { _ = try environment.vault.requireFreshAuthentication() }
        let capture = try PrivateBackupCapture.capture(context: environment.context, vault: environment.vault,
                                                        additionalPrivateTags: additionalPrivateTags)
        let store = environment.attachments
        let root = environment.root
        let result = try await Task.detached(priority: .userInitiated) {
            try PrivateBackupFile.write(capture, password: password, to: url) {
                try store.read(reference: $0, root: root, maximumBytes: VaultCrypto.maximumAttachmentBytes)
            }
        }.value
        let current = try PrivateBackupCapture.capture(context: environment.context, vault: environment.vault)
        guard current.sourceDigest == capture.sourceDigest else { throw PrivacyError.staleOperation }
        return result
    }

    static func inspect(url: URL, password: String) async throws -> PrivateBackupManifest {
        try await Task.detached(priority: .userInitiated) { try PrivateBackupFile.read(from: url, password: password) }.value
    }

    static func restore(from url: URL, password: String, environment: PrivacyPersistence,
                        save: (ModelContext) throws -> Void = { try $0.save() }) async throws {
        guard !StoreHealth.shared.isUsingMemoryFallback else { throw PrivacyError.storageFailure }
        let config = try environment.vault.requireFreshAuthentication()
        let token = environment.vault.generation
        let context = environment.context
        let baseline = try PrivateBackupCapture.capture(context: context, vault: environment.vault, readPrivateContent: false)
        let manifest = try await inspect(url: url, password: password)
        try SnapshotImportState(context: context).validate(manifest.snapshot, privateRestore: true)
        let plan = try RestorePlan(manifest: manifest, context: context, vaultID: config.vaultID)
        let store = environment.attachments
        let root = environment.root
        try await Task.detached(priority: .userInitiated) {
            try plan.stage(from: url, password: password, store: store, root: root)
        }.value
        var committed = false
        do {
            let current = try PrivateBackupCapture.capture(context: context, vault: environment.vault, readPrivateContent: false)
            guard environment.vault.isUnlocked, environment.vault.generation == token, !Task.isCancelled,
                  current.sourceDigest == baseline.sourceDigest else { throw PrivacyError.staleOperation }
            if !plan.privateDiaries.isEmpty { try PrivacyStoreMaintenance.mark(context) }
            try SnapshotImporter.applyDecryptedBackup(manifest.snapshot, context: context, prepare: { context in
                try plan.apply(context: context, vault: environment.vault)
            }, save: save)
            committed = true
            BoardEvents.changed()
            let items = try context.fetch(FetchDescriptor<AttachmentItem>())
            try PrivacyAttachmentBatch.cleanup(items, context: context, store: store, root: root)
            PrivacyStoreMaintenance.request(context)
        } catch {
            if !committed { plan.discard(store: store, root: root) }
            throw error
        }
    }
}

private struct RestorePlan: Sendable {
    struct File: Sendable {
        let id: UUID
        let storageID: UUID
        let previousStorageID: UUID?
        let ownerID: UUID
        let isPrivate: Bool
        let localReference: AttachmentRef?
    }
    let manifest: PrivateBackupManifest
    let privateDiaries: Set<UUID>
    let privateTags: Set<UUID>
    let vaultID: UUID
    let files: [UUID: File]

    @MainActor init(manifest: PrivateBackupManifest, context: ModelContext, vaultID: UUID) throws {
        self.manifest = manifest
        self.vaultID = vaultID
        let state = try SnapshotImportState(context: context)
        guard state.attachments.allSatisfy({ $0.retiredStorageID == nil }) else { throw PrivacyError.storageFailure }
        // 合并恢复不暗中改变本地已有标签的规则，否则备份之外的普通手记也会被重新分类。
        let newPrivateTags = manifest.privateTagIDs.subtracting(state.tags.map(\.id))
        let protectedTags = newPrivateTags.union(state.tags.filter(\.isPrivateDiary).map(\.id))
        privateTags = protectedTags
        let classified = manifest.snapshot.diaries.filter { !protectedTags.isDisjoint(with: TagIDList.parse($0.tagIDs)) }.map(\.id)
        let protectedDiaries = manifest.privateDiaryIDs.union(state.diaries.filter(\.hasProtectedContent).map(\.id)).union(classified)
        privateDiaries = protectedDiaries
        let old = Dictionary(uniqueKeysWithValues: state.attachments.map { ($0.id, $0) })
        var planned = Dictionary(uniqueKeysWithValues: manifest.snapshot.attachments.map { item in
            let existing = old[item.id]
            let privateFile = manifest.privateAttachmentIDs.contains(item.id) || existing?.privacyVaultID != nil
                || (item.ownerKind == AttachmentOwner.diary.rawValue && protectedDiaries.contains(item.ownerID))
            return (item.id, File(id: item.id, storageID: UUID(), previousStorageID: existing.map { $0.storageID ?? $0.id },
                                  ownerID: item.ownerID, isPrivate: privateFile, localReference: nil))
        })
        // 合并恢复保留备份外附件；父手记转为私密时，这些本地图片也必须一并转换。
        for item in state.attachments where planned[item.id] == nil && item.privacyVaultID == nil
            && item.ownerKind == AttachmentOwner.diary.rawValue && protectedDiaries.contains(item.ownerID) {
            planned[item.id] = File(id: item.id, storageID: UUID(), previousStorageID: item.storageID ?? item.id,
                                   ownerID: item.ownerID, isPrivate: true, localReference: item.reference)
        }
        files = planned
    }

    func stage(from url: URL, password: String, store: AttachmentStore, root: URL?) throws {
        do {
            let folder = root ?? store.directory()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let checked = try PrivateBackupFile.read(from: url, password: password) { id, bytes in
                guard let file = files[id] else { throw PrivacyError.corruptData }
                let stored = file.isPrivate
                    ? try PrivateAttachments.encode(bytes, attachmentID: id, ownerID: file.ownerID, vaultID: vaultID, keys: store.keys)
                    : bytes
                try stored.write(to: store.fileURL(id: file.storageID, root: root), options: .atomic)
            }
            guard checked == manifest else { throw PrivacyError.staleOperation }
            for file in files.values {
                guard let reference = file.localReference else { continue }
                try Task.checkCancellation()
                let bytes = try store.read(reference: reference, root: root, maximumBytes: VaultCrypto.maximumAttachmentBytes)
                let stored = try PrivateAttachments.encode(bytes, attachmentID: file.id, ownerID: file.ownerID,
                                                           vaultID: vaultID, keys: store.keys)
                try stored.write(to: store.fileURL(id: file.storageID, root: root), options: .atomic)
            }
        } catch { discard(store: store, root: root); throw error }
    }

    func discard(store: AttachmentStore, root: URL?) {
        files.values.forEach { store.removeFile(id: $0.storageID, root: root) }
    }

    @MainActor func apply(context: ModelContext, vault: PrivacyVault) throws {
        for tag in try context.fetch(FetchDescriptor<TagItem>()) where privateTags.contains(tag.id) {
            tag.isPrivateDiary = true
        }
        let incoming = Set(manifest.snapshot.diaries.map(\.id))
        for entry in try context.fetch(FetchDescriptor<DiaryEntry>()) where incoming.contains(entry.id) {
            if privateDiaries.contains(entry.id) { try DiaryContent.write(entry.text, to: entry, protect: true, vault: vault) }
        }
        for item in try context.fetch(FetchDescriptor<AttachmentItem>()) {
            guard let file = files[item.id] else { continue }
            item.storageID = file.storageID
            item.privacyVaultID = file.isPrivate ? vaultID : nil
            item.retiredStorageID = file.previousStorageID
        }
    }
}
