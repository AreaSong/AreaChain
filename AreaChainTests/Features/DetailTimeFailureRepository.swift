import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 提醒在原 provider 内失败；真实模型修改与 commit 仍由原仓储执行。
/// 包装事务模拟保存失败的返回边界，不等于真实 ModelContext.save 磁盘故障。
@MainActor
final class DetailTimeFailureRepository: TaskRepositoryProtocol {
    let context: ModelContext
    var fails = false
    var calls: [Int?] = []
    var saveBoundaries = 0
    var stages: [String] = []

    init(_ context: ModelContext) { self.context = context }

    func setRemind(id: UUID, minutes: Int?) throws {
        calls.append(minutes)
        do {
            try ModelChanges.transaction(in: context, save: { context in
                self.saveBoundaries += 1
                self.stages.append("save requested=\(String(describing: minutes))")
                if self.fails { throw CocoaError(.fileWriteNoPermission) }
                try context.save()
            }) {
                try SwiftDataTaskRepository(context: context).setRemind(id: id, minutes: minutes)
                stages.append("base returned, boundaries=\(saveBoundaries)")
            }
            stages.append("repository returned")
        } catch {
            stages.append("repository throws after rollback")
            throw error
        }
    }

    private func unexpected() -> Error {
        Issue.record("时间诊断不应调用其他仓储操作")
        return CocoaError(.featureUnsupported)
    }

    func fetchTodos(for dayKey: String) throws -> [TodoItem] { throw unexpected() }
    func fetchTodo(id: UUID) throws -> TodoItem? { throw unexpected() }
    func fetchAllTodos(includeDeleted: Bool) throws -> [TodoItem] { throw unexpected() }
    func fetchTodos(forTag tagID: UUID) throws -> [TodoItem] { throw unexpected() }
    func fetchTodos(isDone: Bool) throws -> [TodoItem] { throw unexpected() }
    func addTodo(_ params: CreateTodoParams) throws -> TodoItem { throw unexpected() }
    func toggleTodo(id: UUID) throws { throw unexpected() }
    func completeTodo(id: UUID) throws { throw unexpected() }
    func updateTodo(id: UUID, title: String?, notes: String?) throws { throw unexpected() }
    func moveTodo(id: UUID, to dayKey: String) throws { throw unexpected() }
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
