import AppKit
import Testing
@testable import AreaChain

/// 生产 CaptureField 的动作边界；组合由原生 API 建立，快捷键仍经应用队列。
@Suite(.serialized) @MainActor
struct CaptureSubmissionTests {
    typealias Input = SearchMultilineBoundaryTests

    @Test(arguments: [false, true])
    func committedPrefixThenComposition(completes: Bool) async throws {
        let fixture = try SearchMultilineFixture(.capture)
        defer { fixture.cleanup() }
        fixture.draft.text = "头🧪尾"
        let field = try await fixture.prepare()
        let editor = try #require(field.currentEditor() as? NSTextView)
        let manager = try #require(editor.undoManager)
        editor.setMarkedText("拼音", selectedRange: NSRange(location: 1, length: 0),
                             replacementRange: NSRange(location: 3, length: 0))
        let text = editor.string
        let draft = fixture.draft.text
        let marked = editor.markedRange()
        let selection = editor.selectedRange()
        let undo = manager.canUndo
        let redo = manager.canRedo
        try await Input.key(command: true, in: fixture.window)
        #expect(fixture.draft.diaryCommits == 0 && fixture.draft.commits == 0)
        #expect(editor.string == text && fixture.draft.text == draft)
        #expect(editor.markedRange() == marked && editor.selectedRange() == selection)
        #expect(editor.undoManager === manager && manager.canUndo == undo && manager.canRedo == redo)
        #expect(field.currentEditor() === editor && fixture.window.firstResponder === editor)
        // 模拟输入法完成/取消替换；保护动作自身不得确认或清除组合。
        editor.insertText(completes ? "中文" : "", replacementRange: editor.markedRange())
        try await SystemPageHost.settle(fixture.window)
        #expect(!editor.hasMarkedText())
        #expect(editor.string == (completes ? "头🧪中文尾" : "头🧪尾"))
        try await Input.key(command: true, in: fixture.window)
        #expect(fixture.draft.diaryCommits == 1 && fixture.draft.commits == 0)
        #expect(field.currentEditor() === editor && editor.undoManager === manager)
    }

    @Test func shortcutGateDoesNotDisableMouse() async throws {
        let fixture = try SearchMultilineFixture(.capture)
        defer { fixture.cleanup() }
        fixture.draft.text = "Synthetic capture"
        fixture.draft.allowsDiaryShortcut = false
        let field = try await fixture.prepare()
        let editor = try #require(field.currentEditor() as? NSTextView)
        try await Input.key(command: true, in: fixture.window)
        #expect(fixture.draft.diaryCommits == 0 && fixture.draft.commits == 0)
        try await SettingsButtonTestSupport.click(SettingsButtonTestSupport.button("capture.diary", in: fixture.window),
                                                 in: fixture.window)
        #expect(fixture.draft.diaryCommits == 1 && fixture.draft.text == "Synthetic capture")
        _ = try await FormInputTestSupport.editor(field, in: fixture.window)
        fixture.draft.allowsDiaryShortcut = true
        try await SystemPageHost.settle(fixture.window)
        try await Input.key(command: true, in: fixture.window)
        #expect(fixture.draft.diaryCommits == 2 && fixture.draft.commits == 0)
        try await Input.key(in: fixture.window)
        #expect(fixture.draft.commits == 1 && fixture.draft.diaryCommits == 2)
        #expect(field.currentEditor() === editor)
    }

    @Test func markedButtonActionPreservesNativeState() async throws {
        let fixture = try SearchMultilineFixture(.capture)
        defer { fixture.cleanup() }
        fixture.draft.text = "Synthetic capture"
        let field = try await fixture.prepare()
        let editor = try #require(field.currentEditor() as? NSTextView)
        let button = try SettingsButtonTestSupport.button("capture.diary", in: fixture.window)
        editor.setMarkedText("拼音", selectedRange: NSRange(location: 1, length: 0),
                             replacementRange: NSRange(location: 0, length: 0))
        let text = editor.string
        let selection = editor.selectedRange()
        let marked = editor.markedRange()
        try press(button)
        #expect(fixture.draft.diaryCommits == 0 && editor.hasMarkedText())
        #expect(editor.string == text && editor.selectedRange() == selection && editor.markedRange() == marked)
        editor.insertText("中文", replacementRange: marked)
        try await SystemPageHost.settle(fixture.window)
        try await SettingsButtonTestSupport.click(button, in: fixture.window)
        #expect(fixture.draft.diaryCommits == 1 && fixture.draft.commits == 0)
    }

    @Test func otherWindowCompositionDoesNotBlockLocalButton() async throws {
        let first = try SearchMultilineFixture(.capture)
        defer { first.cleanup() }
        first.draft.text = "First"
        let firstField = try await first.prepare()
        let firstEditor = try #require(firstField.currentEditor() as? NSTextView)
        firstEditor.setMarkedText("拼音", selectedRange: NSRange(location: 1, length: 0),
                                  replacementRange: NSRange(location: 0, length: 0))
        let second = try SearchMultilineFixture(.capture)
        defer { second.cleanup() }
        second.draft.text = "Second"
        let secondField = try await second.prepare()
        let secondEditor = try #require(secondField.currentEditor() as? NSTextView)
        try #require(firstEditor.hasMarkedText())
        try await Input.key(command: true, in: second.window)
        #expect(first.draft.diaryCommits == 0 && second.draft.diaryCommits == 1)
        #expect(firstEditor.hasMarkedText() && secondField.currentEditor() === secondEditor)
        // 非 key 窗口的真实按钮动作仍检查自身 editor，不借用第二窗口的未组词状态。
        try press(SettingsButtonTestSupport.button("capture.diary", in: first.window))
        #expect(first.draft.diaryCommits == 0)
        second.window.orderOut(nil)
        try await NativeSyntaxUI.prepareFocus(in: first.window)
        _ = try await FormInputTestSupport.editor(firstField, in: first.window)
        // 此次真实鼠标点击由 AppKit 正常结束组词，后续快捷键应恢复一次提交。
        try #require(!firstEditor.hasMarkedText() && first.window.firstResponder === firstEditor)
        try await Input.key(command: true, in: first.window)
        #expect(first.draft.diaryCommits == 1 && second.draft.diaryCommits == 1)
    }

    @Test func inputSwitchAndUnmountReleaseOwnership() async throws {
        let fixture = try SearchMultilineFixture(.capture)
        defer { fixture.cleanup() }
        fixture.draft.text = "Capture"
        fixture.draft.showsSecondary = true
        let field = try await fixture.prepare()
        let editor = try #require(field.currentEditor() as? NSTextView)
        let state = try #require((field.delegate as? DaybookTextField.Coordinator)?.parent.autocomplete)
        let secondary = try #require(FormInputTestSupport.fields(in: fixture.window).first {
            $0.placeholderString == "SYNTHETIC_SECONDARY"
        })
        let other = try await FormInputTestSupport.editor(secondary, in: fixture.window)
        #expect(state.editor == nil)
        other.setMarkedText("其他", selectedRange: NSRange(location: 1, length: 0),
                            replacementRange: NSRange(location: 0, length: 0))
        try press(SettingsButtonTestSupport.button("capture.diary", in: fixture.window))
        #expect(fixture.draft.diaryCommits == 1 && other.hasMarkedText())
        fixture.draft.showsCapture = false
        try await SystemPageHost.settle(fixture.window)
        try await Input.key(command: true, in: fixture.window)
        #expect(fixture.draft.diaryCommits == 1 && fixture.draft.commits == 0)
        #expect(field.window == nil && editor !== other)
        fixture.draft.showsCapture = true
        try await SystemPageHost.settle(fixture.window)
        let replacement = try await fixture.prepare()
        try await Input.key(command: true, in: fixture.window)
        #expect(fixture.draft.diaryCommits == 2 && replacement !== field)
    }

    @Test func undoRedoIntermediateButtonActionDoesNotCommit() async throws {
        let fixture = try SearchMultilineFixture(.capture)
        defer { fixture.cleanup() }
        let field = try await fixture.prepare()
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.insertText("Undo boundary", replacementRange: NSRange(location: 0, length: 0))
        try await SystemPageHost.settle(fixture.window)
        let state = try #require((field.delegate as? DaybookTextField.Coordinator)?.parent.autocomplete)
        try #require(state.editor === editor && fixture.window.firstResponder === editor)
        let manager = try #require(editor.undoManager)
        let button = try SettingsButtonTestSupport.button("capture.diary", in: fixture.window)
        let probe = CaptureUndoActionProbe(manager: manager, button: button)
        manager.beginUndoGrouping()
        manager.registerUndo(withTarget: probe) { $0.replay() }
        manager.endUndoGrouping()
        manager.undo()
        #expect(probe.protectedActions == 1 && fixture.draft.diaryCommits == 0)
        manager.redo()
        #expect(probe.protectedActions == 2 && fixture.draft.diaryCommits == 0)
        #expect(editor.string == "Undo boundary" && field.currentEditor() === editor)
        manager.undo()
        manager.undo()
        #expect(editor.string.isEmpty && editor.selectedRange() == NSRange(location: 0, length: 0))
        manager.redo()
        #expect(editor.string == "Undo boundary" && editor.selectedRange() == NSRange(location: 13, length: 0))
        try await SystemPageHost.settle(fixture.window)
        try await Input.key(command: true, in: fixture.window)
        #expect(fixture.draft.diaryCommits == 1)
    }

    private func press(_ button: NSObject) throws {
        let selector = NSSelectorFromString("accessibilityPerformPress")
        try #require(button.responds(to: selector))
        _ = button.perform(selector)
    }
}

@MainActor
private final class CaptureUndoActionProbe {
    let manager: UndoManager
    let button: NSObject
    var protectedActions = 0

    init(manager: UndoManager, button: NSObject) {
        self.manager = manager
        self.button = button
    }

    func replay() {
        manager.registerUndo(withTarget: self) { $0.replay() }
        #expect(manager.isUndoing || manager.isRedoing)
        protectedActions += 1
        _ = button.perform(NSSelectorFromString("accessibilityPerformPress"))
    }
}
