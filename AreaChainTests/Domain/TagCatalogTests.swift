import Foundation
import SwiftData
import Testing
@testable import AreaChain

struct TagCatalogTests {
    @Test func schemaHasSevenModelsAndNoProject() {
        let names = Set(AreaChainSchema.models.map { String(describing: $0) })
        #expect(names.count == 7)
        #expect(names == [
            "DailyRoutine", "RoutineCheck", "TodoItem", "SubtaskItem",
            "DiaryEntry", "TagItem", "AttachmentItem"
        ])
        let bits = ClassifyBits(tagIDs: "", isImportant: true, isUrgent: false, sourceBundleID: "app")
        #expect(bits.tagIDs == "")
        #expect(BoardFilter().withTag(BoardFilter.noneID).isNoTag)
        #expect(!BoardFilter().isActive)
    }

    @Test func tagIDListDedupesAndKeepsOrder() {
        let first = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let second = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let raw = TagIDList.encode([first, second, first])
        #expect(TagIDList.normalized(raw) == TagIDList.encode([first, second]))
    }

    @Test func usageCountsActiveObjectsAndSkipsDeletedAndChecks() {
        let tag = UUID()
        let other = UUID()
        let encoded = TagIDList.encode([tag])
        let subjects = [
            TagUsageSubject(tagIDs: encoded, createdAt: Date(timeIntervalSince1970: 10), isDeleted: false),
            TagUsageSubject(tagIDs: encoded, createdAt: Date(timeIntervalSince1970: 30), isDeleted: false),
            TagUsageSubject(tagIDs: encoded, createdAt: Date(timeIntervalSince1970: 99), isDeleted: true),
            TagUsageSubject(tagIDs: TagIDList.encode([other]), createdAt: Date(timeIntervalSince1970: 5), isDeleted: false)
        ]
        let usage = TagUsage.records(subjects)
        #expect(usage[tag]?.activeCount == 2)
        #expect(usage[tag]?.latestCreatedAt == Date(timeIntervalSince1970: 30))
        #expect(usage[other]?.activeCount == 1)
    }

    @Test func subjectsCountLiveTodosRoutinesSubtasksAndDiariesWithoutBody() {
        let tag = UUID()
        let encoded = TagIDList.encode([tag])
        let secret = "PRIVATE_BODY_SENTINEL"
        let live = TodoItem(title: "事项", dayKey: "2026-09-24", tagIDs: encoded)
        let removed = TodoItem(title: "已删", dayKey: "2026-09-24", deletedAt: .now, tagIDs: encoded)
        let child = SubtaskItem(title: "子", tagIDs: encoded, todo: live)
        let droppedChild = SubtaskItem(title: "已删子", deletedAt: .now, tagIDs: encoded, todo: live)
        live.subtasks = [child, droppedChild]
        let routine = DailyRoutine(title: "重复", sortOrder: 0, tagIDs: encoded)
        let diary = DiaryEntry(text: secret, dayKey: "2026-09-24", tagIDs: encoded)
        let subjects = TagUsage.subjects(todos: [live, removed], routines: [routine], diaries: [diary])
        let usage = TagUsage.records(subjects)
        #expect(usage[tag]?.activeCount == 4)
        #expect(!String(describing: subjects).contains(secret))
    }

    @Test func filtersFrequentRecentAndUnused() {
        let used = TagItem(name: "常用", sortOrder: 1)
        let quiet = TagItem(name: "闲置", sortOrder: 0)
        let recent = TagItem(name: "最近", sortOrder: 2)
        let usage = [
            used.id: TagUsageRecord(tagID: used.id, activeCount: 4, latestCreatedAt: Date(timeIntervalSince1970: 10)),
            recent.id: TagUsageRecord(tagID: recent.id, activeCount: 1, latestCreatedAt: Date(timeIntervalSince1970: 50))
        ]
        let tags = [quiet, used, recent]
        #expect(TagUsage.filtered(tags, filter: .frequent, usage: usage).map(\.name) == ["常用", "最近", "闲置"])
        #expect(TagUsage.filtered(tags, filter: .recent, usage: usage).map(\.name) == ["最近", "常用"])
        #expect(TagUsage.filtered(tags, filter: .unused, usage: usage).map(\.name) == ["闲置"])
    }

    @Test func mergeMovesLinksDedupesAndSoftDeletesSources() throws {
        let target = TagItem(name: "目标", sortOrder: 0)
        let source = TagItem(name: "来源", sortOrder: 1)
        let extra = TagItem(name: DiaryMemoTags.journal, sortOrder: 2)
        let todo = TodoItem(title: "事项", dayKey: "2026-09-24", tagIDs: TagIDList.encode([source.id, target.id]))
        let routine = DailyRoutine(title: "重复", sortOrder: 0, tagIDs: TagIDList.encode([source.id]))
        let subtask = SubtaskItem(title: "子", tagIDs: TagIDList.encode([source.id]))
        let diary = DiaryEntry(text: "手记", dayKey: "2026-09-24", tagIDs: TagIDList.encode([source.id, extra.id]))
        try Catalog.mergeTags(
            sources: [source.id, extra.id], into: target.id, tags: [target, source, extra],
            todos: [todo], routines: [routine], diaries: [diary], subtasks: [subtask]
        )
        #expect(todo.tagIDs == TagIDList.encode([target.id]))
        #expect(routine.tagIDs == TagIDList.encode([target.id]))
        #expect(subtask.tagIDs == TagIDList.encode([target.id]))
        #expect(diary.tagIDs == TagIDList.encode([target.id]))
        #expect(source.deletedAt != nil)
        #expect(extra.deletedAt != nil)
        #expect(target.deletedAt == nil)
    }

    @Test func matchingDiariesFiltersLiveEntriesAndSortsNewestFirst() {
        let tag = TagItem(name: "灵感", sortOrder: 0)
        let other = TagItem(name: "其他", sortOrder: 1)
        let older = DiaryEntry(
            text: "旧手记", dayKey: "2026-09-24",
            createdAt: Date(timeIntervalSince1970: 100),
            tagIDs: TagIDList.encode([tag.id])
        )
        let newer = DiaryEntry(
            text: "新手记", dayKey: "2026-09-24",
            createdAt: Date(timeIntervalSince1970: 200),
            tagIDs: TagIDList.encode([tag.id, other.id])
        )
        let deleted = DiaryEntry(
            text: "已删", dayKey: "2026-09-24",
            createdAt: Date(timeIntervalSince1970: 300),
            deletedAt: .now,
            tagIDs: TagIDList.encode([tag.id])
        )
        let unrelated = DiaryEntry(
            text: "无关", dayKey: "2026-09-24",
            createdAt: Date(timeIntervalSince1970: 400),
            tagIDs: TagIDList.encode([other.id])
        )
        let matched = Catalog.matchingDiaries([older, newer, deleted, unrelated], tag: tag)
        #expect(matched.map(\.id) == [newer.id, older.id])
    }

    @Test func oldSnapshotIgnoresProjectsAndOmitsThemOnExport() throws {
        let raw = """
        {
          "exportedAt":"2026-09-24T00:00:00Z",
          "routines":[],
          "checks":[],
          "todos":[{
            "id":"11111111-1111-1111-1111-111111111111",
            "title":"旧",
            "isDone":false,
            "dayKey":"2026-09-24",
            "createdAt":"2026-09-24T00:00:00Z",
            "projectID":"22222222-2222-2222-2222-222222222222",
            "tagIDs":""
          }],
          "diaries":[],
          "projects":[{
            "id":"22222222-2222-2222-2222-222222222222",
            "name":"旧项目",
            "sortOrder":0
          }],
          "tags":[{
            "id":"33333333-3333-3333-3333-333333333333",
            "name":"标签",
            "sortOrder":0
          }]
        }
        """.data(using: .utf8)!
        let decoded = try SyncPort.decode(raw)
        #expect(decoded.todos.count == 1)
        #expect(decoded.tags.count == 1)
        #expect(decoded.tags[0].colorToken == TagColorToken.default.rawValue)
        let encoded = String(data: try SyncPort.encode(decoded), encoding: .utf8) ?? ""
        #expect(!encoded.contains("projectID"))
        #expect(!encoded.contains("projects"))
        #expect(encoded.contains("colorToken"))
    }
}

@MainActor
struct TagRepositoryTests {
    private func makeRepo() throws -> (ModelContainer, ModelContext, SwiftDataCatalogRepository) {
        let store = try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = store.mainContext
        return (store, context, SwiftDataCatalogRepository(context: context, container: store))
    }

    @Test func createRejectsDuplicateAllowsAnyNameAndPersistsColorAndOrder() throws {
        let (_, _, repo) = try makeRepo()
        let first = try repo.createTag(name: " 计划 ", sortOrder: nil)
        #expect(first.colorToken == TagColorToken.default.rawValue)
        #expect(!first.isDiaryPreset)
        #expect(throws: RepositoryError.self) { try repo.createTag(name: "计划", sortOrder: nil) }
        let passwordNamed = try repo.createTag(name: DiaryMemoTags.password, sortOrder: nil)
        #expect(!passwordNamed.isDiaryPreset)
        #expect(!passwordNamed.isPrivateDiary)
        try repo.updateTag(id: first.id, name: "计划甲", sortOrder: 3, colorToken: TagColorToken.stamp.rawValue)
        let renamed = try #require(try repo.fetchTag(id: first.id))
        #expect(renamed.name == "计划甲")
        #expect(renamed.sortOrder == 3)
        #expect(renamed.colorToken == TagColorToken.stamp.rawValue)
    }

    @Test func softDeleteRestoreAndPurgeKeepThenDropLinks() throws {
        let (_, context, repo) = try makeRepo()
        let tag = try repo.createTag(name: "临时", sortOrder: 0)
        let todo = TodoItem(title: "事项", dayKey: "2026-09-24", tagIDs: TagIDList.encode([tag.id]))
        context.insert(todo)
        try context.save()
        try repo.deleteTag(id: tag.id, soft: true)
        #expect(try repo.fetchTags().isEmpty)
        #expect(todo.tagIDs == TagIDList.encode([tag.id]))
        try repo.restoreTag(id: tag.id)
        #expect(try repo.fetchTags().count == 1)
        try repo.purgeTag(id: tag.id)
        #expect(todo.tagIDs.isEmpty)
        #expect(try repo.fetchTag(id: tag.id) == nil)
    }

    @Test func ensurePresetTagsDoesNotSeedBuiltInTagsAndMergeWorksOnAllUserTags() throws {
        let (_, context, repo) = try makeRepo()
        try repo.ensurePresetTags()
        #expect(try repo.fetchTags(includeDeleted: true).isEmpty)

        let target = try repo.createTag(name: "目标", sortOrder: 0)
        let source = try repo.createTag(name: DiaryMemoTags.journal, sortOrder: 1)
        let todo = TodoItem(title: "事项", dayKey: "2026-09-24", tagIDs: TagIDList.encode([source.id]))
        context.insert(todo)
        try context.save()
        try repo.mergeTags(sourceIDs: [source.id], into: target.id)
        #expect(todo.tagIDs == TagIDList.encode([target.id]))
        #expect(try repo.fetchTag(id: source.id)?.deletedAt != nil)
    }

    @Test func colorRoundTripsThroughSnapshot() throws {
        let (_, _, repo) = try makeRepo()
        let tag = try repo.createTag(name: "颜色", sortOrder: 1)
        try repo.updateTag(id: tag.id, name: nil, sortOrder: nil, colorToken: TagColorToken.clay.rawValue)
        let snapshot = SyncPort.makeSnapshot(routines: [], checks: [], todos: [], diaries: [], tags: [tag])
        let other = try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        try SnapshotImporter.apply(snapshot, context: other.mainContext)
        let imported = try other.mainContext.fetch(FetchDescriptor<TagItem>())
        #expect(imported.first?.colorToken == TagColorToken.clay.rawValue)
        #expect(imported.first?.name == "颜色")
    }

    @Test func customHexColorAndStoreRoundTrip() throws {
        #expect(TagColorToken.normalizedHex("3b82f6") == "#3B82F6")
        #expect(TagColorToken.normalizedHex("#abc") == "#AABBCC")
        #expect(TagColorToken.normalizedHex("not-a-hex") == nil)
        #expect(TagColorToken.resolvedToken("#3b82f6") == "#3B82F6")
        #expect(TagColorToken.resolvedToken("unknown") == TagColorToken.default.rawValue)

        let (_, _, repo) = try makeRepo()
        let tag = try repo.createTag(name: "调色盘", sortOrder: 1)
        try repo.batchSetColor(ids: [tag.id], colorToken: "#8B5CF6")
        #expect(try repo.fetchTag(id: tag.id)?.colorToken == "#8B5CF6")

        let snapshot = SyncPort.makeSnapshot(routines: [], checks: [], todos: [], diaries: [], tags: [tag])
        let decoded = try SyncPort.decode(try SyncPort.encode(snapshot))
        #expect(decoded.tags.first?.colorToken == "#8B5CF6")

        let suiteName = "AreaChainTests.CustomTagColorStore.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = CustomTagColorStore(defaults: defaults)
        let saved = try #require(store.upsert(hex: "#8b5cf6", name: "紫罗兰"))
        #expect(saved.hex == "#8B5CF6")
        #expect(saved.displayTitle == "紫罗兰")
        #expect(store.colors.count == 1)

        let reloaded = CustomTagColorStore(defaults: defaults)
        #expect(reloaded.colors == [CustomTagColor(hex: "#8B5CF6", name: "紫罗兰")])
        reloaded.remove(hex: "#8B5CF6")
        #expect(reloaded.colors.isEmpty)

        let swatch = DaybookPalette.tagSwatchImage(token: "#8B5CF6", size: 10)
        #expect(!swatch.isTemplate)
        #expect(swatch.size.width == 10)
    }
}
