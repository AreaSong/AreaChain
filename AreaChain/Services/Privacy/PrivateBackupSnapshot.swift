import CryptoKit
import Foundation
import SwiftData

struct BackupAttachmentHeader: Codable, Equatable, Sendable {
    var id: UUID
    var byteCount: Int
    var digest: Data
}

struct PrivateBackupManifest: Codable, Equatable, Sendable {
    var version = 1
    var snapshot: ExportSnapshot
    var privateDiaryIDs: Set<UUID>
    var privateTagIDs: Set<UUID>
    var privateAttachmentIDs: Set<UUID>
    var files: [BackupAttachmentHeader] = []

    func validate() throws {
        guard version == 1 else { throw PrivacyError.unsupportedVersion }
        let diaryIDs = Set(snapshot.diaries.map(\.id))
        let attachmentIDs = Set(snapshot.attachments.map(\.id))
        let groups = [snapshot.routines.map(\.id), snapshot.todos.map(\.id), snapshot.checks.map(\.id),
                      snapshot.diaries.map(\.id), snapshot.tags.map(\.id), snapshot.projects.map(\.id),
                      snapshot.attachments.map(\.id), snapshot.todos.flatMap { $0.subtasks.map(\.id) }]
        guard groups.allSatisfy({ Set($0).count == $0.count }),
              privateDiaryIDs.isSubset(of: diaryIDs),
              privateTagIDs.isSubset(of: Set(snapshot.tags.map(\.id))),
              privateAttachmentIDs.isSubset(of: Set(snapshot.attachments.filter { $0.ownerKind == AttachmentOwner.diary.rawValue }.map(\.id))),
              Set(files.map(\.id)) == attachmentIDs, files.count == attachmentIDs.count,
              files.allSatisfy({ (0...VaultCrypto.maximumAttachmentBytes).contains($0.byteCount) && $0.digest.count == 32 }) else {
            throw PrivacyError.corruptData
        }
    }
}

struct PrivateBackupCapture: Sendable {
    var manifest: PrivateBackupManifest
    var references: [UUID: AttachmentRef]
    var sourceDigest: Data

    @MainActor static func capture(context: ModelContext, vault: PrivacyVault,
                                   additionalPrivateTags: Set<UUID> = [], readPrivateContent: Bool = true) throws -> Self {
        let state = try SnapshotImportState(context: context)
        var snapshot = SyncPort.makeSnapshot(
            routines: state.routines.sorted { $0.id.uuidString < $1.id.uuidString },
            checks: state.checks.sorted { $0.id.uuidString < $1.id.uuidString },
            todos: state.todos.sorted { $0.id.uuidString < $1.id.uuidString }, diaries: [],
            projects: state.projects.sorted { $0.id.uuidString < $1.id.uuidString },
            tags: state.tags.sorted { $0.id.uuidString < $1.id.uuidString })
        snapshot.diaries = try state.diaries.sorted { $0.id.uuidString < $1.id.uuidString }.map {
            ExportedDiary(id: $0.id, text: readPrivateContent ? try DiaryContent.read($0, vault: vault) : $0.text, dayKey: $0.dayKey,
                          createdAt: $0.createdAt, deletedAt: $0.deletedAt, tagIDs: $0.tagIDs, isPinned: $0.isPinned)
        }
        snapshot.attachments = state.attachments.sorted { $0.id.uuidString < $1.id.uuidString }.map {
            ExportedAttachment(id: $0.id, ownerKind: $0.ownerKind, ownerID: $0.ownerID,
                               filename: $0.filename, createdAt: $0.createdAt, deletedAt: $0.deletedAt)
        }
        try state.validate(snapshot, privateRestore: true)
        let privateTags = Set(state.tags.filter(\.isPrivateDiary).map(\.id)).union(additionalPrivateTags)
        let privateIDs = Set(state.diaries.filter {
            $0.hasProtectedContent || !privateTags.isDisjoint(with: TagIDList.parse($0.tagIDs))
                || DiaryPrivacy.isSensitive($0.snapshot, tags: state.tags)
        }.map(\.id))
        let privateAttachments = Set(state.attachments.filter {
            $0.privacyVaultID != nil || ($0.ownerKind == AttachmentOwner.diary.rawValue && privateIDs.contains($0.ownerID))
        }.map(\.id))
        let manifest = PrivateBackupManifest(snapshot: snapshot, privateDiaryIDs: privateIDs,
                                             privateTagIDs: privateTags, privateAttachmentIDs: privateAttachments)
        let digest = try sourceDigest(snapshot: snapshot, state: state)
        return Self(manifest: manifest,
                    references: Dictionary(uniqueKeysWithValues: state.attachments.map { ($0.id, $0.reference) }),
                    sourceDigest: digest)
    }

    private static func sourceDigest(snapshot: ExportSnapshot, state: SnapshotImportState) throws -> Data {
        var stable = snapshot
        stable.exportedAt = Date(timeIntervalSince1970: 0)
        for index in stable.todos.indices { stable.todos[index].subtasks.sort { $0.id.uuidString < $1.id.uuidString } }
        var bytes = try SyncPort.encode(stable)
        let flags = state.tags.filter(\.isPrivateDiary).map { $0.id.uuidString }.sorted()
            + state.diaries.filter(\.hasProtectedContent).map { $0.id.uuidString }.sorted()
            + state.diaries.filter(\.hasProtectedContent).map {
                "\($0.id):\(Data(SHA256.hash(data: $0.encryptedText ?? Data())).base64EncodedString())"
            }.sorted()
            + state.attachments.map { "\($0.id):\($0.storageID?.uuidString ?? ""):\($0.privacyVaultID?.uuidString ?? "")" }.sorted()
        bytes.append(Data(flags.joined(separator: "\n").utf8))
        return Data(SHA256.hash(data: bytes))
    }
}

struct VerifiedPrivateBackup: Sendable {
    let sourceDigest: Data
    let url: URL
    let manifest: PrivateBackupManifest
    let ciphertextDigest: Data
}
