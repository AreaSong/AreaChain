import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TrashContentQueryPrivacyTests {
    @Test func partialDiaryEnumerationAndDuplicateTagCatalogDoNotEstablishProtection() async throws {
        var partial = true
        let probe = BodyReadProbe()
        let f = try SearchReadFixture.trash(configure: { reads in
            let original = reads.diaries
            reads.diaries = {
                let source = try original()
                return partial ? .partial(source.values ?? []) : source
            }
        }, bodies: { $0.observeContent = probe.observe })
        let entry = f.data.diary("PUBLIC_LOOKING", deleted: TodoQueryFixture.created)
        let result = try SearchReadFixture.trashResponse(await f.publishTrash("/trash PUBLIC_LOOKING"))
        #expect(result.matches.isEmpty && result.typeCoverage[.diary] == .partial)
        #expect(probe.calls == 0)
        partial = false
        let tag = f.data.tags.tag("one")
        f.data.tags.tag("two", id: tag.id, deleted: TodoQueryFixture.created)
        let duplicate = try SearchReadFixture.trashResponse(await f.publishTrash("/trash PUBLIC_LOOKING"))
        #expect(duplicate.matches.isEmpty && duplicate.undeterminedObjects.contains { $0.id == entry.id })
        #expect(probe.calls == 0)
    }

    @Test func publicTombstoneReadsRealBodyAndProtectedNeverDecryptsWhenUnlocked() async throws {
        let probe = BodyReadProbe()
        let f = try SearchReadFixture.trash(bodies: { $0.observeContent = probe.observe })
        try await f.unlock()
        let date = TodoQueryFixture.created
        let ordinary = f.data.diary("PUBLIC_TOMBSTONE_NEEDLE", deleted: date)
        let encrypted = try f.protectedDiary("PROTECTED_TOMBSTONE_NEEDLE")
        encrypted.deletedAt = date
        encrypted.encryptedText = Data([1, 2, 3]) // 无效密文也不能进入解密 API。
        f.image(.init(kind: .diary, id: encrypted.id), name: "HIDDEN_IMAGE.png", deleted: date)
        let result = try SearchReadFixture.trashResponse(await f.publishTrash("/trash NEEDLE"))
        #expect(result.matches.map(\.id.id) == [ordinary.id])
        #expect(result.undeterminedObjects.contains { $0.id == encrypted.id })
        #expect(probe.calls == 2) // 初始活普通拥有者 + 普通墓碑，保护墓碑零次。
        let strings = TrashQueryFixture.strings(result)
        #expect(!strings.contains("PROTECTED_TOMBSTONE_NEEDLE") && !strings.contains("SYNTHETIC_RAW_FALLBACK_FORBIDDEN"))
        #expect(!strings.contains("HIDDEN_IMAGE.png"))
        #expect(encrypted.text == "SYNTHETIC_RAW_FALLBACK_FORBIDDEN" && encrypted.encryptedText == Data([1, 2, 3]))
    }

    @Test(arguments: ["#password OLD_SECRET", "#密码 OLD_SECRET", "#private OLD_SECRET"])
    func legacySensitivePlaintextRemainsUnknownWithoutConversion(text: String) async throws {
        let f = try SearchReadFixture.trash()
        let tag = f.data.tags.tag("private", deleted: TodoQueryFixture.created); tag.isPrivateDiary = true
        let entry = f.data.diary(text, deleted: TodoQueryFixture.created)
        f.image(.init(kind: .diary, id: entry.id), name: "LEGACY.png", deleted: TodoQueryFixture.created)
        let result = try SearchReadFixture.trashResponse(await f.publishTrash("/trash OLD_SECRET"))
        #expect(result.matches.isEmpty && result.undeterminedObjects.contains { $0.id == entry.id })
        #expect(!TrashQueryFixture.strings(result).contains(text))
        #expect(!TrashQueryFixture.strings(result).contains("LEGACY.png"))
        #expect(entry.text == text && entry.encryptedText == nil && !entry.hasProtectedContent)
    }

    @Test(arguments: [0, 1, 2, 3]) func insufficientTagAndBodyFactsCannotTurnExclusionsIntoMatches(mode: Int) async throws {
        let f = try SearchReadFixture.trash(configure: { reads in
            if mode == 0 { reads.tags = { .notProvided } }
            if mode == 1 { reads.tags = { .partial([]) } }
        }, bodies: { reads in
            if mode == 2 { reads.observeContent = { _ in throw TrashContentQueryCoverageTests.Failure.syntheticDatabaseMessageMustNotEscape } }
        })
        let entry = f.data.diary("ordinary secret", deleted: TodoQueryFixture.created)
        if mode == 3 { entry.tagIDs = UUID().uuidString }
        let result = try SearchReadFixture.trashResponse(await f.publishTrash("/trash -absent", types: [.diary]))
        #expect(result.matches.isEmpty)
        #expect(result.undeterminedObjects.contains { $0.id == entry.id })
        #expect(result.diagnostics.contains { $0.object?.id == entry.id && $0.issue == .unreadableBody })
        #expect(!TrashQueryFixture.strings(result).contains("ordinary secret"))
    }

    @Test func associatedPrivateTagAndDuplicateIdentityBlockBodyRead() async throws {
        let probe = BodyReadProbe()
        let f = try SearchReadFixture.trash(bodies: { $0.observeContent = probe.observe })
        let date = TodoQueryFixture.created
        let tag = f.data.tags.tag("private", deleted: date); tag.isPrivateDiary = true
        let entry = f.data.diary("PRIVATE_TAG_BODY", deleted: date); entry.tagIDs = tag.id.uuidString
        let duplicate = f.data.diary("DUPLICATE_BODY", deleted: date)
        f.data.diary("live collision").id = duplicate.id
        let normal = f.data.diary("PUBLIC_BODY", deleted: date)
        let result = try SearchReadFixture.trashResponse(await f.publishTrash("/trash BODY"))
        #expect(result.matches.map(\.id.id) == [normal.id])
        #expect(result.readingDiagnostics.contains { $0.object?.id == duplicate.id && $0.issue == .duplicateIdentity })
        #expect(!TrashQueryFixture.strings(result).contains("PRIVATE_TAG_BODY"))
    }

    @Test func deletedPublicDiaryOwnerAllowsImageMetadataWithoutPublishingAuxiliaryBody() async throws {
        let f = try SearchReadFixture.trash()
        let entry = f.data.diary("AUXILIARY_BODY_NOT_FOR_IMAGES", deleted: TodoQueryFixture.created)
        let image = f.image(.init(kind: .diary, id: entry.id), deleted: TodoQueryFixture.created)
        let result = try SearchReadFixture.trashResponse(await f.publishTrash(types: [.image]))
        #expect(result.matches.map(\.id.id) == [image.id])
        #expect(result.matches.first?.object.relation == .cascaded(parent: .init(type: .diary, id: entry.id)))
        #expect(result.matches.first?.object.restoration.independent == .requiresLiveOwner(.init(type: .diary, id: entry.id)))
        #expect(!TrashQueryFixture.strings(result).contains("AUXILIARY_BODY_NOT_FOR_IMAGES"))
    }

    @Test func zeroOneManyHiddenImagesDoNotChangePublicCountsDiagnosticsOrIdentities() async throws {
        let f = try SearchReadFixture.trash()
        let entry = f.data.diary("HIDDEN_BODY", deleted: TodoQueryFixture.created)
        entry.isPrivate = true
        let baseline = try SearchReadFixture.trashResponse(await f.publishTrash())
        for index in 0..<3 {
            let image = f.image(.init(kind: .diary, id: entry.id), name: "HIDDEN_\(index).png", deleted: TodoQueryFixture.created)
            let result = try SearchReadFixture.trashResponse(await f.publishTrash())
            #expect(result.matches == baseline.matches && result.groups == baseline.groups)
            #expect(result.readingDiagnostics == baseline.readingDiagnostics && result.diagnostics == baseline.diagnostics)
            #expect(result.undeterminedObjects == baseline.undeterminedObjects && result.nonmatchingObjects == baseline.nonmatchingObjects)
            #expect(result.typeCoverage == baseline.typeCoverage)
            #expect(!TrashQueryFixture.strings(result).contains(image.id.uuidString))
            #expect(!TrashQueryFixture.strings(result).contains(image.filename))
        }
    }

    @Test func hiddenCrossOwnerImageCollisionSuppressesPublicDetails() async throws {
        let f = try SearchReadFixture.trash()
        let date = TodoQueryFixture.created
        let task = f.data.tags.family.task.todo(deleted: date)
        let diary = f.data.diary("hidden", deleted: date); diary.isPrivate = true
        let hidden = f.image(.init(kind: .diary, id: diary.id), deleted: date)
        let publicImage = f.image(.init(kind: .todo, id: task.id), name: "MUST_NOT_LEAK.png", deleted: date)
        publicImage.id = hidden.id
        let result = try SearchReadFixture.trashResponse(await f.publishTrash())
        #expect(!result.matches.contains { $0.id.type == .image })
        #expect(!result.readingDiagnostics.contains { $0.object?.type == .image })
        #expect(!TrashQueryFixture.strings(result).contains("MUST_NOT_LEAK.png"))
    }
}
