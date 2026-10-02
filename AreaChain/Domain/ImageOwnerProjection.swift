import Foundation

/// 只保存后续所属属性匹配需要的字段；全文、备注、子项与历史不进入图片结果。
struct ImageTodoAttributes: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    var description: String { "ImageTodoAttributes(redacted)" }
    var debugDescription: String { description }

    let scheduledDay: String
    let createdAt: Date
    let tagIDs: String
    let isDone: Bool
    let isImportant: Bool
    let isUrgent: Bool
    let remindMinutes: Int?
    let dueMinutes: Int?
}

struct ImageRoutineAttributes: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    var description: String { "ImageRoutineAttributes(redacted)" }
    var debugDescription: String { description }

    let createdDay: String
    let createdAt: Date
    let tagIDs: String
    let isEnabled: Bool
    let weekdayMask: Int
    let pausedOnDay: String?
    let isImportant: Bool
    let isUrgent: Bool
    let remindMinutes: Int?
}

struct ImageDiaryAttributes: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    var description: String { "ImageDiaryAttributes(redacted)" }
    var debugDescription: String { description }

    let day: String
    let createdAt: Date
    let tagIDs: String
    let isPinned: Bool
}

/// diary 只提供已确认公开的日期/标签/置顶；不带正文或伪造的任务字段。
enum ImageOwnerAttributes: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    var description: String { "ImageOwnerAttributes(redacted)" }
    var debugDescription: String { description }

    case todo(ImageTodoAttributes)
    case routine(ImageRoutineAttributes)
    case diary(ImageDiaryAttributes)
}

struct ImageOwnerProjection: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let owner: AttachmentOwnerKey
    let attributes: ImageOwnerAttributes

    var relatedObject: CommandObjectReference {
        switch owner.kind {
        case .todo: .init(type: .todo, id: owner.id)
        case .routine: .init(type: .routine, id: owner.id)
        case .diary: .init(type: .diary, id: owner.id)
        }
    }
    var description: String { "ImageOwnerProjection(redacted)" }
    var debugDescription: String { description }
}

/// 只在一次 read 的栈内持有输入快照，不进入公开响应。
enum ImageOwnerInput: CustomStringConvertible, CustomDebugStringConvertible {
    case todo(TodoSnapshot), routine(RoutineSnapshot), diary(DiarySnapshot)

    var description: String { "ImageOwnerInput(redacted)" }
    var debugDescription: String { description }

    var key: AttachmentOwnerKey {
        switch self {
        case .todo(let value): .init(kind: .todo, id: value.id)
        case .routine(let value): .init(kind: .routine, id: value.id)
        case .diary(let value): .init(kind: .diary, id: value.id)
        }
    }
    var deletedAt: Date? {
        switch self {
        case .todo(let value): value.deletedAt
        case .routine(let value): value.deletedAt
        case .diary(let value): value.deletedAt
        }
    }
    var projection: ImageOwnerProjection? {
        guard hasValidAttributes else { return nil }
        let attributes: ImageOwnerAttributes
        switch self {
        case .todo(let value):
            attributes = .todo(.init(scheduledDay: value.dayKey, createdAt: value.createdAt,
                                    tagIDs: value.tagIDs, isDone: value.isDone,
                                    isImportant: value.isImportant, isUrgent: value.isUrgent,
                                    remindMinutes: value.remindMinutes, dueMinutes: value.dueMinutes))
        case .routine(let value):
            attributes = .routine(.init(createdDay: value.createdDayKey, createdAt: value.createdAt,
                                       tagIDs: value.tagIDs, isEnabled: value.isEnabled,
                                       weekdayMask: value.weekdayMask, pausedOnDay: value.pausedOnDayKey,
                                       isImportant: value.isImportant, isUrgent: value.isUrgent,
                                       remindMinutes: value.remindMinutes))
        case .diary(let value):
            attributes = .diary(.init(day: value.dayKey, createdAt: value.createdAt,
                                     tagIDs: value.tagIDs, isPinned: value.isPinned))
        }
        return .init(owner: key, attributes: attributes)
    }

    private var hasValidAttributes: Bool {
        let day: String
        let created: Date
        let tags: String
        switch self {
        case .todo(let value): (day, created, tags) = (value.dayKey, value.createdAt, value.tagIDs)
        case .routine(let value): (day, created, tags) = (value.createdDayKey, value.createdAt, value.tagIDs)
        case .diary(let value): (day, created, tags) = (value.dayKey, value.createdAt, value.tagIDs)
        }
        return CommandArgumentValidation.isCanonicalDay(day)
            && created.timeIntervalSince1970.isFinite && DiaryQueryMetadata.hasValidTagIDs(tags)
    }
}
