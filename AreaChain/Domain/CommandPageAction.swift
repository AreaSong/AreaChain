import Foundation

/// 合并批 M-1 C：任务页的交互与只读查询指令。它们只改页面状态或读数据，不进计划、不建 Run、不写库；
/// 执行由显式装配的页面宿主完成，绑定当前页面，页面不对时拒绝而不切页。本类型只做纯解析。
enum CommandPageAction: Equatable {
    enum Section: String, Equatable { case today, yesterday, upcoming }
    enum Streak: String, Equatable { case current, best }

    case cancelTitle(CommandObjectReference)
    case cancelCompletion(UUID)
    case select([CommandObjectReference]), selectAll, clearSelection
    case sections(Section, expanded: Bool)
    case filter(CommandPageFilter), clearFilter
    case kind(ItemKindScope)
    case status(todo: TodoStatusScope?, routine: RoutineStatusScope?)
    case streak(routine: UUID, Streak, day: String)
    /// 合并批 M-2 A：日历月／周、安排页选择，以及看板修改指令转交给已有执行。
    case calendarMode(CommandBoardSpan)
    case ganttSelect(CommandGanttSelectMode, [CommandObjectReference])
    case transfer(CommandBoardTransfer)
    /// 合并批 M-2 B：取消标签页的新建或改名草稿；标签只读查询。
    case tagCancel
    case tagQuery(CommandTagQuery)

    static let commands: Set<String> = Set([
        "todo.cancelTitle", "subtask.cancelTitle", "todo.cancelCompletion", "tasks.select", "selection.all", "selection.clear",
        "tasks.sections", "tasks.filter", "tasks.clearFilter", "tasks.kind", "tasks.status", "routine.streak",
        "calendar.mode", "gantt.select", "tag.cancel",
    ]).union(CommandBoardTransfer.commands).union(CommandTagQuery.commands)

    init(_ draft: CommandDraft) throws {
        let objects = draft.targets.objects
        let arguments = Dictionary(draft.arguments.map { ($0.parameter, $0) }, uniquingKeysWith: { _, last in last })
        func choice(_ id: CommandParameterID) -> String? {
            if case .choice(let value)? = arguments[id]?.value { return value }
            return nil
        }
        func single(_ type: CommandObjectType) throws -> CommandObjectReference {
            guard objects.count == 1, objects[0].type == type else { throw CommandPageIssue.invalidTarget }
            return objects[0]
        }
        switch draft.commandID.rawValue {
        case "todo.cancelTitle": self = .cancelTitle(try single(.todo))
        case "subtask.cancelTitle": self = .cancelTitle(try single(.subtask))
        case "todo.cancelCompletion": self = .cancelCompletion(try single(.todo).id)
        case "tasks.select":
            guard !objects.isEmpty, objects.allSatisfy({ [.todo, .routineOccurrence].contains($0.type) }) else {
                throw CommandPageIssue.invalidTarget
            }
            self = .select(objects)
        case "selection.all": self = .selectAll
        case "selection.clear": self = .clearSelection
        case "tasks.sections":
            guard let section = choice(.section).flatMap(Section.init(rawValue:)),
                  case .boolean(let expanded)? = arguments[.enabled]?.value else { throw CommandPageIssue.invalidArguments }
            self = .sections(section, expanded: expanded)
        case "tasks.filter": self = .filter(try CommandPageFilter(arguments))
        case "tasks.clearFilter": self = .clearFilter
        case "tasks.kind":
            guard let kind = choice(.kind).flatMap(ItemKindScope.init(rawValue:)) else { throw CommandPageIssue.invalidArguments }
            self = .kind(kind)
        case "tasks.status":
            let todo = choice(.status).flatMap(TodoStatusScope.init(rawValue:))
            let routine = choice(.routineStatus).flatMap(RoutineStatusScope.init(rawValue:))
            guard todo != nil || routine != nil else { throw CommandPageIssue.invalidArguments }
            self = .status(todo: todo, routine: routine)
        case "routine.streak":
            guard let kind = choice(.kind).flatMap(Streak.init(rawValue:)), case .day(let day)? = arguments[.day]?.value,
                  CommandArgumentValidation.isCanonicalDay(day) else { throw CommandPageIssue.invalidArguments }
            self = .streak(routine: try single(.routine).id, kind, day: day)
        case "calendar.mode":
            guard let span = choice(.mode).flatMap(CommandBoardSpan.init(rawValue:)) else { throw CommandPageIssue.invalidArguments }
            self = .calendarMode(span)
        case "gantt.select":
            guard let mode = choice(.mode).flatMap(CommandGanttSelectMode.init(rawValue:)) else {
                throw CommandPageIssue.invalidArguments
            }
            // 单选一个、范围两端两个、多选至少一个；只接待办色块。
            let counts: ClosedRange<Int> = mode == .single ? 1...1 : mode == .range ? 2...2 : 1...Int.max
            guard counts.contains(objects.count), objects.allSatisfy({ $0.type == .todo && $0.dayKey == nil }) else {
                throw CommandPageIssue.invalidTarget
            }
            self = .ganttSelect(mode, objects)
        case let id where CommandBoardTransfer.commands.contains(id): self = .transfer(try CommandBoardTransfer(draft))
        case "tag.cancel": self = .tagCancel
        case let id where CommandTagQuery.commands.contains(id): self = .tagQuery(try CommandTagQuery(id, arguments: arguments))
        default: throw CommandPageIssue.unsupported
        }
    }
}

/// 页面筛选的指令输入：只覆盖给出的维度，没给的维度保持页面当前值。页面筛选一次只能选一个标签。
struct CommandPageFilter: Equatable {
    var tag: UUID??
    var priority: PriorityFilterScope?
    var bundleID: String??
    var date: DateFilterScope?
    var reminder: ReminderFilterScope?

    init(tag: UUID?? = nil, priority: PriorityFilterScope? = nil, bundleID: String?? = nil,
         date: DateFilterScope? = nil, reminder: ReminderFilterScope? = nil) {
        self.tag = tag
        self.priority = priority
        self.bundleID = bundleID
        self.date = date
        self.reminder = reminder
    }

    init(_ arguments: [CommandParameterID: CommandArgument]) throws {
        self.init()
        if let argument = arguments[.tags] {
            switch argument.value {
            case .tags(let ids)? where ids.count <= 1: tag = .some(ids.first)
            case nil where argument.operation == .clear: tag = .some(nil)
            default: throw CommandPageIssue.oneTag
            }
        }
        if let argument = arguments[.priority] {
            if argument.operation == .clear { priority = .all }
            else if case .choice(let value)? = argument.value, let scope = PriorityFilterScope(rawValue: value) { priority = scope }
            else { throw CommandPageIssue.invalidArguments }
        }
        if case .shortText(let text)? = arguments[.source]?.value {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            bundleID = .some(trimmed.isEmpty ? nil : trimmed)
        }
        if case .choice(let value)? = arguments[.dateFilter]?.value {
            guard let scope = DateFilterScope(rawValue: value) else { throw CommandPageIssue.invalidArguments }
            date = scope
        }
        if case .choice(let value)? = arguments[.reminderFilter]?.value {
            switch value {
            case "all": reminder = .all
            case "withReminder": reminder = .set
            case "withoutReminder": reminder = .unset
            default: throw CommandPageIssue.invalidArguments
            }
        }
        guard tag != nil || priority != nil || bundleID != nil || date != nil || reminder != nil else {
            throw CommandPageIssue.invalidArguments
        }
    }

    /// 沿 BoardFilter 原有的 with… 写法，不另写一套字段规则。
    func applied(to filter: BoardFilter) -> BoardFilter {
        var next = filter
        if let tag { next = next.withTag(tag) }
        if let priority { next = next.withPriorityScope(priority) }
        if let bundleID { next = next.withBundle(bundleID) }
        if let date { next = next.withDateScope(date) }
        if let reminder { next = next.withReminderScope(reminder) }
        return next
    }
}

enum CommandPageIssue: Error, Equatable {
    case unassembled, unsupported, invalidArguments, invalidTarget, oneTag
    /// 当前页面不是指令所需的页面；附带所需页面的本地化键，宿主不会替用户切页。
    case wrongPage(String)
    case pageUnavailable, nothingToCancel, notInList, missing, stale
    /// 今日区始终展开，没有可收起的状态。
    case todaySectionFixed
    /// 合并批 M-2：日历新建的备注须在新建待办里填写；页面上没有这一项可执行。
    case notesUnsupported
}
