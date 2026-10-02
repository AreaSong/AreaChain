import Foundation

/// 只从墓碑安全字段构造；nil 表示未知/不具备，不拿空值补造父字段。
struct TrashQueryFields: CustomStringConvertible, CustomDebugStringConvertible {
    var description: String { "TrashQueryFields(redacted)" }
    var debugDescription: String { description }
    var text: [(ContentQueryMatchField, String)]?
    var tagIDs: String?
    var createdAt: Date?
    var day: String?
    var done: Bool?
    var important: Bool?
    var urgent: Bool?
    var reminder: Int?
    var source: String?
    var enabled: Bool?
    var type: CommandObjectType

    init(_ fields: TrashObjectFields) {
        switch fields {
        case .todo(let value):
            type = .todo
            text = [(.title, value.title), (.notes, value.notes)]
            tagIDs = value.tagIDs; createdAt = value.createdAt; day = value.dayKey
            done = value.isDone; important = value.isImportant; urgent = value.isUrgent
            reminder = value.remindMinutes; source = value.sourceBundleID
        case .subtask(let value):
            type = .subtask
            text = [(.title, value.title)]; tagIDs = value.tagIDs
            createdAt = value.createdAt; done = value.isDone
        case .routine(let value):
            type = .routine
            text = [(.title, value.title), (.notes, value.notes)]
            tagIDs = value.tagIDs; createdAt = value.createdAt
            important = value.isImportant; urgent = value.isUrgent; enabled = value.isEnabled
            reminder = value.remindMinutes; source = value.sourceBundleID
        case .diary(let value):
            type = .diary
            if case .publicText(let body, _) = value.presentation { text = [(.diaryBody, body)] }
            tagIDs = value.hasValidTagIDs ? TagIDList.encode(value.tags.map(\.id)) : nil
            createdAt = value.createdAt; day = value.dayKey
        case .tag(let value): type = .tag; text = [(.tagName, value.name)]
        case .image(let value): type = .image; text = [(.filename, value.filename)]; createdAt = value.createdAt
        }
    }

    init(_ attributes: ImageOwnerAttributes) {
        switch attributes {
        case .todo(let value):
            type = .todo; tagIDs = value.tagIDs; day = value.scheduledDay
            done = value.isDone; important = value.isImportant; urgent = value.isUrgent
            reminder = value.remindMinutes
        case .routine(let value):
            type = .routine; tagIDs = value.tagIDs
            important = value.isImportant; urgent = value.isUrgent; enabled = value.isEnabled
            reminder = value.remindMinutes
        case .diary(let value): type = .diary; tagIDs = value.tagIDs; day = value.day
        }
    }
}
