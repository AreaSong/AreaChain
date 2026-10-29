import AppKit
import SwiftUI
import Testing
@testable import AreaChain

/// 统一搜索恢复旧搜索的 `#`／`!`／`@` 候选（向上展开、点选补全）；`/` 开头仍只走指令候选。
/// 搜索不能创建标签：`#` 只列已有标签。只用合成标签名，不接仓储。
@Suite(.serialized) @MainActor
struct UnifiedSearchSyntaxCandidateTests {
    private static let tags = ["work", "workshop", "home"]

    @Test func tagCandidatesListOnlyExistingTagsAndClickCompletes() async throws {
        let host = UnifiedSearchTestHost(availableTags: Self.tags)
        defer { host.close() }
        try await host.start()
        let editor = try host.editor
        let state = try host.state
        editor.insertText("#zz", replacementRange: editor.selectedRange())
        try await host.settle()
        #expect(!state.suggestions.isActive && !state.showsSyntax, "未命中的标签不能出现回显或新建候选")
        editor.insertText("#wor", replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        #expect(state.showsSyntax && state.suggestions.isActive)
        #expect(state.suggestions.candidates.map(\.title) == ["#work", "#workshop"])
        #expect(state.suggestions.candidates.allSatisfy { !$0.isCreation && $0.kind == .tag })
        let fieldFrame = try host.field.convert(try host.field.bounds, to: nil)
        let point = try NativeSyntaxUI.center("syntax.candidate.tag_work", in: host.window)
        #expect(point.y > fieldFrame.maxY, "候选沿旧搜索向上展开")
        try await host.click(point)
        #expect(host.model.buffer.text == "#work " && editor.string == "#work ")
        #expect(!state.suggestions.isActive && host.model.intents.isEmpty)
        #expect(host.window.firstResponder === editor)
    }

    @Test func priorityCandidateClickCompletes() async throws {
        let host = UnifiedSearchTestHost(availableTags: Self.tags)
        defer { host.close() }
        try await host.start()
        let editor = try host.editor
        let state = try host.state
        editor.insertText("needle !p", replacementRange: editor.selectedRange())
        try await host.settle()
        #expect(state.showsSyntax && state.suggestions.candidates.map(\.title) == ["!p1", "!p2", "!p3", "!p4"])
        try await host.click(try NativeSyntaxUI.center("syntax.candidate.priority_p2", in: host.window))
        #expect(host.model.buffer.text == "needle !p2 ")
        #expect(!state.suggestions.isActive && host.model.intents.isEmpty)
    }

    @Test func timeCandidateClickCompletes() async throws {
        let host = UnifiedSearchTestHost(locale: "zh-Hans", availableTags: Self.tags)
        defer { host.close() }
        try await host.start()
        let editor = try host.editor
        let state = try host.state
        editor.insertText("@", replacementRange: editor.selectedRange())
        try await host.settle()
        #expect(state.showsSyntax && state.suggestions.isActive)
        let noon = try #require(state.suggestions.candidates.first { $0.title == "@12:00" })
        #expect(noon.subtitle != nil)
        try await host.click(try NativeSyntaxUI.center("syntax.candidate." + noon.id, in: host.window))
        #expect(host.model.buffer.text == "@12:00 ")
        #expect(!state.suggestions.isActive)
    }

    /// 上下选择、Return 补全、Esc 先关候选（第二次 Esc 才交给结果页，统一搜索的规则是不清空查询）。
    @Test func keyboardSelectsCompletesAndEscapeClosesCandidatesFirst() async throws {
        let host = UnifiedSearchTestHost(availableTags: Self.tags)
        defer { host.close() }
        try await host.start()
        let editor = try host.editor
        let state = try host.state
        editor.insertText("!p", replacementRange: editor.selectedRange())
        try await host.settle()
        try await host.key(125, "\u{f701}")
        #expect(state.suggestions.selectedIndex == 1 && host.model.intents.isEmpty)
        try await host.key(36, "\r")
        #expect(host.model.buffer.text == "!p2 " && host.model.intents.isEmpty)
        editor.insertText("#hom", replacementRange: editor.selectedRange())
        try await host.settle()
        #expect(state.suggestions.isActive)
        try await host.key(48, "\t")
        #expect(host.model.buffer.text == "!p2 #home ")
        editor.insertText("#wo", replacementRange: editor.selectedRange())
        try await host.settle()
        #expect(state.suggestions.isActive)
        try await host.key(53, "\u{1b}")
        #expect(!state.suggestions.isActive && host.model.intents.isEmpty)
        #expect(host.model.buffer.text == "!p2 #home #wo")
        try await host.key(53, "\u{1b}")
        #expect(host.model.intents == [.escape] && host.model.buffer.text == "!p2 #home #wo")
    }

    @Test func markedTextNeverShowsOrCompletesCandidates() async throws {
        let host = UnifiedSearchTestHost(availableTags: Self.tags)
        defer { host.close() }
        try await host.start()
        let editor = try host.editor
        let state = try host.state
        editor.setMarkedText("#wo", selectedRange: NSRange(location: 3, length: 0),
                             replacementRange: editor.selectedRange())
        try await host.settle()
        #expect(editor.hasMarkedText() && !state.suggestions.isActive && !state.showsSyntax)
        let candidate = SyntaxCandidate(id: "tag_work", title: "#work", insertText: "#work ", kind: .tag)
        #expect(!state.accept(syntax: candidate), "组字期间不能补全")
        #expect(editor.string == "#wo" && editor.hasMarkedText())
        editor.unmarkText()
        editor.didChangeText()
        try await host.settle()
        #expect(state.showsSyntax && state.suggestions.candidates.map(\.title) == ["#work", "#workshop"])
    }

    /// `/` 开头走指令候选，不混入语法候选；接受仍是原指令路径。
    @Test func slashKeepsCommandCandidates() async throws {
        let host = UnifiedSearchTestHost(availableTags: Self.tags)
        defer { host.close() }
        try await host.start()
        let editor = try host.editor
        let state = try host.state
        editor.insertText("/set", replacementRange: editor.selectedRange())
        try await host.settle()
        let completion = try #require(state.completion)
        #expect(!state.showsSyntax && state.suggestions.isActive && !completion.result.candidates.isEmpty)
        #expect(state.suggestions.candidates.map(\.id) == completion.result.candidates.map(\.id))
    }
}
