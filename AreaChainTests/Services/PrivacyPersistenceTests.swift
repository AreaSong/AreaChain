import AppKit
import CryptoKit
import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor
struct PrivacyFixture {
    let container: ModelContainer
    let vault: PrivacyVault
    let files: AttachmentStore
    let root: URL
    var context: ModelContext { container.mainContext }
    var environment: PrivacyPersistence { PrivacyPersistence(context: context, vault: vault, attachments: files, root: root) }
    var repository: SwiftDataDiaryRepository {
        SwiftDataDiaryRepository(context: context, vault: vault, attachmentStore: files, attachmentRoot: root)
    }

    static func make(password: String = "fixture-master-password") async throws -> Self {
        let container = try ModelContainer(for: Schema(AreaChainSchema.models),
                                            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys())
        try await vault.create(password: password, systemUnlock: false)
        let root = FileManager.default.temporaryDirectory.appending(path: "AreaChain-private-test-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return Self(container: container, vault: vault, files: AttachmentStore(keys: vault.keys, root: root), root: root)
    }

    func tag(private protected: Bool = true) throws -> TagItem {
        let tag = TagItem(name: "私人", sortOrder: 0)
        tag.isPrivateDiary = protected
        context.insert(tag)
        try context.save()
        return tag
    }

    func image(owner: DiaryEntry, data: Data = Data("synthetic-image-bytes".utf8)) throws -> AttachmentItem {
        let item = try files.save(data: data, filename: "fixture.png", ownerKind: .diary,
                                  ownerID: owner.id, context: context, root: root)
        try context.save()
        return item
    }

    func cleanup() { try? FileManager.default.removeItem(at: root) }
}

@Suite(.serialized) @MainActor
struct PrivacyPersistenceTests {
    private let secret = "SYNTHETIC_PRIVATE_NOTE_SENTINEL_47"

    @Test func privateTagEncryptsBodyAndProtectionSurvivesRenameAndRemoval() async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        let tag = try f.tag()
        let note = try f.repository.addDiary(text: secret, dayKey: "2026-09-15", tagIDs: [tag.id])
        #expect(note.text.isEmpty && note.isPrivate && note.encryptedText != nil)
        #expect(try DiaryContent.read(note, vault: f.vault) == secret)
        let reader = ModelContext(f.container)
        #expect(try reader.fetch(FetchDescriptor<DiaryEntry>()).first?.text == "")
        f.vault.lock()
        #expect(throws: PrivacyError.locked) { try DiaryContent.read(note, vault: f.vault) }
        #expect(try f.repository.searchDiaries(query: secret).isEmpty)
        #expect(try f.repository.searchDiaries(query: "#私人").map(\.id) == [note.id])
        try await f.vault.unlockWithPassword("fixture-master-password")
        #expect(try f.repository.searchDiaries(query: secret).map(\.id) == [note.id])
        let catalog = SwiftDataCatalogRepository(context: f.context)
        try catalog.updateTag(id: tag.id, name: "改名", sortOrder: nil)
        try f.repository.toggleTag(id: note.id, tagID: tag.id)
        try catalog.deleteTag(id: tag.id, soft: false)
        #expect(note.hasProtectedContent && note.tagIDs.isEmpty)
        #expect(try DiaryContent.read(note, vault: f.vault) == secret)
    }

    @Test func lockedWritesNeverFallBackToPlaintextAndRollbackNewTags() async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        let tag = try f.tag()
        f.vault.lock()
        #expect(throws: PrivacyError.locked) {
            try f.repository.addDiary(text: secret + " #新标签", dayKey: "2026-09-15", tagIDs: [tag.id])
        }
        #expect(try f.context.fetchCount(FetchDescriptor<DiaryEntry>()) == 0)
        #expect(try f.context.fetchCount(FetchDescriptor<TagItem>()) == 1)
    }

    @Test func privateImagesAreEncryptedAndCannotBeReadByIDWhileLocked() async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        let tag = try f.tag()
        let note = try f.repository.addDiary(text: secret, dayKey: "2026-09-15", tagIDs: [tag.id])
        let bytes = Data("SYNTHETIC_PRIVATE_IMAGE_SENTINEL".utf8)
        let item = try f.image(owner: note, data: bytes)
        let raw = try Data(contentsOf: f.files.fileURL(id: item.id, root: f.root))
        #expect(raw.starts(with: VaultCrypto.attachmentMagic))
        #expect(raw.range(of: bytes) == nil)
        #expect(try f.files.read(reference: item.reference, root: f.root) == bytes)
        #expect(throws: PrivacyError.corruptData) {
            try f.files.read(reference: AttachmentRef(id: item.id, filename: "forged.png"), root: f.root)
        }
        var wrongKind = item.reference
        wrongKind.ownerKind = "todo"
        #expect(throws: PrivacyError.corruptData) { try f.files.read(reference: wrongKind, root: f.root) }
        f.vault.lock()
        #expect(f.files.loadData(id: item.id, root: f.root) == nil)
        #expect(throws: PrivacyError.locked) { try f.files.read(reference: item.reference, root: f.root) }
        let todo = TodoItem(id: note.id, title: "公开任务", dayKey: "2026-09-15")
        f.context.insert(todo)
        let publicImage = try f.files.save(data: bytes, filename: "public.png", ownerKind: .todo,
                                           ownerID: todo.id, context: f.context, root: f.root)
        try f.context.save()
        #expect(f.files.loadData(id: publicImage.id, root: f.root) == bytes)
    }

    @Test func outerTransactionFailureKeepsOriginalImagesAndRemovesStagedCiphertext() async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        let tag = try f.tag()
        let note = try f.repository.addDiary(text: "原文", dayKey: "2026-09-15", tagIDs: [])
        let image = try f.image(owner: note)
        let original = try f.files.read(reference: image.reference, root: f.root)
        #expect(throws: CocoaError.self) {
            try ModelChanges.transaction(in: f.context, save: { _ in throw CocoaError(.fileWriteNoPermission) }) {
                try f.repository.toggleTag(id: note.id, tagID: tag.id)
            }
        }
        #expect(note.text == "原文" && !note.hasProtectedContent && note.tagIDs.isEmpty)
        #expect(image.storageID == nil && image.privacyVaultID == nil)
        #expect(try f.files.read(reference: image.reference, root: f.root) == original)
        #expect(try FileManager.default.contentsOfDirectory(atPath: f.root.path) == [image.id.uuidString])
        try f.repository.toggleTag(id: note.id, tagID: tag.id)
        #expect(note.hasProtectedContent && image.privacyVaultID != nil && image.storageID != nil)
        #expect(!FileManager.default.fileExists(atPath: f.files.fileURL(id: image.id, root: f.root).path))
        #expect(try f.files.read(reference: image.reference, root: f.root) == original)
    }

    @Test func jsonExportAndImportCannotBypassPrivateRecordsOrOwners() async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        let tag = try f.tag()
        let note = try f.repository.addDiary(text: secret, dayKey: "2026-09-15", tagIDs: [tag.id])
        let image = try f.image(owner: note)
        let publicNote = try f.repository.addDiary(text: "公开手记", dayKey: "2026-09-15", tagIDs: [])
        let snapshot = SyncPort.makeSnapshot(routines: [], checks: [], todos: [], diaries: [note, publicNote],
                                              tags: [tag], attachments: [image])
        #expect(snapshot.diaries.map(\.id) == [publicNote.id] && snapshot.attachments.isEmpty)
        #expect(String(decoding: try SyncPort.encode(snapshot), as: UTF8.self).contains(secret) == false)
        var attack = snapshot
        attack.diaries.append(ExportedDiary(id: note.id, text: "覆盖", dayKey: note.dayKey, createdAt: note.createdAt))
        #expect(throws: PrivacyError.privateImport) { try SnapshotImporter.validate(attack, context: f.context) }
        #expect(throws: PrivacyError.privateImport) { try SnapshotImporter.apply(attack, context: f.context) }
        attack = snapshot
        attack.attachments.append(ExportedAttachment(id: UUID(), ownerKind: "diary", ownerID: note.id,
                                                     filename: "bypass.png", createdAt: .now))
        #expect(throws: PrivacyError.privateImport) { try SnapshotImporter.apply(attack, context: f.context) }
        #expect(try DiaryContent.read(note, vault: f.vault) == secret)
    }

    @Test func anotherConversionCannotForgetAnUncleanedPlaintextAttachment() async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        let tag = try f.tag()
        let note = try f.repository.addDiary(text: secret, dayKey: "2026-09-15", tagIDs: [tag.id])
        let image = try f.image(owner: note)
        let retiredID = UUID()
        try f.repository.toggleTag(id: note.id, tagID: tag.id)
        let retiredURL = f.files.fileURL(id: retiredID, root: f.root)
        try Data("RETIRED_PLAINTEXT_SENTINEL".utf8).write(to: retiredURL)
        image.retiredStorageID = retiredID
        try f.context.save()
        #expect(throws: PrivacyError.storageFailure) { try DiaryProtection.unprotect(note, in: f.environment) }
        #expect(note.hasProtectedContent && image.retiredStorageID == retiredID)
        #expect(FileManager.default.fileExists(atPath: retiredURL.path))
        try PrivacyAttachmentBatch.cleanup([image], context: f.context, store: f.files, root: f.root)
        try DiaryProtection.unprotect(note, in: f.environment)
        #expect(!note.hasProtectedContent && image.privacyVaultID == nil)
        #expect(!FileManager.default.fileExists(atPath: retiredURL.path))
    }

    @Test func editorSealsUnsavedDraftAndRequiresUnlockBeforeSaveOrReveal() async throws {
        let f = try await PrivacyFixture.make()
        defer { f.cleanup() }
        let tag = try f.tag()
        let note = try f.repository.addDiary(text: secret, dayKey: "2026-09-15", tagIDs: [tag.id])
        let editor = DiaryEditorSession(source: .entry(note), context: f.context, vault: f.vault)
        editor.reveal()
        editor.text += " 新草稿"
        f.vault.lock()
        #expect(editor.text.isEmpty && editor.hasUnsavedChanges && !editor.canRevealContent)
        editor.reveal()
        #expect(!editor.canRevealContent && !editor.save())
        try await f.vault.unlockWithPassword("fixture-master-password")
        #expect(editor.text == secret + " 新草稿" && !editor.canRevealContent)
        editor.reveal()
        #expect(editor.save())
        #expect(note.text.isEmpty && !editor.hasUnsavedChanges)
        #expect(try DiaryContent.read(note, vault: f.vault) == secret + " 新草稿")
    }

    @Test func protectedClipboardExpiresOnlyOurCurrentCopy() {
        let board = NSPasteboard(name: .init("areachain.private-tests.\(UUID())"))
        defer { board.clearContents() }
        #expect(PrivateClipboard.copy(secret, sensitive: true, to: board))
        #expect(board.pasteboardItems?.count == 1)
        #expect(board.pasteboardItems?.first?.types.contains(NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")) == true)
        #expect(board.pasteboardItems?.first?.types.contains(NSPasteboard.PasteboardType("org.nspasteboard.TransientType")) == true)
        let token = board.string(forType: PrivateClipboard.marker)!
        let count = board.changeCount
        board.clearContents()
        board.setString("后来复制的内容", forType: .string)
        PrivateClipboard.expire(board, token: token, changeCount: count)
        #expect(board.string(forType: .string) == "后来复制的内容")
        #expect(PrivateClipboard.copy(secret, sensitive: true, to: board))
        PrivateClipboard.expire(board, token: board.string(forType: PrivateClipboard.marker)!, changeCount: board.changeCount)
        #expect(board.string(forType: .string) == nil)
    }

    @Test func passwordDerivationMatchesIndependentPBKDF2Vector() throws {
        let key = try VaultCrypto.deriveKey(password: "test-vector-password", salt: Data(0..<32), iterations: 600_000)
        let hex = key.withUnsafeBytes { $0.map { String(format: "%02x", $0) }.joined() }
        #expect(hex == "180876f8e432a9d9f315de26fc49e78b13ef1b1641c5f50844909c45ccfb9e51")
    }
}
