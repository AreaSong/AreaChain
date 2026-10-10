import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchContentBoundaryTests {
    @Test(arguments: [0, 1, 2, 3, 4]) func typedOwnerAndImageIdentitiesFailClosed(_ mode: Int) async throws {
        let f = try UnifiedSearchContentFixture(); defer { f.stop() }
        try await f.query("/images")
        switch mode {
        case 0: f.image.ownerKind = "diary"
        case 1: f.image.ownerKind = "unknown"
        case 2: f.base.todo.deletedAt = .now
        case 3:
            let duplicate = TodoItem(title: "墓碑同 UUID", dayKey: f.base.day)
            duplicate.id = f.base.todo.id; duplicate.deletedAt = .now; f.context.insert(duplicate)
        default:
            let duplicate = AttachmentItem(id: f.image.id, ownerKind: "todo", ownerID: f.base.todo.id, filename: "墓碑")
            duplicate.deletedAt = .now; f.context.insert(duplicate)
        }
        do { try await f.serviceOpen(.init(type: .image, id: f.image.id), parent: .init(type: .todo, id: f.base.todo.id)) }
        catch { #expect(error as? ContentQueryReadSessionError == .stalePermit) }
        #expect(f.content.content == nil)
        #expect(f.base.saves == 0 && f.base.publications == 0)
    }

    @Test func wrongTypedParentRejectedEvenWithMatchingUUIDInAnotherTable() async throws {
        let f = try UnifiedSearchContentFixture(); defer { f.stop() }
        f.diary.id = f.base.todo.id
        try await f.query("/images")
        try await f.serviceOpen(.init(type: .image, id: f.image.id), parent: .init(type: .diary, id: f.base.todo.id))
        #expect(f.content.content == nil && f.content.failure == .invalidTarget)
    }

    @Test(arguments: [0, 1, 2]) func tagIdentityIsNotNameOrStaleUUID(_ mode: Int) async throws {
        let f = try UnifiedSearchContentFixture(); defer { f.stop() }
        try await f.query("/tags")
        switch mode {
        case 0: f.tag.name = "改名"
        case 1: f.tag.deletedAt = .now
        default:
            let tag = TagItem(id: f.tag.id, name: f.tag.name, sortOrder: 1)
            tag.deletedAt = .now; f.context.insert(tag)
        }
        try await f.serviceOpen(.init(type: .tag, id: f.tag.id))
        #expect(f.content.content == nil)
    }

    @Test func presetAndPrivateTagMetadataKeepOriginalDirectoryPolicy() async throws {
        let f = try UnifiedSearchContentFixture(); defer { f.stop() }
        f.tag.name = "密码"; f.tag.isPrivateDiary = true
        try await f.query("/tags")
        try await f.serviceOpen(.init(type: .tag, id: f.tag.id))
        guard case .tag(let tag) = f.content.content else { Issue.record("目录元数据不套写入规则"); return }
        #expect(tag === f.tag && f.bodyProbe.calls == 0)
    }

    @Test func unlockedInjectedVaultStillNeverReadsProtectedBody() async throws {
        let f = try UnifiedSearchContentFixture(); defer { f.stop() }
        // 仅建立合成内存状态，不调用密码/系统认证或保护内容解码。
        let config = PrivacyConfiguration(vaultID: UUID(), systemKeyID: UUID(), verification: Data(repeating: 7, count: 32))
        try f.base.vault.persist(config)
        try f.base.vault.finishAuthentication(Data(repeating: 1, count: 32), configuration: config, token: f.base.vault.generation)
        for _ in 0..<100 where !f.session.isTrackingReady { await Task.yield() }
        f.diary.encryptedText = Data([0, 1, 2]); f.diary.privacyVaultID = config.vaultID
        try await f.query("/diaries")
        try await f.serviceOpen(.init(type: .diary, id: f.diary.id))
        #expect(f.base.vault.isUnlocked && f.content.content == nil)
        #expect(f.bodyProbe.calls == 0)
        f.image.ownerKind = "diary"; f.image.ownerID = f.diary.id
        try await f.query("/images")
        #expect(!(try f.session.presentation().pagination.snapshot.visible).contains(.init(type: .image, id: f.image.id)))
        #expect(f.bodyProbe.calls == 0)
    }

    @Test func missingCatalogAndHostAccessDoNotReadBody() async throws {
        let f = try UnifiedSearchContentFixture(); defer { f.stop() }
        try await f.query("/diaries")
        var reader = f.content.reader
        reader.bodies.tags.allTags = { [] }
        let emptyCatalog = WorkspaceContentSession(reader: reader)
        try await f.serviceOpen(.init(type: .diary, id: f.diary.id), using: emptyCatalog)
        #expect(emptyCatalog.content == nil && f.bodyProbe.calls == 0)
        let deniedReader = WorkspaceContentReader(bodies: f.content.reader.bodies, vault: f.base.vault,
            attachments: f.store, attachmentRoot: f.root,
            navigation: .init(context: f.context, calendar: .current, allows: { _ in false }))
        let denied = WorkspaceContentSession(reader: deniedReader)
        try await f.serviceOpen(.init(type: .diary, id: f.diary.id), using: denied)
        #expect(denied.content == nil && f.bodyProbe.calls == 0)
    }

    @Test func storageIDNotDisplayFilenameDeterminesBytesAndReadingDoesNotModifyFiles() async throws {
        let f = try UnifiedSearchContentFixture(); defer { f.stop() }
        f.image.storageID = UUID(); f.image.filename = "../../不作为路径.png"
        let url = f.store.fileURL(id: f.image.storageID!)
        let original = try UnifiedSearchContentFixture.png()
        try original.write(to: url)
        let names = try FileManager.default.contentsOfDirectory(atPath: f.root.path)
        let dates = try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
        try await f.query("/images")
        try await f.serviceOpen(.init(type: .image, id: f.image.id), parent: .init(type: .todo, id: f.base.todo.id))
        #expect(f.content.content != nil)
        #expect(try Data(contentsOf: url) == original)
        #expect(try FileManager.default.contentsOfDirectory(atPath: f.root.path) == names)
        #expect(try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date == dates)
    }
}
