import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

/// 菜单栏筛选重新缩小统一搜索结果，底栏胶囊可单个移除；筛选只有 BoardFilterSession 一份，
/// 工作台宿主不受影响。只用内存库与合成任务。
@Suite(.serialized) @MainActor
struct MenuBarSearchFilterTests {
    @Test func filterNarrowsMenubarResultsAndIntersectsWithQueryButNotWorkspace() async throws {
        let data = try FilterSearchData()
        defer { data.fixture.cleanup() }
        let assembly = try data.fixture.assembly()
        defer { assembly.discard() }
        let menubar = try #require(assembly.menubar)
        let workspace = try #require(assembly.workspace)
        let filtersBefore = assembly.services.filters.filters
        Self.type(menubar, "needle")
        Self.type(workspace, "needle")
        #expect(try await Self.visible(menubar, equals: [data.alpha.id, data.beta.id]))
        #expect(try await Self.visible(workspace, equals: [data.alpha.id, data.beta.id]))

        menubar.refreshTodayPageFilter(BoardFilter(tagID: data.tagA.id))
        // 交集：查询排除了 other alpha，筛选排除了 needle beta。
        #expect(try await Self.visible(menubar, equals: [data.alpha.id]))
        #expect(try assembly.coordinator.host(UnifiedSearchProductionAssembly.menubarHost).session.query.page.page
                == .today(BoardFilter(tagID: data.tagA.id)))
        workspace.refresh()
        #expect(try await Self.visible(workspace, equals: [data.alpha.id, data.beta.id]), "工作台宿主不受菜单栏筛选影响")

        menubar.refreshTodayPageFilter(BoardFilter())
        #expect(try await Self.visible(menubar, equals: [data.alpha.id, data.beta.id]))
        #expect(menubar.buffer.text == "needle")
        // 派生只读筛选，不回写、不另存：装配持有的筛选会话保持原值。
        #expect(assembly.services.filters.filters == filtersBefore)
        #expect(data.fixture.saves == 0)
    }

    /// 底栏胶囊：设筛选后显示并缩小结果；点胶囊上的移除只改这一项筛选，结果随之恢复。
    @Test func footerTokenShowsActiveFilterAndRemovingItRestoresResults() async throws {
        let data = try FilterSearchData()
        let search = try MenuBarUnifiedSearchProbe(container: data.fixture.container)
        defer { search.stop() }
        let session = BoardFilterSession()
        session.filters.tasks = BoardFilter(tagID: data.tagA.id, priorityScope: .p1)
        // 与其他原生宿主相同：打开增强辅助界面，SwiftUI 才完整暴露胶囊内按钮的可访问性节点；结束时恢复。
        let enhanced = NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface")
        let previous = NSApp.accessibilityAttributeValue(enhanced)
        NSApp.accessibilitySetValue(true, forAttribute: enhanced)
        defer { NSApp.accessibilitySetValue(previous ?? false, forAttribute: enhanced) }
        let window = Self.host(MenuBarPopoverView(toolbar: MenuBarToolbarState(), composer: BoardComposerSession(),
                                                  filterSession: session, production: search.production),
                               data: data)
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let controller = try search.controller
        try await search.type("needle")
        // p1 与标签 A 同时生效：needle alpha 是 p1，needle beta 不是。
        #expect(try await Self.visible(controller, equals: [data.alpha.id]))
        Self.snapshot(window, "m7f-menubar-filter-tokens")
        #expect(Self.node("menubar.filter.token.remove.tag", in: window) != nil)
        #expect(Self.node("menubar.filter.token.remove.priority", in: window) != nil)

        try await Self.click("menubar.filter.token.remove.priority", in: window)
        #expect(session.filters.tasks == BoardFilter(tagID: data.tagA.id), "只移除被点的那一项")
        #expect(try await Self.visible(controller, equals: [data.alpha.id]))
        try await Self.click("menubar.filter.token.remove.tag", in: window)
        #expect(session.filters.tasks == BoardFilter())
        #expect(try await Self.visible(controller, equals: [data.alpha.id, data.beta.id]))
        #expect(Self.node("menubar.filter.token.remove.tag", in: window) == nil, "无筛选时不显示胶囊")
    }

    // MARK: - 辅助

    private static func type(_ controller: UnifiedSearchController, _ text: String) {
        _ = controller.edit(.init(source: controller.buffer, text: text, selection: NSRange(location: text.utf16.count, length: 0)))
    }

    /// 等到结果里的任务集合等于期望（最多约 4 秒）；返回最后一次是否相等。
    private static func visible(_ controller: UnifiedSearchController, equals ids: Set<UUID>) async throws -> Bool {
        var current: Set<UUID> = []
        for _ in 0..<200 {
            if let page = try? controller.session.presentation().pagination {
                current = Set(page.snapshot.visible.filter { $0.type == .todo }.map(\.id))
                if current == ids { return true }
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        Issue.record("结果任务 \(current.count) 条，期望 \(ids.count) 条")
        return false
    }

    /// 截图只写测试进程临时目录，供人工查看胶囊位置；不作为通过依据。
    private static func snapshot(_ window: NSWindow, _ name: String) {
        guard let view = window.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let directory = FileManager.default.temporaryDirectory.appending(path: "AreaChain-M7F-QA")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? bitmap.representation(using: .png, properties: [:])?.write(to: directory.appending(path: name + ".png"))
    }

    private static func node(_ identifier: String, in window: NSWindow) -> NSObject? {
        SettingsButtonTestSupport.elements(window.contentView).first {
            SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String == identifier
        }
    }

    private static func click(_ identifier: String, in window: NSWindow) async throws {
        let target = try #require(Self.node(identifier, in: window))
        try await SettingsButtonTestSupport.click(target, in: window)
        try await SystemPageHost.settle(window)
    }

    private static func host(_ root: MenuBarPopoverView, data: FilterSearchData) -> NSWindow {
        let content = root
            .modelContainer(data.fixture.container)
            .environment(data.fixture.preferences)
            .environment(\.locale, Locale(identifier: "zh-Hans"))
            .transaction { $0.disablesAnimations = true }
        let hosting = NSHostingView(rootView: content)
        hosting.safeAreaRegions = []
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: DaybookMetrics.Window.popoverSize),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.setContentSize(DaybookMetrics.Window.popoverSize)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        return window
    }
}

/// 今日三条合成任务：needle alpha（标签 A、p1）、needle beta（标签 B）、other alpha（标签 A）。
@MainActor
private final class FilterSearchData {
    let fixture: UnifiedSearchProductionFixture
    let tagA = TagItem(name: "SyntheticA", sortOrder: 0)
    let tagB = TagItem(name: "SyntheticB", sortOrder: 1)
    let alpha: TodoItem
    let beta: TodoItem

    init() throws {
        fixture = try UnifiedSearchProductionFixture()
        let today = UnifiedSearchProductionFixture.today
        alpha = TodoItem(title: "needle alpha", dayKey: today)
        alpha.tagIDs = TagIDList.encode([tagA.id])
        alpha.isImportant = true
        alpha.isUrgent = true
        beta = TodoItem(title: "needle beta", dayKey: today)
        beta.tagIDs = TagIDList.encode([tagB.id])
        let other = TodoItem(title: "other alpha", dayKey: today)
        other.tagIDs = TagIDList.encode([tagA.id])
        for model in [tagA, tagB] { try fixture.insert(model) }
        for model in [alpha, beta, other] { try fixture.insert(model) }
        fixture.saves = 0
    }
}
