import AppKit
import SwiftData
import Testing
@testable import AreaChain

/// 合并批 M-3 A：对照表每一项“预览说明正确、回车只导航、没有写入、没有系统调用”；返回票据可回到搜索。
@Suite(.serialized) @MainActor struct UnifiedSearchOriginalPageTests {
    @Test func everyPageRouteOnlyNavigatesAndReturns() async throws {
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        try await fixture.start()
        let original = try fixture.handoff.state().query
        let routes = CommandOriginalPage.all.filter { if case .page = $0.destination { true } else { false } }
        #expect(routes.count >= 70)
        for route in routes {
            let command = try #require(CommandCatalog.standard.command(id: route.command))
            guard case .page(let raw, _) = route.destination, let tab = WorkspaceTab(rawValue: raw) else {
                Issue.record("目标页不存在：\(route.command.rawValue)"); continue
            }
            try await ready(fixture)
            try await fixture.enter(command.path)
            #expect(fixture.controller.isNavigationInput, "\(command.id.rawValue) 应走导航面板")
            try expectPanel(fixture, route: route)
            fixture.controller.intent(.open, source: fixture.controller.buffer)
            await fixture.controller.navigationTask?.value
            try await fixture.settle()
            #expect(fixture.router.outcome == .displayed, "\(command.id.rawValue)")
            #expect(fixture.router.mounted("page." + tab.rawValue), "\(command.id.rawValue) → \(tab.rawValue)")
            #expect(fixture.controller.navigationMessage == "unified.originalPage.displayed")
            #expect(try fixture.handoff.state().operations.active == nil, "\(command.id.rawValue) 不能建草稿")
            #expect(try fixture.handoff.state().plan.items.isEmpty)
            #expect(try fixture.handoff.state().execution == nil)
            #expect(!fixture.context.hasChanges)
            try await fixture.back()
            try await ready(fixture)
            #expect(fixture.navigation.isSearching, "\(command.id.rawValue) 返回搜索")
            #expect(try fixture.handoff.state().query == original)
        }
        #expect(fixture.saves == 0 && fixture.publications == 0)
        #expect(try fixture.context.fetchCount(FetchDescriptor<TagItem>()) == 0)
        #expect(try fixture.context.fetchCount(FetchDescriptor<RoutineCheck>()) == 0)
    }

    @Test func objectRoutesUseInspectorResolutionAndRefuseWithoutDay() async throws {
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        try await fixture.start()
        let todo = CommandObjectReference(type: .todo, id: fixture.todo.id)
        try await activate(fixture, todo)
        try await fixture.enter("/images/add")
        try expectPanel(fixture, route: try #require(CommandOriginalPage.route(for: .init(rawValue: "image.pick"))))
        fixture.controller.intent(.open, source: fixture.controller.buffer)
        await fixture.controller.navigationTask?.value
        try await fixture.settle()
        #expect(fixture.router.outcome == .displayed)
        #expect(fixture.navigation.selectedTaskID == fixture.todo.id)
        #expect(fixture.controller.navigationMessage == "unified.originalPage.displayed")
        try await fixture.back()
        // notification.open 本身就是导航，回执不说“请在这一页完成”。
        try await activate(fixture, todo)
        try await fixture.go("/notification/open")
        #expect(fixture.navigation.selectedTaskID == fixture.todo.id)
        #expect(fixture.controller.navigationMessage == "unified.navigation.displayed")
        try await fixture.back()
        // 子任务不在 image.pick 的目标类型里；重复事项定义没有执行日。
        try await activate(fixture, .init(type: .subtask, id: fixture.child.id))
        try await fixture.go("/images/add")
        #expect(fixture.controller.navigationMessage == "unified.navigation.unsupported")
        try await fixture.enter("needle")
        try await ready(fixture)
        let routine = try fixture.session.presentation().pagination.snapshot.visible.first { $0.type == .routine }
        if let routine {
            try await activate(fixture, routine)
            try await fixture.go("/images/capture")
            #expect(fixture.controller.navigationMessage == "unified.originalPage.needsDay")
        }
        #expect(fixture.saves == 0 && fixture.publications == 0 && !fixture.context.hasChanges)
        #expect(try fixture.handoff.state().operations.active == nil)
    }

    @Test func trashRoutesLocateFocusedObject() async throws {
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        try await fixture.start()
        let todo = CommandObjectReference(type: .todo, id: fixture.todo.id)
        try await activate(fixture, todo)
        try await fixture.go("/trash/delete")
        #expect(fixture.router.mounted("page.trash"))
        #expect(fixture.navigation.focusedTrashID == fixture.todo.id)
        #expect(fixture.todo.deletedAt == nil && fixture.saves == 0)
    }

    @Test func helpAndUseInsteadStayInPanel() async throws {
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        try await fixture.start()
        try await fixture.go("/help/page")
        #expect(fixture.controller.navigationMessage == "unified.help.page.none")
        #expect(fixture.controller.returnSearch == nil, "帮助不导航")
        try await fixture.go("/help/syntax")
        #expect(fixture.controller.helpCardPresented)
        fixture.controller.helpCardPresented = false
        try await fixture.go("/help/example")
        #expect(fixture.controller.helpCardPresented)
        #expect(fixture.controller.navigationMessage == "unified.help.example.choose")
        fixture.controller.prefillExample("tomorrow 9:00 meet #work")
        #expect(fixture.controller.buffer.text == "tomorrow 9:00 meet #work")
        #expect(fixture.controller.navigationMessage == "unified.help.example.prefilled")
        #expect(try fixture.handoff.state().operations.active == nil)
        try await fixture.settle()
        try await fixture.enter("/notification/complete")
        // 工作台操作面板的合成鼠标事件到不了按钮（§9.96 已知），沿 M-1 用 AXPress 按同一按钮。
        try await press(fixture, "unified.originalPage.use.todo.completion")
        #expect(fixture.controller.buffer.text == CommandCatalog.standard.command(id: .init(rawValue: "todo.completion"))?.path)
        try await fixture.go("/notification/snooze")
        #expect(fixture.controller.navigationMessage == "unified.originalPage.useInstead.choose")
        #expect(fixture.saves == 0 && fixture.publications == 0)
        #expect(try fixture.handoff.state().operations.active == nil)
    }

    @Test func unassembledAndLockedExplainWithoutActing() async throws {
        let results = try UnifiedSearchResultsFixture()
        defer { results.stop() }
        for path in ["/tags/delete", "/backup/restore", "/images/add"] {
            _ = results.controller.navigationInput(path)
            results.controller.executeNavigation(source: results.controller.buffer)
            #expect(results.controller.navigationMessage == "unified.navigation.unassembled")
            #expect(try results.handoff.state().operations.active == nil)
        }
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        try await fixture.start()
        // 锁定撤销结果展示：焦点项不可用，只说明原因，不导航、不写入。
        fixture.vault.lock()
        try await fixture.settle()
        _ = fixture.controller.navigationInput("/images/add")
        fixture.controller.executeNavigation(source: fixture.controller.buffer)
        #expect(fixture.controller.navigationMessage == "unified.originalPage.needsUnlock"
            || fixture.controller.navigationMessage == "unified.navigation.chooseObject")
        #expect(fixture.controller.returnSearch == nil && fixture.saves == 0)
    }

    /// 返回搜索后原结果可能按版本重读；等它发布完再继续下一条，避免拿旧许可。
    private func ready(_ fixture: UnifiedSearchNavigationFixture) async throws {
        for _ in 0..<100 {
            if fixture.controller.navigationTask == nil, fixture.controller.returnSearch == nil,
               (try? fixture.session.presentation()) != nil { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        try await fixture.settle()
        try await fixture.settle()
    }

    private func activate(_ fixture: UnifiedSearchNavigationFixture, _ object: CommandObjectReference) async throws {
        try await ready(fixture)
        let page = try fixture.session.presentation().pagination
        try #require(page.snapshot.visible.contains(object))
        fixture.controller.browse(.init(version: page.snapshot.version, action: .activate(object)), source: fixture.controller.buffer)
    }

    private func press(_ fixture: UnifiedSearchNavigationFixture, _ id: String) async throws {
        let node = try #require(SettingsButtonTestSupport.elements(fixture.window?.contentView).first {
            SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String == id
        })
        _ = node.perform(NSSelectorFromString("accessibilityPerformPress"))
        try await fixture.settle()
    }

    private func expectPanel(_ fixture: UnifiedSearchNavigationFixture, route: CommandOriginalPage) throws {
        let nodes = SettingsButtonTestSupport.elements(fixture.window?.contentView)
        let ids = Set(nodes.compactMap { SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String })
        #expect(ids.contains("unified.originalPage"), "\(route.command.rawValue) 预览")
        let note = L10n.string(.init(stringLiteral: route.noteKey), locale: Locale(identifier: "en"))
        let texts = nodes.filter {
            SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String == "unified.originalPage.note"
        }.flatMap { node in
            ["accessibilityLabel", "accessibilityValue", "accessibilityTitle"].compactMap {
                SettingsButtonTestSupport.value(node, $0) as? String
            }
        }
        #expect(texts.contains { $0.contains(note) }, "\(route.command.rawValue) 说明文案：\(texts)")
        if route.sectionKey != nil { #expect(ids.contains("unified.originalPage.section")) }
    }
}
