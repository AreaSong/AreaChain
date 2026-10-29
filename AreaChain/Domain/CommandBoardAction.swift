import Foundation

/// 看板三页（日历、四象限、安排）的导航指令。它们只改页面的日期／月份状态，不写库；
/// 由显式装配的页面宿主执行，页面不对时拒绝而不切页。本类型只做纯解析与纯日期推算。
enum CommandBoardNavigation: Equatable {
    case calendarStep(forward: Bool), calendarToday, calendarDay(String), calendarDayList(String)
    case quadrantDay(String), quadrantStep(forward: Bool)
    case ganttStep(forward: Bool), ganttCurrentMonth
    /// 检查器沿 inspector.open：目标取当前结果的焦点项，宿主只核对它在页面投影里。
    case quadrantInspect, ganttInspect

    static let commands: Set<String> = [
        "calendar.step", "calendar.today", "calendar.day", "calendar.dayList",
        "quadrant.day", "quadrant.step", "gantt.step", "gantt.currentMonth", "quadrant.inspect", "gantt.inspect",
    ]

    /// 参数来自路径解析（导航类指令不建草稿）；缺少或非法即拒绝，不按默认值猜。
    init(command: CommandID, arguments: [CommandArgument]) throws {
        let values = Dictionary(arguments.map { ($0.parameter, $0.value) }, uniquingKeysWith: { _, last in last })
        func choice(_ id: CommandParameterID) -> String? {
            if case .choice(let value)?? = values[id] { return value }
            return nil
        }
        func day() throws -> String {
            guard case .day(let key)?? = values[.day], CommandArgumentValidation.isCanonicalDay(key) else {
                throw CommandPageIssue.invalidArguments
            }
            return key
        }
        func forward() throws -> Bool {
            switch choice(.offset) {
            case "previous": return false
            case "next": return true
            default: throw CommandPageIssue.invalidArguments
            }
        }
        func bare() throws { guard arguments.isEmpty else { throw CommandPageIssue.invalidArguments } }
        switch command.rawValue {
        case "calendar.step": self = .calendarStep(forward: try forward())
        case "calendar.today": try bare(); self = .calendarToday
        case "calendar.day": self = .calendarDay(try day())
        case "calendar.dayList": self = .calendarDayList(try day())
        case "quadrant.day": self = .quadrantDay(try day())
        case "quadrant.step": self = .quadrantStep(forward: try forward())
        case "gantt.step": self = .ganttStep(forward: try forward())
        case "gantt.currentMonth": try bare(); self = .ganttCurrentMonth
        case "quadrant.inspect": try bare(); self = .quadrantInspect
        case "gantt.inspect": try bare(); self = .ganttInspect
        default: throw CommandPageIssue.unsupported
        }
    }

    /// 指令绑定的页面（WorkspaceTab 的 rawValue）。
    var page: String {
        switch self {
        case .calendarStep, .calendarToday, .calendarDay, .calendarDayList: "calendar"
        case .quadrantDay, .quadrantStep, .quadrantInspect: "quadrant"
        case .ganttStep, .ganttCurrentMonth, .ganttInspect: "gantt"
        }
    }

    /// 与页面按钮同一推算：日历按当前视图（月沿 DayKey.shiftedMonth，周 ±7 天），安排页按月，
    /// 四象限 ±1 天，回今天／本月取 today。
    func nextDay(from current: String, today: String, span: CommandBoardSpan = .month, calendar: Calendar) -> String? {
        switch self {
        case .calendarStep(let forward) where span == .week:
            return DayKey.shifted(current, by: forward ? 7 : -7, calendar: calendar)
        case .calendarStep(let forward), .ganttStep(let forward):
            return DayKey.shiftedMonth(current, by: forward ? 1 : -1, calendar: calendar)
        case .quadrantStep(let forward): return DayKey.shifted(current, by: forward ? 1 : -1, calendar: calendar)
        case .calendarToday, .ganttCurrentMonth: return today
        case .calendarDay(let day), .calendarDayList(let day), .quadrantDay(let day): return day
        case .quadrantInspect, .ganttInspect: return nil
        }
    }
}

/// 看板修改指令转交给已有执行：只把参数与目标原样搬到对应指令的新草稿里，由那条指令自己的适配器准备、
/// 确认与保存；本类型不写任何数据，也不另定校验规则。
struct CommandBoardTransfer: Equatable {
    let command: CommandID
    let arguments: [CommandArgument]
    let targets: CommandDraftTargets

    static let commands: Set<String> = [
        "calendar.create", "quadrant.create", "quadrant.priority", "quadrant.complete", "quadrant.copy", "gantt.complete",
    ]

    init(command: CommandID, arguments: [CommandArgument], targets: CommandDraftTargets = .none) {
        self.command = command
        self.arguments = arguments
        self.targets = targets
    }

    init(_ draft: CommandDraft) throws {
        let objects = draft.targets.objects
        let arguments = draft.arguments.filter { $0.parameter != .target }
        func keep(_ ids: Set<CommandParameterID>) -> [CommandArgument] { arguments.filter { ids.contains($0.parameter) } }
        func enabled() -> CommandArgument { .init(parameter: .enabled, operation: .assign, value: .boolean(true)) }
        let types = Set(objects.map(\.type))
        switch draft.commandID.rawValue {
        case "calendar.create":
            // 备注是长文，只能经 todo.create 自己的长文入口填写，不在草稿之间搬运正文。
            guard !arguments.contains(where: { $0.parameter == .notes && $0.value != nil }) else {
                throw CommandPageIssue.notesUnsupported
            }
            self.init(command: .init(rawValue: "todo.create"), arguments: arguments.filter { $0.parameter != .notes })
        case "quadrant.create":
            self.init(command: .init(rawValue: "todo.create"), arguments: keep([.title, .day, .priority]))
        case "quadrant.priority":
            // 所在格子的日期只是页面上下文；优先级本身沿 todo.priority／routine.priority。
            guard types.count == 1, let type = types.first else { throw CommandPageIssue.invalidTarget }
            let command = type == .todo ? "todo.priority" : type == .routine ? "routine.priority" : ""
            guard !command.isEmpty else { throw CommandPageIssue.invalidTarget }
            self.init(command: .init(rawValue: command), arguments: keep([.priority]), targets: draft.targets)
        case "quadrant.complete":
            // 四象限只列当日未完成项，完成是单向的：待办走 todo.completion，习惯执行日走 occurrence.complete。
            guard objects.count == 1, let object = objects.first else { throw CommandPageIssue.invalidTarget }
            switch object.type {
            case .todo: self.init(command: .init(rawValue: "todo.completion"), arguments: [enabled()], targets: draft.targets)
            case .routineOccurrence: self.init(command: .init(rawValue: "occurrence.complete"), arguments: [], targets: draft.targets)
            default: throw CommandPageIssue.invalidTarget
            }
        case "quadrant.copy":
            // 四象限的全文气泡复制的是标题；习惯没有 todo.copy 执行入口，拒绝并说明。
            guard objects.count == 1, objects[0].type == .todo else { throw CommandPageIssue.invalidTarget }
            self.init(command: .init(rawValue: CommandTaskCopyPreview.command), arguments: [
                .init(parameter: .section, operation: .assign, value: .choice(TaskCopySection.title.rawValue)),
            ], targets: draft.targets)
        case "gantt.complete":
            guard !objects.isEmpty, types == [.todo] else { throw CommandPageIssue.invalidTarget }
            self.init(command: .init(rawValue: "batch.completion"), arguments: [enabled()],
                      targets: .init(.selected, objects: objects))
        default: throw CommandPageIssue.unsupported
        }
    }
}

/// 日历月／周与安排页选择方式：页面自己的状态值，指令只写这一份。
enum CommandBoardSpan: String, Equatable { case month, week }
enum CommandGanttSelectMode: String, Equatable { case single, multiple, range }
