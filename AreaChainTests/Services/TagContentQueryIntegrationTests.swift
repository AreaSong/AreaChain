import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct TagContentQueryIntegrationTests {
    @Test func oneFullFetchSuppliesCatalogAndOnlyAssociatedSafeNames() throws {
        let f = try TagContentQueryFixture()
        let todo = f.family.task.todo()
        let child = f.family.task.child(todo)
        let routine = f.family.routine()
        let tags = [f.tag("todo"), f.tag("child", order: 1), f.tag("routine", order: 2)]
        let unrelated = f.tag("not associated", order: 3)
        unrelated.isPrivateDiary = true
        todo.tagIDs = tags[0].id.uuidString
        child.tagIDs = tags[1].id.uuidString
        routine.tagIDs = tags[2].id.uuidString
        try f.context.save()
        var reads = TagContentQueryReads(context: f.context)
        let fetch = reads.allTags
        var fullCalls = 0
        reads.allTags = { fullCalls += 1; return try fetch() }
        var tasks = TaskContentQueryReads(context: f.context)
        tasks.tags = { _ in Issue.record("full catalog must supply same-batch names"); return [] }
        let result = f.read("", tags: reads, tasks: tasks)
        #expect(fullCalls == 1 && result.tagNamesCoverage == .complete)
        #expect(result.batch.facts.metadata.tagNames == Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0.name) }))
        #expect(result.batch.facts.metadata.privateTagIDs == nil)
        #expect(result.batch.snapshots.tags.values?.count == 4 && result.batch.snapshots.todos.values?.count == 1)
        #expect(result.batch.snapshots.subtasks.values?.count == 1 && result.batch.snapshots.routines.values?.count == 1)
        #expect(result.batch.snapshots.diaries.coverage == .notProvided && result.batch.snapshots.images.coverage == .notProvided)
        #expect(!ContentQueryBatchReader.read(result.batch).completeness.matchingIsComplete)
    }

    @Test(arguments: ["private", "duplicate", "missing"])
    func fullCatalogCannotBypassAssociatedNameProtection(mode: String) throws {
        let f = try TagContentQueryFixture()
        let tag = f.tag("catalog visible")
        if mode == "private" { tag.isPrivateDiary = true }
        if mode == "duplicate" { f.tag("duplicate", order: 1, id: tag.id) }
        f.family.task.todo("unrelated").tagIDs = (mode == "missing" ? UUID() : tag.id).uuidString
        let result = f.read("")
        #expect(result.tagNamesCoverage == .partial && result.batch.facts.metadata.tagNames == nil)
        #expect(!result.tagIssues.isEmpty && result.tagCatalog.source == .complete)
        #expect(result.batch.facts.metadata.privateTagIDs == nil)
        #expect(result.batch.facts.trashCoverage.diaryPrivacy == ImageOwnerCoverage())
        if mode == "private" {
            let match = try #require(TagContentQueryFixture.response(result).matches.first)
            #expect(match.tag.id == tag.id && match.tag.name == tag.name && match.tag.isPrivateDiary)
        }
    }

    @Test func tagAssemblyPreservesExistingSourcesMetadataAndOptions() throws {
        let f = try TagContentQueryFixture()
        f.tag()
        var batch = f.family.read("/tasks on:today").batch
        let session = TodoQueryFixture.session("")
        batch = .init(requestID: UUID(), session: session, snapshots: batch.snapshots, facts: batch.facts,
                      options: .init(locale: Locale(identifier: "zh-Hans"), tagView: .catalog(.all)))
        let privateIDs: Set<UUID> = [UUID()]
        let names = [UUID(): "existing metadata"]
        batch.facts.metadata = .init(tagNames: names, privateTagIDs: privateIDs)
        let old = batch
        _ = TagContentQueryReader(context: f.context).readSources(into: &batch)
        #expect(batch.requestID == old.requestID && batch.session == old.session)
        #expect(batch.options.locale == old.options.locale && batch.options.tagView == old.options.tagView)
        #expect(batch.snapshots.todos.values == old.snapshots.todos.values && batch.snapshots.subtasks.values == old.snapshots.subtasks.values)
        #expect(batch.snapshots.routines.values == old.snapshots.routines.values)
        #expect(batch.facts.routine.checks == old.facts.routine.checks)
        #expect(batch.facts.metadata.tagNames == names && batch.facts.metadata.privateTagIDs == privateIDs)
        #expect(batch.facts.trashCoverage.types[.todo] == old.facts.trashCoverage.types[.todo])
    }

    @Test func actualModelBatchReadOwnerDisplayPaginationAndRereadStayFrozen() throws {
        let f = try TagContentQueryFixture()
        let tags = [f.tag("needle", order: 0), f.tag("needle second", order: 1), f.tag("needle third", order: 2)]
        try f.context.save()
        let result = f.read("/tags needle", view: .catalog(.all))
        let owner = try QueryReadFixture.owner(result.batch, pageSize: 1)
        let publication = try #require(owner.published)
        #expect(publication.response.definiteMatchCount == 3 && publication.response.completeness.matchingIsComplete)
        #expect(publication.pagination.snapshot.visible.count == 1)
        #expect(owner.loadMore(QueryReadFixture.load(owner)).didPublish)
        #expect(owner.loadMore(QueryReadFixture.load(owner)).didPublish)
        #expect(owner.published?.pagination.snapshot.visible.count == 3)
        #expect(Set(publication.pagination.snapshot.source.rows.map(\.id.id)) == Set(tags.map(\.id)))
        let oldTask = try owner.begin(result.batch)
        let oldTicket = try owner.evaluate(oldTask)
        tags[0].name = "changed"
        tags[0].colorToken = "clay"
        tags[1].deletedAt = TodoQueryFixture.created
        tags[2].isPrivateDiary = true
        #expect(result.batch.snapshots.tags.values?.map(\.name) == ["needle", "needle second", "needle third"])
        #expect(result.batch.snapshots.tags.values?.allSatisfy { $0.deletedAt == nil && !$0.isPrivateDiary && $0.colorToken == "moss" } == true)
        let fresh = try owner.begin(f.read("/tags needle", view: .catalog(.all)).batch)
        #expect(fresh.source != oldTask.source && fresh.requestID == oldTask.requestID)
        #expect(throws: ContentQueryReadError.self) { try owner.publish(oldTicket) }
        try owner.publish(owner.evaluate(fresh))
        #expect(owner.published?.response.definiteMatchCount == 1 && f.context.hasChanges)
        #expect(publication.response.definiteMatchCount == 3)
    }
}
