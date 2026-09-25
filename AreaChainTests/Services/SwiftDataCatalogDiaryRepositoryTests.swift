import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor
struct SwiftDataCatalogDiaryRepositoryTests {
    private func makeRepos() throws -> (ModelContainer, SwiftDataDiaryRepository, SwiftDataCatalogRepository) {
        let schema = Schema(AreaChainSchema.models)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let diaryRepo = SwiftDataDiaryRepository(container: container)
        let catalogRepo = SwiftDataCatalogRepository(container: container)
        return (container, diaryRepo, catalogRepo)
    }

    @Test func missingEntitiesThrowNotFound() throws {
        let (container, diaryRepo, catalogRepo) = try makeRepos()
        _ = container
        let id = UUID()

        #expect(throws: RepositoryError.self) { try diaryRepo.editDiary(id: id, text: "x") }
        #expect(throws: RepositoryError.self) { try diaryRepo.togglePin(id: id) }
        #expect(throws: RepositoryError.self) { try diaryRepo.setPinned(id: id, isPinned: true) }
        #expect(throws: RepositoryError.self) { try diaryRepo.toggleTag(id: id, tagID: UUID()) }
        #expect(throws: RepositoryError.self) { try diaryRepo.setTags(id: id, tagIDs: []) }
        #expect(throws: RepositoryError.self) { try diaryRepo.deleteDiary(id: id, soft: true) }
        #expect(throws: RepositoryError.self) { try diaryRepo.restoreDiary(id: id) }
        #expect(throws: RepositoryError.self) { try diaryRepo.purgeDiary(id: id) }

        #expect(throws: RepositoryError.self) { try catalogRepo.updateTag(id: id, name: "t", sortOrder: nil) }
        #expect(throws: RepositoryError.self) { try catalogRepo.deleteTag(id: id, soft: true) }
        #expect(throws: RepositoryError.self) { try catalogRepo.restoreTag(id: id) }
        #expect(throws: RepositoryError.self) { try catalogRepo.purgeTag(id: id) }
    }

    @Test func blankInputsThrowInvalidArgument() throws {
        let (container, diaryRepo, catalogRepo) = try makeRepos()
        _ = container
        #expect(throws: RepositoryError.self) { try diaryRepo.addDiary(text: "  ", dayKey: "2026-09-10", tagIDs: []) }
        #expect(throws: RepositoryError.self) { try catalogRepo.createTag(name: "  ", sortOrder: nil) }
        #expect(throws: RepositoryError.self) { try catalogRepo.resolveOrCreateTag(name: "  ") }

        let tag = try catalogRepo.createTag(name: "Valid Tag", sortOrder: 0)
        #expect(throws: RepositoryError.self) {
            try catalogRepo.updateTag(id: tag.id, name: "  ", sortOrder: nil)
        }
    }

    @Test func diarySortingPinningAndSearch() throws {
        let (container, diaryRepo, _) = try makeRepos()
        _ = container
        let d1 = try diaryRepo.addDiary(text: "First note about Swift", dayKey: "2026-09-10", tagIDs: [])
        let d2 = try diaryRepo.addDiary(text: "Second note about Rust", dayKey: "2026-09-10", tagIDs: [])
        let d3 = try diaryRepo.addDiary(text: "Third note about Swift and AI", dayKey: "2026-09-10", tagIDs: [])

        try diaryRepo.setPinned(id: d1.id, isPinned: true)

        let sorted = try diaryRepo.fetchDiaries(for: "2026-09-10")
        #expect(sorted.first?.id == d1.id)

        let searchHits = try diaryRepo.searchDiaries(query: "Swift")
        #expect(searchHits.count == 2)
        #expect(searchHits.contains(where: { $0.id == d1.id }))
        #expect(searchHits.contains(where: { $0.id == d3.id }))

        let emptyHits = try diaryRepo.searchDiaries(query: "Swift", tagID: UUID(), includeDeleted: false)
        #expect(emptyHits.isEmpty)
    }

    @Test func diarySoftDeleteAndAttachmentCascading() throws {
        let (container, diaryRepo, _) = try makeRepos()
        let diary = try diaryRepo.addDiary(text: "Memo with picture", dayKey: "2026-09-10", tagIDs: [])
        let attachment = AttachmentItem(
            ownerKind: AttachmentOwner.diary.rawValue,
            ownerID: diary.id,
            filename: "photo.jpg"
        )
        container.mainContext.insert(attachment)
        try container.mainContext.save()

        try diaryRepo.deleteDiary(id: diary.id, soft: true)
        let stamp = try #require(diary.deletedAt)
        #expect(attachment.deletedAt == stamp)

        try diaryRepo.restoreDiary(id: diary.id)
        #expect(diary.deletedAt == nil)
        #expect(attachment.deletedAt == nil)

        try diaryRepo.purgeDiary(id: diary.id)
        let attachments = try container.mainContext.fetch(FetchDescriptor<AttachmentItem>())
        #expect(attachments.isEmpty)
    }

    @Test func tagReorderIsFlat() throws {
        let (_, _, catalogRepo) = try makeRepos()
        let root = try catalogRepo.createTag(name: "Root", sortOrder: 0)
        let sub = try catalogRepo.createTag(name: "Sub", sortOrder: 1)
        try catalogRepo.reorderTags(orderedIDs: [sub.id, root.id])
        #expect(try catalogRepo.fetchTags().map(\.name) == ["Sub", "Root"])
    }

    @Test func tagResolutionAndPresetRules() throws {
        let (container, _, catalogRepo) = try makeRepos()
        _ = container

        let tag1 = try catalogRepo.resolveOrCreateTag(name: "TagAlpha")
        let tag2 = try catalogRepo.resolveOrCreateTag(name: "TagAlpha")
        #expect(tag1.id == tag2.id)

        try catalogRepo.deleteTag(id: tag1.id, soft: true)
        #expect(tag1.deletedAt != nil)

        let resurrected = try catalogRepo.resolveOrCreateTag(name: "TagAlpha")
        #expect(resurrected.id == tag1.id)
        #expect(resurrected.deletedAt == nil)

        #expect(try catalogRepo.resolveTaskTag(name: "密码") == nil)
        #expect(try catalogRepo.resolveTaskTag(name: "日记") == nil)
        #expect(try catalogRepo.resolveTaskTag(name: "小巧思") == nil)

        let validTaskTag = try catalogRepo.resolveTaskTag(name: "工作待办")
        #expect(validTaskTag != nil)

        try catalogRepo.ensurePresetTags()
        let allTags = try catalogRepo.fetchTags(includeDeleted: true)
        #expect(allTags.contains(where: { $0.name == "密码" }))
        #expect(allTags.contains(where: { $0.name == "日记" }))
        #expect(allTags.contains(where: { $0.name == "小巧思" }))
    }

    @Test(arguments: [("Work", " \tｗＯＲＫ\n"), ("Café", "CAFE\u{301}")])
    func resolvingLiveNormalizedTagDoesNotSaveOrNotify(name: String, equivalentName: String) throws {
        let (container, _, repository) = try makeRepos()
        let context = container.mainContext
        let tag = try repository.createTag(name: name, sortOrder: 0)
        let counts = try mutationCounts(in: context) {
            let resolved = try repository.resolveOrCreateTag(name: equivalentName)
            #expect(resolved.id == tag.id)
        }
        #expect(counts.saves == 0)
        #expect(counts.notifications == 0)
        #expect(!context.hasChanges)
        #expect(try context.fetchCount(FetchDescriptor<TagItem>()) == 1)
    }

    @Test func inputTagResolutionDoesNotDirtyAnExistingLiveTag() throws {
        let (container, _, repository) = try makeRepos()
        let context = container.mainContext
        let tag = try repository.createTag(name: "Work", sortOrder: 0)
        let ids = try InputTagResolver.resolve(["work", "ＷＯＲＫ"], in: context)
        #expect(ids == [tag.id])
        #expect(!context.hasChanges)
    }

    @Test func presetInitializationCommitsOnceAndRepeatedChecksStayReadOnly() throws {
        let (container, _, repository) = try makeRepos()
        let context = container.mainContext
        let initial = try mutationCounts(in: context) { try repository.ensurePresetTags() }
        #expect(initial.saves == 1)
        #expect(initial.notifications == 1)

        let repeated = mutationCounts(in: context) {
            for _ in 0..<10 {
                #expect(DayBoardMutations.ensureDiaryPresetTags(context: context))
            }
        }
        #expect(repeated.saves == 0)
        #expect(repeated.notifications == 0)
        #expect(!context.hasChanges)
        let tags = try ModelContext(container).fetch(FetchDescriptor<TagItem>())
        #expect(tags.count == 3)
        #expect(Set(tags.map(\.name)) == Set(DiaryMemoTags.presets))
    }

    @Test func presetRepairRestoresAndCreatesTogetherWithoutRevivingLiveDuplicates() throws {
        let (container, _, repository) = try makeRepos()
        let context = container.mainContext
        let stamp = Date(timeIntervalSince1970: 123)
        let password = TagItem(name: DiaryMemoTags.password, sortOrder: 0)
        let duplicate = TagItem(name: DiaryMemoTags.password, sortOrder: 1, deletedAt: stamp)
        let journal = TagItem(name: " 日记 ", sortOrder: 2, deletedAt: stamp)
        for tag in [password, duplicate, journal] { context.insert(tag) }
        try context.save()

        let counts = try mutationCounts(in: context) { try repository.ensurePresetTags() }
        #expect(counts.saves == 1)
        #expect(counts.notifications == 1)
        #expect(duplicate.deletedAt == stamp)
        #expect(journal.deletedAt == nil)
        let tags = try ModelContext(container).fetch(FetchDescriptor<TagItem>())
        #expect(tags.count == 4)
        let savedJournal = try #require(tags.first { $0.id == journal.id })
        #expect(savedJournal.deletedAt == nil)
        let liveNames = tags.filter { $0.deletedAt == nil }.map { TagSyntax.normalizedName($0.name) }
        #expect(Set(liveNames) == Set(DiaryMemoTags.presets))
        let repeated = try mutationCounts(in: context) { try repository.ensurePresetTags() }
        #expect(repeated.saves == 0 && repeated.notifications == 0)
    }

    @Test func unchangedPresetChecksDoNotCommitUnrelatedPendingEdits() throws {
        let (container, _, repository) = try makeRepos()
        let context = container.mainContext
        try repository.ensurePresetTags()
        let todo = TodoItem(title: "已保存", dayKey: "2026-09-14")
        context.insert(todo)
        try context.save()
        todo.title = "尚未保存的编辑"

        let counts = try mutationCounts(in: context) {
            #expect(DayBoardMutations.ensureDiaryPresetTags(context: context))
            _ = try repository.resolveOrCreateTag(name: DiaryMemoTags.journal)
        }
        #expect(counts.saves == 0 && counts.notifications == 0)
        #expect(context.hasChanges)
        #expect(todo.title == "尚未保存的编辑")
        #expect(try ModelContext(container).fetch(FetchDescriptor<TodoItem>()).first?.title == "已保存")
    }

    @Test func failedPresetRepairRollsBackCreationAndRestorationTogether() throws {
        let (container, _, repository) = try makeRepos()
        let context = container.mainContext
        let stamp = Date(timeIntervalSince1970: 123)
        let journal = TagItem(name: DiaryMemoTags.journal, sortOrder: 0, deletedAt: stamp)
        context.insert(journal)
        try context.save()

        let counts = mutationCounts(in: context) {
            #expect(throws: CocoaError.self) {
                try ModelChanges.transaction(in: context, save: { _ in throw CocoaError(.fileWriteNoPermission) }) {
                    try repository.ensurePresetTags()
                }
            }
        }
        #expect(counts.saves == 0 && counts.notifications == 0)
        #expect(journal.deletedAt == stamp)
        let tags = try ModelContext(container).fetch(FetchDescriptor<TagItem>())
        #expect(tags.count == 1)
        #expect(tags.first?.id == journal.id && tags.first?.deletedAt == stamp)
    }

    @Test func creatingAndRestoringTagsStillCommitOnce() throws {
        let (container, _, repository) = try makeRepos()
        let context = container.mainContext
        let created = try mutationCounts(in: context) { _ = try repository.resolveOrCreateTag(name: "Work") }
        #expect(created.saves == 1 && created.notifications == 1)
        let tag = try #require(repository.fetchTags().first)
        try repository.deleteTag(id: tag.id, soft: true)

        let restored = try mutationCounts(in: context) {
            let resolved = try repository.resolveOrCreateTag(name: "ｗｏｒｋ")
            #expect(resolved.id == tag.id)
        }
        #expect(restored.saves == 1 && restored.notifications == 1)
        let saved = try #require(ModelContext(container).fetch(FetchDescriptor<TagItem>()).first)
        #expect(saved.id == tag.id && saved.deletedAt == nil)
    }

    private func mutationCounts(
        in context: ModelContext, _ work: () throws -> Void
    ) rethrows -> (saves: Int, notifications: Int) {
        var saves = 0
        var notifications = 0
        let center = NotificationCenter.default
        let saveObserver = center.addObserver(forName: ModelContext.willSave, object: context, queue: .main) { _ in saves += 1 }
        let changeObserver = center.addObserver(forName: .boardDidChange, object: nil, queue: .main) { _ in notifications += 1 }
        defer {
            center.removeObserver(saveObserver)
            center.removeObserver(changeObserver)
        }
        try work()
        return (saves, notifications)
    }

    @Test func projectAndTagUnlinkingOnPurge() throws {
        let (container, _, catalogRepo) = try makeRepos()
        let tag = try catalogRepo.createTag(name: "UntagMe", sortOrder: 0)

        let todo = TodoItem(title: "Task", dayKey: "2026-09-10", tagIDs: TagIDList.encode([tag.id]))
        let routine = DailyRoutine(title: "Habit", sortOrder: 0, tagIDs: TagIDList.encode([tag.id]))
        let diary = DiaryEntry(text: "Entry", dayKey: "2026-09-10", tagIDs: TagIDList.encode([tag.id]))

        container.mainContext.insert(todo)
        container.mainContext.insert(routine)
        container.mainContext.insert(diary)
        try container.mainContext.save()

        try catalogRepo.purgeTag(id: tag.id)
        #expect(!TagIDList.contains(todo.tagIDs, tag.id))
        #expect(!TagIDList.contains(routine.tagIDs, tag.id))
        #expect(!TagIDList.contains(diary.tagIDs, tag.id))
    }

    @Test func catalogOpenCountCalculation() throws {
        let (container, _, catalogRepo) = try makeRepos()
        let day = "2026-09-10"
        let tag = try catalogRepo.createTag(name: "Metrics Tag", sortOrder: 0)

        let t1 = TodoItem(title: "T1", isDone: false, dayKey: day, tagIDs: TagIDList.encode([tag.id]))
        let t2 = TodoItem(title: "T2", isDone: true, dayKey: day, tagIDs: TagIDList.encode([tag.id]))
        let r1 = DailyRoutine(
            title: "R1",
            sortOrder: 0,
            isEnabled: true,
            createdDayKey: day,
            tagIDs: TagIDList.encode([tag.id])
        )

        container.mainContext.insert(t1)
        container.mainContext.insert(t2)
        container.mainContext.insert(r1)
        try container.mainContext.save()

        let count = try catalogRepo.openCount(tagID: tag.id, dayKey: day)
        #expect(count == 2)
    }
}
