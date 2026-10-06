import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 仅 addTodo 委托真实仓储后注入失败，证明内存 mutation 的真实回滚；其他业务入口封闭。
@MainActor final class TaskCreateFailureRepository: TaskRepositoryProtocol {
    let context: ModelContext
    var calls = 0
    var insertedCount = 0
    init(_ context: ModelContext) { self.context = context }

    func addTodo(_ params: CreateTodoParams) throws -> TodoItem {
        calls += 1
        _ = try SwiftDataTaskRepository(context: context).addTodo(params)
        insertedCount = try context.fetchCount(FetchDescriptor<TodoItem>())
        throw TaskCreateCommandIO.Failure.injected
    }

    private func unexpected() -> Error {
        Issue.record("创建失败夹具不应调用其他业务入口")
        return CocoaError(.featureUnsupported)
    }

    func fetchTodos(for dayKey: String) throws -> [TodoItem] { throw unexpected() }
    func fetchTodo(id: UUID) throws -> TodoItem? { throw unexpected() }
    func fetchAllTodos(includeDeleted: Bool) throws -> [TodoItem] { throw unexpected() }
    func fetchTodos(forTag tagID: UUID) throws -> [TodoItem] { throw unexpected() }
    func fetchTodos(isDone: Bool) throws -> [TodoItem] { throw unexpected() }
    func moveTodo(id: UUID, to dayKey: String) throws { throw unexpected() }
    func toggleTodo(id: UUID) throws { throw unexpected() }
    func completeTodo(id: UUID) throws { throw unexpected() }
    func updateTodo(id: UUID, title: String?, notes: String?) throws { throw unexpected() }
    func setRemind(id: UUID, minutes: Int?) throws { throw unexpected() }
    func setPriority(id: UUID, isImportant: Bool, isUrgent: Bool) throws { throw unexpected() }
    func toggleTag(id: UUID, tagID: UUID) throws { throw unexpected() }
    func replaceTagIDs(id: UUID, tagIDs: String) throws { throw unexpected() }
    func applyParsedNotes(id: UUID, update: ParsedNoteUpdate) throws { throw unexpected() }
    func applyCalendarFields(id: UUID, title: String, dayKey: String, remindMinutes: Int?, eventID: String) throws { throw unexpected() }
    func deleteTodo(id: UUID, soft: Bool) throws { throw unexpected() }
    func restoreTodo(id: UUID) throws { throw unexpected() }
    func purgeTodo(id: UUID) throws { throw unexpected() }
    func addSubtask(to todoID: UUID, title: String) throws -> SubtaskItem { throw unexpected() }
    func toggleSubtask(id: UUID) throws { throw unexpected() }
    func editSubtask(id: UUID, title: String) throws { throw unexpected() }
    func toggleSubtaskTag(id: UUID, tagID: UUID) throws { throw unexpected() }
    func deleteSubtask(id: UUID, soft: Bool) throws { throw unexpected() }
    func reorderSubtasks(for todoID: UUID, orderedIDs: [UUID]) throws { throw unexpected() }
    func batchMoveTodos(ids: Set<UUID>, to dayKey: String) throws { throw unexpected() }
    func batchToggleDone(ids: Set<UUID>, markDone: Bool) throws { throw unexpected() }
    func batchTrashTodos(ids: Set<UUID>) throws { throw unexpected() }
    func batchApplyTag(ids: Set<UUID>, tagID: UUID, present: Bool) throws { throw unexpected() }
    func batchToggleTag(ids: Set<UUID>, tagID: UUID) throws { throw unexpected() }
}
