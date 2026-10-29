import Foundation
import SwiftData

/// routine.capture：一行文字快速新增重复事项，执行只经 RoutineCaptureService 的借用出口（与重复事项面板同一 `apply`）。
/// 新习惯身份在准备时分配一次；排序值沿原面板 Catalog.nextSortOrder（全部习惯，含已删除）。
/// 新标签沿原入口在保存时新建；搜索仍不能创建标签。正文只在准备期由托管同步读宿主草稿，封存后只剩印记。
/// 单独成文件，使借用出口守卫能按文件精确放行本规格，而不放行同处的已装配指令。
@MainActor struct RoutineCaptureSpec: SimpleLongTextCommandSpec, SimpleCommandCallSpec {
    let dependencies: TaskCommandDependencies
    let command = CommandID(rawValue: "routine.capture")
    let shape = CommandSimpleShape.none
    let copy = CommandSimpleCopy(preview: "unified.simple.capture.preview", saved: "unified.simple.capture.saved")
    var creates: CommandObjectType? { .routine }

    /// 只认一个 body 参数，操作按目录声明为 assign；值可以是原文（准备期）或印记（封存后）。
    private func creation(_ call: CommandSimpleCall) throws -> CommandObjectReference {
        let arguments = call.input.arguments
        guard let creation = call.creation, creation.type == .routine, arguments.count == 1, let argument = arguments.first,
              argument.parameter == .body, argument.operation == .assign else { throw CommandSimpleIssue.invalidArguments }
        return creation
    }

    /// 准备期的原文；封存后的印记不能取正文（正文只经借用出口）。
    private func text(_ call: CommandSimpleCall) throws -> (String, CommandObjectReference) {
        let creation = try creation(call)
        guard case .longText(let raw)? = call.input.arguments.first?.value else { throw CommandSimpleIssue.invalidArguments }
        guard let text = RoutineCaptureService.trimmed(raw) else { throw CommandSimpleIssue.invalidTarget(.untitled) }
        return (text, creation)
    }

    private func sortOrder(in context: ModelContext) throws -> Int {
        Catalog.nextSortOrder(try context.fetch(FetchDescriptor<DailyRoutine>()).map(\.sortOrder))
    }

    private func tagKeys(_ text: String) -> [String] {
        Set(NaturalLanguageParser.parseTaskCapture(text).tagNames.map { "tag:" + TagSyntax.normalizedName($0) }).sorted()
    }

    private static func row(_ id: UUID, title: String, fields: [CommandSimpleField]) -> CommandSimpleRow {
        .init(key: id.uuidString, record: nil, title: title.isEmpty ? "—" : title, fields: fields)
    }

    /// 新习惯的字段；排序值只说明“排在最后”，值本身参与写后核对。
    private func fields(title: String, remind: Int?, important: Bool, urgent: Bool, tags: [String], notes: String,
                        order: Int) -> [CommandSimpleField] {
        [.init(id: "title", value: title, display: .verbatim(title)), TaskCommandSpecs.remindField(remind),
         TaskCommandSpecs.priorityField(important: important, urgent: urgent), TaskCommandSpecs.tagsField(tags),
         TaskCommandSpecs.notesField(notes, dependencies.digest),
         .init(id: "order", value: String(order), display: .localized("unified.simple.value.last"))]
    }

    private func created(_ creation: CommandObjectReference, in context: ModelContext) throws -> DailyRoutine? {
        let id = creation.id
        let found = try context.fetch(FetchDescriptor<DailyRoutine>(predicate: #Predicate { $0.id == id }))
        guard found.count <= 1 else { throw CommandSimpleIssue.invalidTarget(.duplicate) }
        return found.first
    }

    /// 冻结调用只读冻结行，不需要正文；未冻结时由准备期的原文推出要读的派生行。
    func observe(_ call: CommandSimpleCall, in context: ModelContext) throws -> CommandSimpleState {
        let creation = try creation(call)
        var rows: [CommandSimpleRow] = []
        if let routine = try created(creation, in: context) {
            rows.append(Self.row(routine.id, title: routine.title, fields: fields(
                title: routine.title, remind: routine.remindMinutes, important: routine.isImportant, urgent: routine.isUrgent,
                tags: try TaskCommandSpecs.tagNames(routine.tagIDs, in: context), notes: routine.notes, order: routine.sortOrder)))
        }
        let tags: [String]
        let attachments: [String]
        if let frozen = call.frozen {
            tags = TaskDerivedRows.keys(frozen, prefix: "tag:") ?? []
            attachments = TaskDerivedRows.keys(frozen, prefix: "attachment:") ?? []
        } else {
            let (text, _) = try text(call)
            tags = tagKeys(text)
            attachments = TaskDerivedRows.attachmentKeys(text, owner: creation)
        }
        return .init(rows: try rows + TaskDerivedRows.tags(tags, in: context) + TaskDerivedRows.attachments(attachments, in: context))
    }

    func expect(_ call: CommandSimpleCall, from before: CommandSimpleState, in context: ModelContext) throws -> CommandSimpleState {
        let (text, creation) = try text(call)
        guard before.rows.allSatisfy({ $0.key != creation.id.uuidString }) else { throw CommandSimpleIssue.stale }
        let parsed = NaturalLanguageParser.parseTaskCapture(text)
        let title = parsed.cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        // 与仓储 addRoutine 一致：没有标题时至少要有标签、提醒、优先级或备注。
        guard !title.isEmpty || !parsed.tagNames.isEmpty || parsed.remindMinutes != nil || parsed.isImportant
                || parsed.isUrgent || !parsed.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CommandSimpleIssue.invalidTarget(.untitled)
        }
        let notices = try TaskDerivedRows.protectedTagNotices(parsed.tagNames, in: context)
        var tags = TaskDerivedRows.TagPlan()
        let names = try tags.merge(parsed.tagNames, into: "", in: context)
        let routine = Self.row(creation.id, title: title, fields: fields(
            title: title, remind: RemindMinutes.clamped(parsed.remindMinutes), important: parsed.isImportant,
            urgent: parsed.isUrgent, tags: names, notes: parsed.notes, order: try sortOrder(in: context)))
        let attachments = TaskDerivedRows.expectedAttachments(text, owner: creation, before: before,
                                                              attachments: dependencies.attachments, in: context)
        return .init(rows: [routine] + tags.rows + attachments, notices: TaskDerivedRows.unique(notices))
    }

    /// 唯一写入：托管签发的借用交给 RoutineCaptureService 的出口。
    func apply(_ call: CommandSimpleCall, loan: CommandLongTextLoan, in context: ModelContext) throws {
        let creation = try creation(call)
        try RoutineCaptureService.applyLent(loan, sortOrder: sortOrder(in: context), creationID: creation.id,
                                            createdDayKey: dependencies.today(), repository: dependencies.routines(context),
                                            in: context, attachments: dependencies.attachments)
    }

    /// 回执“打开新习惯”：与转换后打开习惯同一位置（今天的执行日，父对象为新习惯）。
    func openTarget(_ creation: CommandObjectReference) -> ContentQueryBrowseOpen? {
        guard creation.type == .routine else { return nil }
        return .init(object: .init(type: .routineOccurrence, id: creation.id, dayKey: dependencies.today()),
                     parent: creation, viewingTrash: false)
    }

    /// 与原面板一致：保存成功后按解析出的提醒请求授权；封存后没有正文，读新习惯已保存的提醒。
    func afterSave(_ call: CommandSimpleCall, in context: ModelContext) -> Bool {
        guard let creation = try? creation(call), let routine = try? created(creation, in: context),
              let minutes = routine.remindMinutes else { return false }
        dependencies.requestReminderAccess(minutes)
        return true
    }
}
