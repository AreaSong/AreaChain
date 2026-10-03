import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct ImageContentQueryPrivacyTests {
    @Test func protectedOwnerNeverInvokesBodyReadForImagesEvenWhenUnlocked() async throws {
        let probe = BodyReadProbe()
        let f = try SearchReadFixture(imageMode: true, configure: { $0.observeContent = probe.observe })
        try await f.unlock()
        let entry = try f.protectedDiary("SECRET_BODY_NEVER_FOR_IMAGES")
        // 损坏密文仍保持 protected；图片公开判定不能试解密。
        entry.encryptedText = Data([1, 2, 3])
        let image = f.image(.init(kind: .diary, id: entry.id), name: "HIDDEN_FILENAME.png")
        image.privacyVaultID = UUID()
        let response = try SearchReadFixture.images(await f.publishImages())
        #expect(probe.calls == 1) // 只读取夹具普通种子行。
        #expect(response.matches.isEmpty)
        #expect(response.associations[.init(kind: .diary, id: entry.id)]?.presence == .protected)
        #expect(!TrashQueryFixture.strings(response).contains("HIDDEN_FILENAME"))
    }

    @Test func readableProtectedBodyCanMatchRecordButNeverMakesImagesPublic() async throws {
        let f = try SearchReadFixture(imageMode: true)
        try await f.unlock()
        let entry = try f.protectedDiary("secret-needle")
        f.image(.init(kind: .diary, id: entry.id), name: "secret-needle.png")
        let record = try SearchReadFixture.diaryResponse(await f.publishImages("/diaries secret-needle"))
        #expect(record.matches.map(\.id.id) == [entry.id])
        guard case .hiddenTitle = record.matches[0].presentation else { Issue.record("保护正文泄露"); return }
        let combined = try await f.publishImages("secret-needle")
        #expect(try SearchReadFixture.diaryResponse(combined).matches.map(\.id.id) == [entry.id])
        #expect(try SearchReadFixture.images(combined).matches.isEmpty)
        let filtered = try SearchReadFixture.diaryResponse(await f.publishImages("/diaries secret-needle has:image"))
        #expect(filtered.matches.isEmpty && filtered.undeterminedObjects.contains { $0.id == entry.id })
        let images = try SearchReadFixture.images(await f.publishImages())
        #expect(images.matches.isEmpty && images.associations[.init(kind: .diary, id: entry.id)]?.presence == .protected)
    }

    @Test func legacyMarkersPrivateTagsMissingAndDeletedTagsFailClosed() async throws {
        let f = try SearchReadFixture(imageMode: true)
        let privateTag = f.data.tags.tag("private-name", deleted: TodoQueryFixture.created)
        privateTag.isPrivateDiary = true
        let passwordTag = f.data.tags.tag("password")
        let marker = f.data.diary("ordinary #password")
        let linked = f.data.diary("ordinary"); linked.tagIDs = privateTag.id.uuidString
        let named = f.data.diary("ordinary #private-name")
        let password = f.data.diary("ordinary"); password.tagIDs = passwordTag.id.uuidString
        let missing = f.data.diary("ordinary"); missing.tagIDs = UUID().uuidString
        let invalid = f.data.diary("ordinary"); invalid.tagIDs = "broken-tag-id"
        let publicEntry = f.data.diary("normal public text")
        for row in [marker, linked, named, password, missing, invalid, publicEntry] {
            f.image(.init(kind: .diary, id: row.id), name: row.id == publicEntry.id ? "public.png" : "HIDDEN.png")
        }
        let response = try SearchReadFixture.images(await f.publishImages())
        #expect(response.matches.map(\.owner.id) == [publicEntry.id])
        for row in [marker, linked, named, password, missing, invalid] {
            #expect(response.associations[.init(kind: .diary, id: row.id)]?.presence == .protected)
        }
        #expect(!TrashQueryFixture.strings(response).contains("HIDDEN.png"))
    }

    @Test func protectedZeroOneManyHaveEquivalentPublicShape() async throws {
        let f = try SearchReadFixture(imageMode: true)
        let entry = f.data.diary("unused"); entry.isPrivate = true
        let key = AttachmentOwnerKey(kind: .diary, id: entry.id)
        let zero = try SearchReadFixture.images(await f.publishImages())
        f.image(key, name: "HIDDEN-1.png")
        let one = try SearchReadFixture.images(await f.publishImages())
        let duplicate = f.image(key, name: "HIDDEN-2.png")
        f.image(key, name: "HIDDEN-3.png").id = duplicate.id
        let many = try SearchReadFixture.images(await f.publishImages())
        for value in [one, many] {
            #expect(value.associations == zero.associations)
            #expect(value.associationDiagnostics == zero.associationDiagnostics)
            #expect(value.diagnostics == zero.diagnostics && value.coverage == zero.coverage)
            #expect(value.matches == zero.matches && value.undeterminedObjects == zero.undeterminedObjects)
            #expect(!TrashQueryFixture.strings(value).contains("HIDDEN"))
        }
    }

    @Test func duplicateDiaryIsIsolatedBeforeAnyBodyRead() async throws {
        let probe = BodyReadProbe()
        let f = try SearchReadFixture(imageMode: true, configure: { $0.observeContent = probe.observe })
        let first = f.data.diary("DO_NOT_READ")
        let second = f.data.diary("DO_NOT_READ", deleted: TodoQueryFixture.created); second.id = first.id
        f.image(.init(kind: .diary, id: first.id), name: "HIDDEN.png")
        let response = try SearchReadFixture.images(await f.publishImages())
        #expect(probe.calls == 1 && response.matches.isEmpty)
        #expect(response.associations[.init(kind: .diary, id: first.id)]?.ownerState == .ambiguous)
    }
}
