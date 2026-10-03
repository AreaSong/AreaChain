import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DiaryContentQueryIntegrationTests {
    @Test func realReadFlowsThroughSafeProjectionSortSummaryAndPagination() throws {
        let f = try DiaryContentQueryFixture()
        let tag = f.tags.tag("工作")
        let first = f.diary()
        let newer = f.diary("#密码 " + DiaryQueryFixture.secret)
        first.tagIDs = tag.id.uuidString
        newer.tagIDs = tag.id.uuidString
        newer.createdAt = first.createdAt.addingTimeInterval(60)
        try f.context.save()
        let result = f.read("/diaries #工作 date:today")
        let response = try DiaryContentQueryFixture.response(result)
        #expect(Set(response.matches.map(\.id.id)) == [first.id, newer.id])
        #expect(response.undeterminedObjects.isEmpty)
        for match in response.matches {
            guard case .hiddenTitle = match.presentation else { Issue.record("必须隐藏"); continue }
            #expect(match.metadataEvidence.allSatisfy { $0.field != .diaryBody })
        }
        let owner = try QueryReadFixture.owner(result.batch, pageSize: 1)
        let publication = try #require(owner.published)
        let snapshot = publication.pagination.snapshot
        #expect(snapshot.source.source.ordered.map(\.id.id) == [newer.id, first.id])
        #expect(snapshot.visible.count == 1 && snapshot.units.count == 2)
        for row in snapshot.source.rows {
            #expect(row.summary == nil && row.expansion.isEmpty && !row.omittedPublicContent)
            #expect(row.primary?.mapping == nil && row.primary?.highlights.isEmpty == true)
            #expect(row.reasons.allSatisfy { $0.field != .diaryBody })
        }
        #expect(!DiaryQueryFixture.containsSecret(publication))
        #expect(owner.loadMore(QueryReadFixture.load(owner)).didPublish)
        #expect(owner.published?.pagination.snapshot.visible.count == 2)
        #expect(owner.published?.pagination.snapshot.sharesSource(with: snapshot) == true)
    }

    @Test(arguments: ["needle", "-needle", "(needle | -needle)"])
    func bodyDependentQueriesAreUnknownForOrdinaryProtectedAndLegacyShapes(query: String) throws {
        let f = try DiaryContentQueryFixture()
        let ordinary = f.diary("needle")
        let protected = f.diary("needle")
        protected.isPrivate = true
        let legacy = f.diary("#密码 needle")
        let result = f.read("/diaries " + query)
        let response = try DiaryContentQueryFixture.response(result)
        #expect(response.matches.isEmpty)
        #expect(Set(response.undeterminedObjects.map(\.id)) == [ordinary.id, protected.id, legacy.id])
        #expect(response.diagnostics.contains { $0.issue == .bodyUnavailable })
        #expect(result.batch.snapshots.diaries.values?.allSatisfy { !$0.isContentAvailable } == true)
    }

    @Test func metadataDecisiveOrBranchMatchesButExclusionStillNeedsBody() throws {
        let f = try DiaryContentQueryFixture()
        let tag = f.tags.tag("工作")
        let diary = f.diary()
        diary.tagIDs = tag.id.uuidString
        let certain = try DiaryContentQueryFixture.response(f.read("/diaries (unknown | 工作)"))
        #expect(certain.matches.map(\.id.id) == [diary.id] && certain.undeterminedObjects.isEmpty)
        let unknown = try DiaryContentQueryFixture.response(f.read("/diaries #工作 -unknown"))
        #expect(unknown.matches.isEmpty && unknown.undeterminedObjects.map(\.id) == [diary.id])
        let no = try DiaryContentQueryFixture.response(f.read("/diaries #其他"))
        #expect(no.matches.isEmpty && no.undeterminedObjects.isEmpty)
    }

    @Test func frozenBatchAndPublishedValuesDoNotTrackModelChanges() throws {
        let f = try DiaryContentQueryFixture()
        let tag = f.tags.tag("工作")
        let diary = f.diary()
        diary.tagIDs = tag.id.uuidString
        let result = f.read("/diaries #工作")
        let owner = try QueryReadFixture.owner(result.batch)
        let old = try #require(owner.published)
        diary.tagIDs = ""
        diary.dayKey = "2026-01-01"
        diary.isPrivate = true
        tag.name = "changed"
        #expect(result.batch.snapshots.diaries.values?.first?.dayKey == QuerySessionFixture.today)
        #expect(result.batch.facts.metadata.tagNames?[tag.id] == "工作")
        #expect(owner.published?.response.definiteMatchCount == old.response.definiteMatchCount)
        #expect(try DiaryContentQueryFixture.response(f.read("/diaries #工作")).matches.isEmpty)
        #expect(f.context.hasChanges)
    }
}
