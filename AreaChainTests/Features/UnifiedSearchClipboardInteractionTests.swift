import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

/// 原生：工作台宿主里的剪贴板指令。搜索结果与原生历史浏览（同一会话的 visibleItems）逐行一致；
/// 复制写私有命名剪贴板、粘贴只到 fake；小窗打开两次只有一个窗口。0 标准英文浅色、3 最小中文深色。
@Suite(.serialized) @MainActor struct UnifiedSearchClipboardInteractionTests {
    private func fixture(_ clipboard: ClipboardCommandFixture) throws -> UnifiedSearchNavigationFixture {
        let f = try UnifiedSearchNavigationFixture(clipboard: clipboard.session)
        f.assemblePages(.clipboard).clipboard = clipboard.actions
        return f
    }

    /// C1 等价：同一查询与模式下，指令面板列出的结果与历史页（ClipboardHistoryBrowser 渲染的 visibleItems）逐行相同。
    @Test(arguments: [0, 3]) func searchMatchesTheNativeHistoryBrowser(style: Int) async throws {
        let clipboard = try ClipboardCommandFixture()
        let f = try fixture(clipboard)
        defer { f.stop() }
        try await f.start(style: style)
        try await f.go("/go/clipboard")
        clipboard.session.query = "alpha"
        clipboard.session.searchMode = .mixed
        try await f.settle()
        try await f.snapshot("m2-clipboard-page-\(style)")
        let page = clipboard.session.visibleItems.map(WorkspacePageCommands.line)
        try await f.back()
        try await f.begin("clipboard.search")
        try await f.edit(.init(parameter: .query, operation: .assign, value: .shortText("alpha")))
        try await f.edit(.init(parameter: .mode, operation: .assign, value: .choice("mixed")))
        try await f.press("unified.page.prepare")
        try await f.press("unified.page.apply")
        #expect(f.controller.pageReceipt?.after == .results(page, total: page.count) && page.count == 2)
        #expect(try f.label("unified.page.status").contains(page[0]))
        try await f.snapshot("m2-clipboard-search-\(style)")
    }

    @Test func copyAndPasteStayIsolated() async throws {
        let clipboard = try ClipboardCommandFixture()
        let f = try fixture(clipboard)
        defer { f.stop() }
        let general = NSPasteboard.general.changeCount
        try await f.start(style: 1)
        try await f.begin("clipboard.pastePlain")
        try await f.target([.init(type: .clipboardEntry, id: clipboard.records[0].id)])
        try await f.press("unified.page.prepare")
        try await f.press("unified.page.apply")
        #expect(f.controller.pageReceipt?.after == .clipboardResult("needsAccessibility"))
        #expect(clipboard.written() == "第一条 alpha" && clipboard.probe.prompts == 1 && clipboard.probe.keystrokes == 0)
        #expect(NSPasteboard.general.changeCount == general)
        try await f.snapshot("m2-clipboard-paste")
    }

    /// 小窗沿现有窗口管理（真实 ClipboardHistoryPanel）：打开两次仍只有这一个窗口，关闭后隐藏。
    @Test func windowCommandsKeepASinglePanel() async throws {
        let clipboard = try ClipboardCommandFixture()
        let f = try fixture(clipboard)
        defer { f.stop(); ClipboardHistoryPanel.shared.closeReturning() }
        var actions = clipboard.actions
        actions.window = ClipboardHistoryPanel.shared.window
        f.controller.pageCommands?.clipboard = actions
        try await f.start(style: 2)
        try await f.go("/window/clipboard/open")
        try await f.go("/window/clipboard/open")
        let panels = NSApp.windows.filter { $0 === ClipboardHistoryPanel.shared.hostedWindow }
        #expect(panels.count == 1 && panels.first?.isVisible == true)
        #expect(f.controller.navigationMessage == "unified.clipboard.window.opened")
        try await f.go("/window/clipboard/close")
        #expect(ClipboardHistoryPanel.shared.hostedWindow?.isVisible == false)
        #expect(f.controller.navigationMessage == "unified.clipboard.window.closed")
        #expect(NSApp.windows.filter { $0 === ClipboardHistoryPanel.shared.hostedWindow }.count == 1)
    }
}
