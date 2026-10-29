import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

/// 原生：真实工作台宿主里的页面指令面板。筛选双向同步、选择经导航显示当前页后按页面投影、
/// 页面不对时说明且不切页、取消与连击查询。0 标准英文浅色、1 标准英文深色、2 最小中文浅色、3 最小中文深色。
@Suite(.serialized, .tags(.backgroundWindow)) @MainActor struct UnifiedSearchPageCommandInteractionTests {
    private func fixture(_ page: WorkspaceTab) throws -> UnifiedSearchNavigationFixture {
        let f = try UnifiedSearchNavigationFixture()
        f.navigation.selectedTab = page
        f.controller.pageCommands = WorkspacePageCommands(router: f.router, host: f.hostContext, context: f.context)
        return f
    }

    private func locale(_ style: Int) -> Locale { Locale(identifier: style < 2 ? "en" : "zh-Hans") }

    private func begin(_ f: UnifiedSearchNavigationFixture, _ command: String) async throws {
        try #require(f.controller.beginOperation(.init(rawValue: command), source: f.controller.buffer) != nil)
        try await f.settle()
    }

    /// 与参数字段确认后发出的编辑事件相同。
    private func edit(_ f: UnifiedSearchNavigationFixture, _ argument: CommandArgument) async throws {
        let stamp = try #require(f.controller.operations?.active?.stamp)
        try #require(f.controller.sendOperation(.edit(stamp, argument), source: f.controller.buffer) != nil)
        try await f.settle()
    }

    /// 与对象选择器接受时发出的目标事件相同。
    private func target(_ f: UnifiedSearchNavigationFixture, _ object: CommandObjectReference) async throws {
        let stamp = try #require(f.controller.operations?.active?.stamp)
        try #require(f.controller.sendOperation(.selectTargets(stamp, .init(.single, objects: [object]), baseline: nil),
                                                source: f.controller.buffer) != nil)
        try await f.settle()
    }

    /// 先把控件滚进操作面板（离开渐隐边缘），再用辅助功能按下（AXPress，同键盘／VoiceOver 激活）。
    /// 工作台窗口里合成鼠标事件到不了操作面板按钮（缓冲版本与输入焦点都不变，原因未判定），
    /// 因此不用鼠标；按钮仍按渲染时的原身份调用同一入口。
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
        try #require(boundary.convert(boundary.bounds, to: nil).contains(try SettingsButtonTestSupport.frame(node, in: window)),
                     "控件 \(id) 须位于操作面板内")
        _ = node.perform(NSSelectorFromString("accessibilityPerformPress"))
        try await f.settle()
    }

    private func label(_ f: UnifiedSearchNavigationFixture, _ id: String) throws -> String {
        let window = try #require(f.window)
        let node = try #require(SettingsButtonTestSupport.elements(window.contentView).first {
            SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String == id
        }, "缺少 \(id)")
        let parts = ["accessibilityLabel", "accessibilityValue"].compactMap { SettingsButtonTestSupport.value(node, $0) as? String }
        return parts.joined(separator: " ")
    }

    private static func choice(_ id: CommandParameterID, _ value: String) -> CommandArgument {
        .init(parameter: id, operation: .assign, value: .choice(value))
    }

    /// 指令改 → 页面那一份筛选跟着变；页面改 → 旧预览失效，重新预览读到页面的新条件。
    @Test(arguments: [0, 3]) func filterCommandAndPageStayInSync(style: Int) async throws {
        let f = try fixture(.today)
        defer { f.stop() }
        try await f.start(style: style)
        try await begin(f, "tasks.filter")
        try await edit(f, Self.choice(.priority, "p1"))
        try await press(f, "unified.page.prepare")
        #expect(try label(f, "unified.page.before").contains(L10n.string("unified.page.filter.none", locale: locale(style))))
        try await press(f, "unified.page.apply")
        let applied = BoardFilter().withPriorityScope(.p1)
        #expect(f.hostContext.filters.filters.tasks == applied && f.saves == 0)
        #expect(try label(f, "unified.page.status").contains(applied.priorityTitle(locale: locale(style))))
        try await f.snapshot("m1-page-filter-applied-\(style)")
        // 回到今日页（同一页，不切换），像用户在页面上那样改筛选。
        try await f.go("/go/today")
        #expect(f.navigation.selectedTab == .today && f.navigation.searchPresentation == false)
        var next = f.hostContext.filters.filters
        next.write(applied.withDateScope(.overdue), for: .tasks)
        f.hostContext.filters.filters = next
        try await f.settle()
        try await f.back()
        #expect(f.controller.currentPagePreview == nil)
        try await press(f, "unified.page.prepare")
        let before = try label(f, "unified.page.before")
        #expect(before.contains(DateFilterScope.overdue.title(locale: locale(style))))
        #expect(before.contains(applied.priorityTitle(locale: locale(style))))
        try await f.snapshot("m1-page-filter-page-changed-\(style)")
    }

    /// 选择类经导航：先显示当前页（不切页），再按页面登记的投影全选。
    @Test func selectAllRevealsTheCurrentPageAndUsesItsList() async throws {
        let f = try fixture(.allItems)
        defer { f.stop() }
        try await f.start(style: 0)
        try await begin(f, "selection.all")
        try await press(f, "unified.page.prepare")
        try await press(f, "unified.page.apply")
        await f.controller.navigationTask?.value
        try await f.settle()
        #expect(f.navigation.selectedTab == .allItems && f.navigation.searchPresentation == false)
        #expect(!f.navigation.selectedTaskIDs.isEmpty && f.navigation.selectedTaskIDs == f.navigation.inspectorTargetIDs)
        #expect(f.navigation.selectedTaskIDs.contains(f.todo.id) && f.controller.navigationMessage == "unified.page.selected")
        #expect(f.saves == 0)
        try await f.snapshot("m1-page-select-all")
    }

    /// 页面不对时说明需要哪一页，页面与搜索都不动。
    @Test(arguments: [1, 2]) func wrongPageIsExplainedWithoutSwitching(style: Int) async throws {
        let f = try fixture(.dashboard)
        defer { f.stop() }
        try await f.start(style: style)
        try await begin(f, "tasks.kind")
        try await edit(f, Self.choice(.kind, "recurring"))
        try await press(f, "unified.page.prepare")
        let expected = UnifiedSearchPageCopy.message(.wrongPage("allItems"), locale: locale(style))
        #expect(try label(f, "unified.page.issue") == expected)
        #expect(f.navigation.selectedTab == .dashboard && f.navigation.searchPresentation == true)
        #expect(f.navigation.allItemsQuery.kind == .all)
        try await f.snapshot("m1-page-wrong-page-\(style)")
    }

    /// 取消标题编辑等同标题编辑器的 Esc：去掉保留的草稿，标题不变、不写库。
    @Test(arguments: [0, 2]) func cancelTitleDiscardsTheRetainedDraft(style: Int) async throws {
        let f = try fixture(.today)
        defer { f.stop() }
        f.drafts.titles[EditDrafts.key(todo: f.todo.id)] = "改到一半"
        try await f.start(style: style)
        try await begin(f, "todo.cancelTitle")
        try await target(f, .init(type: .todo, id: f.todo.id))
        try await press(f, "unified.page.prepare")
        #expect(try label(f, "unified.page.before").contains(L10n.string("unified.page.titleDraft.on", locale: locale(style))))
        try await press(f, "unified.page.apply")
        #expect(f.drafts.titles.isEmpty && f.todo.title == "needle parent" && f.saves == 0)
        #expect(try label(f, "unified.page.status").contains(L10n.string("unified.page.titleDraft.off", locale: locale(style))))
        try await f.snapshot("m1-page-cancel-title-\(style)")
    }

    /// 连击查询沿 HabitStreakLogic，不需要页面，也不写库。
    @Test(arguments: [1, 3]) func streakQueryReusesHabitStreakLogic(style: Int) async throws {
        let f = try fixture(.dashboard)
        defer { f.stop() }
        try await f.start(style: style)
        try await begin(f, "routine.streak")
        try await target(f, .init(type: .routine, id: f.routine.id))
        try await edit(f, Self.choice(.kind, "current"))
        try await edit(f, .init(parameter: .day, operation: .assign, value: .day(f.day)))
        try await press(f, "unified.page.prepare")
        let streak = HabitStreakLogic.calculate(routine: f.routine.snapshot, checks: f.routine.checks.compactMap(\.snapshot),
                                                todayKey: f.day)
        let before = try label(f, "unified.page.before")
        #expect(before.contains(L10n.format("unified.page.streak.current", locale: locale(style), streak.currentStreak)))
        #expect(before.contains(L10n.format("unified.page.streak.best", locale: locale(style), streak.bestStreak)))
        #expect(try label(f, "unified.page.target") == L10n.string("unified.page.targetWorkspace", locale: locale(style)))
        #expect(f.saves == 0 && f.publications == 0 && f.navigation.selectedTab == .dashboard)
        try await f.snapshot("m1-page-streak-\(style)")
    }
}
