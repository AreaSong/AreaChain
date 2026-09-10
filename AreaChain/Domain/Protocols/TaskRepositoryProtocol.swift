import Foundation
import SwiftData

/// 待办创建参数 DTO（参数归一化，避免方法签名超过 5 个参数）
struct CreateTodoParams: Sendable {
    var title: String
    var dayKey: String
    var notes: String
    var remindMinutes: Int?
    var isImportant: Bool
    var isUrgent: Bool
    var projectID: UUID?
    var tagIDs: [UUID]
    var sourceBundleID: String
    var calendarEventID: String

    init(
        title: String,
        dayKey: String,
        notes: String = "",
        remindMinutes: Int? = nil,
        isImportant: Bool = false,
        isUrgent: Bool = false,
        projectID: UUID? = nil,
        tagIDs: [UUID] = [],
        sourceBundleID: String = "",
        calendarEventID: String = ""
    ) {
        self.title = title
        self.dayKey = dayKey
        self.notes = notes
        self.remindMinutes = remindMinutes
        self.isImportant = isImportant
        self.isUrgent = isUrgent
        self.projectID = projectID
        self.tagIDs = tagIDs
        self.sourceBundleID = sourceBundleID
        self.calendarEventID = calendarEventID
    }
}

/// 待办数据访问与变更核心协议（纯 Swift / SwiftData，无 UI 依赖）
@MainActor
protocol TaskRepositoryProtocol: AnyObject {
    // MARK: - 查询 (Query)
    /// 获取指定日期的活跃待办（按创建时间升序排列）
    func fetchTodos(for dayKey: String) throws -> [TodoItem]

    /// 按唯一标识查询待办
    func fetchTodo(id: UUID) throws -> TodoItem?

    /// 全量待办查询（支持是否包含软删除）
    func fetchAllTodos(includeDeleted: Bool) throws -> [TodoItem]

    /// 按所属项目筛选活跃待办
    func fetchTodos(forProject projectID: UUID) throws -> [TodoItem]

    /// 按标签筛选活跃待办
    func fetchTodos(forTag tagID: UUID) throws -> [TodoItem]

    // MARK: - 创建 (Create)
    /// 基于结构化参数创建待办
    @discardableResult
    func addTodo(_ params: CreateTodoParams) throws -> TodoItem

    /// 便捷多参数重载（满足 PROJECT.md 契约规范）
    @discardableResult
    func addTodo(
        title: String,
        dayKey: String,
        notes: String?,
        remindMinutes: Int?,
        priority: (isImportant: Bool, isUrgent: Bool)?,
        projectID: UUID?,
        tagIDs: [UUID]?
    ) throws -> TodoItem

    // MARK: - 状态与属性变更 (Update & Toggle)
    /// 切换待办完成状态；若标记为完成，则级联将所有未删除子任务标记为完成
    func toggleTodo(id: UUID) throws

    /// 显式标记完成待办（幂等），并级联完成所有活跃子任务
    func completeTodo(id: UUID) throws

    /// 更新待办基础信息（标题、备注等）
    func updateTodo(id: UUID, title: String?, notes: String?) throws

    /// 调整待办计划日期
    func moveTodo(id: UUID, to dayKey: String) throws

    /// 设置待办提醒分钟偏移（nil 表示取消提醒）
    func setRemind(id: UUID, minutes: Int?) throws

    /// 设置四象限优先级
    func setPriority(id: UUID, isImportant: Bool, isUrgent: Bool) throws

    /// 归属项目变更
    func setProject(id: UUID, projectID: UUID?) throws

    /// 切换标签关联状态
    func toggleTag(id: UUID, tagID: UUID) throws

    // MARK: - 删除与恢复 (Delete & Restore)
    /// 删除待办：soft=true 时执行软删除并级联标记子任务/附件；soft=false 时彻底物理删除
    func deleteTodo(id: UUID, soft: Bool) throws

    /// 恢复已软删除待办及其级联子任务与附件
    func restoreTodo(id: UUID) throws

    /// 从持久化库中物理移除已软删除的待办
    func purgeTodo(id: UUID) throws

    // MARK: - 子任务级联操作 (Subtask Operations)
    /// 添加子任务并维护正确的排序号
    @discardableResult
    func addSubtask(to todoID: UUID, title: String) throws -> SubtaskItem

    /// 切换子任务完成状态
    func toggleSubtask(id: UUID) throws

    /// 修改子任务标题
    func editSubtask(id: UUID, title: String) throws

    /// 软删除或物理删除子任务
    func deleteSubtask(id: UUID, soft: Bool) throws

    /// 重排子任务序号
    func reorderSubtasks(for todoID: UUID, orderedIDs: [UUID]) throws

    // MARK: - 批量操作 (Batch Operations)
    /// 批量移动待办日期
    func batchMoveTodos(ids: Set<UUID>, to dayKey: String) throws

    /// 批量修改待办完成状态（若为完成则级联完成其子任务）
    func batchToggleDone(ids: Set<UUID>, markDone: Bool) throws

    /// 批量软删除待办
    func batchTrashTodos(ids: Set<UUID>) throws

    /// 批量设置所属项目
    func batchSetProject(ids: Set<UUID>, projectID: UUID?) throws

    /// 批量切换标签关联
    func batchToggleTag(ids: Set<UUID>, tagID: UUID) throws
}

extension TaskRepositoryProtocol {
    func addTodo(
        title: String,
        dayKey: String,
        notes: String? = nil,
        remindMinutes: Int? = nil,
        priority: (isImportant: Bool, isUrgent: Bool)? = nil,
        projectID: UUID? = nil,
        tagIDs: [UUID]? = nil
    ) throws -> TodoItem {
        let params = CreateTodoParams(
            title: title,
            dayKey: dayKey,
            notes: notes ?? "",
            remindMinutes: remindMinutes,
            isImportant: priority?.isImportant ?? false,
            isUrgent: priority?.isUrgent ?? false,
            projectID: projectID,
            tagIDs: tagIDs ?? []
        )
        return try addTodo(params)
    }
}
