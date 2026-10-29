import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 第 failOn 次备注／改期／子任务排序调用先真实写入再抛错，检验多目标共同事务整体回滚。
@MainActor final class TaskSimpleCommandFailureRepository: TaskRepositoryProtocol {
    let context: ModelContext
    let failOn: Int
    var calls = 0
    init(_ context: ModelContext, failOn: Int) {
        self.context = context
        self.failOn = failOn
    }

    private func forward(_ write: (SwiftDataTaskRepository) throws -> Void) throws {
        calls += 1
        try write(SwiftDataTaskRepository(context: context))
        if calls == failOn { throw TaskCreateCommandIO.Failure.injected }
    }

    func addTodo(_ params: CreateTodoParams) throws -> TodoItem { throw unexpected() }

    private func unexpected() -> Error {
        Issue.record("T-M6 失败夹具不应调用其他业务入口")
        return CocoaError(.featureUnsupported)
    }

    func fetchTodos(for dayKey: String) throws -> [TodoItem] { throw unexpected() }
    func fetchTodo(id: UUID) throws -> TodoItem? { throw unexpected() }
    func fetchAllTodos(includeDeleted: Bool) throws -> [TodoItem] { throw unexpected() }
    func fetchTodos(forTag tagID: UUID) throws -> [TodoItem] { throw unexpected() }
    func fetchTodos(isDone: Bool) throws -> [TodoItem] { throw unexpected() }
    func moveTodo(id: UUID, to dayKey: String) throws { try forward { try $0.moveTodo(id: id, to: dayKey) } }
    func toggleTodo(id: UUID) throws { throw unexpected() }
    func completeTodo(id: UUID) throws { throw unexpected() }
    func updateTodo(id: UUID, title: String?, notes: String?) throws { throw unexpected() }
    func setRemind(id: UUID, minutes: Int?) throws { throw unexpected() }
    func setPriority(id: UUID, isImportant: Bool, isUrgent: Bool) throws { throw unexpected() }
    func toggleTag(id: UUID, tagID: UUID) throws { throw unexpected() }
    func replaceTagIDs(id: UUID, tagIDs: String) throws { throw unexpected() }
    func applyParsedNotes(id: UUID, update: ParsedNoteUpdate) throws {
        try forward { try $0.applyParsedNotes(id: id, update: update) }
    }
    func applyCalendarFields(id: UUID, title: String, dayKey: String, remindMinutes: Int?, eventID: String) throws { throw unexpected() }
    func deleteTodo(id: UUID, soft: Bool) throws { throw unexpected() }
    func restoreTodo(id: UUID) throws { throw unexpected() }
    func purgeTodo(id: UUID) throws { throw unexpected() }
    func addSubtask(to todoID: UUID, title: String) throws -> SubtaskItem { throw unexpected() }
    func toggleSubtask(id: UUID) throws { throw unexpected() }
    func editSubtask(id: UUID, title: String) throws { throw unexpected() }
    func toggleSubtaskTag(id: UUID, tagID: UUID) throws { throw unexpected() }
    func deleteSubtask(id: UUID, soft: Bool) throws { throw unexpected() }
    func reorderSubtasks(for todoID: UUID, orderedIDs: [UUID]) throws {
        try forward { try $0.reorderSubtasks(for: todoID, orderedIDs: orderedIDs) }
    }
    func batchMoveTodos(ids: Set<UUID>, to dayKey: String) throws { throw unexpected() }
    func batchToggleDone(ids: Set<UUID>, markDone: Bool) throws { throw unexpected() }
    func batchTrashTodos(ids: Set<UUID>) throws { throw unexpected() }
    func batchApplyTag(ids: Set<UUID>, tagID: UUID, present: Bool) throws { throw unexpected() }
    func batchToggleTag(ids: Set<UUID>, tagID: UUID) throws { throw unexpected() }
}
