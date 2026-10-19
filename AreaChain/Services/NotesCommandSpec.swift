import Foundation
import SwiftData

/// todo.notes／routine.notes：替换、追加或清空备注，执行只经 TaskNotesService（与详情页同一入口），
/// 因此 #标签合并、提醒与优先级派生、@附件关联都与原界面一致。预览逐项列出这些派生变化。
/// 冲突基线只记备注摘要；固定多目标在一次事务内依次写入，任何一个失败整体回滚。
@MainActor struct NotesCommandSpec: SimpleCommandSpec {
    let kind: CommandObjectType
    let dependencies: TaskCommandDependencies
    var command: CommandID { .init(rawValue: kind == .todo ? "todo.notes" : "routine.notes") }
    var shape: CommandSimpleShape { .fixed(kind) }
    var copy: CommandSimpleCopy {
        .init(preview: "unified.simple.notes.preview", saved: "unified.simple.notes.saved")
    }

    func observe(_ input: CommandResolvedInput, in context: ModelContext) throws -> CommandSimpleState {
        try observe(CommandSimpleCall(input: input), in: context)
    }

    func expect(_ input: CommandResolvedInput, from before: CommandSimpleState,
                in context: ModelContext) throws -> CommandSimpleState {
        try expect(CommandSimpleCall(input: input), from: before, in: context)
    }

    func apply(_ input: CommandResolvedInput, in context: ModelContext) throws {
        try apply(CommandSimpleCall(input: input), in: context)
    }

    func observe(_ call: CommandSimpleCall, in context: ModelContext) throws -> CommandSimpleState {
        let edit = try NotesEdit(call.input)
        let owners = try call.input.targets.objects.map { try owner($0, in: context) }
        let texts = owners.map { edit.final($0.notes) }
        let tagKeys = TaskDerivedRows.keys(call.frozen, prefix: "tag:") ?? TaskDerivedRows.tagKeys(texts)
        let attachmentKeys = TaskDerivedRows.keys(call.frozen, prefix: "attachment:")
            ?? zip(owners, texts).flatMap { TaskDerivedRows.attachmentKeys($1, owner: $0.reference) }.sorted()
        return .init(rows: try owners.map { try row($0, in: context) }
            + TaskDerivedRows.tags(tagKeys, in: context) + TaskDerivedRows.attachments(attachmentKeys, in: context))
    }

    func expect(_ call: CommandSimpleCall, from before: CommandSimpleState, in context: ModelContext) throws -> CommandSimpleState {
        let edit = try NotesEdit(call.input)
        var tags = TaskDerivedRows.TagPlan()
        var rows: [CommandSimpleRow] = []
        var attachments: [CommandSimpleRow] = []
        for target in call.input.targets.objects {
            let owner = try owner(target, in: context)
            let text = edit.final(owner.notes)
            guard CommandLongTextLimit.allows(text) else { throw CommandSimpleIssue.invalidTarget(.tooLong) }
            let parsed = NaturalLanguageParser.parseTaskNotes(text)
            let names = try tags.merge(parsed.tagNames, into: owner.tagIDs, in: context)
            let remind = parsed.remindMinutes != nil ? RemindMinutes.clamped(parsed.remindMinutes) : owner.remind
            let important = parsed.hasPriorityToken ? parsed.isImportant : owner.important
            let urgent = parsed.hasPriorityToken ? parsed.isUrgent : owner.urgent
            rows.append(.init(key: target.id.uuidString, record: owner.record, title: owner.title, fields: [
                TaskCommandSpecs.notesField(text), TaskCommandSpecs.tagsField(names), TaskCommandSpecs.remindField(remind),
                TaskCommandSpecs.priorityField(important: important, urgent: urgent)]))
            attachments += TaskDerivedRows.expectedAttachments(text, owner: target, before: before,
                                                               attachments: dependencies.attachments, in: context)
        }
        return .init(rows: rows + tags.rows + attachments.sorted { $0.key < $1.key })
    }

    func apply(_ call: CommandSimpleCall, in context: ModelContext) throws {
        let edit = try NotesEdit(call.input)
        for target in call.input.targets.objects {
            if kind == .todo {
                let todo = try TaskCommandSpecs.todo(target.id, in: context)
                try TaskNotesService.apply(edit.final(todo.notes), to: todo, repository: dependencies.tasks(context),
                                           in: context, attachments: dependencies.attachments)
            } else {
                let routine = try TaskCommandSpecs.routine(target.id, in: context)
                try TaskNotesService.apply(edit.final(routine.notes), to: routine, repository: dependencies.routines(context),
                                           in: context, attachments: dependencies.attachments)
            }
        }
    }

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
            TaskCommandSpecs.notesField(owner.notes), TaskCommandSpecs.tagsField(try TaskCommandSpecs.tagNames(owner.tagIDs, in: context)),
            TaskCommandSpecs.remindField(owner.remind),
            TaskCommandSpecs.priorityField(important: owner.important, urgent: owner.urgent)])
    }
}

/// 备注参数的三种改写；三者都把最终全文交给同一解析。追加以换行接在原备注后（原备注为空时就是追加内容本身）。
@MainActor enum NotesEdit: Equatable {
    case replace(String), append(String), clear

    init(_ input: CommandResolvedInput) throws {
        let arguments = TagCommandSpecs.arguments(input)
        guard arguments.count == 1, let argument = arguments.first, argument.parameter == .notes else {
            throw CommandSimpleIssue.invalidArguments
        }
        switch (argument.operation, argument.value) {
        case (.replace, .longText(let text)?): self = .replace(text)
        case (.append, .longText(let text)?): self = .append(text)
        case (.clear, nil): self = .clear
        default: throw CommandSimpleIssue.invalidArguments
        }
    }

    func final(_ current: String) -> String {
        switch self {
        case .replace(let text): return text
        case .append(let text): return current.isEmpty ? text : current + "\n" + text
        case .clear: return ""
        }
    }
}
