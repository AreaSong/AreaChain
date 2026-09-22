import Foundation

/// 待办和习惯共有的分类字段。仓储仍各自负责查找和保存。
protocol ClassifiedFields: AnyObject {
    var remindMinutes: Int? { get set }
    var isImportant: Bool { get set }
    var isUrgent: Bool { get set }
    var projectID: UUID? { get set }
    var tagIDs: String { get set }
}

extension DailyRoutine: ClassifiedFields {}
extension TodoItem: ClassifiedFields {}

enum ClassifiedFieldsUpdate {
    static func setRemind(_ item: some ClassifiedFields, minutes: Int?) {
        item.remindMinutes = RemindMinutes.clamped(minutes)
    }

    static func setPriority(_ item: some ClassifiedFields, isImportant: Bool, isUrgent: Bool) {
        item.isImportant = isImportant
        item.isUrgent = isUrgent
    }

    static func setProject(_ item: some ClassifiedFields, projectID: UUID?) {
        item.projectID = projectID
    }

    static func toggleTag(_ item: some ClassifiedFields, tagID: UUID) {
        item.tagIDs = TagIDList.toggling(item.tagIDs, tagID)
    }
}
