import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct SearchMultilineUndoTests {
    @Test(arguments: SearchMultilineConsumer.searches + [.capture, .form], [false, true])
    func oneNativeImportThenUndo(kind: SearchMultilineConsumer, namedBoard: Bool) async throws {
        let fixture = try SearchMultilineFixture(kind)
        defer { fixture.cleanup() }
        let field = try await fixture.prepare()
        let editor = try #require(field.currentEditor() as? NSTextView)
        let trace = kind == .form ? nil : try SearchMultilineTrace(field)
        defer { trace?.restore() }
        try #require(editor.string.isEmpty && editor.undoManager?.canUndo != true)
        print("SEARCH_I_UNDO_BEGIN \(kind) board=\(namedBoard) groups=\(editor.undoManager?.groupingLevel ?? -1)")
        try SearchMultilineBoundaryTests.importText("甲\n乙", editor: editor, namedBoard: namedBoard)
        try await SystemPageHost.settle(fixture.window)
        #expect(editor.string == (kind == .form ? "甲\n乙" : "甲 乙"))
        trace?.record("\(kind).beforeUndo")
        try #require(editor.tryToPerform(Selector(("undo:")), with: nil))
        trace?.record("\(kind).afterUndo")
        try await SystemPageHost.settle(fixture.window)
        print("SEARCH_I_UNDO_END \(kind) board=\(namedBoard) field=\(field.stringValue.debugDescription) editor=\(editor.string.debugDescription) query=\((trace?.coordinator.parent.text ?? fixture.draft.text).debugDescription) selection=\(editor.selectedRange())")
        #expect(editor.string.isEmpty)
        #expect(field.stringValue.isEmpty)
        #expect((trace?.coordinator.parent.text ?? fixture.draft.text).isEmpty)
    }

    @Test(arguments: SearchMultilineConsumer.searches)
    func keyboardUndoThenReturnAndTyping(kind: SearchMultilineConsumer) async throws {
        let fixture = try SearchMultilineFixture(kind)
        defer { fixture.cleanup() }
        let field = try await fixture.prepare()
        let editor = try #require(field.currentEditor() as? NSTextView)
        let trace = try SearchMultilineTrace(field)
        defer { trace.restore() }
        try #require(editor.string.isEmpty && editor.undoManager?.canUndo != true)
        try SearchMultilineBoundaryTests.importText("甲\n乙", editor: editor, namedBoard: true)
        try await SystemPageHost.settle(fixture.window)
        trace.reset()
        try await SearchMultilineBoundaryTests.key(command: true, code: 6, text: "z", in: fixture.window)
        trace.record("\(kind).keyboard.undo")
        // 保留恢复要求；后面的特征断言仅刻画现存缺陷，不把它作为正确产品契约。
        #expect(editor.string.isEmpty)
        #expect(trace.events.contains { $0.name == "enter.controlTextDidChange:" && $0.editor == "甲\n乙" })
        #expect(trace.events.contains { $0.name == "exit.controlTextDidChange:" && $0.query == "甲 // 乙" })
        #expect(editor.string == "/ 乙" && trace.coordinator.parent.text == "/ 乙")
        #expect(editor.selectedRange() == NSRange(location: 0, length: 0))
        fixture.assertResults(space: false, slash: true)
        try await SearchMultilineBoundaryTests.key(in: fixture.window)
        #expect(trace.coordinator.parent.text == "/ 乙")
        #expect(fixture.draft.commits == (kind == .clipboard ? 1 : 0))
        try await SearchMultilineBoundaryTests.key(command: true, in: fixture.window)
        #expect(trace.coordinator.parent.text == "/ 乙")
        #expect(fixture.draft.commits == (kind == .clipboard ? 1 : 0))
        try await SearchMultilineBoundaryTests.key(code: 7, text: "x", in: fixture.window)
        trace.record("\(kind).keyboard.afterTyping")
        #expect(editor.string == "x/ 乙" && trace.coordinator.parent.text == "x/ 乙")
        #expect(editor.selectedRange() == NSRange(location: 1, length: 0))
        fixture.assertResults(space: false, slash: false)
    }
}
