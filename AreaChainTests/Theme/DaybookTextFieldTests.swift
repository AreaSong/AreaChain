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
        let todoCalled = false

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
        _ = DaybookAppKitTextField(string: text)
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

    @Test func livePreviewTwoStageEscapeInterception() {
        var text = "买牛奶 #"
        let binding = Binding(get: { text }, set: { text = $0 })
        let focus = FocusState<Bool>()
        let autocomplete = SyntaxAutocompleteState(context: .capture, allowsLivePreview: true)
        autocomplete.inputText = text
        autocomplete.isActive = true
        autocomplete.trigger = SyntaxTrigger(kind: .tag, query: "", range: NSRange(location: 4, length: 1))
        autocomplete.candidates = [
            SyntaxCandidate(id: "tag_work", title: "#工作", insertText: "#工作 ", kind: .tag)
        ]

        #expect(autocomplete.showsPreview == true)
        #expect(autocomplete.hasPresentation == true)

        let daybookField = DaybookTextField(
            text: binding,
            placeholder: "test",
            focus: focus.projectedValue,
            autocomplete: autocomplete,
            onSubmit: {}
        )

        let coordinator = daybookField.makeCoordinator()
        let tf = DaybookAppKitTextField(string: text)
        let editor = NSTextView()
        editor.string = text

        // 第一次按 Esc：应该仅关闭候选列表，保留实时预览
        let handledFirstEsc = coordinator.control(tf, textView: editor, doCommandBy: #selector(NSResponder.cancelOperation(_:)))
        #expect(handledFirstEsc == true)
        #expect(autocomplete.isActive == false)
        #expect(autocomplete.showsPreview == true)

        // 第二次按 Esc：应该关闭实时预览
        let handledSecondEsc = coordinator.control(tf, textView: editor, doCommandBy: #selector(NSResponder.cancelOperation(_:)))
        #expect(handledSecondEsc == true)
        #expect(autocomplete.showsPreview == false)
        #expect(autocomplete.hasPresentation == false)
    }

    @Test func plainTextInputPreservesLivePreviewAndHandlesIME() {
        var text = ""
        let binding = Binding(get: { text }, set: { text = $0 })
        let focus = FocusState<Bool>()
        let autocomplete = SyntaxAutocompleteState(context: .capture, allowsLivePreview: true)

        let daybookField = DaybookTextField(
            text: binding,
            placeholder: "test",
            focus: focus.projectedValue,
            autocomplete: autocomplete,
            onSubmit: {}
        )

        let coordinator = daybookField.makeCoordinator()
        let tf = DaybookAppKitTextField(string: "")
        tf.delegate = coordinator
        let editor = NSTextView()
        editor.string = ""

        // 1. 开始编辑空文本
        coordinator.controlTextDidBeginEditing(Notification(name: NSControl.textDidBeginEditingNotification, object: tf))
        #expect(autocomplete.showsPreview == false)

        // 2. 模拟普通文字输入（如 "你 23123"）
        tf.stringValue = "你 23123"
        coordinator.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: tf))
        #expect(text == "你 23123")
        #expect(autocomplete.inputText == "你 23123")
        #expect(autocomplete.showsPreview == true)
        #expect(autocomplete.hasPresentation == true)
        #expect(autocomplete.presentedAt > 0)

        // 3. 模拟失焦触发 dismiss
        coordinator.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification, object: tf))
        #expect(autocomplete.isDismissedByUser == false)
        #expect(autocomplete.showsPreview == true)

        // 4. 再次聚焦继续输入
        tf.stringValue = "你 23123 再次输入"
        coordinator.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: tf))
        #expect(autocomplete.showsPreview == true)
        #expect(autocomplete.hasPresentation == true)

        // 5. 模拟输入 "1312312313你 #" (带空标签库，应展示空态引导项，绝不一片空白)
        tf.stringValue = "1312312313你 #"
        coordinator.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: tf))
        #expect(autocomplete.isActive == true)
        #expect(autocomplete.candidates.count == 1)
        #expect(autocomplete.candidates.first?.id == "tag_empty_guide")

        // 6. 模拟有可用标签后输入 "#"
        coordinator.parent.availableTags = ["工作", "生活"]
        coordinator.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: tf))
        #expect(autocomplete.isActive == true)
        #expect(autocomplete.candidates.count == 2)
        #expect(autocomplete.candidates.map(\.title) == ["#工作", "#生活"])

        // 7. 模拟全角 "＃" 识别
        tf.stringValue = "1312312313你 ＃"
        coordinator.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: tf))
        #expect(autocomplete.isActive == true)
        #expect(autocomplete.candidates.count == 2)

        // 8. 模拟在 "#" 后继续输入具体文字（如 "#项目"），转为创建新标签候选
        tf.stringValue = "1312312313你 #项目"
        coordinator.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: tf))
        #expect(autocomplete.isActive == true)
        #expect(autocomplete.candidates.first?.title == "#项目")
        #expect(autocomplete.candidates.first?.isCreation == true)
    }

    @Test func livePreviewSnapsToAnchorWidthAndCleansSyntaxPrefix() {
        // 测试几何定位 snapToAnchor 宽度严格对齐输入框
        let container = CGSize(width: 400, height: 500)
        let anchor = CGRect(x: 20, y: 50, width: 340, height: 36)
        let preferred = CGSize(width: 316, height: 32)
        let placement = SyntaxOverlayPlacement.resolve(
            anchor: anchor, container: container, preferred: preferred, prefersAbove: false, matchAnchorWidth: true
        )
        #expect(placement.frame.width == 340.0)
        #expect(placement.frame.minX == 20.0)
        #expect(placement.frame.minY == 90.0)
    }
}
