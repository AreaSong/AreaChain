import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

/// 合并批 M-2 A（原生）：真实工作台宿主里的看板指令。导航沿 N-M1 显示当前页、只写页面那一份状态；
/// 页面不对时说明且不切页；月／周与安排页选择走页面指令面板；修改指令转交给已有指令。
/// 0 标准英文浅色、1 标准英文深色、2 最小中文浅色、3 最小中文深色。
@Suite(.serialized) @MainActor struct UnifiedSearchBoardInteractionTests {
    private func fixture(_ page: WorkspaceTab) throws -> UnifiedSearchNavigationFixture {
        let f = try UnifiedSearchNavigationFixture()
        f.navigation.selectedTab = page
        f.navigation.boardSelection.inspectingDayKey = f.day
        let pages = WorkspacePageCommands(router: f.router, host: f.hostContext, context: f.context)
        pages.today = { [day = f.day] in day }
        f.controller.pageCommands = pages
        return f
    }

    private func begin(_ f: UnifiedSearchNavigationFixture, _ command: String) async throws {
        try #require(f.controller.beginOperation(.init(rawValue: command), source: f.controller.buffer) != nil)
        try await f.settle()
    }

    private func edit(_ f: UnifiedSearchNavigationFixture, _ argument: CommandArgument) async throws {
        let stamp = try #require(f.controller.operations?.active?.stamp)
        try #require(f.controller.sendOperation(.edit(stamp, argument), source: f.controller.buffer) != nil)
        try await f.settle()
    }

    private func target(_ f: UnifiedSearchNavigationFixture, _ objects: [CommandObjectReference]) async throws {
        let stamp = try #require(f.controller.operations?.active?.stamp)
        try #require(f.controller.sendOperation(.selectTargets(stamp, .init(objects.count == 1 ? .single : .selected, objects: objects),
                                                               baseline: nil), source: f.controller.buffer) != nil)
        try await f.settle()
    }

    /// 同 M-1：先把控件滚进操作面板，再用 AXPress 触发同一入口（工作台窗口里合成鼠标到不了操作面板，见 §9.96）。
    private func press(_ f: UnifiedSearchNavigationFixture, _ id: String) async throws {
        let window = try #require(f.window)
        let node = try #require(SettingsButtonTestSupport.elements(window.contentView).first {
            SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String == id
        }, "缺少 \(id)")
        let boundary = try #require(SettingsButtonTestSupport.elements(window.contentView)
            .compactMap { $0 as? UnifiedSearchOperationBoundary }.first)
        let scroll = try #require(SettingsButtonTestSupport.elements(window.contentView).compactMap { $0 as? NSScrollView }
            .first { $0.convert($0.bounds, to: nil) == boundary.convert(boundary.bounds, to: nil) })
        let document = try #require(scroll.documentView)
        let rect = try SettingsButtonTestSupport.frame(node, in: window)
        document.scrollToVisible(document.convert(rect.insetBy(dx: 0, dy: -60), from: nil))
        scroll.reflectScrolledClipView(scroll.contentView)
        try await f.settle()
        _ = node.perform(NSSelectorFromString("accessibilityPerformPress"))
        try await f.settle()
        await f.controller.navigationTask?.value
        try await f.settle()
    }

    private func exists(_ f: UnifiedSearchNavigationFixture, _ id: String) throws -> Bool {
        let window = try #require(f.window)
        return SettingsButtonTestSupport.elements(window.contentView).contains {
            SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String == id
        }
    }

    private static func choice(_ id: CommandParameterID, _ value: String) -> CommandArgument {
        .init(parameter: id, operation: .assign, value: .choice(value))
    }

    /// 上一／下一、回今天：显示的仍是日历页（不切页），选中日写在共享 BoardSelection。
    @Test(arguments: [0, 3]) func calendarNavigationShowsTheSamePage(style: Int) async throws {
        let f = try fixture(.calendar)
        defer { f.stop() }
        try await f.start(style: style)
        try await f.go("/calendar/step/next")
        #expect(f.navigation.selectedTab == .calendar && f.navigation.searchPresentation == false)
        #expect(f.navigation.boardSelection.inspectingDayKey == DayKey.shiftedMonth(f.day, by: 1, calendar: .current))
        #expect(f.controller.navigationMessage == "unified.board.done" && f.saves == 0)
        try await f.snapshot("m2-calendar-next-\(style)")
        try await f.back()
        try await f.go("/calendar/today")
        #expect(f.navigation.boardSelection.inspectingDayKey == f.day && f.navigation.selectedTab == .calendar)
    }

    /// 页面不对：说明需要哪一页，页面与搜索都不动，也不写状态。
    @Test(arguments: [1, 2]) func wrongPageIsExplainedWithoutSwitching(style: Int) async throws {
        let f = try fixture(.today)
        defer { f.stop() }
        try await f.start(style: style)
        try await f.go("/quadrant/step/next")
        #expect(f.controller.navigationMessage == "unified.board.wrongPage.quadrant")
        #expect(f.navigation.selectedTab == .today && f.navigation.searchPresentation == true)
        #expect(f.navigation.boardSelection.inspectingDayKey == f.day)
        try await f.snapshot("m2-board-wrong-page-\(style)")
    }

    /// 月／周：指令写宿主那一份，挂载中的日历页随之换成周条；页面切回月视图后旧预览失效。
    @Test(arguments: [0, 2]) func calendarModeDrivesTheMountedPage(style: Int) async throws {
        let f = try fixture(.calendar)
        defer { f.stop() }
        try await f.start(style: style)
        try await begin(f, "calendar.mode")
        try await edit(f, Self.choice(.mode, "week"))
        try await press(f, "unified.page.prepare")
        try await press(f, "unified.page.apply")
        #expect(f.navigation.boardPages.calendarSpan == .week && f.saves == 0)
        try await f.go("/go/calendar")
        #expect(try exists(f, "calendar.week.strip"))
        try await f.snapshot("m2-calendar-week-\(style)")
    }

    /// 选择沿 N-M1：先显示安排页，再按页面登记的色块顺序选择；检查器沿页面的 inspect。
    @Test func ganttSelectionAndInspectUseThePageProjection() async throws {
        let f = try fixture(.gantt)
        defer { f.stop() }
        try await f.start(style: 0)
        try await f.go("/gantt/current-month")
        #expect(f.navigation.boardPages.ganttMonth == f.day && f.navigation.boardPages.ganttOrder.contains(f.todo.id))
        try await f.back()
        try await begin(f, "gantt.select")
        try await target(f, [.init(type: .todo, id: f.todo.id)])
        try await edit(f, Self.choice(.mode, "single"))
        try await press(f, "unified.page.prepare")
        try await press(f, "unified.page.apply")
        #expect(f.navigation.selectedTab == .gantt && f.navigation.boardPages.ganttSelection.ids == [f.todo.id])
        #expect(f.controller.navigationMessage == "unified.page.selected" && f.saves == 0)
        try await f.snapshot("m2-gantt-selected")
    }

    @Test func quadrantInspectOpensTheFocusedResult() async throws {
        let f = try fixture(.quadrant)
        defer { f.stop() }
        try await f.start(style: 1)
        let page = try f.session.presentation().pagination
        let object = CommandObjectReference(type: .todo, id: f.todo.id)
        try #require(page.snapshot.visible.contains(object))
        f.controller.browse(.init(version: page.snapshot.version, action: .activate(object)), source: f.controller.buffer)
        try await f.go("/quadrant/inspect")
        #expect(f.navigation.selectedTab == .quadrant && f.navigation.selectedTaskID == f.todo.id)
        #expect(f.controller.navigationMessage == "unified.board.done" && f.saves == 0)
    }

    /// 转交：四象限完成换成 todo.completion 的草稿（同一目标、完成），看板草稿不再保留；不写库。
    @Test(arguments: [0, 3]) func quadrantCompleteTransfersToTodoCompletion(style: Int) async throws {
        let f = try fixture(.quadrant)
        defer { f.stop() }
        try await f.start(style: style)
        try await begin(f, "quadrant.complete")
        try await target(f, [.init(type: .todo, id: f.todo.id)])
        try await press(f, "unified.page.prepare")
        #expect(f.controller.pageFailure == nil && f.controller.currentPagePreview != nil)
        try await f.snapshot("m2-quadrant-transfer-\(style)")
        try await press(f, "unified.page.apply")
        #expect(f.controller.pageFailure == nil)
        let active = try #require(f.controller.operations?.active)
        #expect(active.commandID.rawValue == "todo.completion" && active.targets.objects == [.init(type: .todo, id: f.todo.id)])
        #expect(active.arguments == [.init(parameter: .enabled, operation: .assign, value: .boolean(true))])
        #expect(f.controller.operations?.retained.isEmpty == true && f.todo.isDone == false && f.saves == 0)
    }
}
