import Foundation
import Testing
@testable import AreaChain

/// 看板导航的纯解析与日期推算，以及修改指令转交给已有执行时搬运的参数与目标。
@Suite struct CommandBoardActionTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }()
    private func choice(_ id: CommandParameterID, _ value: String) -> CommandArgument {
        .init(parameter: id, operation: .assign, value: .choice(value))
    }
    private func day(_ key: String) -> CommandArgument { .init(parameter: .day, operation: .assign, value: .day(key)) }
    private func draft(_ command: String, _ targets: [CommandObjectReference] = [], _ arguments: [CommandArgument] = []) -> CommandDraft {
        CommandDraft(id: UUID(), hostID: "host", commandID: .init(rawValue: command),
                     targets: targets.isEmpty ? .none : .init(targets.count > 1 ? .selected : .single, objects: targets),
                     arguments: arguments)
    }

    /// 与页面按钮同一推算：月 ±1、周 ±7 天、四象限 ±1 天、回今天。
    @Test func navigationFollowsThePageButtons() throws {
        let next = try CommandBoardNavigation(command: .init(rawValue: "calendar.step"), arguments: [choice(.offset, "next")])
        #expect(next.nextDay(from: "2026-01-31", today: "2026-10-20", calendar: calendar)
                == DayKey.shiftedMonth("2026-01-31", by: 1, calendar: calendar))
        let previous = try CommandBoardNavigation(command: .init(rawValue: "calendar.step"), arguments: [choice(.offset, "previous")])
        #expect(previous.nextDay(from: "2026-10-20", today: "2026-10-20", span: .week, calendar: calendar) == "2026-10-13")
        // 导航路径只接一个尾段参数：/calendar/step/next 能直接解析。
        let parsed = CommandPathParser().parse(.init(text: "/calendar/step/next"))
        #expect(parsed.state == .command && parsed.arguments == [choice(.offset, "next")])
        let quadrant = try CommandBoardNavigation(command: .init(rawValue: "quadrant.step"), arguments: [choice(.offset, "next")])
        #expect(quadrant.nextDay(from: "2026-10-31", today: "2026-10-20", calendar: calendar) == "2026-11-01")
        let today = try CommandBoardNavigation(command: .init(rawValue: "calendar.today"), arguments: [])
        #expect(today.nextDay(from: "2026-01-01", today: "2026-10-20", calendar: calendar) == "2026-10-20")
        #expect(try CommandBoardNavigation(command: .init(rawValue: "calendar.dayList"), arguments: [day("2026-10-05")]).page == "calendar")
        #expect(throws: CommandPageIssue.invalidArguments) {
            try CommandBoardNavigation(command: .init(rawValue: "calendar.step"), arguments: [])
        }
        #expect(throws: CommandPageIssue.invalidArguments) {
            try CommandBoardNavigation(command: .init(rawValue: "quadrant.day"), arguments: [day("2026-13-40")])
        }
    }

    @Test func createTransfersEveryArgumentButNotes() throws {
        let title = CommandArgument(parameter: .title, operation: .assign, value: .shortText("日历新建"))
        let calendarCreate = try CommandBoardTransfer(draft("calendar.create", [], [title, day("2026-10-21")]))
        #expect(calendarCreate.command.rawValue == "todo.create" && calendarCreate.arguments == [title, day("2026-10-21")])
        let notes = CommandArgument(parameter: .notes, operation: .assign, value: .longText("正文"))
        #expect(throws: CommandPageIssue.notesUnsupported) {
            try CommandBoardTransfer(draft("calendar.create", [], [title, day("2026-10-21"), notes]))
        }
        let priority = choice(.priority, "p1")
        let quadrant = try CommandBoardTransfer(draft("quadrant.create", [], [title, day("2026-10-21"), priority]))
        #expect(quadrant.command.rawValue == "todo.create" && quadrant.arguments == [title, day("2026-10-21"), priority])
    }

    @Test func fieldAndStateCommandsTransferToTheExistingExecution() throws {
        let todo = CommandObjectReference(type: .todo, id: UUID())
        let routine = CommandObjectReference(type: .routine, id: UUID())
        let occurrence = CommandObjectReference(type: .routineOccurrence, id: UUID(), dayKey: "2026-10-20")
        let enabled = CommandArgument(parameter: .enabled, operation: .assign, value: .boolean(true))
        let todoPriority = try CommandBoardTransfer(draft("quadrant.priority", [todo], [choice(.priority, "p2"), day("2026-10-20")]))
        #expect(todoPriority.command.rawValue == "todo.priority" && todoPriority.arguments == [choice(.priority, "p2")])
        #expect(try CommandBoardTransfer(draft("quadrant.priority", [routine], [choice(.priority, "p2")])).command.rawValue
                == "routine.priority")
        #expect(throws: CommandPageIssue.invalidTarget) {
            try CommandBoardTransfer(draft("quadrant.priority", [todo, routine], [choice(.priority, "p2")]))
        }
        let complete = try CommandBoardTransfer(draft("quadrant.complete", [todo]))
        #expect(complete.command.rawValue == "todo.completion" && complete.arguments == [enabled] && complete.targets.objects == [todo])
        #expect(try CommandBoardTransfer(draft("quadrant.complete", [occurrence])).command.rawValue == "occurrence.complete")
        let copy = try CommandBoardTransfer(draft("quadrant.copy", [todo]))
        #expect(copy.command.rawValue == CommandTaskCopyPreview.command && copy.arguments == [choice(.section, "title")])
        #expect(throws: CommandPageIssue.invalidTarget) { try CommandBoardTransfer(draft("quadrant.copy", [routine])) }
        let other = CommandObjectReference(type: .todo, id: UUID())
        let gantt = try CommandBoardTransfer(draft("gantt.complete", [todo, other]))
        #expect(gantt.command.rawValue == "batch.completion" && gantt.arguments == [enabled])
        #expect(gantt.targets == .init(.selected, objects: [todo, other]))
    }

    /// 目录：quadrant.complete 已按习惯跳过语义解决，转交执行；看板指令都在页面指令里登记。
    @Test func catalogDeclaresTheBoardCommands() throws {
        let catalog = CommandCatalog.standard
        #expect(catalog.command(id: .init(rawValue: "quadrant.complete"))?.availability == .declared)
        for id in CommandBoardTransfer.commands.union(["calendar.mode", "gantt.select"]) {
            #expect(CommandPageAction.commands.contains(id))
            #expect(catalog.command(id: .init(rawValue: id)) != nil)
        }
        for id in CommandBoardNavigation.commands {
            #expect(catalog.command(id: .init(rawValue: id))?.category == .navigation)
        }
    }
}
