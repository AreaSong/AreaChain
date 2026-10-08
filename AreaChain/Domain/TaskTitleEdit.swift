import Foundation

/// 标题编辑的旧解析语义；nil 表示保留，不能套用新增任务的默认值或元数据空标题规则。
struct TaskTitleEdit: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    struct Priority: Equatable {
        let isImportant: Bool
        let isUrgent: Bool
    }

    let title: String
    let notes: String?
    let priority: Priority?
    let remindMinutes: Int?
    let tagNames: [String]

    init?(_ rawInput: String) {
        let text = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let parsed = NaturalLanguageParser.parseTaskCapture(text)
        title = parsed.cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        notes = parsed.notes.isEmpty ? nil : parsed.notes
        priority = parsed.hasPriorityToken ? .init(isImportant: parsed.isImportant, isUrgent: parsed.isUrgent) : nil
        remindMinutes = parsed.remindMinutes
        tagNames = parsed.tagNames
    }

    var writeFields: Set<TaskTitleField> {
        var fields: Set<TaskTitleField> = [.title, .tagIDs]
        if notes != nil { fields.insert(.notes) }
        if priority != nil { fields.formUnion([.isImportant, .isUrgent]) }
        if remindMinutes != nil { fields.insert(.remindMinutes) }
        return fields
    }

    /// 旧 tagIDs 是合并输入；其他原值只用于冲突核对，不参与合成。
    var synthesisDependencies: Set<TaskTitleField> { [.tagIDs] }
    var description: String { "TaskTitleEdit(redacted)" }
    var debugDescription: String { description }
}

enum TaskTitleField: Hashable { case title, tagIDs, isImportant, isUrgent, remindMinutes, notes }

enum TaskTitleFieldValue: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    case text(String), flag(Bool), minutes(Int?)
    var description: String { "TaskTitleFieldValue(redacted)" }
    var debugDescription: String { description }
}
