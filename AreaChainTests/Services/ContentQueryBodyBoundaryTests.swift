import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct ContentQueryBodyBoundaryTests {
    @Test func sameCatalogIsFetchedOnceAndSharedWithOldReadValidation() async throws {
        var fetches = 0
        let f = try SearchReadFixture(bodyMode: true) { reads in
            let original = reads.tags.allTags
            reads.tags.allTags = { fetches += 1; return try original() }
        }
        let tag = f.data.tags.tag("ordinary")
        let row = f.data.diary("needle"); row.tagIDs = tag.id.uuidString
        let result = try await f.publishBodies("/diaries needle")
        #expect(fetches == 1 && result.response.definiteMatchCount == 1)
        let match = try #require(SearchReadFixture.diaryResponse(result).matches.first)
        guard case .publicText(let body, _) = match.presentation else { Issue.record("缺少普通投影"); return }
        #expect(try DiaryContent.read(row, vault: f.vault) == body)
        tag.isPrivateDiary = true
        #expect(throws: PrivacyError.corruptData) { try DiaryContent.read(row, vault: f.vault) }
        let blocked = try SearchReadFixture.diaryResponse(await f.publishBodies("/diaries needle"))
        #expect(blocked.matches.isEmpty && blocked.undeterminedObjects.contains { $0.id == row.id })
    }

    @Test func oldProtectedReadIsEquivalentAndDoesNotReplaceStoredText() async throws {
        let f = try SearchReadFixture(bodyMode: true)
        try await f.unlock()
        let row = try f.protectedDiary("synthetic protected API equivalence")
        #expect(try DiaryContent.read(row, vault: f.vault) == "synthetic protected API equivalence")
        let result = try SearchReadFixture.diaryResponse(await f.publishBodies("/diaries equivalence"))
        #expect(result.matches.map(\.id.id) == [row.id])
        guard case .hiddenTitle = result.matches[0].presentation else { Issue.record("保护投影无效"); return }
        #expect(row.text == "SYNTHETIC_RAW_FALLBACK_FORBIDDEN")
        f.vault.lock()
        #expect(throws: PrivacyError.locked) { try DiaryContent.read(row, vault: f.vault) }
    }

    @Test func missingOrAmbiguousCatalogNeverReachesContentDependency() async throws {
        for failed in [false, true] {
            let probe = BodyReadProbe()
            let f = try SearchReadFixture(bodyMode: true) { reads in
                reads.observeContent = probe.observe
                if failed { reads.tags.allTags = { throw PrivacyError.storageFailure } }
            }
            if !failed {
                let tag = f.data.tags.tag("first")
                f.data.tags.tag("duplicate", id: tag.id)
            }
            let result = try SearchReadFixture.diaryResponse(await f.publishBodies("/diaries needle"))
            #expect(probe.calls == 0 && result.matches.isEmpty && !result.undeterminedObjects.isEmpty)
        }
    }

    @Test func injectedReadFailureNeverBecomesEmptyOrPlaintextFallback() async throws {
        let f = try SearchReadFixture(bodyMode: true) { reads in
            reads.observeContent = { _ in throw PrivacyError.corruptData }
        }
        let row = f.data.diary("needle")
        let response = try SearchReadFixture.diaryResponse(await f.publishBodies("/diaries -absent"))
        #expect(response.matches.isEmpty && response.undeterminedObjects.contains { $0.id == row.id })
        #expect(row.text == "needle" && f.data.context.hasChanges)
    }

    @Test func protectedMetadataMutationAfterFreezeRejectsEvaluationAndPublication() async throws {
        let f = try SearchReadFixture(bodyMode: true)
        try await f.unlock()
        let row = try f.protectedDiary("needle")
        let handle = try f.prepareBodies()
        try f.session.evaluate(handle)
        row.privacyVaultID = UUID()
        await #expect(throws: ContentQueryReadSessionError.stalePermit) { try await f.session.publish(handle) }
        #expect(!f.session.hasPublicationPermit && !f.session.hasRetainedPresentation)
    }

    @Test func hostTransferRevokesOldBodyOwnershipAndHandle() async throws {
        let f = try SearchReadFixture(bodyMode: true)
        try await f.unlock()
        _ = try f.protectedDiary("needle")
        let handle = try f.prepareBodies()
        try f.session.evaluate(handle)
        try f.handoff.transfer()
        await #expect(throws: ContentQueryReadSessionError.self) { try await f.session.publish(handle) }
        #expect(!f.session.hasPublicationPermit && !f.session.hasRetainedPresentation)
        #expect(throws: ContentQueryReadSessionError.self) { try f.prepareBodies() }
    }

    @Test func unsavedChangesRemainUncommittedAndNoBusinessEventIsPublished() async throws {
        let f = try SearchReadFixture(bodyMode: true)
        let row = f.data.diary("needle")
        var events = 0
        let observer = NotificationCenter.default.addObserver(forName: .boardDidChange, object: nil, queue: nil) { _ in
            MainActor.assumeIsolated { events += 1 }
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        let before = f.vault.generation
        _ = try await f.publishBodies("/diaries needle")
        #expect(f.data.context.hasChanges && row.text == "needle")
        let fresh = ModelContext(f.data.context.container)
        #expect(try fresh.fetch(FetchDescriptor<DiaryEntry>()).isEmpty)
        #expect(events == 0 && f.vault.generation == before && !f.vault.isAuthenticating)
        #expect(await f.system.items.isEmpty)
    }
}
