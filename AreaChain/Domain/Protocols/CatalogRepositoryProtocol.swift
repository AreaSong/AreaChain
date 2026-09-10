import Foundation
import SwiftData

/// 分类目录（项目树与标签体系）数据访问与拓扑计算契约
@MainActor
protocol CatalogRepositoryProtocol: AnyObject {
    // MARK: - 项目操作 (Projects)
    /// 获取项目列表（可筛选软删除）
    func fetchProjects(includeDeleted: Bool) throws -> [ProjectItem]

    /// 获取活跃项目列表
    func fetchProjects() throws -> [ProjectItem]

    /// 按唯一标识查询项目
    func fetchProject(id: UUID) throws -> ProjectItem?

    /// 创建新项目
    @discardableResult
    func createProject(name: String, parentID: UUID?, sortOrder: Int?) throws -> ProjectItem

    /// 更新项目名称、父级归属或排序
    func updateProject(id: UUID, name: String?, parentID: UUID??, sortOrder: Int?) throws

    /// 删除项目（软删除或物理删除）
    func deleteProject(id: UUID, soft: Bool) throws

    /// 恢复已软删除的项目
    func restoreProject(id: UUID) throws

    /// 物理删除项目并解除待办/习惯的关联
    func purgeProject(id: UUID) throws

    /// 生成扁平化的层级树大纲（含缩进深度）
    func projectOutline() throws -> [ProjectOutlineRow]

    /// 获取当前项目允许移动到的父级列表（规避环路引用）
    func allowedParents(for projectID: UUID) throws -> [ProjectOutlineRow]

    /// 获取项目完整路径层级文本（例如 "主分类 / 子项目"）
    func pathLabel(for projectID: UUID) throws -> String

    /// 解除指定项目与其所有关联项的归属关系
    func unlinkProject(id: UUID) throws

    // MARK: - 标签操作 (Tags)
    /// 获取标签列表
    func fetchTags(includeDeleted: Bool) throws -> [TagItem]

    /// 获取活跃标签列表
    func fetchTags() throws -> [TagItem]

    /// 按唯一标识查询标签
    func fetchTag(id: UUID) throws -> TagItem?

    /// 获取待办侧可用的活跃标签（过滤手记预设分类）
    func fetchLiveTaskTags() throws -> [TagItem]

    /// 创建新标签
    @discardableResult
    func createTag(name: String, sortOrder: Int?) throws -> TagItem

    /// 获取已有同名标签或新建标签（复用被软删除的标签）
    @discardableResult
    func resolveOrCreateTag(name: String) throws -> TagItem

    /// 寻找任务标签（非手记预设标签）
    func resolveTaskTag(name: String) throws -> TagItem?

    /// 确保手记预设标签（密码 / 小巧思 / 日记）存在且可用
    func ensurePresetTags() throws

    /// 更新标签基本信息
    func updateTag(id: UUID, name: String?, sortOrder: Int?) throws

    /// 删除标签
    func deleteTag(id: UUID, soft: Bool) throws

    /// 恢复软删除标签
    func restoreTag(id: UUID) throws

    /// 物理清除标签并从所有任务/手记的 tagIDs 中移除
    func purgeTag(id: UUID) throws

    /// 从所有任务、习惯、手记中解绑指定标签
    func unlinkTag(id: UUID) throws

    // MARK: - 聚合指标 (Metrics)
    /// 统计指定项目或标签下的未完成任务总数（待办 + 今日应打卡习惯）
    func openCount(projectID: UUID?, tagID: UUID?, dayKey: String) throws -> Int
}

extension CatalogRepositoryProtocol {
    func fetchProjects() throws -> [ProjectItem] {
        try fetchProjects(includeDeleted: false)
    }

    func fetchTags() throws -> [TagItem] {
        try fetchTags(includeDeleted: false)
    }

    func projectOutline() throws -> [ProjectOutlineRow] {
        let projects = try fetchProjects(includeDeleted: false)
        return ProjectTree.outline(projects)
    }

    func allowedParents(for projectID: UUID) throws -> [ProjectOutlineRow] {
        let projects = try fetchProjects(includeDeleted: false)
        return ProjectTree.allowedParents(for: projectID, in: projects)
    }

    func pathLabel(for projectID: UUID) throws -> String {
        let projects = try fetchProjects(includeDeleted: false)
        return ProjectTree.pathLabel(projectID, in: projects)
    }
}
