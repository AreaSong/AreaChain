import AppKit
import SwiftUI
import Testing
@testable import AreaChain

/// 修复批 M-7G 检查点 B：候选接受后 Return 是否被占用。真实原生输入：键盘选中候选＋两次 Return、鼠标点选候选＋Return；
/// 工作台与菜单栏各一遍。每一步记录候选是否仍活动与操作状态，作为结论证据。前台套件（发真实键鼠事件）。
@Suite(.serialized) @MainActor struct UnifiedSearchCandidateReturnTests {
    @Test(arguments: UnifiedSearchFocusRecoveryTests.Kind.allCases) func keyboardSelectThenTwoReturnsOpensPanel(kind: UnifiedSearchFocusRecoveryTests.Kind) async throws {
        let host = try UnifiedSearchFocusHost(kind)
        defer { host.close() }
        try await host.start()
        try await host.type("/setting/appea")
        let state = try host.inputState
        #expect(state.suggestions.isActive)
        let index = try #require(state.completion?.result.candidates.firstIndex { $0.command.id.rawValue == "setting.appearance" })
        for _ in 0..<index { try await host.key(125, "\u{F701}") }
        try await host.key(36, "\r")
        // 第一次 Return 接受“完整指令”候选即开始草稿并出面板（accept → beginOperation），不必等第二次。
        #expect(host.controller.operations?.active?.commandID.rawValue == "setting.appearance")
        #expect(host.operationPanelShown)
        let afterFirst = (try host.inputState).suggestions.isActive
        let candidates = (try host.inputState).completion?.result.candidates.map(\.id) ?? []
        Attachment.record("afterFirstReturn suggestionsActive=\(afterFirst) candidates=\(candidates)", named: "m7g-b-\(kind)-keyboard.txt")
        // 证据：afterFirstReturn 候选仍活动且选中项还是同一条 command 候选（接受后文字不变）。
        // 修复前第二次 Return 只会原地重复接受；修复后改发 .open，记录意图来源。
        #expect(afterFirst && candidates.first == "command:setting.appearance")
        let selected = try host.inputState.suggestions.selectedCandidate()?.id
        #expect(selected == "command:setting.appearance")
        let text = host.controller.buffer.text
        try await host.key(36, "\r")
        #expect(host.controller.buffer.text == text, "第二次 Return 不改写文字、不接受别的候选")
        // 第二次 Return 进入 .open（同一草稿继续），草稿与面板都还在。
        #expect(host.controller.operations?.active?.commandID.rawValue == "setting.appearance")
        #expect(host.operationPanelShown)
    }

    /// 参数值候选照常工作：继续输入 `/` 后列出浅色／深色，Return 接受“深色”写进同一草稿。
    @Test func argumentCandidatesStillWorkAfterCollapse() async throws {
        let host = try UnifiedSearchFocusHost(.workspace)
        defer { host.close() }
        try await host.start()
        try await host.type("/setting/appea")
        try await host.key(36, "\r")
        #expect(host.controller.operations?.active?.commandID.rawValue == "setting.appearance")
        let editor = try host.editor
        editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
        editor.insertText("/da", replacementRange: editor.selectedRange())
        try await host.settle()
        #expect((try host.inputState).suggestions.isActive)
        try await host.key(36, "\r")
        let value = host.controller.operations?.active?.arguments.first { $0.parameter == .value }?.value
        #expect(value == .choice("dark"))
    }

    @Test(arguments: UnifiedSearchFocusRecoveryTests.Kind.allCases) func mouseClickCandidateThenReturnOpensPanel(kind: UnifiedSearchFocusRecoveryTests.Kind) async throws {
        let host = try UnifiedSearchFocusHost(kind)
        defer { host.close() }
        try await host.start()
        try await host.type("/setting/appea")
        let state = try host.inputState
        let candidate = try #require(state.completion?.result.candidates.first { $0.command.id.rawValue == "setting.appearance" })
        let point = try host.candidateCenter(candidate.title)
        try await host.click(point)
        try await host.key(36, "\r")
        #expect(host.controller.operations?.active?.commandID.rawValue == "setting.appearance")
        #expect(host.operationPanelShown)
    }

    /// 完整写出的指令路径：选中项是同一条指令候选时，Return 发 .open，不改写文字、不跳到相邻候选（如 /tasks/filter 不会变成 tasks.kind）。
    @Test(arguments: ["/setting/appearance", "/tasks/filter"]) func returnOnFullyTypedCommandSendsOpen(path: String) async throws {
        let host = UnifiedSearchTestHost()
        defer { host.close() }
        try await host.start()
        let editor = try host.editor
        editor.insertText(path, replacementRange: editor.selectedRange())
        try await host.settle()
        let state = try host.state
        if state.suggestions.isActive, let selected = state.suggestions.selectedCandidate(),
           let candidate = state.completion?.result.candidates.first(where: { $0.id == selected.id }) {
            #expect(UnifiedSearchInputState.isUnchangedCommand(candidate, in: path), "选中项不是已写完的同一条指令：\(selected.id)")
        }
        try await host.key(36, "\r")
        #expect(host.model.intents == [.open])
        #expect(host.model.buffer.text == path)
    }

    /// 输入法组字期间 Return 只交给输入法，不接受候选、不开始操作。
    @Test func markedTextReturnDoesNotStartOperation() async throws {
        let host = try UnifiedSearchFocusHost(.workspace)
        defer { host.close() }
        try await host.start()
        try await host.type("/setting/appea")
        let editor = try host.editor
        editor.setMarkedText("wai", selectedRange: NSRange(location: 3, length: 0),
                             replacementRange: NSRange(location: editor.selectedRange().location, length: 0))
        try await host.settle()
        #expect(editor.hasMarkedText())
        let state = try host.inputState
        #expect(!state.command(#selector(NSResponder.insertNewline(_:)), editor: editor))
        #expect(host.controller.operations?.active == nil)
        editor.unmarkText()
    }
}
