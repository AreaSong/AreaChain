import Foundation
import SwiftData

/// 已挂在对象上的附件回收的唯一入口（从 DayBoardMutations.trashAttachment 与附件中心抽出，原界面转调）：
/// 只打删除戳，文件与拥有者关系保留，可从回收站恢复。事务由调用方给出。
@MainActor enum AttachmentTrashService {
    static func stamp(_ row: AttachmentItem, at stamp: Date = SoftDelete.stamp()) {
        row.deletedAt = stamp
    }

    /// 与附件中心同一资格（AttachmentAccess.canBrowse）：附件未删、未加密，拥有者唯一且存活（孤儿不在其中），
    /// 手记拥有者不敏感。附件中心看不到的，指令也不能回收。
    static func eligibility(_ row: AttachmentItem, in context: ModelContext) throws -> Eligibility {
        guard row.deletedAt == nil else { return .deleted }
        guard row.privacyVaultID == nil else { return .protected }
        guard let owner = row.ownerKey else { return .orphan }
        let owners = try AttachmentAccess.ownerIndex(context: context, keys: [owner])
        guard owners.ownerIsLive(owner) else { return .orphan }
        let tags = try context.fetch(FetchDescriptor<TagItem>())
        return AttachmentAccess.canBrowse(row, owners: owners, tags: tags) ? .eligible : .protected
    }

    enum Eligibility: Equatable { case eligible, deleted, protected, orphan }
}
