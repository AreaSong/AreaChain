import AppKit
import Foundation
import Testing
@testable import AreaChain

/// 服务层：剪贴板浏览与搜索与历史页同一取法；复制写入失败不报成功；粘贴在隔离环境只到 fake；
/// 置顶沿会话原有入口且保存成功才报告；小窗指令不新建第二个窗口；默认未装配。
@Suite(.serialized) @MainActor struct ClipboardPageCommandTests {
    typealias Fixture = WorkspacePageCommandTests.Fixture

    private func assembled(_ clipboard: ClipboardCommandFixture) throws -> Fixture {
        let f = try Fixture(page: .dashboard)
        f.pages.clipboard = clipboard.actions
        return f
    }
    private func entry(_ record: ClipboardHistoryRecord) -> CommandObjectReference { .init(type: .clipboardEntry, id: record.id) }
    private func run(_ f: Fixture, _ command: String, targets: [CommandObjectReference] = [],
                     _ arguments: [CommandArgument] = []) throws -> WorkspacePageSnapshot {
        try f.run(f.draft(command, targets: targets, arguments)).after
    }

    /// 与原生历史浏览同一取法（ClipboardHistoryRules.filtered：置顶在前、模式可见）；默认不进普通搜索的规则不变。
    @Test func browseAndSearchMatchTheHistoryBrowser() throws {
        let clipboard = try ClipboardCommandFixture()
        let f = try assembled(clipboard)
        let lines = { (records: [ClipboardHistoryRecord]) in records.map(WorkspacePageCommands.line) }
        let all = ClipboardHistoryRules.filtered(clipboard.session.items, query: "", mode: .mixed)
        #expect(try run(f, "clipboard.browse") == .results(lines(all), total: 3))
        #expect(lines(all).first == "[b] 第二条 beta")
        clipboard.session.query = "alpha"
        clipboard.session.searchMode = .exact
        let exact = CommandArgument(parameter: .mode, operation: .assign, value: .choice("exact"))
        let query = CommandArgument(parameter: .query, operation: .assign, value: .shortText("alpha"))
        #expect(try run(f, "clipboard.search", [query, exact]) == .results(lines(clipboard.session.visibleItems), total: 1))
        let mixed = CommandArgument(parameter: .mode, operation: .assign, value: .choice("mixed"))
        #expect(try run(f, "clipboard.search", [query, mixed]) == .results(lines(ClipboardHistoryRules.filtered(clipboard.session.items,
                                                                                                                   query: "alpha", mode: .mixed)), total: 2))
        let invalid = CommandArgument(parameter: .query, operation: .assign, value: .shortText("(["))
        let regex = CommandArgument(parameter: .mode, operation: .assign, value: .choice("regex"))
        #expect(throws: CommandPageIssue.invalidArguments) { try f.pages.prepare(f.draft("clipboard.search", [invalid, regex])) }
    }

    @Test func copyWritesThroughTheHistoryPathAndFailureIsNotSuccess() throws {
        let clipboard = try ClipboardCommandFixture()
        let f = try assembled(clipboard)
        #expect(try run(f, "clipboard.copy", targets: [entry(clipboard.records[0])]) == .clipboardResult("copied"))
        #expect(clipboard.written() == "第一条 alpha" && clipboard.probe.keystrokes == 0)
        // 写剪贴板失败（stage 没写成）：报写入失败，不报“已复制”，也不发粘贴按键。
        var failing = clipboard.actions
        failing.stage = { _, _ in .empty }
        f.pages.clipboard = failing
        clipboard.probe.trusted = true
        #expect(throws: CommandPageIssue.copyFailed) { try f.run(f.draft("clipboard.copy", targets: [entry(clipboard.records[2])])) }
        #expect(throws: CommandPageIssue.copyFailed) { try f.run(f.draft("clipboard.paste", targets: [entry(clipboard.records[2])])) }
        #expect(clipboard.written() == "第一条 alpha" && clipboard.probe.keystrokes == 0)
    }

    /// 粘贴只到 fake：没有权限时请求一次（fake）、已复制但不发按键；有权限时发按键（fake 计数），不碰真实辅助功能。
    @Test func pasteOnlyReachesTheFakeGate() throws {
        let clipboard = try ClipboardCommandFixture()
        let f = try assembled(clipboard)
        #expect(try run(f, "clipboard.paste", targets: [entry(clipboard.records[0])]) == .clipboardResult("needsAccessibility"))
        #expect(clipboard.probe.prompts == 1 && clipboard.probe.keystrokes == 0 && clipboard.written() == "第一条 alpha")
        clipboard.probe.trusted = true
        #expect(try run(f, "clipboard.pastePlain", targets: [entry(clipboard.records[2])]) == .clipboardResult("pasted"))
        #expect(clipboard.probe.keystrokes == 1 && clipboard.written() == "第三条 Alpha" && clipboard.closes == 0)
    }

    /// 置顶沿会话原有入口：结果与历史页的置顶一致；保存失败报失败、不改状态。
    @Test func pinFollowsTheSessionAndSaveFailureIsReported() throws {
        let clipboard = try ClipboardCommandFixture()
        let f = try assembled(clipboard)
        let on = CommandArgument(parameter: .enabled, operation: .assign, value: .boolean(true))
        let target = entry(clipboard.records[0])
        let preview = try f.pages.prepare(f.draft("clipboard.pinned", targets: [target], [on]))
        #expect(preview.before == .clipboardPin(false) && preview.after == .clipboardPin(true))
        #expect(try run(f, "clipboard.pinned", targets: [target], [on]) == .clipboardPin(true))
        let page = try ClipboardCommandFixture()
        page.session.togglePin(page.records[0].id)
        #expect(clipboard.session.items.first { $0.id == target.id }?.pinKey == page.session.items.first { $0.id == page.records[0].id }?.pinKey)
        let broken = try ClipboardCommandFixture()
        let g = try assembled(broken)
        try broken.breakSaving()
        #expect(throws: CommandPageIssue.saveFailed) {
            try g.run(g.draft("clipboard.pinned", targets: [entry(broken.records[2])], [on]))
        }
        #expect(broken.session.items.first { $0.id == broken.records[2].id }?.isPinned == false)
    }

    @Test func copyLetterUsesThePinnedKey() throws {
        let clipboard = try ClipboardCommandFixture()
        let f = try assembled(clipboard)
        let letter = { (value: String) in CommandArgument(parameter: .letter, operation: .assign, value: .choice(value)) }
        #expect(try run(f, "clipboard.copyLetter", [letter("b")]) == .clipboardResult("copied"))
        #expect(clipboard.written() == "第二条 beta" && clipboard.closes == 0)
        #expect(throws: CommandPageIssue.notInList) { try f.pages.prepare(f.draft("clipboard.copyLetter", [letter("z")])) }
    }

    /// 小窗只有一个：已开再开不新建；没开不能关；置顶写会话那一份偏好。
    @Test func windowCommandsReuseTheSingleWindow() throws {
        let clipboard = try ClipboardCommandFixture()
        let f = try assembled(clipboard)
        #expect(try f.pages.applyClipboardWindow(.open) && clipboard.toggles == 1)
        #expect(try f.pages.applyClipboardWindow(.open) && clipboard.toggles == 1)
        #expect(try !f.pages.applyClipboardWindow(.close) && clipboard.closes == 1)
        #expect(throws: CommandPageIssue.nothingToCancel) { try f.pages.applyClipboardWindow(.close) }
        let off = CommandArgument(parameter: .enabled, operation: .assign, value: .boolean(false))
        #expect(try run(f, "clipboard.pinWindow", [off]) == .windowPinned(false) && !clipboard.session.panelStaysOnTop)
    }

    @Test func clipboardCommandsAreUnassembledByDefault() throws {
        let f = try Fixture(page: .dashboard)
        #expect(f.pages.clipboard == nil)
        #expect(throws: CommandPageIssue.unassembled) { try f.pages.prepare(f.draft("clipboard.browse")) }
        #expect(throws: CommandPageIssue.unassembled) { try f.pages.applyClipboardWindow(.open) }
    }
}
