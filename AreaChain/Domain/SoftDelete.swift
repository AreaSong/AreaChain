import Foundation

enum SoftDelete {
    static func stamp() -> Date { Date() }

    /// 父项进回收站时，只把当时还活着的子项打上同一时间戳，便于恢复时成组还原。
    static func shouldRestoreChild(parentDeletedAt: Date?, childDeletedAt: Date?) -> Bool {
        guard let parentDeletedAt, let childDeletedAt else { return false }
        return childDeletedAt == parentDeletedAt
    }

    static func restoreCascadedSubtasks(parentDeletedAt: Date?, subtasks: [SubtaskItem]) {
        for sub in subtasks where shouldRestoreChild(parentDeletedAt: parentDeletedAt, childDeletedAt: sub.deletedAt) {
            sub.deletedAt = nil
        }
    }

    static func stampLiveSubtasks(_ subtasks: [SubtaskItem], at date: Date) {
        for sub in subtasks where sub.deletedAt == nil {
            sub.deletedAt = date
        }
    }

    static func stampAttachments(ownerID: UUID, at date: Date, attachments: [AttachmentItem]) {
        for item in attachments where item.ownerID == ownerID && item.deletedAt == nil {
            item.deletedAt = date
        }
    }

    static func restoreCascadedAttachments(
        ownerID: UUID,
        parentDeletedAt: Date?,
        attachments: [AttachmentItem]
    ) {
        for item in attachments where item.ownerID == ownerID
            && shouldRestoreChild(parentDeletedAt: parentDeletedAt, childDeletedAt: item.deletedAt)
        {
            item.deletedAt = nil
        }
    }
}
