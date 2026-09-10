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

        #expect(throws: RepositoryError.self) {
            try catalogRepo.updateProject(id: id, name: "p", parentID: nil, sortOrder: nil)
        }
        #expect(throws: RepositoryError.self) { try catalogRepo.deleteProject(id: id, soft: true) }
        #expect(throws: RepositoryError.self) { try catalogRepo.restoreProject(id: id) }
        #expect(throws: RepositoryError.self) { try catalogRepo.purgeProject(id: id) }

        #expect(throws: RepositoryError.self) { try catalogRepo.updateTag(id: id, name: "t", sortOrder: nil) }
        #expect(throws: RepositoryError.self) { try catalogRepo.deleteTag(id: id, soft: true) }
        #expect(throws: RepositoryError.self) { try catalogRepo.restoreTag(id: id) }
        #expect(throws: RepositoryError.self) { try catalogRepo.purgeTag(id: id) }
    }

    @Test func blankInputsThrowInvalidArgument() throws {
        let (container, diaryRepo, catalogRepo) = try makeRepos()
        _ = container
        #expect(throws: RepositoryError.self) { try diaryRepo.addDiary(text: "  ", dayKey: "2026-09-10", tagIDs: []) }
        #expect(throws: RepositoryError.self) { try catalogRepo.createProject(name: "  ", parentID: nil, sortOrder: nil) }
        #expect(throws: RepositoryError.self) { try catalogRepo.createTag(name: "  ", sortOrder: nil) }
        #expect(throws: RepositoryError.self) { try catalogRepo.resolveOrCreateTag(name: "  ") }

        let proj = try catalogRepo.createProject(name: "Valid Proj", parentID: nil, sortOrder: 0)
        #expect(throws: RepositoryError.self) {
            try catalogRepo.updateProject(id: proj.id, name: "  ", parentID: nil, sortOrder: nil)
        }

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

    @Test func projectTreeHierarchyAndNilParentID() throws {
        let (container, _, catalogRepo) = try makeRepos()
        _ = container
        let root = try catalogRepo.createProject(name: "Root", parentID: nil, sortOrder: 0)
        let sub1 = try catalogRepo.createProject(name: "Sub 1", parentID: root.id, sortOrder: 0)
        let sub2 = try catalogRepo.createProject(name: "Sub 2", parentID: sub1.id, sortOrder: 0)

        var outline = try catalogRepo.projectOutline()
        #expect(outline.count == 3)
        #expect(outline[0].id == root.id && outline[0].depth == 0)
        #expect(outline[1].id == sub1.id && outline[1].depth == 1)
        #expect(outline[2].id == sub2.id && outline[2].depth == 2)

        #expect(try catalogRepo.pathLabel(for: sub2.id) == "Root / Sub 1 / Sub 2")

        try catalogRepo.updateProject(id: sub2.id, name: nil, parentID: .some(nil), sortOrder: nil)
        outline = try catalogRepo.projectOutline()
        let sub2Row = try #require(outline.first(where: { $0.id == sub2.id }))
        #expect(sub2Row.depth == 0)
    }

    @Test func projectTreeCyclePreventionViaAllowedParents() throws {
        let (container, _, catalogRepo) = try makeRepos()
        _ = container
        let rootA = try catalogRepo.createProject(name: "Root A", parentID: nil, sortOrder: 0)
        let childA = try catalogRepo.createProject(name: "Child A", parentID: rootA.id, sortOrder: 0)
        let grandA = try catalogRepo.createProject(name: "Grand A", parentID: childA.id, sortOrder: 0)
        let rootB = try catalogRepo.createProject(name: "Root B", parentID: nil, sortOrder: 1)

        let allowedForRootA = try catalogRepo.allowedParents(for: rootA.id)
        let allowedIDsForRootA = Set(allowedForRootA.map(\.id))
        #expect(!allowedIDsForRootA.contains(rootA.id))
        #expect(!allowedIDsForRootA.contains(childA.id))
        #expect(!allowedIDsForRootA.contains(grandA.id))
        #expect(allowedIDsForRootA.contains(rootB.id))

        let allowedForGrandA = try catalogRepo.allowedParents(for: grandA.id)
        let allowedIDsForGrandA = Set(allowedForGrandA.map(\.id))
        #expect(!allowedIDsForGrandA.contains(grandA.id))
        #expect(allowedIDsForGrandA.contains(rootA.id))
        #expect(allowedIDsForGrandA.contains(childA.id))
        #expect(allowedIDsForGrandA.contains(rootB.id))

        try catalogRepo.updateProject(id: rootA.id, name: nil, parentID: .some(childA.id), sortOrder: nil)
        let cycleOutline = try catalogRepo.projectOutline()
        #expect(!cycleOutline.contains(where: { $0.id == rootA.id }))
        let cycleLabel = try catalogRepo.pathLabel(for: rootA.id)
        #expect(!cycleLabel.isEmpty)
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

    @Test func projectAndTagUnlinkingOnPurge() throws {
        let (container, _, catalogRepo) = try makeRepos()
        let proj = try catalogRepo.createProject(name: "DeleteMe", parentID: nil, sortOrder: 0)
        let childProj = try catalogRepo.createProject(name: "Child", parentID: proj.id, sortOrder: 0)
        let tag = try catalogRepo.createTag(name: "UntagMe", sortOrder: 0)

        let todo = TodoItem(title: "Task", dayKey: "2026-09-10", projectID: proj.id, tagIDs: TagIDList.encode([tag.id]))
        let routine = DailyRoutine(title: "Habit", sortOrder: 0, projectID: proj.id, tagIDs: TagIDList.encode([tag.id]))
        let diary = DiaryEntry(text: "Entry", dayKey: "2026-09-10", tagIDs: TagIDList.encode([tag.id]))

        container.mainContext.insert(todo)
        container.mainContext.insert(routine)
        container.mainContext.insert(diary)
        try container.mainContext.save()

        try catalogRepo.purgeProject(id: proj.id)
        #expect(todo.projectID == nil)
        #expect(routine.projectID == nil)
        #expect(childProj.parentID == nil)

        try catalogRepo.purgeTag(id: tag.id)
        #expect(!TagIDList.contains(todo.tagIDs, tag.id))
        #expect(!TagIDList.contains(routine.tagIDs, tag.id))
        #expect(!TagIDList.contains(diary.tagIDs, tag.id))
    }

    @Test func catalogOpenCountCalculation() throws {
        let (container, _, catalogRepo) = try makeRepos()
        let day = "2026-09-10"
        let proj = try catalogRepo.createProject(name: "Metrics Project", parentID: nil, sortOrder: 0)
        let tag = try catalogRepo.createTag(name: "Metrics Tag", sortOrder: 0)

        let t1 = TodoItem(title: "T1", isDone: false, dayKey: day, projectID: proj.id, tagIDs: TagIDList.encode([tag.id]))
        let t2 = TodoItem(title: "T2", isDone: true, dayKey: day, projectID: proj.id, tagIDs: TagIDList.encode([tag.id]))
        let r1 = DailyRoutine(
            title: "R1",
            sortOrder: 0,
            isEnabled: true,
            createdDayKey: day,
            projectID: proj.id,
            tagIDs: TagIDList.encode([tag.id])
        )

        container.mainContext.insert(t1)
        container.mainContext.insert(t2)
        container.mainContext.insert(r1)
        try container.mainContext.save()

        let count = try catalogRepo.openCount(projectID: proj.id, tagID: tag.id, dayKey: day)
        #expect(count == 2)
    }
}
