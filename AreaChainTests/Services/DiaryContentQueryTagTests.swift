import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DiaryContentQueryTagTests {
    @Test func allFamiliesShareOneCatalogAndFinalMetadataWithoutOverwritingSources() throws {
        let f = try DiaryContentQueryFixture()
        let tags = (0..<4).map { f.tags.tag("tag\($0)", order: $0) }
        let todo = f.tags.family.task.todo()
        let child = f.tags.family.task.child(todo)
        let routine = f.tags.family.routine()
        let diary = f.diary()
        todo.tagIDs = tags[0].id.uuidString
        child.tagIDs = tags[1].id.uuidString
        routine.tagIDs = tags[2].id.uuidString
        diary.tagIDs = tags[3].id.uuidString
        var catalog = TagContentQueryReads(context: f.context)
        let fetch = catalog.allTags
        var calls = 0
        catalog.allTags = { calls += 1; return try fetch() }
        var tasks = TaskContentQueryReads(context: f.context)
        tasks.tags = { _ in Issue.record("不应重复读取关联标签"); return [] }
        let result = f.read("", catalog: catalog, tasks: tasks)
        #expect(calls == 1)
        #expect(result.batch.snapshots.todos.values?.map(\.id) == [todo.id])
        #expect(result.batch.snapshots.subtasks.values?.map(\.id) == [child.id])
        #expect(result.batch.snapshots.routines.values?.map(\.id) == [routine.id])
        #expect(result.batch.snapshots.diaries.values?.map(\.id) == [diary.id])
        #expect(result.batch.snapshots.tags.values?.count == 4)
        #expect(ContentQueryTagNames.associatedIDs(in: result.batch) == Set(tags.map(\.id)))
        #expect(result.batch.facts.metadata.tagNames == Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0.name) }))
        #expect(result.diaryTagPrivacy?.coverage == .complete && result.batch.facts.metadata.privateTagIDs == [])
        #expect(result.batch.snapshots.images.coverage == .notProvided && result.batch.snapshots.clipboard.coverage == .notProvided)
        #expect(result.batch.facts.imageCoverage == ImageAssociationCoverage())
        #expect(result.batch.facts.trashCoverage.diaryPrivacy == ImageOwnerCoverage())
        #expect(result.batch.facts.trashCoverage.types[.diary] == nil)
    }

    @Test func fullDirectoryIncludesUnassociatedPrivateTombstonesWithoutPublishingPrivateNames() throws {
        let f = try DiaryContentQueryFixture()
        let visible = f.tags.tag("visible", deleted: TodoQueryFixture.created)
        let secret = f.tags.tag("private", deleted: TodoQueryFixture.created)
        secret.isPrivateDiary = true
        let diary = f.diary()
        diary.tagIDs = visible.id.uuidString
        let result = f.read()
        #expect(result.batch.facts.metadata.privateTagIDs == [secret.id])
        #expect(result.batch.facts.metadata.tagNames == [visible.id: "visible"])
        #expect(result.batch.snapshots.tags.coverage == .notProvided)
        diary.tagIDs = secret.id.uuidString
        let hidden = f.read("/diaries #private")
        #expect(hidden.tagIssues == [.privateNameUnavailable(secret.id)])
        #expect(hidden.batch.facts.metadata.tagNames == nil)
        #expect(hidden.batch.facts.metadata.privateTagIDs == [secret.id])
        #expect(try DiaryContentQueryFixture.response(hidden).undeterminedObjects.map(\.id) == [diary.id])
    }

    @Test func missingNamesAndDuplicatePrivacyIDsHaveSeparateDiagnostics() throws {
        let f = try DiaryContentQueryFixture()
        let diary = f.diary()
        let missing = UUID()
        diary.tagIDs = missing.uuidString
        let duplicate = f.tags.tag("one")
        f.tags.tag("two", id: duplicate.id, deleted: TodoQueryFixture.created).isPrivateDiary = true
        let result = f.read()
        #expect(result.tagIssues == [.missingID(missing)])
        #expect(result.diaryTagPrivacy?.issues == [.ambiguousID(duplicate.id)])
        #expect(result.batch.facts.metadata.privateTagIDs == nil && result.batch.facts.metadata.tagNames == nil)
        diary.tagIDs = duplicate.id.uuidString
        #expect(f.read().tagIssues == [.ambiguousID(duplicate.id)])
        let response = try DiaryContentQueryFixture.response(f.read("/diaries date:today"))
        #expect(response.matches.map(\.id.id) == [diary.id])
        #expect(response.diagnostics.contains { $0.issue == .incompletePrivacyMetadata })
        guard case .hiddenTitle = response.matches.first?.presentation else { Issue.record("必须隐藏"); return }
    }

    @Test(arguments: TagListFilter.allCases)
    func diaryReadDoesNotCreateStatisticsOrChangeLegacyStatistics(filter: TagListFilter) throws {
        let f = try DiaryContentQueryFixture()
        let tag = f.tags.tag()
        let diary = f.diary()
        diary.tagIDs = tag.id.uuidString
        diary.isPrivate = true
        let before = TagUsage.records(TagUsage.subjects(todos: [], routines: [], diaries: [diary]))
        let result = f.read("", options: .init(tagView: .catalog(filter)))
        let response = try TagContentQueryFixture.response(result)
        #expect(result.batch.facts.tagUsage == nil && result.tagCatalog.usageOrigin == .notProvided)
        #expect(response.coverage.usage == nil)
        if filter == .recent || filter == .unused {
            #expect(response.matches.isEmpty && response.undeterminedObjects.map(\.id) == [tag.id])
        } else {
            #expect(response.matches.first?.usageState == .unavailable && response.matches.first?.usage == nil)
        }
        if filter == .frequent {
            #expect(response.ordering.applied == .inputOrder && !response.ordering.isComplete)
        }
        #expect(TagUsage.records(TagUsage.subjects(todos: [], routines: [], diaries: [diary])) == before)
    }
}
