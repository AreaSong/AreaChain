import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DiaryContentQueryReaderTests {
    @Test func emptyEnumerationIsCompleteButBodyAndProtectionRemainUnestablished() throws {
        let f = try DiaryContentQueryFixture()
        let result = f.read()
        #expect(result.diary.source == .complete && result.diary.mode == .metadataOnly)
        #expect(result.batch.snapshots.diaries.values?.isEmpty == true)
        #expect(result.diary.issues == [.bodyNotRead, .protectionNotEstablished])
        #expect(try DiaryContentQueryFixture.response(result).matches.isEmpty)
    }

    @Test func metadataProjectionPreservesTombstonesAndProtectionPresenceWithoutContent() throws {
        let f = try DiaryContentQueryFixture()
        let rows = (0..<5).map { _ in f.diary() }
        rows[1].isPrivate = true
        rows[2].encryptedText = Data([1, 2, 3])
        rows[3].privacyVaultID = UUID()
        rows[4].deletedAt = TodoQueryFixture.created
        rows[4].tagIDs = UUID().uuidString
        rows[4].isPinned = true
        try f.context.save()
        let result = f.read()
        let values = try #require(result.batch.snapshots.diaries.values)
        #expect(values.count == 5)
        for row in rows {
            let value = try #require(values.first { $0.id == row.id })
            #expect(value.dayKey == row.dayKey && value.createdAt == row.createdAt && value.deletedAt == row.deletedAt)
            #expect(value.tagIDs == row.tagIDs && value.isPinned == row.isPinned)
            #expect(value.isPrivate == row.hasProtectedContent)
            #expect(value.text.isEmpty && !value.isContentAvailable)
        }
        #expect(!DiaryQueryFixture.containsSecret(result))
        #expect(try DiaryContentQueryFixture.response(result).matches.count == 4)
    }

    @Test func liveAndDeletedDuplicateIdentityIsNotDeduplicatedOrRepaired() throws {
        let f = try DiaryContentQueryFixture()
        let live = f.diary()
        let deleted = f.diary(deleted: TodoQueryFixture.created)
        deleted.id = live.id
        try f.context.save()
        let result = f.read()
        #expect(result.batch.snapshots.diaries.values?.count == 2)
        let response = try DiaryContentQueryFixture.response(result)
        #expect(response.matches.isEmpty && response.undeterminedObjects.map(\.id) == [live.id])
        #expect(response.diagnostics.contains { $0.issue == .duplicateDiaryID && $0.inputIndices.count == 2 })
    }

    @Test func invalidMetadataIsDiagnosedWithoutNormalization() throws {
        let f = try DiaryContentQueryFixture()
        let row = f.diary()
        row.dayKey = "invalid"
        row.tagIDs = "invalid-id"
        row.createdAt = Date(timeIntervalSince1970: .infinity)
        let deleted = f.diary(deleted: Date(timeIntervalSince1970: .infinity))
        let result = f.read()
        #expect(result.diary.issues.contains(.invalidDeletedAt(deleted.id)))
        #expect(result.batch.snapshots.diaries.values?.first { $0.id == row.id }?.tagIDs == "invalid-id")
        let response = try DiaryContentQueryFixture.response(result)
        #expect(response.diagnostics.contains { $0.issue == .invalidDiaryDay })
        #expect(response.diagnostics.contains { $0.issue == .invalidCreatedAt })
        #expect(response.diagnostics.contains { $0.issue == .invalidTagIDs })
    }

    @Test func capabilityIsOptInAndNonDiaryOrInvalidRequestsDoNotFetch() throws {
        let f = try DiaryContentQueryFixture()
        f.diary()
        let disabled = TaskFamilyContentQueryReader(context: f.context).read(
            session: TodoQueryFixture.session(""), requestID: UUID(), observation: RoutineContentQueryFixture.observation())
        #expect(disabled.diary.source == .notProvided && disabled.batch.facts.metadata.privateTagIDs == nil)
        var reads = DiaryContentQueryReads(context: f.context)
        var count = 0
        let original = reads.allDiaries
        reads.allDiaries = { count += 1; return try original() }
        for source in ["/tasks", "/tags", "/trash", "/diaries (", "/todo new"] {
            #expect(f.read(source, diaries: reads).diary.source == .notProvided)
        }
        #expect(count == 0)
        let enabled = TaskFamilyContentQueryReader(context: f.context, diaryMode: .metadataOnly).read(
            session: TodoQueryFixture.session("/diaries"), requestID: UUID(), observation: RoutineContentQueryFixture.observation())
        #expect(enabled.diary.source == .complete)
    }
}
