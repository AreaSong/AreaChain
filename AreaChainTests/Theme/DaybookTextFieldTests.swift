import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@MainActor
struct DaybookTextFieldTests {
    @Test func textFieldFieldEditorDelegatePreservedAndSubmitsOnReturn() {
        var text = ""
        var submitted = false
        let binding = Binding(get: { text }, set: { text = $0 })
        let focus = FocusState<Bool>()

        let daybookField = DaybookTextField(
            text: binding,
            placeholder: "test",
            focus: focus.projectedValue,
            onSubmit: { submitted = true }
        )

        let coordinator = daybookField.makeCoordinator()
        let tf = DaybookAppKitTextField(string: "initial")
        tf.delegate = coordinator

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView?.addSubview(tf)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(tf)

        guard let editor = tf.currentEditor() as? NSTextView else {
            Issue.record("Field editor should be present when first responder")
            return
        }

        // 模拟开始编辑
        coordinator.controlTextDidBeginEditing(Notification(name: NSControl.textDidBeginEditingNotification, object: tf))

        // 核心断言：field editor 的 delegate 必须仍为 NSTextField，严禁被 Coordinator 劫持
        #expect(editor.delegate === tf)

        // 模拟用户键入文本并派发 controlTextDidChange
        tf.stringValue = "New Task"
        coordinator.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: tf))
        #expect(text == "New Task")

        // 模拟按下回车 (insertNewline:)
        editor.string = "New Task"
        let handled = coordinator.control(tf, textView: editor, doCommandBy: #selector(NSResponder.insertNewline(_:)))
        #expect(handled == true)
        #expect(submitted == true)
        #expect(text == "New Task")
    }

    @Test func textFieldCommandReturnViaPerformKeyEquivalent() {
        var text = ""
        var diaryCalled = false
        var todoCalled = false

        let tf = DaybookAppKitTextField(string: "")
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView?.addSubview(tf)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(tf)

        tf.onCommandReturn = {
            let editorString = (tf.currentEditor() as? NSTextView)?.string ?? tf.stringValue
            text = editorString
            diaryCalled = true
        }

        guard let editor = tf.currentEditor() as? NSTextView else {
            Issue.record("Field editor should be present")
            return
        }

        editor.insertText("Today is great", replacementRange: NSRange(location: 0, length: 0))

        let cmdReturnEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36 // Return
        )!

        let handled = window.performKeyEquivalent(with: cmdReturnEvent)
        #expect(handled == true)
        #expect(diaryCalled == true)
        #expect(todoCalled == false)
        #expect(text == "Today is great")
    }

    @Test func textFieldCommandReturnViaCoordinatorDelegation() {
        var text = "Draft diary"
        var diaryCalled = false
        var todoCalled = false
        let binding = Binding(get: { text }, set: { text = $0 })
        let focus = FocusState<Bool>()

        let daybookField = DaybookTextField(
            text: binding,
            placeholder: "test",
            focus: focus.projectedValue,
            onSubmit: { todoCalled = true },
            onCommandReturn: { diaryCalled = true }
        )

        let coordinator = daybookField.makeCoordinator()
        let tf = DaybookAppKitTextField(string: text)
        let editor = NSTextView()
        editor.string = text

        // 模拟直接调用 onCommandReturn 委托闭包
        coordinator.parent.onCommandReturn?()
        #expect(diaryCalled == true)
        #expect(todoCalled == false)
    }

    @Test func autocompleteInterceptionOnReturn() {
        var text = "#tag"
        var submitted = false
        let binding = Binding(get: { text }, set: { text = $0 })
        let focus = FocusState<Bool>()
        let autocomplete = SyntaxAutocompleteState()
        autocomplete.isActive = true
        autocomplete.trigger = SyntaxTrigger(kind: .tag, query: "tag", range: NSRange(location: 0, length: 4))
        autocomplete.candidates = [
            SyntaxCandidate(id: "tag_work", title: "#work", insertText: "#work ", kind: .tag)
        ]
        autocomplete.selectedIndex = 0

        let daybookField = DaybookTextField(
            text: binding,
            placeholder: "test",
            focus: focus.projectedValue,
            autocomplete: autocomplete,
            onSubmit: { submitted = true }
        )

        let coordinator = daybookField.makeCoordinator()
        let tf = DaybookAppKitTextField(string: text)
        let editor = NSTextView()
        editor.string = text

        // 补全弹窗激活时，回车应先选中补全条目，不触发提交
        let handled = coordinator.control(tf, textView: editor, doCommandBy: #selector(NSResponder.insertNewline(_:)))
        #expect(handled == true)
        #expect(submitted == false)
        #expect(text == "#work ")
        #expect(autocomplete.isActive == false)
    }
}
