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
        let restoredQuery = trace?.coordinator.parent.text ?? fixture.draft.text
        #expect(restoredQuery.isEmpty)
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
        #expect(editor.string.isEmpty)
        // 预提交的单行 payload 不再需要原生第二次整段归一化；旧中间态见冻结诊断。
        #expect(!trace.events.contains { $0.query.contains("//") || $0.editor == "/ 乙" })
        #expect(field.stringValue.isEmpty && trace.coordinator.parent.text.isEmpty)
        #expect(editor.selectedRange() == NSRange(location: 0, length: 0))
        try await SearchMultilineBoundaryTests.key(in: fixture.window)
        #expect(trace.coordinator.parent.text.isEmpty)
        #expect(fixture.draft.commits == (kind == .clipboard ? 1 : 0))
        try await SearchMultilineBoundaryTests.key(command: true, in: fixture.window)
        #expect(trace.coordinator.parent.text.isEmpty)
        #expect(fixture.draft.commits == (kind == .clipboard ? 1 : 0))
        try await SearchMultilineBoundaryTests.key(code: 7, text: "x", in: fixture.window)
        trace.record("\(kind).keyboard.afterTyping")
        #expect(editor.string == "x" && field.stringValue == "x" && trace.coordinator.parent.text == "x")
        #expect(editor.selectedRange() == NSRange(location: 1, length: 0))
        fixture.assertResults(space: false, slash: false)
    }

    @Test(arguments: SearchMultilineConsumer.allCases, [false, true])
    func repeatedUndoRedoRestoresTextAndSelection(kind: SearchMultilineConsumer, middle: Bool) async throws {
        let fixture = try SearchMultilineFixture(kind)
        defer { fixture.cleanup() }
        let initial = middle ? "头🧪尾" : ""
        if kind == .form { fixture.draft.text = initial }
        let field = try await fixture.prepare()
        let editor = try #require(field.currentEditor() as? NSTextView)
        let coordinator = field.delegate as? DaybookTextField.Coordinator
        coordinator?.parent.text = initial
        try await SystemPageHost.settle(fixture.window)
        let position = middle ? 3 : 0
        editor.setSelectedRange(NSRange(location: position, length: 0))
        try #require(editor.undoManager?.canUndo != true)
        try SearchMultilineBoundaryTests.importText("甲\n乙", editor: editor, namedBoard: true)
        try await SystemPageHost.settle(fixture.window)
        let imported = (initial as NSString).replacingCharacters(in: NSRange(location: position, length: 0),
                                                               with: kind == .form ? "甲\n乙" : "甲 乙")
        for _ in 0..<3 {
            try #require(editor.tryToPerform(Selector(("undo:")), with: nil))
            Self.assertValue(initial, field: field, fixture: fixture)
            #expect(editor.selectedRange() == NSRange(location: position, length: 0))
            try await SystemPageHost.settle(fixture.window)
            Self.assertValue(initial, field: field, fixture: fixture)
            try #require(editor.tryToPerform(Selector(("redo:")), with: nil))
            Self.assertValue(imported, field: field, fixture: fixture)
            #expect(editor.selectedRange() == NSRange(location: position + 3, length: 0))
            try await SystemPageHost.settle(fixture.window)
            Self.assertValue(imported, field: field, fixture: fixture)
            #expect(field.currentEditor() === editor)
        }
        try #require(editor.tryToPerform(Selector(("undo:")), with: nil))
        editor.insertText("x", replacementRange: editor.selectedRange())
        try await SystemPageHost.settle(fixture.window)
        Self.assertValue((initial as NSString).replacingCharacters(in: NSRange(location: position, length: 0), with: "x"),
                         field: field, fixture: fixture)
        #expect(editor.selectedRange() == NSRange(location: position + 1, length: 0))
        #expect(fixture.draft.commits == 0 && fixture.draft.diaryCommits == 0)
    }

    static func assertValue(_ value: String, field: NSTextField, fixture: SearchMultilineFixture) {
        #expect((field.currentEditor() as? NSTextView)?.string == value)
        #expect(field.stringValue == value)
        #expect(((field.delegate as? DaybookTextField.Coordinator)?.parent.text ?? fixture.draft.text) == value)
    }

    @Test(arguments: SearchMultilineConsumer.searches + [.capture])
    func materialUndoRedoDoesNotPolluteQuery(kind: SearchMultilineConsumer) async throws {
        let fixture = try SearchMultilineFixture(kind)
        defer { fixture.cleanup() }
        let field = try await fixture.prepare()
        let editor = try #require(field.currentEditor() as? NSTextView)
        for (raw, expected) in SearchMultilineBoundaryTests.samples {
            editor.breakUndoCoalescing()
            try SearchMultilineBoundaryTests.importText(raw, editor: editor, namedBoard: true)
            try await SystemPageHost.settle(fixture.window)
            Self.assertValue(expected, field: field, fixture: fixture)
            try #require(editor.tryToPerform(Selector(("undo:")), with: nil))
            Self.assertValue("", field: field, fixture: fixture)
            try #require(editor.tryToPerform(Selector(("redo:")), with: nil))
            Self.assertValue(expected, field: field, fixture: fixture)
            #expect(editor.selectedRange() == NSRange(location: expected.utf16.count, length: 0))
            try #require(editor.tryToPerform(Selector(("undo:")), with: nil))
            try await SystemPageHost.settle(fixture.window)
            Self.assertValue("", field: field, fixture: fixture)
        }
    }

    @Test(arguments: SearchMultilineConsumer.searches)
    func queuedUndoRedo(kind: SearchMultilineConsumer) async throws {
        let fixture = try SearchMultilineFixture(kind)
        defer { fixture.cleanup() }
        let field = try await fixture.prepare()
        let editor = try #require(field.currentEditor() as? NSTextView)
        try SearchMultilineBoundaryTests.importText("甲\n乙", editor: editor, namedBoard: true)
        try await SystemPageHost.settle(fixture.window)
        for _ in 0..<3 {
            try await SearchMultilineBoundaryTests.key(command: true, code: 6, text: "z", in: fixture.window)
            Self.assertValue("", field: field, fixture: fixture)
            #expect(editor.selectedRange() == NSRange(location: 0, length: 0))
            try await SearchMultilineBoundaryTests.key(command: true, shift: true, code: 6, text: "z", in: fixture.window)
            Self.assertValue("甲 乙", field: field, fixture: fixture)
            #expect(editor.selectedRange() == NSRange(location: 3, length: 0))
            fixture.assertResults(space: true, slash: kind != .tags)
        }
        #expect(fixture.draft.commits == 0 && fixture.draft.diaryCommits == 0)
    }
}
