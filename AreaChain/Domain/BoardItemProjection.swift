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

    var modelID: UUID {
        switch self {
        case .todo(let id), .recurring(let id):
            return id
        }
    }

    init?(listID: String) {
        let parts = listID.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let uuid = UUID(uuidString: parts[1]) else { return nil }
        switch parts[0] {
        case "todo":
            self = .todo(uuid)
        case "recurring":
            self = .recurring(uuid)
        default:
            return nil
        }
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
    var tagIDs: [UUID]

    static var fresh: RecurringCaptureDraft {
        RecurringCaptureDraft(
            title: "",
            notes: "",
            weekdayMask: WeekdayMask.all,
            isEnabled: true,
            remindMinutes: nil,
            isImportant: false,
            isUrgent: false,
            tagIDs: []
        )
    }

    var hasSelectedWeekday: Bool {
        (weekdayMask & WeekdayMask.all) != 0
    }
}
