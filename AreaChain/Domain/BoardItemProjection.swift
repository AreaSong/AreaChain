import Foundation

enum BoardItemKind: Equatable {
    case oneOff
    case recurring
}

enum BoardItemReference: Hashable, Identifiable {
    case todo(UUID)
    case recurring(UUID)

    var id: String {
        switch self {
        case .todo(let id):
            return "todo:\(id.uuidString)"
        case .recurring(let id):
            return "recurring:\(id.uuidString)"
        }
    }

    var kind: BoardItemKind {
        switch self {
        case .todo:
            return .oneOff
        case .recurring:
            return .recurring
        }
    }

    var canReschedule: Bool {
        if case .todo = self { return true }
        return false
    }
}

struct BoardProgress: Equatable {
    var completed: Int
    var total: Int

    var ratio: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
}

/// 新建重复事项的草稿。星期掩码为 0 时拒绝保存，避免被收成「每天」。
struct RecurringCaptureDraft: Equatable {
    var title: String
    var notes: String
    var weekdayMask: Int
    var isEnabled: Bool
    var remindMinutes: Int?
    var isImportant: Bool
    var isUrgent: Bool

    static var fresh: RecurringCaptureDraft {
        RecurringCaptureDraft(
            title: "",
            notes: "",
            weekdayMask: WeekdayMask.all,
            isEnabled: true,
            remindMinutes: nil,
            isImportant: false,
            isUrgent: false
        )
    }

    var hasSelectedWeekday: Bool {
        (weekdayMask & WeekdayMask.all) != 0
    }
}
