import Foundation
import SwiftData

/// 平面标签目录的数据访问契约
@MainActor
protocol CatalogRepositoryProtocol: AnyObject {
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

    /// 更新标签名称、排序或颜色。手记预置标签拒绝改名和改色。
    func updateTag(id: UUID, name: String?, sortOrder: Int?, colorToken: String?) throws

    /// 删除标签
    func deleteTag(id: UUID, soft: Bool) throws

    /// 恢复软删除标签
    func restoreTag(id: UUID) throws

    /// 物理清除标签并从所有任务/手记的 tagIDs 中移除
    func purgeTag(id: UUID) throws

    /// 从所有任务、习惯、手记中解绑指定标签
    func unlinkTag(id: UUID) throws

    /// 按当前顺序写回 sortOrder。
    func reorderTags(orderedIDs: [UUID]) throws

    /// 把来源标签的关联并入目标标签，并软删除来源。一次事务。
    func mergeTags(sourceIDs: [UUID], into targetID: UUID) throws

    /// 批量改色。手记预置标签会被跳过并在全部是预置时失败。
    func batchSetColor(ids: Set<UUID>, colorToken: String) throws

    // MARK: - 聚合指标 (Metrics)
    /// 统计指定标签下的未完成事项（待办 + 今日应打卡习惯 + 未完成子任务）
    func openCount(tagID: UUID?, dayKey: String) throws -> Int
}

extension CatalogRepositoryProtocol {
    func fetchTags() throws -> [TagItem] {
        try fetchTags(includeDeleted: false)
    }

    func updateTag(id: UUID, name: String?, sortOrder: Int?) throws {
        try updateTag(id: id, name: name, sortOrder: sortOrder, colorToken: nil)
    }
}
