import Foundation
import SwiftData

/// todo.notes／routine.notes：替换、追加或清空备注，执行只经 TaskNotesService 的借用出口（与详情页同一 `apply`），
/// 因此 #标签合并、提醒与优先级派生、@附件关联都与原界面一致。预览逐项列出这些派生变化。
/// L-M1b：正文只在准备期由托管同步读宿主草稿；封存后输入只剩印记，写入只经一次性借用（`apply(_:loan:in:)`）。
/// 冲突基线记目标备注与派生字段（标签、提醒、优先级）的带键摘要（L6、L8）；固定多目标在一次事务内依次写入，任何一个失败整体回滚。
@MainActor struct NotesCommandSpec: SimpleLongTextCommandSpec, SimpleCommandCallSpec {
    let kind: CommandObjectType
    let dependencies: TaskCommandDependencies
    var command: CommandID { .init(rawValue: kind == .todo ? "todo.notes" : "routine.notes") }
    var shape: CommandSimpleShape { .fixed(kind) }
    var copy: CommandSimpleCopy {
        .init(preview: "unified.simple.notes.preview", saved: "unified.simple.notes.saved")
    }

    /// 冻结调用（写后与未知核对）只读冻结行，不需要正文；未冻结时由准备期的原文推出要读的派生行。
    func observe(_ call: CommandSimpleCall, in context: ModelContext) throws -> CommandSimpleState {
        try NotesEdit.requireShape(call.input)
        let owners = try call.input.targets.objects.map { try owner($0, in: context) }
        let tagKeys: [String]
        let attachmentKeys: [String]
        if let frozen = call.frozen {
            tagKeys = TaskDerivedRows.keys(frozen, prefix: "tag:") ?? []
            attachmentKeys = TaskDerivedRows.keys(frozen, prefix: "attachment:") ?? []
        } else {
            let edit = try NotesEdit(call.input)
            let texts = owners.map { edit.final($0.notes) }
            tagKeys = TaskDerivedRows.tagKeys(texts)
            attachmentKeys = zip(owners, texts).flatMap { TaskDerivedRows.attachmentKeys($1, owner: $0.reference) }.sorted()
        }
        return .init(rows: try owners.map { try row($0, in: context) }
            + TaskDerivedRows.tags(tagKeys, in: context) + TaskDerivedRows.attachments(attachmentKeys, in: context))
    }

    func expect(_ call: CommandSimpleCall, from before: CommandSimpleState, in context: ModelContext) throws -> CommandSimpleState {
        let edit = try NotesEdit(call.input)
        var tags = TaskDerivedRows.TagPlan()
        var rows: [CommandSimpleRow] = []
        var attachments: [CommandSimpleRow] = []
        var notices: [CommandSimpleNotice] = []
        for target in call.input.targets.objects {
            let owner = try owner(target, in: context)
            let text = edit.final(owner.notes)
            guard CommandLongTextLimit.allows(text) else { throw CommandSimpleIssue.invalidTarget(.tooLong) }
            let parsed = NaturalLanguageParser.parseTaskNotes(text)
            notices += try TaskDerivedRows.protectedTagNotices(parsed.tagNames, in: context)
            let names = try tags.merge(parsed.tagNames, into: owner.tagIDs, in: context)
            let remind = parsed.remindMinutes != nil ? RemindMinutes.clamped(parsed.remindMinutes) : owner.remind
            let important = parsed.hasPriorityToken ? parsed.isImportant : owner.important
            let urgent = parsed.hasPriorityToken ? parsed.isUrgent : owner.urgent
            rows.append(.init(key: target.id.uuidString, record: owner.record, title: owner.title, fields: [
                notesField(text), TaskCommandSpecs.tagsField(names), TaskCommandSpecs.remindField(remind),
                TaskCommandSpecs.priorityField(important: important, urgent: urgent)]))
            attachments += TaskDerivedRows.expectedAttachments(text, owner: target, before: before,
                                                               attachments: dependencies.attachments, in: context)
        }
        return .init(rows: rows + tags.rows + attachments.sorted { $0.key < $1.key },
                     notices: TaskDerivedRows.unique(notices))
    }

    /// 唯一写入：托管签发的借用交给 TaskNotesService 的出口，一次 consume 写全部冻结目标。
    func apply(_ call: CommandSimpleCall, loan: CommandLongTextLoan, in context: ModelContext) throws {
        try NotesEdit.requireShape(call.input)
        if kind == .todo {
            let todos = try call.input.targets.objects.map { try TaskCommandSpecs.todo($0.id, in: context) }
            try TaskNotesService.applyLent(loan, to: todos, repository: dependencies.tasks(context), in: context,
                                           attachments: dependencies.attachments)
        } else {
            let routines = try call.input.targets.objects.map { try TaskCommandSpecs.routine($0.id, in: context) }
            try TaskNotesService.applyLent(loan, to: routines, repository: dependencies.routines(context), in: context,
                                           attachments: dependencies.attachments)
        }
    }

    private func notesField(_ notes: String) -> CommandSimpleField { TaskCommandSpecs.notesField(notes, dependencies.digest) }

    /// 与原界面一致：保存成功后按备注解析出的提醒请求授权；多目标只请求一次。
    func afterSave(_ call: CommandSimpleCall, in context: ModelContext) -> Bool {
        let minutes = call.input.targets.objects.lazy.compactMap { target -> Int? in
            guard let owner = try? owner(target, in: context) else { return nil }
            return NaturalLanguageParser.parseTaskNotes(owner.notes).remindMinutes
        }.first
        guard let minutes else { return false }
        dependencies.requestReminderAccess(minutes)
        return true
    }

    private struct Owner {
        let reference: CommandObjectReference
        let record: PersistentIdentifier
        let title, notes, tagIDs: String
        let remind: Int?
        let important, urgent: Bool
    }

    private func owner(_ target: CommandObjectReference, in context: ModelContext) throws -> Owner {
        guard target.type == kind else { throw CommandSimpleIssue.invalidArguments }
        if kind == .todo {
            let todo = try TaskCommandSpecs.todo(target.id, in: context)
            try TaskCommandSpecs.qualify(target, dependencies)
            return .init(reference: target, record: todo.persistentModelID, title: todo.title, notes: todo.notes,
                         tagIDs: todo.tagIDs, remind: todo.remindMinutes, important: todo.isImportant, urgent: todo.isUrgent)
        }
        let routine = try TaskCommandSpecs.routine(target.id, in: context)
        try TaskCommandSpecs.qualify(target, dependencies)
        return .init(reference: target, record: routine.persistentModelID, title: routine.title, notes: routine.notes,
                     tagIDs: routine.tagIDs, remind: routine.remindMinutes, important: routine.isImportant, urgent: routine.isUrgent)
    }

    private func row(_ owner: Owner, in context: ModelContext) throws -> CommandSimpleRow {
        .init(key: owner.reference.id.uuidString, record: owner.record, title: owner.title, fields: [
            notesField(owner.notes), TaskCommandSpecs.tagsField(try TaskCommandSpecs.tagNames(owner.tagIDs, in: context)),
            TaskCommandSpecs.remindField(owner.remind),
            TaskCommandSpecs.priorityField(important: owner.important, urgent: owner.urgent)])
    }
}

/// 备注参数的三种改写；三者都把最终全文交给同一解析。追加以换行接在原备注后（原备注为空时就是追加内容本身）。
@MainActor enum NotesEdit: Equatable {
    case replace(String), append(String), clear

    /// 准备期从原文参数构造；封存后的印记不能构造（正文只经借用出口）。
    init(_ input: CommandResolvedInput) throws {
        let argument = try Self.requireShape(input)
        switch (argument.operation, argument.value) {
        case (.replace, .longText(let text)?): self = .replace(text)
        case (.append, .longText(let text)?): self = .append(text)
        case (.clear, nil): self = .clear
        default: throw CommandSimpleIssue.invalidArguments
        }
    }

    /// 借用出口在 consume 闭包内构造；只活在那次同步调用里。
    init(_ operation: CommandFieldOperation, text: String) throws {
        switch operation {
        case .replace: self = .replace(text)
        case .append: self = .append(text)
        case .clear: self = .clear
        default: throw CommandSimpleIssue.invalidArguments
        }
    }

    /// 只认一个 notes 参数；值可以是原文（准备期）或印记（封存后）。
    @discardableResult
    static func requireShape(_ input: CommandResolvedInput) throws -> CommandArgument {
        let arguments = TagCommandSpecs.arguments(input)
        guard arguments.count == 1, let argument = arguments.first, argument.parameter == .notes,
              [.replace, .append, .clear].contains(argument.operation) else { throw CommandSimpleIssue.invalidArguments }
        return argument
    }

    func final(_ current: String) -> String {
        switch self {
        case .replace(let text): return text
        case .append(let text): return current.isEmpty ? text : current + "\n" + text
        case .clear: return ""
        }
    }
}
