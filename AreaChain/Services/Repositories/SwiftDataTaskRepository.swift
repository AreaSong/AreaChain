import Foundation
import SwiftData

/// 待办数据访问与变更 SwiftData 具体仓储实现
@MainActor
final class SwiftDataTaskRepository: TaskRepositoryProtocol {
    private let context: ModelContext
    private let retainedContainer: ModelContainer?

    init(context: ModelContext, container: ModelContainer? = nil) {
        self.context = context
        self.retainedContainer = container
    }

    convenience init(container: ModelContainer) {
        self.init(context: container.mainContext, container: container)
    }

    private func saveAndNotify() throws {
        try ModelChanges.commit(context)
    }

    // MARK: - 查询 (Query)

    func fetchTodos(for dayKey: String) throws -> [TodoItem] {
        let all = try fetchAllTodos(includeDeleted: false)
        return all
            .filter { $0.dayKey == dayKey }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func fetchTodo(id: UUID) throws -> TodoItem? {
        let items = try context.fetch(FetchDescriptor<TodoItem>())
        return items.first { $0.id == id }
    }

    func fetchAllTodos(includeDeleted: Bool) throws -> [TodoItem] {
        let items = try context.fetch(FetchDescriptor<TodoItem>())
        let sorted = items.sorted { $0.createdAt < $1.createdAt }
        if includeDeleted {
            return sorted
        }
        return sorted.filter { $0.deletedAt == nil }
    }

    func fetchTodos(forProject projectID: UUID) throws -> [TodoItem] {
        let all = try fetchAllTodos(includeDeleted: false)
        return all.filter { $0.projectID == projectID }
    }

    func fetchTodos(forTag tagID: UUID) throws -> [TodoItem] {
        let all = try fetchAllTodos(includeDeleted: false)
        return all.filter { TagIDList.contains($0.tagIDs, tagID) }
    }

    // MARK: - 创建 (Create)

    @discardableResult
    func addTodo(_ params: CreateTodoParams) throws -> TodoItem {
        let trimmed = params.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RepositoryError.invalidArgument("待办标题不能为空")
        }
        let todo = TodoItem(
            title: trimmed,
            dayKey: params.dayKey,
            remindMinutes: params.remindMinutes,
            projectID: params.projectID,
            tagIDs: TagIDList.encode(params.tagIDs),
            isImportant: params.isImportant,
            isUrgent: params.isUrgent,
            sourceBundleID: params.sourceBundleID,
            calendarEventID: params.calendarEventID,
            notes: params.notes
        )
        context.insert(todo)
        try saveAndNotify()
        return todo
    }

    // MARK: - 状态与属性变更 (Update & Toggle)

    func toggleTodo(id: UUID) throws {
        guard let todo = try fetchTodo(id: id) else {
            throw RepositoryError.notFound("TodoItem(id: \(id))")
        }
        todo.isDone.toggle()
        if todo.isDone {
            cascadeCompleteSubtasks(todo)
        }
        try saveAndNotify()
    }

    func completeTodo(id: UUID) throws {
        guard let todo = try fetchTodo(id: id) else {
            throw RepositoryError.notFound("TodoItem(id: \(id))")
        }
        todo.isDone = true
        cascadeCompleteSubtasks(todo)
        try saveAndNotify()
    }

    private func cascadeCompleteSubtasks(_ todo: TodoItem) {
        for sub in todo.subtasks where sub.deletedAt == nil && !sub.isDone {
            sub.isDone = true
        }
    }

    func updateTodo(id: UUID, title: String?, notes: String?) throws {
        guard let todo = try fetchTodo(id: id) else {
            throw RepositoryError.notFound("TodoItem(id: \(id))")
        }
        if let title {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw RepositoryError.invalidArgument("待办标题不能为空")
            }
            todo.title = trimmed
        }
        if let notes {
            todo.notes = notes
        }
        try saveAndNotify()
    }

    func moveTodo(id: UUID, to dayKey: String) throws {
        guard let todo = try fetchTodo(id: id) else {
            throw RepositoryError.notFound("TodoItem(id: \(id))")
        }
        guard todo.dayKey != dayKey else { return }
        todo.dayKey = dayKey
        try saveAndNotify()
    }

    func setRemind(id: UUID, minutes: Int?) throws {
        guard let todo = try fetchTodo(id: id) else {
            throw RepositoryError.notFound("TodoItem(id: \(id))")
        }
        todo.remindMinutes = RemindMinutes.clamped(minutes)
        try saveAndNotify()
    }

    func setPriority(id: UUID, isImportant: Bool, isUrgent: Bool) throws {
        guard let todo = try fetchTodo(id: id) else {
            throw RepositoryError.notFound("TodoItem(id: \(id))")
        }
        todo.isImportant = isImportant
        todo.isUrgent = isUrgent
        try saveAndNotify()
    }

    func setProject(id: UUID, projectID: UUID?) throws {
        guard let todo = try fetchTodo(id: id) else {
            throw RepositoryError.notFound("TodoItem(id: \(id))")
        }
        todo.projectID = projectID
        try saveAndNotify()
    }

    func toggleTag(id: UUID, tagID: UUID) throws {
        guard let todo = try fetchTodo(id: id) else {
            throw RepositoryError.notFound("TodoItem(id: \(id))")
        }
        todo.tagIDs = TagIDList.toggling(todo.tagIDs, tagID)
        try saveAndNotify()
    }

    // MARK: - 删除与恢复 (Delete & Restore)

    func deleteTodo(id: UUID, soft: Bool) throws {
        guard let todo = try fetchTodo(id: id) else {
            throw RepositoryError.notFound("TodoItem(id: \(id))")
        }
        if soft {
            let now = SoftDelete.stamp()
            todo.deletedAt = now
            SoftDelete.stampLiveSubtasks(todo.subtasks, at: now)
            SoftDelete.stampAttachments(ownerID: todo.id, at: now, attachments: fetchOwnedAttachments())
        } else {
            purgeAttachments(ownerID: todo.id)
            context.delete(todo)
        }
        try saveAndNotify()
    }

    func restoreTodo(id: UUID) throws {
        guard let todo = try fetchTodo(id: id) else {
            throw RepositoryError.notFound("TodoItem(id: \(id))")
        }
        let stamp = todo.deletedAt
        todo.deletedAt = nil
        SoftDelete.restoreCascadedSubtasks(parentDeletedAt: stamp, subtasks: todo.subtasks)
        SoftDelete.restoreCascadedAttachments(
            ownerID: todo.id,
            parentDeletedAt: stamp,
            attachments: fetchOwnedAttachments()
        )
        try saveAndNotify()
    }

    func purgeTodo(id: UUID) throws {
        try deleteTodo(id: id, soft: false)
    }

    // MARK: - 子任务级联操作 (Subtask Operations)

    @discardableResult
    func addSubtask(to todoID: UUID, title: String) throws -> SubtaskItem {
        guard let todo = try fetchTodo(id: todoID) else {
            throw RepositoryError.notFound("TodoItem(id: \(todoID))")
        }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RepositoryError.invalidArgument("子任务标题不能为空")
        }
        let active = todo.subtasks.filter { $0.deletedAt == nil }
        let nextOrder = (active.map(\.sortOrder).max() ?? -1) + 1
        let subtask = SubtaskItem(title: trimmed, sortOrder: nextOrder, todo: todo)
        context.insert(subtask)
        try saveAndNotify()
        return subtask
    }

    func toggleSubtask(id: UUID) throws {
        guard let subtask = try fetchSubtask(id: id) else {
            throw RepositoryError.notFound("SubtaskItem(id: \(id))")
        }
        subtask.isDone.toggle()
        try saveAndNotify()
    }

    func editSubtask(id: UUID, title: String) throws {
        guard let subtask = try fetchSubtask(id: id) else {
            throw RepositoryError.notFound("SubtaskItem(id: \(id))")
        }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RepositoryError.invalidArgument("子任务标题不能为空")
        }
        subtask.title = trimmed
        try saveAndNotify()
    }

    func deleteSubtask(id: UUID, soft: Bool) throws {
        guard let subtask = try fetchSubtask(id: id) else {
            throw RepositoryError.notFound("SubtaskItem(id: \(id))")
        }
        if soft {
            subtask.deletedAt = .now
        } else {
            context.delete(subtask)
        }
        try saveAndNotify()
    }

    func reorderSubtasks(for todoID: UUID, orderedIDs: [UUID]) throws {
        guard let todo = try fetchTodo(id: todoID) else {
            throw RepositoryError.notFound("TodoItem(id: \(todoID))")
        }
        for (idx, id) in orderedIDs.enumerated() {
            if let item = todo.subtasks.first(where: { $0.id == id }) {
                item.sortOrder = idx
            }
        }
        try saveAndNotify()
    }

    // MARK: - 批量操作 (Batch Operations)

    func batchMoveTodos(ids: Set<UUID>, to dayKey: String) throws {
        guard !ids.isEmpty else { return }
        let todos = try fetchAllTodos(includeDeleted: false)
        for todo in todos where ids.contains(todo.id) {
            todo.dayKey = dayKey
        }
        try saveAndNotify()
    }

    func batchToggleDone(ids: Set<UUID>, markDone: Bool) throws {
        guard !ids.isEmpty else { return }
        let todos = try fetchAllTodos(includeDeleted: false)
        for todo in todos where ids.contains(todo.id) {
            todo.isDone = markDone
            if markDone {
                cascadeCompleteSubtasks(todo)
            }
        }
        try saveAndNotify()
    }

    func batchTrashTodos(ids: Set<UUID>) throws {
        guard !ids.isEmpty else { return }
        let now = SoftDelete.stamp()
        let attachments = fetchOwnedAttachments()
        let todos = try fetchAllTodos(includeDeleted: false)
        for todo in todos where ids.contains(todo.id) {
            todo.deletedAt = now
            SoftDelete.stampLiveSubtasks(todo.subtasks, at: now)
            SoftDelete.stampAttachments(ownerID: todo.id, at: now, attachments: attachments)
        }
        try saveAndNotify()
    }

    func batchSetProject(ids: Set<UUID>, projectID: UUID?) throws {
        guard !ids.isEmpty else { return }
        let todos = try fetchAllTodos(includeDeleted: false)
        for todo in todos where ids.contains(todo.id) {
            todo.projectID = projectID
        }
        try saveAndNotify()
    }

    func batchToggleTag(ids: Set<UUID>, tagID: UUID) throws {
        guard !ids.isEmpty else { return }
        let todos = try fetchAllTodos(includeDeleted: false)
        for todo in todos where ids.contains(todo.id) {
            todo.tagIDs = TagIDList.toggling(todo.tagIDs, tagID)
        }
        try saveAndNotify()
    }

    // MARK: - 内部辅助 (Internal Helpers)

    private func fetchSubtask(id: UUID) throws -> SubtaskItem? {
        let items = try context.fetch(FetchDescriptor<SubtaskItem>())
        return items.first { $0.id == id }
    }

    private func fetchOwnedAttachments() -> [AttachmentItem] {
        (try? context.fetch(FetchDescriptor<AttachmentItem>())) ?? []
    }

    private func purgeAttachments(ownerID: UUID) {
        let attachments = fetchOwnedAttachments()
        for item in attachments where item.ownerID == ownerID {
            context.delete(item)
        }
    }
}
