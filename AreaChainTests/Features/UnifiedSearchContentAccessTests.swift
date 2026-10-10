import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchContentAccessTests {
    @Test func readsFullOrdinaryDiaryWithCurrentCatalogAndNoWrites() async throws {
        let f = try UnifiedSearchContentFixture(); defer { f.stop() }
        try await f.query("/diaries")
        try await f.serviceOpen(.init(type: .diary, id: f.diary.id))
        guard case .diary(let value) = f.content.content else { Issue.record("必须读取全文"); return }
        #expect(value.text == UnifiedSearchContentFixture.text)
        #expect(value.day == f.base.day && value.tags == [f.tag.name])
        #expect(f.bodyProbe.calls == 1 && f.content.validate())
        try f.assertNoWrites()
    }

    @Test(arguments: [0, 1, 2, 3, 4, 5, 6]) func refusesAllProtectionAndIncompleteMetadata(_ mode: Int) async throws {
        let f = try UnifiedSearchContentFixture(); defer { f.stop() }
        switch mode {
        case 0: f.diary.isPrivate = true
        case 1: f.diary.encryptedText = Data([1, 2, 3])
        case 2: f.diary.privacyVaultID = UUID()
        case 3: f.diary.text = "合成旧正文 #PASSWORD"
        case 4: f.tag.isPrivateDiary = true
        case 5:
            f.tag.name = "隐藏"
            f.tag.isPrivateDiary = true; f.tag.deletedAt = .now
            f.diary.tagIDs = ""; f.diary.text = "合成 #\(f.tag.name)"
        default: f.diary.tagIDs = UUID().uuidString
        }
        try await f.query("/diaries")
        try await f.serviceOpen(.init(type: .diary, id: f.diary.id))
        #expect(f.content.content == nil && f.content.failure != nil)
        if mode < 3 || mode == 6 { #expect(f.bodyProbe.calls == 0) }
        #expect(f.base.saves == 0 && f.base.publications == 0)
    }

    @Test(arguments: [0, 1, 2]) func deniesDuplicateTombstoneAndReplacementIdentity(_ mode: Int) async throws {
        let f = try UnifiedSearchContentFixture(); defer { f.stop() }
        try await f.query("/diaries")
        if mode == 0 { f.diary.deletedAt = .now }
        else {
            let duplicate = DiaryEntry(text: "替换实体", dayKey: f.diary.dayKey)
            duplicate.id = f.diary.id
            if mode == 1 { duplicate.deletedAt = .now }
            else { f.context.delete(f.diary) }
            f.context.insert(duplicate)
        }
        try await f.serviceOpen(.init(type: .diary, id: f.diary.id))
        #expect(f.content.content == nil && f.bodyProbe.calls == 0)
    }

    @Test(arguments: [0, 1]) func reentrantBodyMutationNeverPublishes(_ after: Int) async throws {
        let f = try UnifiedSearchContentFixture(); defer { f.stop() }
        try await f.query("/diaries")
        if after == 0 { f.bodyProbe.before = { f.diary.isPrivate = true } }
        else { f.bodyProbe.after = { f.tag.name = "目录已变" } }
        try await f.serviceOpen(.init(type: .diary, id: f.diary.id))
        #expect(f.content.content == nil)
    }

    @Test func contentChangesRevokeAlreadyDisplayedBodySynchronously() async throws {
        let f = try UnifiedSearchContentFixture(); defer { f.stop() }
        try await f.query("/diaries")
        try await f.serviceOpen(.init(type: .diary, id: f.diary.id))
        #expect(f.content.content != nil)
        f.diary.text = "新修订"
        #expect(f.content.content == nil && !f.content.validate())
    }

    @Test(arguments: ["todo", "routine", "diary"]) func decodesOrdinaryImagesForTypedOwners(_ kind: String) async throws {
        let f = try UnifiedSearchContentFixture(); defer { f.stop() }
        f.image.ownerKind = kind
        f.image.ownerID = kind == "todo" ? f.base.todo.id : (kind == "routine" ? f.base.routine.id : f.diary.id)
        try await f.query("/images")
        let owner = CommandObjectReference(type: kind == "todo" ? .todo : (kind == "routine" ? .routine : .diary), id: f.image.ownerID)
        try await f.serviceOpen(.init(type: .image, id: f.image.id), parent: owner)
        guard case .image(let actual, let filename, let actualOwner, _) = f.content.content else {
            Issue.record("必须解码实际图片"); return
        }
        #expect(actual.size == NSSize(width: 320, height: 200))
        #expect(filename == f.image.filename && actualOwner == owner)
        #expect(f.base.saves == 0 && f.base.publications == 0)
    }

    @Test(arguments: [0, 1, 2]) func distinguishesFileFailures(_ mode: Int) async throws {
        let f = try UnifiedSearchContentFixture(); defer { f.stop() }
        let url = f.store.fileURL(id: f.image.id)
        if mode == 0 { f.image.storageID = UUID() }
        else if mode == 1 { try Data("损坏图片".utf8).write(to: url) }
        else { try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: url.path) }
        try await f.query("/images")
        try await f.serviceOpen(.init(type: .image, id: f.image.id), parent: .init(type: .todo, id: f.base.todo.id))
        #expect(f.content.content == nil)
        #expect(f.content.failure == [WorkspaceContentFailure.missingFile, .invalidImage, .unreadableFile][mode])
    }

    @Test func lateImageReadCannotPublishAfterReferenceChange() async throws {
        let f = try UnifiedSearchContentFixture(); defer { f.stop() }
        try await f.query("/images")
        var reader = f.content.reader
        reader.beforeImageRead = { f.image.storageID = UUID() }
        let isolated = WorkspaceContentSession(reader: reader)
        try await f.serviceOpen(.init(type: .image, id: f.image.id), parent: .init(type: .todo, id: f.base.todo.id), using: isolated)
        #expect(isolated.content == nil)
    }

    @Test func encryptedFormatAndNonmatchingRootNeverUsePrivateDecoder() throws {
        let f = try UnifiedSearchContentFixture(); defer { f.stop() }
        try (VaultCrypto.attachmentMagic + Data("synthetic-envelope".utf8)).write(to: f.store.fileURL(id: f.image.id))
        #expect(throws: PrivacyError.corruptData) { try f.store.readOrdinary(reference: f.image.reference, root: f.root) }
        #expect(throws: PrivacyError.corruptData) {
            try f.store.readOrdinary(reference: f.image.reference, root: f.root.appending(path: "other"))
        }
        #expect(throws: PrivacyError.locked) {
            var ref = f.image.reference; ref.privacyVaultID = UUID()
            _ = try f.store.readOrdinary(reference: ref, root: f.root)
        }
    }
}
