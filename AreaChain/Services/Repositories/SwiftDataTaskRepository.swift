import Foundation
import SwiftData

enum TodoCalendarFieldUpdate {
    static func apply(_ todo: TodoItem, title: String, dayKey: String, remindMinutes: Int?, eventID: String) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, DayKey.date(from: dayKey) != nil else {
            throw RepositoryError.invalidArgument("日历回写缺少标题或日期")
        }
        todo.title = trimmed
        todo.dayKey = dayKey
        if let remindMinutes {
            ClassifiedFieldsUpdate.setRemind(todo, minutes: remindMinutes)
        } else {
            todo.remindMinutes = nil
        }
        todo.calendarEventID = eventID
    }
}

/// 待办数据访问与变更 SwiftData 具体仓储实现
@MainActor
final class SwiftDataTaskRepository: TaskRepositoryProtocol {
    var taskMutationContext: ModelContext? { context }
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
        try fetchTodos(matching: #Predicate { $0.dayKey == dayKey && $0.deletedAt == nil })
    }

    func fetchTodo(id: UUID) throws -> TodoItem? {
        // 含已软删除行：restore / purge / 按 id 变更都依赖这条路径找到回收站里的待办。
        // fetchLimit 1 是身份读取；附件存活仍走 AttachmentAccess，不设 limit，以便 isSingleLive 看到重复 UUID。
        var descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func fetchAllTodos(includeDeleted: Bool) throws -> [TodoItem] {
        if includeDeleted {
            return try fetchTodos(matching: nil)
        }
        return try fetchTodos(matching: #Predicate { $0.deletedAt == nil })
    }

    func fetchTodos(withID id: UUID) throws -> [TodoItem] {
        try context.fetch(FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == id }))
    }

    func fetchTodos(forTag tagID: UUID) throws -> [TodoItem] {
        let needle = tagID.uuidString
        // 库侧按编码子串缩小集合；是否命中仍以 TagIDList 解析为准，避免编码差异误匹配。
        return try fetchTodos(
            matching: #Predicate { $0.deletedAt == nil && $0.tagIDs.contains(needle) }
        ).filter { TagIDList.contains($0.tagIDs, tagID) }
    }

    func fetchTodos(isDone: Bool) throws -> [TodoItem] {
        let wantedDone = isDone
        return try fetchTodos(matching: #Predicate { $0.deletedAt == nil && $0.isDone == wantedDone })
    }

    // MARK: - 创建 (Create)

    @discardableResult
    func addTodo(_ params: CreateTodoParams) throws -> TodoItem {
        if let id = params.creationID, try !fetchTodos(withID: id).isEmpty {
            throw RepositoryError.invalidArgument("创建身份已存在")
        }
        let trimmed = params.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasMetadata = !params.tagIDs.isEmpty
            || params.remindMinutes != nil
            || params.isImportant
            || params.isUrgent
            || !params.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard !trimmed.isEmpty || hasMetadata else {
            throw RepositoryError.invalidArgument("待办标题不能为空")
        }
        let todo = TodoItem(
            id: params.creationID ?? UUID(),
            title: trimmed,
            dayKey: params.dayKey,
            remindMinutes: params.remindMinutes,
            tagIDs: TagIDList.encode(TagIDList.normalized(params.tagIDs)),
            isImportant: params.isImportant,
            isUrgent: params.isUrgent,
            sourceBundleID: params.sourceBundleID,
            calendarEventID: params.calendarEventID,
            notes: params.notes,
            sortOrder: try nextBoardOrder(on: params.dayKey)
        )
        context.insert(todo)
        try saveAndNotify()
        return todo
    }

    private func nextBoardOrder(on dayKey: String) throws -> Int {
        let todos = try fetchTodos(for: dayKey).map(\.sortOrder)
        let routines = try context.fetch(
            FetchDescriptor<DailyRoutine>(predicate: #Predicate { $0.deletedAt == nil })
        ).map(\.sortOrder)
        return (todos + routines).max().map { $0 + 1 } ?? 0
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
        ClassifiedFieldsUpdate.setRemind(todo, minutes: minutes)
        try saveAndNotify()
    }

    func setPriority(id: UUID, isImportant: Bool, isUrgent: Bool) throws {
        guard let todo = try fetchTodo(id: id) else {
            throw RepositoryError.notFound("TodoItem(id: \(id))")
        }
        ClassifiedFieldsUpdate.setPriority(todo, isImportant: isImportant, isUrgent: isUrgent)
        try saveAndNotify()
    }

    func toggleTag(id: UUID, tagID: UUID) throws {
        guard let todo = try fetchTodo(id: id) else {
            throw RepositoryError.notFound("TodoItem(id: \(id))")
        }
        ClassifiedFieldsUpdate.toggleTag(todo, tagID: tagID)
        try saveAndNotify()
    }

    func replaceTagIDs(id: UUID, tagIDs: String) throws {
        guard let todo = try fetchTodo(id: id) else {
            throw RepositoryError.notFound("TodoItem(id: \(id))")
        }
        todo.tagIDs = tagIDs
        try saveAndNotify()
    }

    func applyParsedNotes(id: UUID, update: ParsedNoteUpdate) throws {
        guard let todo = try fetchTodo(id: id) else {
            throw RepositoryError.notFound("TodoItem(id: \(id))")
        }
        todo.notes = update.notes
        todo.tagIDs = update.tagIDs
        if let minutes = update.remindMinutes {
            ClassifiedFieldsUpdate.setRemind(todo, minutes: minutes)
        }
        if let isImportant = update.isImportant, let isUrgent = update.isUrgent {
            ClassifiedFieldsUpdate.setPriority(todo, isImportant: isImportant, isUrgent: isUrgent)
        }
        try saveAndNotify()
    }

    func applyCalendarFields(id: UUID, title: String, dayKey: String, remindMinutes: Int?, eventID: String) throws {
        guard let todo = try fetchTodo(id: id) else {
            throw RepositoryError.notFound("TodoItem(id: \(id))")
        }
        try TodoCalendarFieldUpdate.apply(todo, title: title, dayKey: dayKey, remindMinutes: remindMinutes, eventID: eventID)
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
            SoftDelete.stampAttachments(
                ownerID: todo.id, at: now, attachments: try ownedAttachments(todo.id), ownerKind: .todo
            )
        } else {
            let stamp = todo.deletedAt ?? SoftDelete.stamp()
            SoftDelete.stampAttachments(
                ownerID: todo.id, at: stamp, attachments: try ownedAttachments(todo.id), ownerKind: .todo
            )
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
            attachments: try ownedAttachments(todo.id),
            ownerKind: .todo
        )
        try saveAndNotify()
    }

    func purgeTodo(id: UUID) throws {
        guard let todo = try fetchTodo(id: id) else {
            throw RepositoryError.notFound("TodoItem(id: \(id))")
        }
        let ids = Set(try ownedAttachments(todo.id).map(\.id))
        try deleteTodo(id: id, soft: false)
        if !ids.isEmpty { try AttachmentCleanup.purge(ids: ids, context: context) }
    }

    // MARK: - 子任务级联操作 (Subtask Operations)

    @discardableResult
    func addSubtask(to todoID: UUID, title: String) throws -> SubtaskItem {
        guard try fetchTodo(id: todoID) != nil else {
            throw RepositoryError.notFound("TodoItem(id: \(todoID))")
        }
        guard let edit = SubtaskTitleEdit(title) else {
            throw RepositoryError.invalidArgument("子任务标题不能为空")
        }
        return try ModelChanges.transaction(in: context) {
            let tagIDs = try InputTagResolver.merging(edit.tagNames, into: "", in: context)
            return try addSubtask(.init(parentID: todoID, title: edit.title, tagIDs: tagIDs))
        }
    }

    func addSubtask(_ params: CreateSubtaskParams) throws -> SubtaskItem {
        guard let todo = try fetchTodo(id: params.parentID) else {
            throw RepositoryError.notFound("TodoItem(id: \(params.parentID))")
        }
        guard !params.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RepositoryError.invalidArgument("子任务标题不能为空")
        }
        if let id = params.creationID,
           try !context.fetch(FetchDescriptor<SubtaskItem>(predicate: #Predicate { $0.id == id })).isEmpty {
            throw RepositoryError.invalidArgument("创建身份已存在")
        }
        return try ModelChanges.transaction(in: context) {
            let nextOrder = Catalog.nextSortOrder(todo.subtasks.filter { $0.deletedAt == nil }.map(\.sortOrder))
            let subtask = SubtaskItem(
                id: params.creationID ?? UUID(), title: params.title,
                sortOrder: nextOrder, tagIDs: params.tagIDs, todo: todo
            )
            context.insert(subtask)
            return subtask
        }
    }

    func toggleSubtask(id: UUID) throws {
        guard let subtask = try fetchSubtask(id: id) else {
            throw RepositoryError.notFound("SubtaskItem(id: \(id))")
        }
        SubtaskFields.completion(subtask, enabled: !subtask.isDone)
        try saveAndNotify()
    }

    var subtaskMutationContext: ModelContext? { context }

    func updateSubtask(id: UUID, update: SubtaskFieldUpdate) throws {
        guard let subtask = try fetchSubtask(id: id) else {
            throw RepositoryError.notFound("SubtaskItem(id: \(id))")
        }
        switch update {
        case .title(let title, let tags):
            guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw RepositoryError.invalidArgument("子任务标题不能为空")
            }
            SubtaskFields.title(subtask, title: title, tagIDs: tags)
        case .completion(let enabled): SubtaskFields.completion(subtask, enabled: enabled)
        case .tags(let tags): SubtaskFields.tags(subtask, tagIDs: tags)
        }
        try saveAndNotify()
    }

    func editSubtask(id: UUID, title: String) throws {
        guard let subtask = try fetchSubtask(id: id) else {
            throw RepositoryError.notFound("SubtaskItem(id: \(id))")
        }
        guard let edit = SubtaskTitleEdit(title) else {
            throw RepositoryError.invalidArgument("子任务标题不能为空")
        }
        try ModelChanges.transaction(in: context) {
            let tags = try InputTagResolver.merging(edit.tagNames, into: subtask.tagIDs, in: context)
            SubtaskFields.title(subtask, title: edit.title, tagIDs: tags)
        }
    }

    func toggleSubtaskTag(id: UUID, tagID: UUID) throws {
        guard let subtask = try fetchSubtask(id: id) else {
            throw RepositoryError.notFound("SubtaskItem(id: \(id))")
        }
        SubtaskFields.tags(subtask, tagIDs: TagIDList.toggling(subtask.tagIDs, tagID))
        try saveAndNotify()
    }

    func deleteSubtask(id: UUID, soft: Bool) throws {
        guard let subtask = try fetchSubtask(id: id) else {
            throw RepositoryError.notFound("SubtaskItem(id: \(id))")
        }
        if soft {
            subtask.deletedAt = SoftDelete.stamp()
        } else {
            context.delete(subtask)
        }
        try saveAndNotify()
    }

    func reorderSubtasks(for todoID: UUID, orderedIDs: [UUID]) throws {
        guard let todo = try fetchTodo(id: todoID) else {
            throw RepositoryError.notFound("TodoItem(id: \(todoID))")
        }
        Catalog.writeSortOrder(Array(todo.subtasks), orderedIDs: orderedIDs, id: \.id) { item, index in
            item.sortOrder = index
        }
        try saveAndNotify()
    }

    // MARK: - 批量操作 (Batch Operations)

    func batchMoveTodos(ids: Set<UUID>, to dayKey: String) throws {
        guard !ids.isEmpty else { return }
        for todo in try fetchLiveTodos(ids: ids) {
            todo.dayKey = dayKey
        }
        try saveAndNotify()
    }

    func batchToggleDone(ids: Set<UUID>, markDone: Bool) throws {
        guard !ids.isEmpty else { return }
        for todo in try fetchLiveTodos(ids: ids) {
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
        let todos = try fetchLiveTodos(ids: ids)
        let attachments = try OwnedAttachments.matching(
            ownerIDs: Set(todos.map(\.id)), kind: .todo, in: context
        )
        for todo in todos {
            todo.deletedAt = now
            SoftDelete.stampLiveSubtasks(todo.subtasks, at: now)
            SoftDelete.stampAttachments(ownerID: todo.id, at: now, attachments: attachments, ownerKind: .todo)
        }
        try saveAndNotify()
    }

    func batchApplyTag(ids: Set<UUID>, tagID: UUID, present: Bool) throws {
        guard !ids.isEmpty else { return }
        for todo in try fetchLiveTodos(ids: ids) {
            ClassifiedFieldsUpdate.setTag(todo, tagID: tagID, present: present)
        }
        try saveAndNotify()
    }

    func batchToggleTag(ids: Set<UUID>, tagID: UUID) throws {
        guard !ids.isEmpty else { return }
        for todo in try fetchLiveTodos(ids: ids) {
            ClassifiedFieldsUpdate.toggleTag(todo, tagID: tagID)
        }
        try saveAndNotify()
    }

    // MARK: - 内部辅助 (Internal Helpers)

    private func fetchTodos(
        matching predicate: Predicate<TodoItem>?,
        sortBy: [SortDescriptor<TodoItem>] = [SortDescriptor(\.createdAt)]
    ) throws -> [TodoItem] {
        try context.fetch(FetchDescriptor(predicate: predicate, sortBy: sortBy))
    }

    private func fetchLiveTodos(ids: Set<UUID>) throws -> [TodoItem] {
        guard !ids.isEmpty else { return [] }
        let wanted = Array(ids)
        return try fetchTodos(
            matching: #Predicate { wanted.contains($0.id) && $0.deletedAt == nil },
            sortBy: []
        )
    }

    private func fetchSubtask(id: UUID) throws -> SubtaskItem? {
        var descriptor = FetchDescriptor<SubtaskItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func ownedAttachments(_ ownerID: UUID) throws -> [AttachmentItem] {
        try OwnedAttachments.matching(ownerID: ownerID, kind: .todo, in: context)
    }
}
