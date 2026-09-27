import Foundation
import SwiftData

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

    static func stampAttachments(ownerID: UUID, at date: Date, attachments: [AttachmentItem], ownerKind: AttachmentOwner) {
        for item in attachments where item.ownerID == ownerID && item.ownerKind == ownerKind.rawValue && item.deletedAt == nil {
            item.deletedAt = date
        }
    }

    static func restoreCascadedAttachments(
        ownerID: UUID,
        parentDeletedAt: Date?,
        attachments: [AttachmentItem],
        ownerKind: AttachmentOwner
    ) {
        for item in attachments where item.ownerID == ownerID
            && item.ownerKind == ownerKind.rawValue
            && shouldRestoreChild(parentDeletedAt: parentDeletedAt, childDeletedAt: item.deletedAt)
        {
            item.deletedAt = nil
        }
    }

    /// 回收站列表只需要墓碑行；拥有者是否可恢复另走 id predicate，不能靠这批结果当 live 集。
    static var deletedTodos: Predicate<TodoItem> { #Predicate { $0.deletedAt != nil } }
    static var deletedRoutines: Predicate<DailyRoutine> { #Predicate { $0.deletedAt != nil } }
    static var deletedDiaries: Predicate<DiaryEntry> { #Predicate { $0.deletedAt != nil } }
    static var deletedAttachments: Predicate<AttachmentItem> { #Predicate { $0.deletedAt != nil } }
    static var liveAttachments: Predicate<AttachmentItem> { #Predicate { $0.deletedAt == nil } }
}
