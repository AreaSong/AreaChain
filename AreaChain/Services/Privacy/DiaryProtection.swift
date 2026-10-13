import Foundation
import SwiftData

@MainActor
struct PrivacyPersistence {
    let context: ModelContext
    let vault: PrivacyVault
    let attachments: AttachmentStore
    let root: URL?

    init(context: ModelContext, vault: PrivacyVault? = nil, attachments: AttachmentStore = .shared, root: URL? = nil) {
        self.context = context
        self.vault = vault ?? .shared
        self.attachments = attachments
        self.root = root
    }
}

@MainActor
enum DiaryProtection {
    private struct TagPlan {
        let tagIDs: Set<UUID>
        let tags: [TagItem]
        let entries: [DiaryEntry]
        let attachments: [AttachmentItem]
    }
    static func candidates(tagIDs: Set<UUID>, context: ModelContext, includeLegacy: Bool = false) throws -> [DiaryEntry] {
        let tags = try context.fetch(FetchDescriptor<TagItem>())
        return try context.fetch(FetchDescriptor<DiaryEntry>()).filter {
            !$0.hasProtectedContent && (!tagIDs.isDisjoint(with: TagIDList.parse($0.tagIDs))
                || (includeLegacy && (DiaryPrivacy.isSensitive($0.snapshot, tags: tags)
                    || DiaryPrivacy.hasLegacyPrivateMarker($0.text))))
        }
    }

    static func setTagsPrivacy(
        _ tagIDs: Set<UUID>,
        isPrivate: Bool,
        in environment: PrivacyPersistence,
        save: (ModelContext) throws -> Void = { try $0.save() }
    ) throws {
        _ = try environment.vault.requireFreshAuthentication()
        let tags = try environment.context.fetch(FetchDescriptor<TagItem>())
        guard !tagIDs.isEmpty, tagIDs.isSubset(of: Set(tags.map(\.id))) else {
            throw PrivacyError.staleOperation
        }
        if isPrivate {
            try authorizeTags(tagIDs, tags: tags, in: environment, save: save)
        } else {
            try revokeTags(tagIDs, tags: tags, in: environment, save: save)
        }
    }

    private static func authorizeTags(
        _ tagIDs: Set<UUID>,
        tags: [TagItem],
        in environment: PrivacyPersistence,
        save: (ModelContext) throws -> Void
    ) throws {
        let context = environment.context
        let entries = try context.fetch(FetchDescriptor<DiaryEntry>()).filter {
            !$0.hasProtectedContent && !tagIDs.isDisjoint(with: TagIDList.parse($0.tagIDs))
        }
        let owners = Set(entries.map(\.id))
        let attachments = try context.fetch(FetchDescriptor<AttachmentItem>()).filter {
            $0.ownerKind == AttachmentOwner.diary.rawValue && owners.contains($0.ownerID)
        }
        if !entries.isEmpty { try PrivacyStoreMaintenance.mark(context) }
        let batch = PrivacyAttachmentBatch(store: environment.attachments, root: environment.root)
        try batch.prepare(attachments, vault: environment.vault)
        do {
            try ModelChanges.transaction(in: context, save: save) {
                attachEffects(batch, items: attachments, environment: environment)
                for entry in entries {
                    try DiaryContent.write(entry.text, to: entry, protect: true, vault: environment.vault)
                }
                for tag in tags where tagIDs.contains(tag.id) { tag.isPrivateDiary = true }
                batch.apply()
            }
        } catch { batch.rollback(); throw error }
        environment.vault.changed()
    }

    private static func revokeTags(
        _ tagIDs: Set<UUID>,
        tags: [TagItem],
        in environment: PrivacyPersistence,
        save: (ModelContext) throws -> Void
    ) throws {
        let context = environment.context
        let remainingPrivateIDs = Set(tags.filter { $0.isPrivateDiary && !tagIDs.contains($0.id) }.map(\.id))
        let entries = try context.fetch(FetchDescriptor<DiaryEntry>()).filter { entry in
            let entryTagIDs = TagIDList.parse(entry.tagIDs)
            return entry.hasProtectedContent
                && !tagIDs.isDisjoint(with: entryTagIDs)
                && remainingPrivateIDs.isDisjoint(with: entryTagIDs)
        }
        let decrypted = try entries.map { (entry: $0, text: try DiaryContent.read($0, vault: environment.vault)) }
        let owners = Set(entries.map(\.id))
        let attachments = try context.fetch(FetchDescriptor<AttachmentItem>()).filter {
            $0.ownerKind == AttachmentOwner.diary.rawValue && owners.contains($0.ownerID)
        }
        let batch = PrivacyAttachmentBatch(store: environment.attachments, root: environment.root)
        try batch.prepare(attachments, vault: environment.vault, protecting: false)
        do {
            try ModelChanges.transaction(in: context, save: save) {
                attachEffects(batch, items: attachments, environment: environment)
                for item in decrypted {
                    item.entry.text = item.text
                    item.entry.encryptedText = nil
                    item.entry.privacyVaultID = nil
                    DiaryPrivacy.assign(item.entry, isPrivate: false)
                }
                for tag in tags where tagIDs.contains(tag.id) { tag.isPrivateDiary = false }
                batch.apply()
            }
        } catch { batch.rollback(); throw error }
        environment.vault.changed()
    }

    static func applyTags(_ tagIDs: Set<UUID>, in environment: PrivacyPersistence,
                          backup: VerifiedPrivateBackup? = nil,
                          includeLegacy: Bool = false,
                          save: (ModelContext) throws -> Void = { try $0.save() }) throws {
        let plan = try tagPlan(tagIDs, environment: environment, includeLegacy: includeLegacy)
        if !plan.entries.isEmpty { try verifyBackup(backup, tagIDs: tagIDs, environment: environment) }
        let batch = PrivacyAttachmentBatch(store: environment.attachments, root: environment.root)
        let hashes = backup.map { Dictionary(uniqueKeysWithValues: $0.manifest.files.map { ($0.id, $0.digest) }) }
        if !plan.entries.isEmpty { try PrivacyStoreMaintenance.mark(environment.context) }
        try batch.prepare(plan.attachments, vault: environment.vault, expectedDigests: hashes)
        try commit(plan, batch: batch, environment: environment, save: save)
    }

    static func applyTagsAsync(_ tagIDs: Set<UUID>, in environment: PrivacyPersistence,
                               backup: VerifiedPrivateBackup? = nil, includeLegacy: Bool = false) async throws {
        let plan = try tagPlan(tagIDs, environment: environment, includeLegacy: includeLegacy)
        let token = environment.vault.generation
        let baseline = try PrivateBackupCapture.capture(context: environment.context, vault: environment.vault)
        if !plan.entries.isEmpty {
            guard let backup, tagIDs.isSubset(of: backup.manifest.privateTagIDs) else { throw PrivacyError.requiresBackup }
            guard baseline.sourceDigest == backup.sourceDigest else { throw PrivacyError.staleOperation }
            let digest = try await PrivacyTask.detached { try PrivateBackupFile.digest(backup.url) }
            guard digest == backup.ciphertextDigest else { throw PrivacyError.staleOperation }
            try PrivacyStoreMaintenance.mark(environment.context)
        }
        let batch = PrivacyAttachmentBatch(store: environment.attachments, root: environment.root)
        let hashes = backup.map { Dictionary(uniqueKeysWithValues: $0.manifest.files.map { ($0.id, $0.digest) }) }
        do {
            try await batch.prepareAsync(plan.attachments, vault: environment.vault, expectedDigests: hashes)
            try PrivacyTask.checkCancellation()
            let current = try PrivateBackupCapture.capture(context: environment.context, vault: environment.vault)
            guard environment.vault.generation == token, environment.vault.isUnlocked,
                  current.sourceDigest == baseline.sourceDigest else { throw PrivacyError.staleOperation }
            try commit(plan, batch: batch, environment: environment, save: { try $0.save() })
        } catch {
            batch.rollback()
            if error is CancellationError { throw PrivacyError.cancelled }
            throw error
        }
    }

    static func unprotect(_ entry: DiaryEntry, context: ModelContext) throws {
        try unprotect(entry, in: PrivacyPersistence(context: context))
    }

    static func unprotect(_ entry: DiaryEntry, in environment: PrivacyPersistence) throws {
        let context = environment.context
        _ = try environment.vault.requireFreshAuthentication()
        let tags = try context.fetch(FetchDescriptor<TagItem>())
        guard !DiaryContent.requiresProtection(tagIDs: entry.tagIDs, tags: tags) else { throw PrivacyError.privateImport }
        let text = try DiaryContent.read(entry, vault: environment.vault)
        let items = try context.fetch(FetchDescriptor<AttachmentItem>()).filter {
            $0.ownerKind == AttachmentOwner.diary.rawValue && $0.ownerID == entry.id
        }
        let batch = PrivacyAttachmentBatch(store: environment.attachments, root: environment.root)
        try batch.prepare(items, vault: environment.vault, protecting: false)
        do {
            try ModelChanges.transaction(in: context) {
                attachEffects(batch, items: items, environment: environment)
                entry.text = text
                entry.encryptedText = nil
                entry.privacyVaultID = nil
                DiaryPrivacy.assign(entry, isPrivate: false)
                batch.apply()
            }
        } catch { batch.rollback(); throw error }
    }

    private static func verifyBackup(_ backup: VerifiedPrivateBackup?, tagIDs: Set<UUID>,
                                      environment: PrivacyPersistence) throws {
        guard let backup, tagIDs.isSubset(of: backup.manifest.privateTagIDs) else { throw PrivacyError.requiresBackup }
        let current = try PrivateBackupCapture.capture(context: environment.context, vault: environment.vault)
        guard current.sourceDigest == backup.sourceDigest,
              try PrivateBackupFile.digest(backup.url) == backup.ciphertextDigest else { throw PrivacyError.staleOperation }
    }

    private static func tagPlan(_ ids: Set<UUID>, environment: PrivacyPersistence, includeLegacy: Bool) throws -> TagPlan {
        _ = try environment.vault.requireFreshAuthentication()
        let context = environment.context
        let tags = try context.fetch(FetchDescriptor<TagItem>())
        guard ids.isSubset(of: Set(tags.map(\.id))) else { throw PrivacyError.staleOperation }
        let entries = try candidates(tagIDs: ids, context: context, includeLegacy: includeLegacy)
        let owners = Set(entries.map(\.id))
        let attachments = try context.fetch(FetchDescriptor<AttachmentItem>()).filter {
            $0.ownerKind == AttachmentOwner.diary.rawValue && owners.contains($0.ownerID)
        }
        return TagPlan(tagIDs: ids, tags: tags, entries: entries, attachments: attachments)
    }

    private static func commit(_ plan: TagPlan, batch: PrivacyAttachmentBatch, environment: PrivacyPersistence,
                               save: (ModelContext) throws -> Void) throws {
        do {
            try ModelChanges.transaction(in: environment.context, save: save) {
                attachEffects(batch, items: plan.attachments, environment: environment)
                for entry in plan.entries { try DiaryContent.write(entry.text, to: entry, protect: true, vault: environment.vault) }
                for tag in plan.tags { tag.isPrivateDiary = plan.tagIDs.contains(tag.id) }
                batch.apply()
            }
        } catch { batch.rollback(); throw error }
        environment.vault.changed()
    }

    private static func attachEffects(_ batch: PrivacyAttachmentBatch, items: [AttachmentItem],
                                      environment: PrivacyPersistence) {
        ModelChanges.afterTransaction(in: environment.context, commit: {
            try PrivacyAttachmentBatch.cleanup(items, context: environment.context,
                                               store: environment.attachments, root: environment.root)
            PrivacyStoreMaintenance.request(environment.context)
        }, rollback: { batch.rollback() })
    }
}
