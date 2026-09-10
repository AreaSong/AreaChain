import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// Milestone M2 Empirical Challenger Stress Tests:
/// Adversarially stress testing all 4 SwiftData repositories on lifecycle retention,
/// edge cases, graph integrity, subtask deduplication, cascade operations, and cycle prevention.
@MainActor
struct SwiftDataRepositoryEmpiricalStressTests {

    private func makeIsolatedTaskRepo() throws -> SwiftDataTaskRepository {
        let schema = Schema(AreaChainSchema.models)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return SwiftDataTaskRepository(container: container)
    }

    private func makeIsolatedRoutineRepo() throws -> SwiftDataRoutineRepository {
        let schema = Schema(AreaChainSchema.models)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return SwiftDataRoutineRepository(container: container)
    }

    private func makeIsolatedCatalogRepo() throws -> SwiftDataCatalogRepository {
        let schema = Schema(AreaChainSchema.models)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return SwiftDataCatalogRepository(container: container)
    }

    private func makeIsolatedDiaryRepo() throws -> SwiftDataDiaryRepository {
        let schema = Schema(AreaChainSchema.models)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return SwiftDataDiaryRepository(container: container)
    }

    // MARK: - 1. Container Retention Verification (No External Reference Held)

    @Test func containerRetentionKeepsTaskRepositoryAliveWithoutExternalReference() throws {
        let repo = try makeIsolatedTaskRepo()
        // Caller holds ZERO reference to container; internal retainedContainer must keep context alive
        let todo = try repo.addTodo(title: "Autonomous Repo Task", dayKey: "2026-09-10")
        #expect(todo.title == "Autonomous Repo Task")
        let sub = try repo.addSubtask(to: todo.id, title: "Autonomous Sub")
        #expect(sub.title == "Autonomous Sub")
        try repo.toggleTodo(id: todo.id)
        #expect(todo.isDone)
        #expect(sub.isDone)
        let fetched = try repo.fetchTodo(id: todo.id)
        #expect(fetched?.isDone == true)
        try repo.deleteTodo(id: todo.id, soft: true)
        #expect(try repo.fetchTodos(for: "2026-09-10").isEmpty)
    }

    @Test func containerRetentionKeepsRoutineRepositoryAliveWithoutExternalReference() throws {
        let repo = try makeIsolatedRoutineRepo()
        let routine = try repo.addRoutine(title: "Autonomous Routine")
        #expect(routine.title == "Autonomous Routine")
        try repo.toggleRoutine(id: routine.id, dayKey: "2026-09-10")
        let checks = try repo.fetchChecks(for: routine.id)
        #expect(checks.count == 1 && checks[0].isDone)
        try repo.skipRoutine(id: routine.id, dayKey: "2026-09-11")
        let checksAfter = try repo.fetchChecks(for: routine.id)
        #expect(checksAfter.count == 2)
        try repo.deleteRoutine(id: routine.id, soft: true)
        #expect(try repo.fetchRoutines(includeDisabled: true, includeDeleted: false).isEmpty)
    }

    @Test func containerRetentionKeepsCatalogRepositoryAliveWithoutExternalReference() throws {
        let repo = try makeIsolatedCatalogRepo()
        let project = try repo.createProject(name: "Autonomous Project", parentID: nil, sortOrder: 0)
        let tag = try repo.createTag(name: "Autonomous Tag", sortOrder: 0)
        #expect(try repo.fetchProject(id: project.id) != nil)
        #expect(try repo.fetchTag(id: tag.id) != nil)
        try repo.deleteProject(id: project.id, soft: true)
        try repo.deleteTag(id: tag.id, soft: true)
        #expect(try repo.fetchProjects(includeDeleted: false).isEmpty)
        #expect(try repo.fetchTags(includeDeleted: false).isEmpty)
    }

    @Test func containerRetentionKeepsDiaryRepositoryAliveWithoutExternalReference() throws {
        let repo = try makeIsolatedDiaryRepo()
        let diary = try repo.addDiary(text: "Autonomous Note", dayKey: "2026-09-10", tagIDs: [])
        #expect(diary.text == "Autonomous Note")
        try repo.togglePin(id: diary.id)
        #expect(diary.isPinned)
        let fetched = try repo.fetchDiaries(for: "2026-09-10", includeDeleted: false)
        #expect(fetched.count == 1)
        try repo.deleteDiary(id: diary.id, soft: true)
        #expect(try repo.fetchDiaries(for: "2026-09-10", includeDeleted: false).isEmpty)
    }

    // MARK: - 2. Subtask Edge Cases & Deduplication

    @Test func addSubtaskNeverDuplicatesSubtaskReferencesAcrossMultipleAdditions() throws {
        let repo = try makeIsolatedTaskRepo()
        let todo = try repo.addTodo(title: "Multi-Subtask Host", dayKey: "2026-09-10")
        #expect(todo.subtasks.isEmpty)

        var createdIDs: [UUID] = []
        for i in 0..<20 {
            let sub = try repo.addSubtask(to: todo.id, title: "Subtask \(i)")
            createdIDs.append(sub.id)
            #expect(todo.subtasks.count == i + 1, "Subtask count must exactly equal additions")
        }

        #expect(todo.subtasks.count == 20)
        let idSet = Set(todo.subtasks.map(\.id))
        #expect(idSet.count == 20, "All subtask IDs in todo.subtasks must be unique")
        #expect(idSet == Set(createdIDs))

        for (idx, sub) in todo.subtasks.sorted(by: { $0.sortOrder < $1.sortOrder }).enumerated() {
            #expect(sub.sortOrder == idx)
        }

        let freshTodo = try #require(try repo.fetchTodo(id: todo.id))
        #expect(freshTodo.subtasks.count == 20)
    }

    @Test func subtaskCascadeCompletionAndSelectiveRestoreDeepStress() throws {
        let repo = try makeIsolatedTaskRepo()
        let todo = try repo.addTodo(title: "Cascade Master", dayKey: "2026-09-10")
        let sub1 = try repo.addSubtask(to: todo.id, title: "Active Sub 1")
        let sub2 = try repo.addSubtask(to: todo.id, title: "Active Sub 2")
        let deletedSub = try repo.addSubtask(to: todo.id, title: "Independently Deleted")

        let pastDate = Date(timeIntervalSince1970: 500)
        deletedSub.deletedAt = pastDate

        try repo.toggleTodo(id: todo.id)
        #expect(todo.isDone)
        #expect(sub1.isDone && sub2.isDone)
        #expect(!deletedSub.isDone, "Independently deleted subtask should not be marked done")

        try repo.toggleTodo(id: todo.id)
        #expect(!todo.isDone)
        #expect(sub1.isDone && sub2.isDone)

        try repo.deleteTodo(id: todo.id, soft: true)
        let parentDeletedStamp = try #require(todo.deletedAt)
        #expect(sub1.deletedAt == parentDeletedStamp)
        #expect(sub2.deletedAt == parentDeletedStamp)
        #expect(deletedSub.deletedAt == pastDate, "Prior deleted subtask stamp must not be overwritten")

        try repo.restoreTodo(id: todo.id)
        #expect(todo.deletedAt == nil)
        #expect(sub1.deletedAt == nil)
        #expect(sub2.deletedAt == nil)
        #expect(deletedSub.deletedAt == pastDate, "Prior deleted subtask must remain deleted upon parent restore")
    }

    @Test func subtaskPurgeCascadesPhysicalDeletion() throws {
        let repo = try makeIsolatedTaskRepo()
        let todo = try repo.addTodo(title: "Purge Host", dayKey: "2026-09-10")
        let sub1 = try repo.addSubtask(to: todo.id, title: "Sub A")
        let sub2 = try repo.addSubtask(to: todo.id, title: "Sub B")
        let sub1ID = sub1.id
        let sub2ID = sub2.id

        try repo.purgeTodo(id: todo.id)
        #expect(try repo.fetchTodo(id: todo.id) == nil)
        #expect(throws: RepositoryError.self) { try repo.toggleSubtask(id: sub1ID) }
        #expect(throws: RepositoryError.self) { try repo.toggleSubtask(id: sub2ID) }
    }

    // MARK: - 3. Routine Check Toggles, Skips, and Masked Bridges

    @Test func routineCheckTogglesSkipsAndMaskedBridgesAcrossDates() throws {
        let repo = try makeIsolatedRoutineRepo()
        let routine = try repo.addRoutine(CreateRoutineParams(
            title: "Morning Standup",
            weekdaysOnly: true,
            createdDayKey: "2026-09-01"
        ))
        let dates = ["2026-09-01", "2026-09-02", "2026-09-03", "2026-09-04"]
        for d in dates {
            try repo.toggleRoutine(id: routine.id, dayKey: d)
        }
        var checks = try repo.fetchChecks(for: routine.id)
        #expect(checks.count == 4)
        #expect(checks.allSatisfy { $0.isDone && !$0.isSkipped })

        try repo.skipRoutine(id: routine.id, dayKey: "2026-09-03")
        checks = try repo.fetchChecks(for: routine.id)
        let skipped = try #require(checks.first(where: { $0.dayKey == "2026-09-03" }))
        #expect(skipped.isDone && skipped.isSkipped)

        try repo.toggleRoutine(id: routine.id, dayKey: "2026-09-03")
        checks = try repo.fetchChecks(for: routine.id)
        let unskipped = try #require(checks.first(where: { $0.dayKey == "2026-09-03" }))
        #expect(!unskipped.isDone && !unskipped.isSkipped)

        try repo.setRoutineEnabled(id: routine.id, enabled: false, todayKey: "2026-09-04")
        #expect(!routine.isEnabled)
        #expect(routine.pausedOnDayKey == "2026-09-04")

        try repo.setRoutineEnabled(id: routine.id, enabled: true, todayKey: "2026-09-09")
        #expect(routine.isEnabled)
        #expect(routine.pausedOnDayKey == nil)

        let updatedChecks = try repo.fetchChecks(for: routine.id)
        let checkDaySet = Set(updatedChecks.map(\.dayKey))
        #expect(checkDaySet.contains("2026-09-07"))
        #expect(checkDaySet.contains("2026-09-08"))
        #expect(!checkDaySet.contains("2026-09-05"))
        #expect(!checkDaySet.contains("2026-09-06"))

        let countBefore = updatedChecks.count
        try repo.setRoutineEnabled(id: routine.id, enabled: true, todayKey: "2026-09-10")
        #expect((try repo.fetchChecks(for: routine.id)).count == countBefore)
    }

    // MARK: - 4. Project Tree Cycles & Nil Parent Stress

    @Test func projectTreeCycleStressAndTerminationGuarantee() throws {
        let repo = try makeIsolatedCatalogRepo()
        let nodeA = try repo.createProject(name: "A", parentID: nil, sortOrder: 0)
        let nodeB = try repo.createProject(name: "B", parentID: nodeA.id, sortOrder: 0)
        let nodeC = try repo.createProject(name: "C", parentID: nodeB.id, sortOrder: 0)
        let nodeD = try repo.createProject(name: "D", parentID: nodeC.id, sortOrder: 0)

        let allowedForA = try repo.allowedParents(for: nodeA.id)
        let allowedIDsForA = Set(allowedForA.map(\.id))
        #expect(!allowedIDsForA.contains(nodeA.id))
        #expect(!allowedIDsForA.contains(nodeB.id))
        #expect(!allowedIDsForA.contains(nodeC.id))
        #expect(!allowedIDsForA.contains(nodeD.id))

        try repo.updateProject(id: nodeA.id, name: nil, parentID: .some(nodeD.id), sortOrder: nil)

        let outline = try repo.projectOutline()
        #expect(outline.isEmpty)

        let labelA = try repo.pathLabel(for: nodeA.id)
        #expect(!labelA.isEmpty)

        try repo.updateProject(id: nodeA.id, name: nil, parentID: .some(nil), sortOrder: nil)
        let restoredOutline = try repo.projectOutline()
        #expect(restoredOutline.count == 4)
    }

    @Test func projectTreeNilParentAndReparentingStress() throws {
        let repo = try makeIsolatedCatalogRepo()
        let orphan = try repo.createProject(name: "Orphan", parentID: UUID(), sortOrder: 0)
        let outline = try repo.projectOutline()
        let orphanRow = try #require(outline.first(where: { $0.id == orphan.id }))
        #expect(orphanRow.depth == 0)

        let parent = try repo.createProject(name: "Parent", parentID: nil, sortOrder: 1)
        let child = try repo.createProject(name: "Child", parentID: parent.id, sortOrder: 0)
        #expect(try repo.pathLabel(for: child.id) == "Parent / Child")

        try repo.updateProject(id: child.id, name: nil, parentID: .some(nil), sortOrder: nil)
        #expect(try repo.pathLabel(for: child.id) == "Child")

        try repo.updateProject(id: child.id, name: nil, parentID: .some(parent.id), sortOrder: nil)
        #expect(try repo.pathLabel(for: child.id) == "Parent / Child")
    }

    // MARK: - 5. Soft-Deleted Items Filtering

    @Test func softDeletedItemsFilteringAcrossAllRepositories() throws {
        let schema = Schema(AreaChainSchema.models)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let taskRepo = SwiftDataTaskRepository(container: container)
        let routineRepo = SwiftDataRoutineRepository(container: container)
        let catalogRepo = SwiftDataCatalogRepository(container: container)
        let diaryRepo = SwiftDataDiaryRepository(container: container)

        let todo = try taskRepo.addTodo(title: "Task Soft", dayKey: "2026-09-10")
        try taskRepo.deleteTodo(id: todo.id, soft: true)
        #expect(try taskRepo.fetchTodos(for: "2026-09-10").isEmpty)
        #expect(try taskRepo.fetchAllTodos(includeDeleted: false).isEmpty)
        #expect(try taskRepo.fetchAllTodos(includeDeleted: true).count == 1)

        let routine = try routineRepo.addRoutine(title: "Routine Soft")
        try routineRepo.deleteRoutine(id: routine.id, soft: true)
        #expect(try routineRepo.fetchRoutines(includeDisabled: true, includeDeleted: false).isEmpty)
        #expect(try routineRepo.fetchRoutines(includeDisabled: true, includeDeleted: true).count == 1)

        let project = try catalogRepo.createProject(name: "Project Soft", parentID: nil, sortOrder: 0)
        try catalogRepo.deleteProject(id: project.id, soft: true)
        #expect(try catalogRepo.fetchProjects(includeDeleted: false).isEmpty)
        #expect(try catalogRepo.fetchProjects(includeDeleted: true).count == 1)
        #expect(try catalogRepo.projectOutline().isEmpty)

        let tag = try catalogRepo.createTag(name: "Tag Soft", sortOrder: 0)
        try catalogRepo.deleteTag(id: tag.id, soft: true)
        #expect(try catalogRepo.fetchTags(includeDeleted: false).isEmpty)
        #expect(try catalogRepo.fetchTags(includeDeleted: true).count == 1)

        let diary = try diaryRepo.addDiary(text: "Diary Soft", dayKey: "2026-09-10", tagIDs: [])
        try diaryRepo.deleteDiary(id: diary.id, soft: true)
        #expect(try diaryRepo.fetchDiaries(for: "2026-09-10", includeDeleted: false).isEmpty)
        #expect(try diaryRepo.fetchDiaries(for: "2026-09-10", includeDeleted: true).count == 1)
    }

    // MARK: - 6. Non-Existent UUID Handling

    @Test func nonExistentUUIDStressAcrossAllFourRepositories() throws {
        let schema = Schema(AreaChainSchema.models)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let taskRepo = SwiftDataTaskRepository(container: container)
        let routineRepo = SwiftDataRoutineRepository(container: container)
        let catalogRepo = SwiftDataCatalogRepository(container: container)
        let diaryRepo = SwiftDataDiaryRepository(container: container)
        let ghost = UUID()

        #expect(try taskRepo.fetchTodo(id: ghost) == nil)
        #expect(try routineRepo.fetchRoutine(id: ghost) == nil)
        #expect(try catalogRepo.fetchProject(id: ghost) == nil)
        #expect(try catalogRepo.fetchTag(id: ghost) == nil)
        #expect(try diaryRepo.fetchDiary(id: ghost) == nil)
        #expect(try taskRepo.fetchTodos(forProject: ghost).isEmpty)
        #expect(try taskRepo.fetchTodos(forTag: ghost).isEmpty)
        #expect(try routineRepo.fetchChecks(for: ghost).isEmpty)

        #expect(throws: RepositoryError.self) { try taskRepo.toggleTodo(id: ghost) }
        #expect(throws: RepositoryError.self) { try taskRepo.addSubtask(to: ghost, title: "Ghost Sub") }
        #expect(throws: RepositoryError.self) { try routineRepo.toggleRoutine(id: ghost, dayKey: "2026-09-10") }
        #expect(throws: RepositoryError.self) {
            try catalogRepo.updateProject(id: ghost, name: "G", parentID: nil, sortOrder: nil)
        }
        #expect(throws: RepositoryError.self) { try diaryRepo.editDiary(id: ghost, text: "G") }
    }
}
