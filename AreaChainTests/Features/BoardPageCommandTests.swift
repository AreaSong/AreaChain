import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 合并批 M-2 A（服务层）：看板页面指令只写页面那一份状态（BoardSelection 日期、宿主 boardPages），
/// 页面不对时拒绝且不切页；检查器与选择只在页面投影里。
@Suite(.serialized) @MainActor struct BoardPageCommandTests {
    typealias Fixture = WorkspacePageCommandTests.Fixture

    private func board(_ page: WorkspaceTab) throws -> Fixture {
        let f = try Fixture(page: page)
        f.pages.today = { "2026-10-20" }
        f.navigation.boardSelection.inspectingDayKey = "2026-10-20"
        return f
    }
    private func navigate(_ f: Fixture, _ command: String, _ arguments: [CommandArgument] = [],
                          inspecting target: CommandObjectReference? = nil) throws -> WorkspaceTab {
        try f.pages.applyBoardNavigation(.init(command: .init(rawValue: command), arguments: arguments), inspecting: target)
    }
    private func choice(_ id: CommandParameterID, _ value: String) -> CommandArgument { WorkspacePageCommandTests.choice(id, value) }
    private func day(_ key: String) -> CommandArgument { .init(parameter: .day, operation: .assign, value: .day(key)) }

    @Test func calendarNavigationWritesTheSharedSelectedDay() throws {
        let f = try board(.calendar)
        #expect(try navigate(f, "calendar.step", [choice(.offset, "next")]) == .calendar)
        #expect(f.navigation.boardSelection.inspectingDayKey == DayKey.shiftedMonth("2026-10-20", by: 1, calendar: .current))
        _ = try navigate(f, "calendar.day", [day("2026-10-05")])
        // 周视图里上一／下一按周移动，同页面的周条。
        f.navigation.boardPages.calendarSpan = .week
        _ = try navigate(f, "calendar.step", [choice(.offset, "previous")])
        #expect(f.navigation.boardSelection.inspectingDayKey == "2026-09-28")
        _ = try navigate(f, "calendar.today")
        #expect(f.navigation.boardSelection.inspectingDayKey == "2026-10-20")
        let before = f.navigation.boardPages.calendarListRequest
        f.pages.requestCalendarDayList()
        #expect(f.navigation.boardPages.calendarListRequest == before + 1)
    }

    /// 页面不对：说明需要哪一页，不写状态也不切页。
    @Test(arguments: ["calendar.today", "quadrant.step", "gantt.currentMonth"])
    func wrongPageIsRejectedWithoutSwitching(command: String) throws {
        let f = try board(.today)
        let arguments = command == "quadrant.step" ? [choice(.offset, "next")] : []
        let page = String(command.prefix { $0 != "." })
        #expect(throws: CommandPageIssue.wrongPage(page)) { try navigate(f, command, arguments) }
        #expect(f.navigation.selectedTab == .today && f.navigation.boardSelection.inspectingDayKey == "2026-10-20")
        #expect(f.navigation.boardPages.ganttMonth == nil)
    }

    @Test func quadrantAndGanttNavigationWriteTheirOwnState() throws {
        let quadrant = try board(.quadrant)
        _ = try navigate(quadrant, "quadrant.step", [choice(.offset, "previous")])
        #expect(quadrant.navigation.boardSelection.inspectingDayKey == "2026-10-19")
        _ = try navigate(quadrant, "quadrant.day", [day("2026-11-02")])
        #expect(quadrant.navigation.boardSelection.inspectingDayKey == "2026-11-02")
        let gantt = try board(.gantt)
        _ = try navigate(gantt, "gantt.step", [choice(.offset, "next")])
        #expect(gantt.navigation.boardPages.ganttMonth == DayKey.shiftedMonth("2026-10-20", by: 1, calendar: .current))
        _ = try navigate(gantt, "gantt.currentMonth")
        #expect(gantt.navigation.boardPages.ganttMonth == "2026-10-20")
        // 安排页翻月不动日历／四象限的选中日。
        #expect(gantt.navigation.boardSelection.inspectingDayKey == "2026-10-20")
    }

    /// 检查器沿页面的 inspect：目标须在页面投影里；不在就拒绝，不换成别的行。
    @Test func inspectRequiresTheTargetInThePageProjection() throws {
        let f = try board(.quadrant)
        let target = CommandObjectReference(type: .todo, id: f.todo.id)
        #expect(throws: CommandPageIssue.notInList) { try navigate(f, "quadrant.inspect", inspecting: target) }
        f.navigation.updateInspectorTargets([f.todo.id])
        _ = try navigate(f, "quadrant.inspect", inspecting: target)
        #expect(f.navigation.selectedTaskID == f.todo.id)
        #expect(throws: CommandPageIssue.invalidTarget) {
            try navigate(f, "quadrant.inspect", inspecting: .init(type: .tag, id: f.tag.id))
        }
    }

    /// 月／周写宿主那一份；页面在预览后改了，旧预览失效，重新预览读到新值。
    @Test func calendarModeWritesHostSpanAndGoesStaleOnPageChange() throws {
        let f = try board(.calendar)
        let draft = f.draft("calendar.mode", [choice(.mode, "week")])
        let preview = try f.pages.prepare(draft)
        #expect(preview.page == .calendar && preview.before == .calendarSpan("month") && preview.after == .calendarSpan("week"))
        f.navigation.boardPages.calendarSpan = .week
        #expect(throws: CommandPageIssue.stale) { try f.pages.apply(preview, draft: draft) }
        f.navigation.boardPages.calendarSpan = .month
        #expect(try f.run(draft).after == .calendarSpan("week") && f.navigation.boardPages.calendarSpan == .week)
        let wrong = try board(.gantt)
        #expect(throws: CommandPageIssue.wrongPage("calendar")) { try wrong.pages.prepare(wrong.draft("calendar.mode", [choice(.mode, "week")])) }
    }

    /// 选择沿页面的 TaskSelection 规则与页面登记的色块顺序；不在当月清单里的目标拒绝。
    @Test func ganttSelectionFollowsThePageOrder() throws {
        let f = try board(.gantt)
        let ids = (0..<4).map { _ in UUID() }
        f.navigation.boardPages.ganttOrder = ids
        let refs = ids.map { CommandObjectReference(type: .todo, id: $0) }
        func select(_ mode: String, _ targets: [CommandObjectReference]) throws -> Set<UUID> {
            let draft = f.draft("gantt.select", targets: targets, [choice(.mode, mode)])
            let preview = try f.pages.prepare(draft)
            #expect(preview.revealsPage)
            return try f.pages.applySelection(preview).after == .selection(f.navigation.boardPages.ganttSelection.ids)
                ? f.navigation.boardPages.ganttSelection.ids : []
        }
        #expect(try select("single", [refs[1]]) == [ids[1]])
        #expect(try select("multiple", [refs[0], refs[3]]) == [ids[0], ids[3]])
        #expect(try select("range", [refs[3], refs[1]]) == Set(ids[1...3]))
        let outside = CommandObjectReference(type: .todo, id: UUID())
        let draft = f.draft("gantt.select", targets: [outside], [choice(.mode, "single")])
        #expect(throws: CommandPageIssue.notInList) { try f.pages.applySelection(f.pages.prepare(draft)) }
        #expect(throws: CommandPageIssue.invalidTarget) {
            try f.pages.prepare(f.draft("gantt.select", targets: [refs[0]], [choice(.mode, "range")]))
        }
    }

    /// 转交不绑页面、不写库：预览只给出目标指令与原样搬运的内容。
    @Test func transferPreviewNamesTheExistingCommand() throws {
        let f = try board(.today)
        let draft = f.draft("quadrant.complete", targets: [.init(type: .todo, id: f.todo.id)])
        let preview = try f.pages.prepare(draft)
        guard case .transfer(let transfer) = preview.before else { Issue.record("应为转交"); return }
        #expect(preview.page == nil && transfer.command.rawValue == "todo.completion")
        #expect(f.todo.isDone == false && f.context.hasChanges == false)
    }
}
