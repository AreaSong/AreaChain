import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct ContentQueryBodyReadTests {
    @Test func unconfiguredOrdinaryBodyMatchesAndHasSafeSummary() async throws {
        let f = try SearchReadFixture(bodyMode: true)
        let row = f.data.diary("Synthetic heading\nordinary body needle")
        let result = try await f.publishBodies("/diaries needle")
        let diary = try SearchReadFixture.diaryResponse(result)
        #expect(diary.matches.map(\.id.id) == [row.id])
        guard case .publicText(let text, let evidence) = diary.matches[0].presentation else {
            Issue.record("普通正文没有公开投影"); return
        }
        #expect(text == row.text && !evidence.isEmpty)
        let presentation = result.pagination.snapshot.source
        #expect(presentation.rows[0].summary != nil)
        #expect(!f.vault.isConfigured && !f.vault.isAuthenticating)
        #expect(await f.system.items.isEmpty)
        let title = try await f.publishBodies("/diaries heading")
        #expect(try SearchReadFixture.diaryResponse(title).matches.map(\.id.id) == [row.id])
    }

    @Test func protectedMatchHasNoBodyEvidenceSummaryExpansionOrBodyRank() async throws {
        let f = try SearchReadFixture(bodyMode: true)
        try await f.unlock()
        let row = try f.protectedDiary("needle SYNTHETIC_PROTECTED_CONTENT")
        let original = row.encryptedText
        let result = try await f.publishBodies("/diaries needle")
        let diary = try SearchReadFixture.diaryResponse(result)
        #expect(diary.matches.map(\.id.id) == [row.id])
        guard case .hiddenTitle = diary.matches[0].presentation else { Issue.record("私密结果泄露"); return }
        #expect(diary.matches[0].metadataEvidence.allSatisfy { $0.field == .scope && $0.range == nil })
        let rendered = try #require(result.pagination.snapshot.source.rows.first)
        #expect(rendered.summary == nil && rendered.expansion.isEmpty && !rendered.canRequestExpansion)
        #expect(rendered.primary?.mapping == nil && rendered.primary?.highlights.isEmpty == true)
        let strings = TrashQueryFixture.strings(result)
        #expect(!strings.contains("SYNTHETIC_PROTECTED_CONTENT"))
        #expect(!String(reflecting: result).contains("SYNTHETIC_PROTECTED_CONTENT"))
        let rank = result.pagination.snapshot.source.source.ordered
        row.encryptedText = try f.vault.keys.seal(Data("needle needle\nSYNTHETIC_PROTECTED_CONTENT".utf8),
            vaultID: #require(f.vault.configuration).vaultID, context: "diary:\(row.id.uuidString)")
        try f.session.modelDidChange(expecting: f.lease.ownership)
        let changed = try await f.publishBodies("/diaries needle")
        #expect(changed.pagination.snapshot.source.source.ordered == rank)
        #expect(row.encryptedText != original && row.text == "SYNTHETIC_RAW_FALLBACK_FORBIDDEN")
    }

    @Test func lockedProtectedUnknownAndOrdinaryReadable() async throws {
        let f = try SearchReadFixture(bodyMode: true)
        try await f.unlock()
        let protected = try f.protectedDiary("needle")
        let ordinary = f.data.diary("needle ordinary")
        f.vault.lock()
        await f.settle()
        try f.handoff.send(.query(.enterPage(QuerySessionFixture.page(.diaries(tagID: nil), host: HandoffFixture.source))))
        let result = try await f.publishBodies("/diaries needle")
        let diary = try SearchReadFixture.diaryResponse(result)
        #expect(diary.matches.map(\.id.id) == [ordinary.id])
        #expect(diary.undeterminedObjects.contains { $0.id == protected.id })
        let exclusion = try SearchReadFixture.diaryResponse(await f.publishBodies("/diaries -absent"))
        #expect(!exclusion.matches.contains { $0.id.id == protected.id })
        #expect(exclusion.undeterminedObjects.contains { $0.id == protected.id })
    }

    @Test func legacySensitivePlaintextAndUnknownProtectionNeverBecomeReadableFacts() async throws {
        let f = try SearchReadFixture(bodyMode: true)
        let marker = f.data.diary("needle #password")
        let tag = f.data.tags.tag("private-category")
        tag.isPrivateDiary = true
        let linked = f.data.diary("needle"); linked.tagIDs = tag.id.uuidString
        let named = f.data.diary("needle #private-category")
        let missing = f.data.diary("needle"); missing.tagIDs = UUID().uuidString
        let flag = f.data.diary("needle"); flag.isPrivate = true
        let result = try SearchReadFixture.diaryResponse(await f.publishBodies("/diaries needle"))
        #expect(result.matches.isEmpty)
        for row in [marker, linked, named, missing, flag] {
            #expect(result.undeterminedObjects.contains { $0.id == row.id })
            #expect(row.text.contains("needle"))
        }
    }

    @Test func corruptWrongOwnerMissingCipherAndReadFailureDoNotFallbackOrWrite() async throws {
        let f = try SearchReadFixture(bodyMode: true)
        try await f.unlock()
        let corrupt = try f.protectedDiary("needle"); corrupt.encryptedText = Data([0, 1])
        let wrong = try f.protectedDiary("needle"); wrong.privacyVaultID = UUID()
        let missing = try f.protectedDiary("needle"); missing.encryptedText = nil
        let result = try SearchReadFixture.diaryResponse(await f.publishBodies("/diaries SYNTHETIC_RAW_FALLBACK_FORBIDDEN"))
        #expect(result.matches.isEmpty)
        #expect([corrupt, wrong, missing].allSatisfy { row in result.undeterminedObjects.contains { $0.id == row.id } })
        #expect(corrupt.encryptedText == Data([0, 1]) && missing.encryptedText == nil)
        #expect([corrupt, wrong, missing].allSatisfy { $0.text == "SYNTHETIC_RAW_FALLBACK_FORBIDDEN" })
        #expect(f.data.context.hasChanges)
    }

    @Test func duplicateIncludingTombstoneNeverCallsBodyDependency() async throws {
        let probe = BodyReadProbe()
        let f = try SearchReadFixture(bodyMode: true) { $0.observeContent = probe.observe }
        try await f.unlock()
        let first = try f.protectedDiary("needle")
        let second = f.data.diary("needle", deleted: TodoQueryFixture.created)
        second.id = first.id
        let result = try SearchReadFixture.diaryResponse(await f.publishBodies("/diaries needle"))
        #expect(probe.calls == 1) // 唯一的普通种子行；重复保护行根本没有进入正文依赖。
        #expect(result.undeterminedObjects.contains { $0.id == first.id })
    }
}
