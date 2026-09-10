import Foundation
import SwiftData

/// 灵感手记数据访问与搜索契约
@MainActor
protocol DiaryRepositoryProtocol: AnyObject {
    // MARK: - 查询与搜索 (Query & Search)
    /// 按日期获取手记列表（支持全量获取）
    func fetchDiaries(for dayKey: String?, includeDeleted: Bool) throws -> [DiaryEntry]

    /// 获取活跃手记列表（便捷方法）
    func fetchDiaries(for dayKey: String?) throws -> [DiaryEntry]

    /// 按唯一标识查询单篇手记
    func fetchDiary(id: UUID) throws -> DiaryEntry?

    /// 搜索手记正文及标签名称（置顶项在前，按创建时间降序）
    func searchDiaries(query: String, tagID: UUID?, includeDeleted: Bool) throws -> [DiaryEntry]

    /// 纯文本快捷搜索手记
    func searchDiaries(query: String) throws -> [DiaryEntry]

    // MARK: - 创建与编辑 (Create & Edit)
    /// 新建手记
    @discardableResult
    func addDiary(text: String, dayKey: String, tagIDs: Set<UUID>) throws -> DiaryEntry

    /// 修改手记文本内容
    func editDiary(id: UUID, text: String) throws

    // MARK: - 置顶与标签操作 (Pin & Tags)
    /// 切换置顶状态
    func togglePin(id: UUID) throws

    /// 显式设置置顶状态
    func setPinned(id: UUID, isPinned: Bool) throws

    /// 切换手记关联标签
    func toggleTag(id: UUID, tagID: UUID) throws

    /// 全量重设手记关联标签
    func setTags(id: UUID, tagIDs: Set<UUID>) throws

    // MARK: - 删除与恢复 (Delete & Restore)
    /// 删除手记：soft=true 软删除并级联附件；soft=false 物理删除
    func deleteDiary(id: UUID, soft: Bool) throws

    /// 恢复已软删除的手记及级联附件
    func restoreDiary(id: UUID) throws

    /// 彻底物理清除手记及附件文件
    func purgeDiary(id: UUID) throws
}

extension DiaryRepositoryProtocol {
    func fetchDiaries(for dayKey: String? = nil) throws -> [DiaryEntry] {
        try fetchDiaries(for: dayKey, includeDeleted: false)
    }

    func searchDiaries(query: String) throws -> [DiaryEntry] {
        try searchDiaries(query: query, tagID: nil, includeDeleted: false)
    }
}
