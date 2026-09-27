import Foundation
import SwiftData

/// 三个仓储共用的附件读取和硬删除。待办的子任务级联、手记的加密转换仍留在各自仓储。
enum OwnedAttachments {
    static func all(in context: ModelContext) throws -> [AttachmentItem] {
        try context.fetch(FetchDescriptor<AttachmentItem>())
    }

    static func matching(_ attachments: [AttachmentItem], ownerID: UUID, kind: AttachmentOwner) -> [AttachmentItem] {
        attachments.filter { $0.ownerID == ownerID && $0.ownerKind == kind.rawValue }
    }

    /// 含已软删除行：父项彻底删除仍要拿到墓碑附件做文件清理。不按日期过滤。
    static func matching(ownerID: UUID, kind: AttachmentOwner, in context: ModelContext) throws -> [AttachmentItem] {
        try matching(ownerIDs: [ownerID], kind: kind, in: context)
    }

    static func matching(ownerIDs: Set<UUID>, kind: AttachmentOwner, in context: ModelContext) throws -> [AttachmentItem] {
        guard !ownerIDs.isEmpty else { return [] }
        let wanted = Array(ownerIDs)
        let kindValue = kind.rawValue
        return try context.fetch(
            FetchDescriptor<AttachmentItem>(predicate: #Predicate {
                wanted.contains($0.ownerID) && $0.ownerKind == kindValue
            })
        )
    }

    static func purge(ownerID: UUID, kind: AttachmentOwner, in context: ModelContext) throws {
        for item in try matching(ownerID: ownerID, kind: kind, in: context) {
            context.delete(item)
        }
    }
}
