import Foundation
import SwiftData
import Testing
@testable import AreaChain

@MainActor
struct SwiftDataTaskRepositoryTests {
    private func makeRepo() throws -> (ModelContainer, SwiftDataTaskRepository) {
        let schema = Schema(AreaChainSchema.models)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return (container, SwiftDataTaskRepository(container: container))
    }

    @Test func missingTodoThrowsNotFound() throws {
        let (container, repo) = try makeRepo()
        _ = container
        let nonExistentID = UUID()

        #expect(throws: RepositoryError.self) { try repo.toggleTodo(id: nonExistentID) }
        #expect(throws: RepositoryError.self) { try repo.completeTodo(id: nonExistentID) }
        #expect(throws: RepositoryError.self) { try repo.updateTodo(id: nonExistentID, title: "x", notes: nil) }
        #expect(throws: RepositoryError.self) { try repo.moveTodo(id: nonExistentID, to: "2026-09-10") }
        #expect(throws: RepositoryError.self) { try repo.setRemind(id: nonExistentID, minutes: 15) }
        #expect(throws: RepositoryError.self) { try repo.setPriority(id: nonExistentID, isImportant: true, isUrgent: false) }
        #expect(throws: RepositoryError.self) { try repo.setProject(id: nonExistentID, projectID: UUID()) }
        #expect(throws: RepositoryError.self) { try repo.toggleTag(id: nonExistentID, tagID: UUID()) }
        #expect(throws: RepositoryError.self) { try repo.deleteTodo(id: nonExistentID, soft: true) }
        #expect(throws: RepositoryError.self) { try repo.restoreTodo(id: nonExistentID) }
        #expect(throws: RepositoryError.self) { try repo.purgeTodo(id: nonExistentID) }
        #expect(throws: RepositoryError.self) { try repo.addSubtask(to: nonExistentID, title: "sub") }
        #expect(throws: RepositoryError.self) { try repo.reorderSubtasks(for: nonExistentID, orderedIDs: [UUID()]) }
    }

    @Test func missingSubtaskThrowsNotFound() throws {
        let (container, repo) = try makeRepo()
        _ = container
        let nonExistentID = UUID()

        #expect(throws: RepositoryError.self) { try repo.toggleSubtask(id: nonExistentID) }
        #expect(throws: RepositoryError.self) { try repo.editSubtask(id: nonExistentID, title: "sub") }
        #expect(throws: RepositoryError.self) { try repo.deleteSubtask(id: nonExistentID, soft: true) }
    }

    @Test func blankTitleThrowsInvalidArgument() throws {
        let (container, repo) = try makeRepo()
        _ = container
        let day = "2026-09-10"

        #expect(throws: RepositoryError.self) { try repo.addTodo(title: "   ", dayKey: day) }
        #expect(throws: RepositoryError.self) { try repo.addTodo(title: "\n\t  ", dayKey: day) }

        let todo = try repo.addTodo(title: "Valid Todo", dayKey: day)
        #expect(throws: RepositoryError.self) { try repo.updateTodo(id: todo.id, title: "   ", notes: nil) }
        #expect(throws: RepositoryError.self) { try repo.addSubtask(to: todo.id, title: "   ") }

        let sub = try repo.addSubtask(to: todo.id, title: "Valid Sub")
        #expect(throws: RepositoryError.self) { try repo.editSubtask(id: sub.id, title: "   ") }
    }

    @Test func subtaskCompletionCascadesOneWay() throws {
        let (container, repo) = try makeRepo()
        _ = container
        let todo = try repo.addTodo(title: "Cascade Parent", dayKey: "2026-09-10")
        let sub1 = try repo.addSubtask(to: todo.id, title: "Sub 1")
        let sub2 = try repo.addSubtask(to: todo.id, title: "Sub 2")
        let deletedSub = try repo.addSubtask(to: todo.id, title: "Deleted Sub")

        try repo.deleteSubtask(id: deletedSub.id, soft: true)

        #expect(!todo.isDone)
        #expect(!sub1.isDone && !sub2.isDone && !deletedSub.isDone)

        try repo.toggleTodo(id: todo.id)
        #expect(todo.isDone)
        #expect(sub1.isDone)
        #expect(sub2.isDone)
        #expect(!deletedSub.isDone)

        try repo.toggleTodo(id: todo.id)
        #expect(!todo.isDone)
        #expect(sub1.isDone)
        #expect(sub2.isDone)

        let otherTodo = try repo.addTodo(title: "Other Parent", dayKey: "2026-09-10")
        let otherSub = try repo.addSubtask(to: otherTodo.id, title: "Other Sub")
        try repo.completeTodo(id: otherTodo.id)
        #expect(otherTodo.isDone)
        #expect(otherSub.isDone)
    }

    @Test func softDeleteTimestampAlignmentAndSelectiveRestore() throws {
        let (container, repo) = try makeRepo()
        let todo = try repo.addTodo(title: "Align Parent", dayKey: "2026-09-10")
        let liveSub = try repo.addSubtask(to: todo.id, title: "Live Sub")
        let priorSub = try repo.addSubtask(to: todo.id, title: "Prior Deleted Sub")

        let priorDate = Date(timeIntervalSince1970: 1000)
        priorSub.deletedAt = priorDate

        let attachment = AttachmentItem(
            ownerKind: AttachmentOwner.todo.rawValue,
            ownerID: todo.id,
            filename: "proof.pdf"
        )
        container.mainContext.insert(attachment)
        try container.mainContext.save()

        try repo.deleteTodo(id: todo.id, soft: true)

        let deletedStamp = try #require(todo.deletedAt)
        #expect(liveSub.deletedAt == deletedStamp)
        #expect(priorSub.deletedAt == priorDate)
        #expect(attachment.deletedAt == deletedStamp)

        try repo.restoreTodo(id: todo.id)
        #expect(todo.deletedAt == nil)
        #expect(liveSub.deletedAt == nil)
        #expect(priorSub.deletedAt == priorDate)
        #expect(attachment.deletedAt == nil)
    }

    @Test func purgeTodoPhysicallyDeletesAttachments() throws {
        let (container, repo) = try makeRepo()
        let todo = try repo.addTodo(title: "Purge Parent", dayKey: "2026-09-10")
        let attachment = AttachmentItem(
            ownerKind: AttachmentOwner.todo.rawValue,
            ownerID: todo.id,
            filename: "shot.png"
        )
        container.mainContext.insert(attachment)
        try container.mainContext.save()

        try repo.purgeTodo(id: todo.id)

        let remainingTodos = try repo.fetchAllTodos(includeDeleted: true)
        #expect(!remainingTodos.contains(where: { $0.id == todo.id }))
        let attachments = try container.mainContext.fetch(FetchDescriptor<AttachmentItem>())
        #expect(attachments.isEmpty)
    }

    @Test func reorderSubtasksAndSortingStability() throws {
        let (container, repo) = try makeRepo()
        _ = container
        let todo = try repo.addTodo(title: "Reorder Parent", dayKey: "2026-09-10")
        let subA = try repo.addSubtask(to: todo.id, title: "A")
        let subB = try repo.addSubtask(to: todo.id, title: "B")
        let subC = try repo.addSubtask(to: todo.id, title: "C")

        #expect(subA.sortOrder == 0)
        #expect(subB.sortOrder == 1)
        #expect(subC.sortOrder == 2)

        try repo.reorderSubtasks(for: todo.id, orderedIDs: [subC.id, subA.id, subB.id])
        #expect(subC.sortOrder == 0)
        #expect(subA.sortOrder == 1)
        #expect(subB.sortOrder == 2)

        let fetchDay = "2026-09-11"
        let t1 = try repo.addTodo(title: "T1", dayKey: fetchDay)
        let t2 = try repo.addTodo(title: "T2", dayKey: fetchDay)
        let t3 = try repo.addTodo(title: "T3", dayKey: fetchDay)
        let fetched = try repo.fetchTodos(for: fetchDay)
        #expect(fetched.map(\.id) == [t1.id, t2.id, t3.id])
    }

    @Test func batchOperationsIntegrity() throws {
        let (container, repo) = try makeRepo()
        _ = container
        let t1 = try repo.addTodo(title: "B1", dayKey: "2026-09-10")
        let t2 = try repo.addTodo(title: "B2", dayKey: "2026-09-10")
        let s1 = try repo.addSubtask(to: t1.id, title: "S1")

        let set = Set([t1.id, t2.id])
        try repo.batchMoveTodos(ids: set, to: "2026-09-12")
        #expect(t1.dayKey == "2026-09-12" && t2.dayKey == "2026-09-12")

        try repo.batchToggleDone(ids: set, markDone: true)
        #expect(t1.isDone && t2.isDone && s1.isDone)

        try repo.batchToggleDone(ids: set, markDone: false)
        #expect(!t1.isDone && !t2.isDone && s1.isDone)

        let projID = UUID()
        try repo.batchSetProject(ids: set, projectID: projID)
        #expect(t1.projectID == projID && t2.projectID == projID)

        let tagID = UUID()
        try repo.batchToggleTag(ids: set, tagID: tagID)
        #expect(TagIDList.contains(t1.tagIDs, tagID))
        #expect(TagIDList.contains(t2.tagIDs, tagID))

        try repo.batchTrashTodos(ids: set)
        #expect(t1.deletedAt != nil && t2.deletedAt != nil && s1.deletedAt == t1.deletedAt)
    }
}
