import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct PrivateBackupTests {
    private let backupPassword = "independent-backup-passphrase"

    @Test func asynchronousTagProtectionCommitsPreparedImages() async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        let tag = try f.tag(private: false)
        let note = try f.repository.addDiary(text: "异步转换", dayKey: "2026-09-15", tagIDs: [tag.id])
        let bytes = Data(repeating: 0x5a, count: 1_024 * 1_024)
        let image = try f.image(owner: note, data: bytes)
        let url = f.root.appending(path: "async.areachainbackup")
        let proof = try await PrivateBackupService.export(to: url, password: backupPassword, environment: f.environment,
                                                          additionalPrivateTags: [tag.id])
        try await DiaryProtection.applyTagsAsync([tag.id], in: f.environment, backup: proof)
        #expect(note.hasProtectedContent && tag.isPrivateDiary)
        #expect(try f.files.read(reference: image.reference, root: f.root) == bytes)
        #expect(!FileManager.default.fileExists(atPath: f.files.fileURL(id: image.id, root: f.root).path))
    }

    @Test func mergingBackupDoesNotReclassifyUnrelatedLocalNotes() async throws {
        let source = try await PrivacyFixture.make()
        let destination = try await PrivacyFixture.make()
        defer { source.cleanup(); destination.cleanup() }
        let sourceTag = try source.tag()
        let protected = try source.repository.addDiary(text: "备份私密内容", dayKey: "2026-09-15", tagIDs: [sourceTag.id])
        let localTag = TagItem(id: sourceTag.id, name: "本地分类", sortOrder: 0)
        destination.context.insert(localTag)
        try destination.context.save()
        let local = try destination.repository.addDiary(text: "备份外的本地普通内容", dayKey: "2026-09-15", tagIDs: [localTag.id])
        let url = source.root.appending(path: "merge.areachainbackup")
        _ = try await PrivateBackupService.export(to: url, password: backupPassword, environment: source.environment)
        try await PrivateBackupService.restore(from: url, password: backupPassword, environment: destination.environment)
        #expect(!localTag.isPrivateDiary && !local.hasProtectedContent)
        #expect(try DiaryContent.read(local, vault: destination.vault) == "备份外的本地普通内容")
        #expect(try destination.repository.fetchDiary(id: protected.id)?.hasProtectedContent == true)
    }

    @Test func restoringPrivateNoteAlsoProtectsExistingLocalImagesOutsideTheBackup() async throws {
        let source = try await PrivacyFixture.make()
        let destination = try await PrivacyFixture.make()
        defer { source.cleanup(); destination.cleanup() }
        let tag = try source.tag()
        let note = try source.repository.addDiary(text: "恢复后的私密正文", dayKey: "2026-09-15", tagIDs: [tag.id])
        let local = DiaryEntry(id: note.id, text: "本地普通正文", dayKey: note.dayKey)
        destination.context.insert(local)
        let bytes = Data("LOCAL_IMAGE_OUTSIDE_BACKUP_SENTINEL".utf8)
        let image = try destination.image(owner: local, data: bytes)
        let trashed = try destination.image(owner: local, data: bytes)
        trashed.deletedAt = .now
        try destination.context.save()
        let url = source.root.appending(path: "merge-local-images.areachainbackup")
        _ = try await PrivateBackupService.export(to: url, password: backupPassword, environment: source.environment)
        try await PrivateBackupService.restore(from: url, password: backupPassword, environment: destination.environment)
        #expect(local.hasProtectedContent)
        for item in [image, trashed] {
            #expect(item.privacyVaultID == destination.vault.configuration?.vaultID)
            #expect(try destination.files.read(reference: item.reference, root: destination.root) == bytes)
            #expect(!FileManager.default.fileExists(atPath: destination.files.fileURL(id: item.id, root: destination.root).path))
        }
        destination.vault.lock()
        for item in [image, trashed] {
            #expect(throws: PrivacyError.locked) { try destination.files.read(reference: item.reference, root: destination.root) }
            let stored = try Data(contentsOf: destination.files.fileURL(id: item.storageID ?? item.id, root: destination.root))
            #expect(stored.range(of: bytes) == nil)
        }
    }

    @Test func oversizedFrameIsRejectedBeforeAllocatingItsPayload() async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        let url = f.root.appending(path: "oversized.areachainbackup")
        try (PrivateBackupFile.magic + Data(repeating: 0xff, count: 8)).write(to: url)
        #expect(throws: PrivacyError.corruptData) { try PrivateBackupFile.read(from: url, password: backupPassword) }
    }

    @Test func encryptedBackupRestoresImagesAndPrivateNotesUnderANewKey() async throws {
        let source = try await PrivacyFixture.make()
        let destination = try await PrivacyFixture.make(password: "different-device-master-password")
        defer { source.cleanup(); destination.cleanup() }
        let tag = try source.tag()
        let privateNote = try source.repository.addDiary(text: "PRIVATE_BACKUP_SENTINEL", dayKey: "2026-09-15", tagIDs: [tag.id])
        let publicNote = try source.repository.addDiary(text: "普通手记", dayKey: "2026-09-15", tagIDs: [])
        let image = try source.image(owner: privateNote, data: Data("private-image".utf8))
        let publicImage = try source.image(owner: publicNote, data: Data("public-image".utf8))
        source.context.insert(TodoItem(title: "普通任务", dayKey: "2026-09-15"))
        try source.context.save()
        let url = source.root.appending(path: "portable.areachainbackup")
        let proof = try await PrivateBackupService.export(to: url, password: backupPassword, environment: source.environment)
        #expect(proof.manifest.files.count == 2)
        let raw = try Data(contentsOf: url)
        #expect(raw.starts(with: PrivateBackupFile.magic))
        #expect(raw.range(of: Data("PRIVATE_BACKUP_SENTINEL".utf8)) == nil)
        try await PrivateBackupService.restore(from: url, password: backupPassword, environment: destination.environment)
        let restored = try #require(try destination.repository.fetchDiary(id: privateNote.id))
        #expect(restored.text.isEmpty && restored.hasProtectedContent)
        #expect(restored.privacyVaultID == destination.vault.configuration?.vaultID)
        #expect(restored.privacyVaultID != source.vault.configuration?.vaultID)
        #expect(try DiaryContent.read(restored, vault: destination.vault) == "PRIVATE_BACKUP_SENTINEL")
        #expect(try destination.repository.fetchDiary(id: publicNote.id)?.text == "普通手记")
        #expect(try destination.context.fetch(FetchDescriptor<TodoItem>()).first?.title == "普通任务")
        let restoredImages = try destination.context.fetch(FetchDescriptor<AttachmentItem>())
        let privateRef = try #require(restoredImages.first { $0.id == image.id }).reference
        let publicRef = try #require(restoredImages.first { $0.id == publicImage.id }).reference
        #expect(try destination.files.read(reference: privateRef, root: destination.root) == Data("private-image".utf8))
        destination.vault.lock()
        #expect(throws: PrivacyError.locked) { try destination.files.read(reference: privateRef, root: destination.root) }
        #expect(try destination.files.read(reference: publicRef, root: destination.root) == Data("public-image".utf8))
    }

    @Test func verifiedBackupIsRequiredAndStaleBackupCannotAuthorizeMigration() async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        let tag = try f.tag(private: false)
        let note = try f.repository.addDiary(text: "准备保护的原文", dayKey: "2026-09-15", tagIDs: [tag.id])
        let image = try f.image(owner: note)
        #expect(throws: PrivacyError.requiresBackup) {
            try DiaryProtection.applyTags([tag.id], in: f.environment)
        }
        let url = f.root.appending(path: "migration.areachainbackup")
        let stale = try await PrivateBackupService.export(to: url, password: backupPassword, environment: f.environment,
                                                           additionalPrivateTags: [tag.id])
        try f.repository.editDiary(id: note.id, text: "备份之后的新内容")
        #expect(throws: PrivacyError.staleOperation) {
            try DiaryProtection.applyTags([tag.id], in: f.environment, backup: stale)
        }
        #expect(!note.hasProtectedContent && !tag.isPrivateDiary && image.privacyVaultID == nil)
        let current = try await PrivateBackupService.export(to: url, password: backupPassword, environment: f.environment,
                                                             additionalPrivateTags: [tag.id])
        try DiaryProtection.applyTags([tag.id], in: f.environment, backup: current)
        #expect(note.hasProtectedContent && tag.isPrivateDiary && image.privacyVaultID != nil)
        #expect(try DiaryContent.read(note, vault: f.vault) == "备份之后的新内容")
        try DiaryProtection.applyTags([], in: f.environment)
        #expect(!tag.isPrivateDiary && note.hasProtectedContent)
        try DiaryProtection.unprotect(note, in: f.environment)
        #expect(!note.hasProtectedContent && note.text == "备份之后的新内容")
        #expect(image.privacyVaultID == nil)
    }

    @Test func missingImageOrWrongBackupPasswordDoesNotMutateNotes() async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        let tag = try f.tag(private: false)
        let note = try f.repository.addDiary(text: "#密码 OLD_PRIVATE_MARKER", dayKey: "2026-09-15", tagIDs: [])
        let url = f.root.appending(path: "legacy.areachainbackup")
        let proof = try await PrivateBackupService.export(to: url, password: backupPassword, environment: f.environment,
                                                           additionalPrivateTags: [tag.id])
        await #expect(throws: PrivacyError.wrongPassword) {
            try await PrivateBackupService.inspect(url: url, password: "wrong-password")
        }
        #expect(!note.hasProtectedContent)
        try DiaryProtection.applyTags([tag.id], in: f.environment, backup: proof, includeLegacy: true)
        #expect(note.hasProtectedContent)
        let missing = AttachmentItem(ownerKind: "diary", ownerID: note.id, filename: "missing.png")
        f.context.insert(missing)
        try f.context.save()
        let failedURL = f.root.appending(path: "missing.areachainbackup")
        await #expect(throws: (any Error).self) {
            try await PrivateBackupService.export(to: failedURL, password: backupPassword, environment: f.environment)
        }
        #expect(!FileManager.default.fileExists(atPath: failedURL.path))
        #expect(try DiaryContent.read(note, vault: f.vault) == "#密码 OLD_PRIVATE_MARKER")
    }

    @Test func restoreWithWrongPasswordDoesNotMutateDestination() async throws {
        let source = try await PrivacyFixture.make()
        let destination = try await PrivacyFixture.make()
        defer { source.cleanup(); destination.cleanup() }
        let tag = try source.tag()
        let note = try source.repository.addDiary(text: "备份内容", dayKey: "2026-09-15", tagIDs: [tag.id])
        _ = try source.image(owner: note)
        let url = source.root.appending(path: "restore.areachainbackup")
        _ = try await PrivateBackupService.export(to: url, password: backupPassword, environment: source.environment)
        let existing = DiaryEntry(id: note.id, text: "目的地原文", dayKey: "2026-09-15")
        destination.context.insert(existing)
        try destination.context.save()
        await #expect(throws: PrivacyError.wrongPassword) {
            try await PrivateBackupService.restore(
                from: url, password: "wrong-password", environment: destination.environment
            )
        }
        #expect(existing.text == "目的地原文" && !existing.hasProtectedContent)
        #expect(try destination.context.fetchCount(FetchDescriptor<DiaryEntry>()) == 1)
    }

    @Test func corruptBackupAndFailedRestoreKeepDestinationAndItsFiles() async throws {
        let source = try await PrivacyFixture.make()
        let destination = try await PrivacyFixture.make()
        defer { source.cleanup(); destination.cleanup() }
        let tag = try source.tag()
        let note = try source.repository.addDiary(text: "备份内容", dayKey: "2026-09-15", tagIDs: [tag.id])
        _ = try source.image(owner: note)
        let url = source.root.appending(path: "restore.areachainbackup")
        _ = try await PrivateBackupService.export(to: url, password: backupPassword, environment: source.environment)
        let existing = DiaryEntry(id: note.id, text: "目的地原文", dayKey: "2026-09-15")
        destination.context.insert(existing)
        let existingImage = try destination.image(owner: existing, data: Data("destination-image".utf8))
        let existingBytes = try destination.files.read(reference: existingImage.reference, root: destination.root)
        await #expect(throws: CocoaError.self) {
            try await PrivateBackupService.restore(from: url, password: backupPassword, environment: destination.environment,
                                                    save: { _ in throw CocoaError(.fileWriteNoPermission) })
        }
        #expect(existing.text == "目的地原文" && !existing.hasProtectedContent)
        #expect(try destination.files.read(reference: existingImage.reference, root: destination.root) == existingBytes)
        #expect(try FileManager.default.contentsOfDirectory(atPath: destination.root.path) == [existingImage.id.uuidString])
        var damaged = try Data(contentsOf: url)
        damaged[damaged.count - 1] ^= 1
        let broken = source.root.appending(path: "corrupt.areachainbackup")
        try damaged.write(to: broken)
        await #expect(throws: PrivacyError.corruptData) {
            try await PrivateBackupService.restore(from: broken, password: backupPassword, environment: destination.environment)
        }
        #expect(existing.text == "目的地原文")
    }

    @Test func failedConversionRollsBackPrivacyFlagsAndOriginalAttachment() async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        let tag = try f.tag(private: false)
        let note = try f.repository.addDiary(text: "未转换原文", dayKey: "2026-09-15", tagIDs: [tag.id])
        let image = try f.image(owner: note)
        let url = f.root.appending(path: "rollback.areachainbackup")
        let proof = try await PrivateBackupService.export(to: url, password: backupPassword, environment: f.environment,
                                                           additionalPrivateTags: [tag.id])
        #expect(throws: CocoaError.self) {
            try DiaryProtection.applyTags([tag.id], in: f.environment, backup: proof,
                                           save: { _ in throw CocoaError(.fileWriteNoPermission) })
        }
        #expect(note.text == "未转换原文" && !note.hasProtectedContent && !tag.isPrivateDiary)
        #expect(image.privacyVaultID == nil && image.storageID == nil)
        #expect(try f.files.read(reference: image.reference, root: f.root) == Data("synthetic-image-bytes".utf8))
        let files = try FileManager.default.contentsOfDirectory(atPath: f.root.path)
        #expect(Set(files) == [image.id.uuidString, url.lastPathComponent])
    }

    @Test func cancelledBackupWriteLeavesExistingDestinationUntouched() async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        let tag = try f.tag()
        let note = try f.repository.addDiary(text: "取消导出原文", dayKey: "2026-09-15", tagIDs: [tag.id])
        let imageBytes = Data(repeating: 0x11, count: 64 * 1024)
        let image = try f.image(owner: note, data: imageBytes)
        let originalText = note.text
        let originalProtected = note.hasProtectedContent
        let url = f.root.appending(path: "keep.areachainbackup")
        let sentinel = Data("EXISTING_BACKUP_SENTINEL".utf8)
        try sentinel.write(to: url)
        let capture = try PrivateBackupCapture.capture(context: f.context, vault: f.vault)
        let files = f.files
        let root = f.root
        let password = backupPassword
        let gate = CancelGate(allowPasses: 1)
        let task = Task.detached {
            try PrivateBackupFile.write(capture, password: password, to: url) { reference in
                try gate.blockUntilCancelled()
                return try files.read(reference: reference, root: root, maximumBytes: VaultCrypto.maximumAttachmentBytes)
            }
        }
        try await Task.detached { try gate.waitUntilWorkStarted() }.value
        task.cancel()
        await #expect(throws: PrivacyError.cancelled) { try await task.value }
        #expect(try Data(contentsOf: url) == sentinel)
        #expect(note.text == originalText && note.hasProtectedContent == originalProtected)
        #expect(try f.files.read(reference: image.reference, root: f.root) == imageBytes)
    }

    @Test func cancelledBackupReadStopsInAttachmentCallback() async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        let tag = try f.tag()
        let note = try f.repository.addDiary(text: "取消回读原文", dayKey: "2026-09-15", tagIDs: [tag.id])
        let imageBytes = Data(repeating: 0x55, count: 32 * 1024)
        let image = try f.image(owner: note, data: imageBytes)
        let originalText = note.text
        let originalProtected = note.hasProtectedContent
        let url = f.root.appending(path: "read-cancel.areachainbackup")
        _ = try await PrivateBackupService.export(to: url, password: backupPassword, environment: f.environment)
        let original = try Data(contentsOf: url)
        let gate = CancelGate()
        let password = backupPassword
        let task = Task.detached {
            try PrivateBackupFile.read(from: url, password: password) { _, _ in
                try gate.blockUntilCancelled()
            }
        }
        try await Task.detached { try gate.waitUntilWorkStarted() }.value
        task.cancel()
        await #expect(throws: PrivacyError.cancelled) { try await task.value }
        #expect(try Data(contentsOf: url) == original)
        #expect(note.text == originalText && note.hasProtectedContent == originalProtected)
        #expect(try f.files.read(reference: image.reference, root: f.root) == imageBytes)
    }

    @Test func cancelledExportDoesNotReplaceExistingBackup() async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        let tag = try f.tag()
        let note = try f.repository.addDiary(text: "取消服务导出", dayKey: "2026-09-15", tagIDs: [tag.id])
        _ = try f.image(owner: note, data: Data(repeating: 0x22, count: 64 * 1024))
        let url = f.root.appending(path: "export-keep.areachainbackup")
        let sentinel = Data("EXISTING_SERVICE_BACKUP_SENTINEL".utf8)
        try sentinel.write(to: url)
        let task = Task {
            try await PrivateBackupService.export(to: url, password: backupPassword, environment: f.environment)
        }
        task.cancel()
        await expectCancellation { _ = try await task.value }
        #expect(try Data(contentsOf: url) == sentinel)
    }

    @Test func cancelledRestoreDoesNotMutateDestinationNotes() async throws {
        let source = try await PrivacyFixture.make()
        let destination = try await PrivacyFixture.make()
        defer { source.cleanup(); destination.cleanup() }
        let tag = try source.tag()
        let note = try source.repository.addDiary(text: "不应写入目的地", dayKey: "2026-09-15", tagIDs: [tag.id])
        let url = source.root.appending(path: "cancel-restore.areachainbackup")
        _ = try await PrivateBackupService.export(to: url, password: backupPassword, environment: source.environment)
        let local = try destination.repository.addDiary(text: "目的地原文", dayKey: "2026-09-15", tagIDs: [])
        let task = Task {
            try await PrivateBackupService.restore(from: url, password: backupPassword, environment: destination.environment)
        }
        task.cancel()
        await expectCancellation { try await task.value }
        #expect(try destination.repository.fetchDiary(id: local.id)?.text == "目的地原文")
        #expect(try destination.repository.fetchDiary(id: note.id) == nil)
        #expect(!local.hasProtectedContent)
    }

    @Test func cancelledAttachmentPrepareLeavesOriginalFile() async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        let tag = try f.tag(private: false)
        let note = try f.repository.addDiary(text: "暂存取消", dayKey: "2026-09-15", tagIDs: [tag.id])
        let image = try f.image(owner: note, data: Data(repeating: 0x33, count: 32 * 1024))
        let original = try f.files.read(reference: image.reference, root: f.root)
        let batch = PrivacyAttachmentBatch(store: f.files, root: f.root)
        let task = Task {
            try await batch.prepareAsync([image], vault: f.vault)
        }
        task.cancel()
        await expectCancellation { try await task.value }
        #expect(image.storageID == nil && image.privacyVaultID == nil && image.retiredStorageID == nil)
        #expect(try f.files.read(reference: image.reference, root: f.root) == original)
        #expect(try FileManager.default.contentsOfDirectory(atPath: f.root.path) == [image.id.uuidString])
    }

    @Test func cancelledTagProtectionLeavesOriginalNoteAndFile() async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        let tag = try f.tag(private: false)
        let note = try f.repository.addDiary(text: "取消转换原文", dayKey: "2026-09-15", tagIDs: [tag.id])
        let image = try f.image(owner: note, data: Data(repeating: 0x44, count: 16 * 1024))
        let original = try f.files.read(reference: image.reference, root: f.root)
        let url = f.root.appending(path: "cancel-convert.areachainbackup")
        let proof = try await PrivateBackupService.export(
            to: url, password: backupPassword, environment: f.environment, additionalPrivateTags: [tag.id]
        )
        let task = Task {
            try await DiaryProtection.applyTagsAsync([tag.id], in: f.environment, backup: proof)
        }
        task.cancel()
        await expectCancellation { try await task.value }
        #expect(note.text == "取消转换原文" && !note.hasProtectedContent && !tag.isPrivateDiary)
        #expect(image.storageID == nil && image.privacyVaultID == nil && image.retiredStorageID == nil)
        #expect(try f.files.read(reference: image.reference, root: f.root) == original)
        #expect(Set(try FileManager.default.contentsOfDirectory(atPath: f.root.path)) == [image.id.uuidString, url.lastPathComponent])
    }

    private func expectCancellation(_ work: () async throws -> Void) async {
        do {
            try await work()
            Issue.record("expected cancellation")
        } catch is CancellationError {
            return
        } catch let error as PrivacyError where error == .cancelled {
            return
        } catch {
            Issue.record("unexpected \(error)")
        }
    }
}
