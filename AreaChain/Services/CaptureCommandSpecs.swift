import Foundation
import SwiftData

/// tasks.postponeYesterday：今日页“昨天”清单里全部未完成的待办（不含习惯）延至今天。
/// 取法沿 AgendaProjection.overdueTodos（与今日页 DayBoardPageProjection 同一规则；指令没有页面筛选）。
/// 目标在准备时推出、接受后冻结：之后清单增减都要求重新预览；写入沿 B-M1 批量改期的 moveTodo，在一次事务内完成。
/// 总量沿 CommandBatchWriteSet.Counts.entityLimit；day 参数必须是今天。原页面按钮仍逐个保存，未改。
@MainActor struct PostponeYesterdaySpec: SimpleCommandCallSpec {
    let dependencies: TaskCommandDependencies
    let command = CommandID(rawValue: "tasks.postponeYesterday")
    let shape = CommandSimpleShape.none
    let copy = CommandSimpleCopy(preview: "unified.simple.postpone.preview", saved: "unified.simple.postpone.saved")

    private func day(_ input: CommandResolvedInput) throws -> String {
        guard input.arguments.count == 1, let argument = input.arguments.first, argument.parameter == .day,
              case .day(let day)? = argument.value else { throw CommandSimpleIssue.invalidArguments }
        return day
    }

    private func row(_ todo: TodoItem) -> CommandSimpleRow {
        .init(key: todo.id.uuidString, record: todo.persistentModelID, title: todo.title,
              fields: [.init(id: "day", value: todo.dayKey, display: .verbatim(todo.dayKey))])
    }

    /// 未冻结时按页面取法推出目标；冻结后只读冻结的待办（写后与未知核对）。
    private func targets(_ call: CommandSimpleCall, in context: ModelContext) throws -> [TodoItem] {
        if let frozen = call.frozen {
            return try frozen.sorted().map { key in
                guard let id = UUID(uuidString: key) else { throw CommandSimpleIssue.stale }
                return try TaskCommandSpecs.todo(id, in: context)
            }
        }
        let todos = try context.fetch(FetchDescriptor<TodoItem>())
        let overdue = AgendaProjection.overdueTodos(todos: todos.map(\.snapshot), todayKey: dependencies.today(),
                                                    calendar: dependencies.calendar)
        return try overdue.map { try TaskCommandSpecs.todo($0.id, in: context) }
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }

    func observe(_ call: CommandSimpleCall, in context: ModelContext) throws -> CommandSimpleState {
        _ = try day(call.input)
        let todos = try targets(call, in: context)
        for todo in todos { try TaskCommandSpecs.qualify(.init(type: .todo, id: todo.id), dependencies) }
        return .init(rows: todos.map(row))
    }

    func expect(_ call: CommandSimpleCall, from before: CommandSimpleState, in context: ModelContext) throws -> CommandSimpleState {
        let today = dependencies.today()
        guard try day(call.input) == today else { throw CommandSimpleIssue.invalidTarget(.notToday) }
        guard !before.rows.isEmpty else { throw CommandSimpleIssue.invalidTarget(.nothingToMove) }
        guard before.rows.count <= CommandBatchWriteSet.Counts.entityLimit else { throw CommandSimpleIssue.invalidTarget(.tooMany) }
        return .init(rows: before.rows.map { row in
            .init(key: row.key, record: row.record, title: row.title,
                  fields: [.init(id: "day", value: today, display: .verbatim(today))])
        })
    }

    func apply(_ call: CommandSimpleCall, in context: ModelContext) throws {
        let today = dependencies.today()
        let repository = dependencies.tasks(context)
        for todo in try targets(call, in: context) { try repository.moveTodo(id: todo.id, to: today) }
    }
}

/// routine.capture：一行文字快速新增重复事项，执行只经 RoutineCaptureService（与重复事项面板同一入口）。
/// 新习惯身份在准备时分配一次；排序值沿原面板 Catalog.nextSortOrder（全部习惯，含已删除）。
/// 新标签沿原入口在保存时新建；搜索仍不能创建标签。
@MainActor struct RoutineCaptureSpec: SimpleCommandCallSpec {
    let dependencies: TaskCommandDependencies
    let command = CommandID(rawValue: "routine.capture")
    let shape = CommandSimpleShape.none
    let copy = CommandSimpleCopy(preview: "unified.simple.capture.preview", saved: "unified.simple.capture.saved")
    var creates: CommandObjectType? { .routine }

    private func text(_ call: CommandSimpleCall) throws -> (String, CommandObjectReference) {
        let arguments = call.input.arguments
        guard let creation = call.creation, creation.type == .routine, arguments.count == 1, let argument = arguments.first,
              argument.parameter == .body, argument.operation == .replace, case .longText(let raw)? = argument.value else {
            throw CommandSimpleIssue.invalidArguments
        }
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
    private static func fields(title: String, remind: Int?, important: Bool, urgent: Bool, tags: [String], notes: String,
                               order: Int) -> [CommandSimpleField] {
        [.init(id: "title", value: title, display: .verbatim(title)), TaskCommandSpecs.remindField(remind),
         TaskCommandSpecs.priorityField(important: important, urgent: urgent), TaskCommandSpecs.tagsField(tags),
         TaskCommandSpecs.notesField(notes),
         .init(id: "order", value: String(order), display: .localized("unified.simple.value.last"))]
    }

    func observe(_ call: CommandSimpleCall, in context: ModelContext) throws -> CommandSimpleState {
        let (text, creation) = try text(call)
        let id = creation.id
        let found = try context.fetch(FetchDescriptor<DailyRoutine>(predicate: #Predicate { $0.id == id }))
        var rows: [CommandSimpleRow] = []
        if let routine = found.first {
            guard found.count == 1 else { throw CommandSimpleIssue.invalidTarget(.duplicate) }
            rows.append(Self.row(routine.id, title: routine.title, fields: Self.fields(
                title: routine.title, remind: routine.remindMinutes, important: routine.isImportant, urgent: routine.isUrgent,
                tags: try TaskCommandSpecs.tagNames(routine.tagIDs, in: context), notes: routine.notes, order: routine.sortOrder)))
        }
        let tags = TaskDerivedRows.keys(call.frozen, prefix: "tag:") ?? tagKeys(text)
        let attachments = TaskDerivedRows.keys(call.frozen, prefix: "attachment:")
            ?? TaskDerivedRows.attachmentKeys(text, owner: creation)
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
        var tags = TaskDerivedRows.TagPlan()
        let names = try tags.merge(parsed.tagNames, into: "", in: context)
        let routine = Self.row(creation.id, title: title, fields: Self.fields(
            title: title, remind: RemindMinutes.clamped(parsed.remindMinutes), important: parsed.isImportant,
            urgent: parsed.isUrgent, tags: names, notes: parsed.notes, order: try sortOrder(in: context)))
        let attachments = TaskDerivedRows.expectedAttachments(text, owner: creation, before: before,
                                                              attachments: dependencies.attachments, in: context)
        return .init(rows: [routine] + tags.rows + attachments)
    }

    func apply(_ call: CommandSimpleCall, in context: ModelContext) throws {
        let (text, creation) = try text(call)
        _ = try RoutineCaptureService.apply(.init(text: text, sortOrder: sortOrder(in: context), creationID: creation.id,
                                                  createdDayKey: dependencies.today()),
                                            repository: dependencies.routines(context), in: context,
                                            attachments: dependencies.attachments)
    }

    func afterSave(_ call: CommandSimpleCall, in context: ModelContext) -> Bool {
        guard let (text, _) = try? text(call), let minutes = NaturalLanguageParser.parseTaskCapture(text).remindMinutes else {
            return false
        }
        dependencies.requestReminderAccess(minutes)
        return true
    }
}
