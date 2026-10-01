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

    @Test func presetRepairCreatesMissingWithoutRestoringDeleted() throws {
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
        #expect(journal.deletedAt == stamp)
        let tags = try ModelContext(container).fetch(FetchDescriptor<TagItem>())
        #expect(tags.count == 4)
        let liveNames = tags.filter { $0.deletedAt == nil }.map { TagSyntax.normalizedName($0.name) }
        #expect(Set(liveNames) == Set([DiaryMemoTags.password, DiaryMemoTags.idea]))
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
        #expect(try catalogRepo.openCount(tagID: UUID(), dayKey: day) == 0)
        try catalogRepo.deleteTag(id: tag.id, soft: true)
        #expect(try catalogRepo.openCount(tagID: tag.id, dayKey: day) == 0)
    }

    @Test func diaryIdentityDateSearchAndFailedSaveStayEquivalent() throws {
        let (container, diaryRepo, catalogRepo) = try makeRepos()
        let context = container.mainContext
        #expect(try diaryRepo.fetchDiary(id: UUID()) == nil)
        #expect(try diaryRepo.fetchDiaries(for: "2026-09-10").isEmpty)

        let older = try diaryRepo.addDiary(text: "Older note", dayKey: "2026-09-10", tagIDs: [])
        older.createdAt = Date(timeIntervalSince1970: 10)
        let newer = try diaryRepo.addDiary(text: "Newer note", dayKey: "2026-09-10", tagIDs: [])
        newer.createdAt = Date(timeIntervalSince1970: 20)
        let otherDay = try diaryRepo.addDiary(text: "Other day", dayKey: "2026-09-11", tagIDs: [])
        try context.save()

        #expect(try diaryRepo.fetchDiaries(for: "2026-09-10").map(\.id) == [newer.id, older.id])
        #expect(try diaryRepo.fetchDiaries(for: "2026-09-11").map(\.id) == [otherDay.id])
        #expect(try diaryRepo.fetchDiaries(for: "2026-09-12").isEmpty)

        let tag = try catalogRepo.createTag(name: "Swift", sortOrder: 0)
        try diaryRepo.setTags(id: newer.id, tagIDs: [tag.id])
        #expect(try diaryRepo.searchDiaries(query: "note", tagID: tag.id, includeDeleted: false).map(\.id) == [newer.id])
        #expect(try diaryRepo.searchDiaries(query: "note", tagID: UUID(), includeDeleted: false).isEmpty)

        try diaryRepo.deleteDiary(id: older.id, soft: true)
        #expect(try diaryRepo.fetchDiary(id: older.id)?.deletedAt != nil)
        #expect(try diaryRepo.fetchDiaries(for: "2026-09-10", includeDeleted: false).map(\.id) == [newer.id])
        #expect(try diaryRepo.searchDiaries(query: "Older", tagID: nil, includeDeleted: true).map(\.id) == [older.id])
        #expect(try diaryRepo.searchDiaries(query: "Older", tagID: nil, includeDeleted: false).isEmpty)

        try diaryRepo.moveDiary(id: newer.id, to: "2026-09-12")
        #expect(try diaryRepo.fetchDiary(id: newer.id)?.dayKey == "2026-09-12")
        #expect(throws: RepositoryError.self) { try diaryRepo.moveDiary(id: newer.id, to: "not-a-day") }
        #expect(try diaryRepo.fetchDiary(id: newer.id)?.dayKey == "2026-09-12")

        let original = try #require(try diaryRepo.fetchDiary(id: newer.id)?.text)
        let counts = mutationCounts(in: context) {
            #expect(throws: CocoaError.self) {
                try ModelChanges.transaction(in: context, save: { _ in throw CocoaError(.fileWriteNoPermission) }) {
                    try diaryRepo.editDiary(id: newer.id, text: "should roll back")
                }
            }
        }
        #expect(counts.saves == 0 && counts.notifications == 0)
        #expect(try diaryRepo.fetchDiary(id: newer.id)?.text == original)
        try diaryRepo.editDiary(id: newer.id, text: "retried text")
        #expect(try diaryRepo.fetchDiary(id: newer.id)?.text == "retried text")
        try diaryRepo.editDiary(id: newer.id, text: "retried text")
        #expect(try diaryRepo.fetchDiary(id: newer.id)?.text == "retried text")
    }

    @Test func purgedPresetIsNotRecreatedByEnsureOrKeyword() throws {
        let suiteName = "areachain.tests.presets.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        suite.removePersistentDomain(forName: suiteName)
        let previous = DiaryPresetRetention.defaultsOverride
        DiaryPresetRetention.defaultsOverride = suite
        defer {
            DiaryPresetRetention.defaultsOverride = previous
            suite.removePersistentDomain(forName: suiteName)
        }

        let (_, diaryRepo, catalogRepo) = try makeRepos()
        try catalogRepo.ensurePresetTags()
        let password = try #require(try catalogRepo.fetchTags().first { $0.name == DiaryMemoTags.password })
        try catalogRepo.purgeTag(id: password.id)
        _ = try diaryRepo.addDiary(text: "家里 wifi 密码", dayKey: "2026-09-30", tagIDs: [])
        try catalogRepo.ensurePresetTags()
        let names = try catalogRepo.fetchTags(includeDeleted: true).map(\.name)
        #expect(!names.contains(DiaryMemoTags.password))
    }

    @Test func catalogIdentityDeletedBatchColorAndUnlinkStayEquivalent() throws {
        let (container, diaryRepo, catalogRepo) = try makeRepos()
        #expect(try catalogRepo.fetchTag(id: UUID()) == nil)
        let kept = try catalogRepo.createTag(name: "KeepColor", sortOrder: 0)
        let removed = try catalogRepo.createTag(name: "DropMe", sortOrder: 1)
        try catalogRepo.ensurePresetTags()
        let preset = try #require(try catalogRepo.fetchTags().first { $0.isDiaryPreset })

        try catalogRepo.deleteTag(id: removed.id, soft: true)
        #expect(try catalogRepo.fetchTag(id: removed.id)?.deletedAt != nil)
        #expect(try catalogRepo.fetchTags(includeDeleted: false).map(\.id).contains(removed.id) == false)
        #expect(try catalogRepo.fetchTags(includeDeleted: true).contains { $0.id == removed.id })

        try catalogRepo.batchSetColor(ids: [kept.id, preset.id], colorToken: TagColorToken.clay.rawValue)
        #expect(try catalogRepo.fetchTag(id: kept.id)?.colorToken == TagColorToken.clay.rawValue)
        #expect(try catalogRepo.fetchTag(id: preset.id)?.colorToken == TagColorToken.default.rawValue)
        #expect(throws: RepositoryError.self) {
            try catalogRepo.batchSetColor(ids: [preset.id], colorToken: TagColorToken.ink.rawValue)
        }
        #expect(throws: RepositoryError.self) {
            try catalogRepo.batchSetColor(ids: [], colorToken: TagColorToken.ink.rawValue)
        }

        let diary = try diaryRepo.addDiary(text: "tagged", dayKey: "2026-09-10", tagIDs: [kept.id])
        let orphanParent = TodoItem(title: "parent", dayKey: "2026-09-10")
        let child = SubtaskItem(title: "child", tagIDs: TagIDList.encode([kept.id]), todo: orphanParent)
        container.mainContext.insert(orphanParent)
        container.mainContext.insert(child)
        try container.mainContext.save()
        try catalogRepo.unlinkTag(id: kept.id)
        #expect(!TagIDList.contains(diary.tagIDs, kept.id))
        #expect(!TagIDList.contains(child.tagIDs, kept.id))
        #expect(try catalogRepo.fetchTag(id: kept.id) != nil)
    }
}
