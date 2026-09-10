import Foundation

/// 快照导入应用统计结果 DTO
struct ImportSummary: Equatable, Sendable {
    var routinesApplied: Int
    var checksApplied: Int
    var todosApplied: Int
    var diariesApplied: Int
    var projectsApplied: Int
    var tagsApplied: Int
    var attachmentsApplied: Int

    init(
        routinesApplied: Int = 0,
        checksApplied: Int = 0,
        todosApplied: Int = 0,
        diariesApplied: Int = 0,
        projectsApplied: Int = 0,
        tagsApplied: Int = 0,
        attachmentsApplied: Int = 0
    ) {
        self.routinesApplied = routinesApplied
        self.checksApplied = checksApplied
        self.todosApplied = todosApplied
        self.diariesApplied = diariesApplied
        self.projectsApplied = projectsApplied
        self.tagsApplied = tagsApplied
        self.attachmentsApplied = attachmentsApplied
    }

    var totalApplied: Int {
        routinesApplied + checksApplied + todosApplied + diariesApplied
            + projectsApplied + tagsApplied + attachmentsApplied
    }
}

/// 数据快照导出、序列化、差异比对及导入服务契约
protocol SnapshotServiceProtocol: AnyObject, Sendable {
    // MARK: - 导出 (Export)
    /// 从持久层提取全量数据并构造结构化快照对象
    func exportSnapshot() throws -> ExportSnapshot

    /// 导出为已格式化的 JSON 二进制数据（供文件保存）
    func exportData() throws -> Data

    // MARK: - 预览 (Preview)
    /// 比对快照与当前库中已存实体 ID，生成新增与更新的统计预览
    func previewImport(from snapshot: ExportSnapshot) throws -> ImportPreview

    /// 从 JSON 二进制数据解析并生成导入预览
    func previewImport(from data: Data) throws -> ImportPreview

    // MARK: - 导入 (Import)
    /// 执行快照合并导入并返回应用项统计
    func importSnapshot(_ snapshot: ExportSnapshot) throws -> ImportSummary

    /// 直接从 JSON 数据反序列化并合并导入
    func importData(_ data: Data) throws -> ImportSummary

    // MARK: - 编解码协议契约 (Serialization)
    /// 将快照模型编码为符合 AreaChain 标准日期格式的 JSON 数据
    func encode(_ snapshot: ExportSnapshot) throws -> Data

    /// 将 JSON 数据解码为结构化快照模型
    func decode(_ data: Data) throws -> ExportSnapshot
}

extension SnapshotServiceProtocol {
    func exportData() throws -> Data {
        let snapshot = try exportSnapshot()
        return try encode(snapshot)
    }

    func previewImport(from data: Data) throws -> ImportPreview {
        let snapshot = try decode(data)
        return try previewImport(from: snapshot)
    }

    func importData(_ data: Data) throws -> ImportSummary {
        let snapshot = try decode(data)
        return try importSnapshot(snapshot)
    }
}
