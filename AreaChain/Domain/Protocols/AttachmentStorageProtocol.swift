import Foundation
import SwiftData

/// 附件文件物理存储与数据库元数据管理契约
protocol AttachmentStorageProtocol: Sendable {
    /// 获取附件存储主目录
    func directory(fileManager: FileManager) -> URL

    /// 获取单个附件的文件物理存储路径
    func fileURL(id: UUID, root: URL?) -> URL

    /// 将二进制文件保存到磁盘并在数据库插入元数据记录
    @discardableResult
    func save(
        data: Data,
        filename: String,
        ownerKind: AttachmentOwner,
        ownerID: UUID,
        context: ModelContext,
        root: URL?,
        id: UUID,
        createdAt: Date
    ) throws -> AttachmentItem

    /// 读取附件二进制数据
    func loadData(id: UUID, root: URL?) -> Data?

    /// 删除指定附件在磁盘上的文件
    func removeFile(id: UUID, root: URL?)

    /// 清除指定归属者名下的所有附件文件与数据库记录
    func purge(
        ownerID: UUID,
        attachments: [AttachmentItem],
        context: ModelContext,
        root: URL?
    )

    /// 重置清空附件目录
    func resetDirectory(fileManager: FileManager) throws
}

extension AttachmentStorageProtocol {
    func directory() -> URL {
        directory(fileManager: .default)
    }

    func fileURL(id: UUID) -> URL {
        fileURL(id: id, root: nil)
    }

    @discardableResult
    func save(
        data: Data,
        filename: String,
        ownerKind: AttachmentOwner,
        ownerID: UUID,
        context: ModelContext,
        root: URL? = nil,
        id: UUID = UUID(),
        createdAt: Date = .now
    ) throws -> AttachmentItem {
        try save(
            data: data,
            filename: filename,
            ownerKind: ownerKind,
            ownerID: ownerID,
            context: context,
            root: root,
            id: id,
            createdAt: createdAt
        )
    }

    func loadData(id: UUID) -> Data? {
        loadData(id: id, root: nil)
    }

    func removeFile(id: UUID) {
        removeFile(id: id, root: nil)
    }

    func purge(
        ownerID: UUID,
        attachments: [AttachmentItem],
        context: ModelContext
    ) {
        purge(ownerID: ownerID, attachments: attachments, context: context, root: nil)
    }

    func resetDirectory() throws {
        try resetDirectory(fileManager: .default)
    }
}
