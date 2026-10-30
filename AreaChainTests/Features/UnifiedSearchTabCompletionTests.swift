import AppKit
import Testing
@testable import AreaChain

/// 指令路径的 Tab 只补文字、一次一层：有下一层时补上 `/` 并列出下一层，不开始草稿；Return 才开始。
/// 前台套件：发真实键盘事件。只用内存偏好与合成输入。
@Suite(.serialized) @MainActor struct UnifiedSearchTabCompletionTests {
    private func select(_ id: String, in host: UnifiedSearchTestHost) throws {
        let state = try host.state
        let result = try #require(state.completion).result
        state.suggestions.selectedIndex = try #require(result.candidates.firstIndex { $0.id == id }, "缺少候选 \(id)")
    }

    @Test func tabCompletesOneLevelAndReturnBegins() async throws {
        let fixture = try UnifiedSearchSettingFixture(hostID: HandoffFixture.target)
        defer { fixture.stop() }
        let host = try await fixture.host()
        defer { host.close() }
        let editor = try host.editor
        editor.insertText("/se", replacementRange: .init(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        try select("command:group.setting", in: host)
        try await host.key(48, "\t")
        #expect(try host.editor.string == "/setting/")
        #expect(fixture.controller.operations?.active == nil)

        (try host.editor).insertText("ap", replacementRange: (try host.editor).selectedRange())
        try await host.settle()
        try select("command:setting.appearance", in: host)
        try await host.key(48, "\t")
        #expect(try host.editor.string == "/setting/appearance/")
        #expect(fixture.controller.operations?.active == nil, "Tab 不开始草稿")

        try select("argument:setting.appearance:value:dark", in: host)
        try await host.key(48, "\t")
        #expect(try host.editor.string == "/setting/appearance/dark")
        #expect(fixture.controller.operations?.active == nil)

        try await host.key(36, "\r")
        let draft = try #require(fixture.controller.operations?.active)
        #expect(draft.commandID.rawValue == "setting.appearance")
        #expect(draft.arguments.first?.value == .choice("dark"))
        #expect(fixture.io.writes.isEmpty)
    }
}
