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

    static func purge(ownerID: UUID, kind: AttachmentOwner, in context: ModelContext) throws {
        for item in matching(try all(in: context), ownerID: ownerID, kind: kind) {
            context.delete(item)
        }
    }
}
