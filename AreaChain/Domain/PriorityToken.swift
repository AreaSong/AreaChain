import Foundation

/// `!p1`–`!p4` 与中文优先级口令对应的重要、紧急标记。输入写入和搜索匹配共用这一张表。
struct PriorityFlags: Equatable {
    var isImportant: Bool
    var isUrgent: Bool
}

enum PriorityToken {
    static func flags(in token: String) -> PriorityFlags? {
        switch token.lowercased() {
        case "!p1", "!重要紧急", "!紧急重要", "!重要且紧急":
            return PriorityFlags(isImportant: true, isUrgent: true)
        case "!p2", "!重要", "!重要不紧急":
            return PriorityFlags(isImportant: true, isUrgent: false)
        case "!p3", "!紧急", "!不重要紧急", "!紧急不重要":
            return PriorityFlags(isImportant: false, isUrgent: true)
        case "!p4", "!不重要不紧急":
            return PriorityFlags(isImportant: false, isUrgent: false)
        default:
            return nil
        }
    }
}
