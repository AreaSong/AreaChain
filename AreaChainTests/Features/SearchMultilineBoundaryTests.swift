import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct SearchMultilineBoundaryTests {
    @Test(arguments: SearchMultilineConsumer.allCases)
    func nativeMaterialMatrix(kind: SearchMultilineConsumer) async throws {
        let fixture = try SearchMultilineFixture(kind)
        defer { fixture.cleanup() }
        let field = try await fixture.prepare()
        let editor = try #require(field.currentEditor() as? NSTextView)
        for namedBoard in [false, true] {
            for (raw, singleLine) in Self.samples {
                let expected = (kind == .form || kind == .clipboard) ? raw : singleLine
                editor.setSelectedRange(NSRange(location: 0, length: (editor.string as NSString).length))
                try Self.importText(raw, editor: editor, namedBoard: namedBoard)
                try await SystemPageHost.settle(fixture.window)
                let query = (field.delegate as? DaybookTextField.Coordinator)?.parent.text ?? fixture.draft.text
                print("SEARCH_I_MATRIX \(kind) board=\(namedBoard) raw=\(raw.debugDescription) field=\(field.stringValue.debugDescription) editor=\(editor.string.debugDescription) query=\(query.debugDescription) selection=\(editor.selectedRange())")
                #expect(field.stringValue == expected)
                #expect(editor.string == expected)
                #expect(query == expected)
                #expect(editor.selectedRange() == NSRange(location: (expected as NSString).length, length: 0))
                #expect(fixture.draft.commits == 0 && fixture.draft.diaryCommits == 0)
            }
        }
    }

    @Test(arguments: SearchMultilineConsumer.searches + [.capture])
    func compositionAndCommit(kind: SearchMultilineConsumer) async throws {
        let fixture = try SearchMultilineFixture(kind)
        defer { fixture.cleanup() }
        let field = try await fixture.prepare()
        let editor = try #require(field.currentEditor() as? NSTextView)
        let trace = try SearchMultilineTrace(field)
        defer { trace.restore() }
        editor.setMarkedText("拼音", selectedRange: NSRange(location: 2, length: 0),
                             replacementRange: NSRange(location: 0, length: 0))
        trace.record("\(kind).marked.normal")
        #expect(editor.hasMarkedText())
        #expect(!trace.coordinator.parent.text.contains("//"))
        editor.insertText("甲\n乙", replacementRange: editor.markedRange())
        try await SystemPageHost.settle(fixture.window)
        trace.record("\(kind).composition.committed")
        #expect(!editor.hasMarkedText() && editor.string == (kind == .clipboard ? "甲\n乙" : "甲 乙"))
        #expect(trace.coordinator.parent.text == (kind == .clipboard ? "甲\n乙" : "甲 乙"))
        for command in [false, true] {
            let before = fixture.draft.commits + fixture.draft.diaryCommits
            trace.reset()
            try await Self.key(command: command, in: fixture.window)
            trace.record("\(kind).return.command=\(command)")
            #expect(editor.string == (kind == .clipboard ? "甲\n乙" : "甲 乙") && trace.coordinator.parent.text == (kind == .clipboard ? "甲\n乙" : "甲 乙"))
            let expected = kind == .capture || (kind == .clipboard && !command) ? 1 : 0
            #expect(fixture.draft.commits + fixture.draft.diaryCommits == before + expected)
        }
    }

    @Test(arguments: SearchMultilineConsumer.searches + [.capture])
    func externalBindingAndReturn(kind: SearchMultilineConsumer) async throws {
        let fixture = try SearchMultilineFixture(kind)
        defer { fixture.cleanup() }
        let field = try await fixture.prepare()
        let editor = try #require(field.currentEditor() as? NSTextView)
        let trace = try SearchMultilineTrace(field)
        defer { trace.restore() }
        // 只写原 Binding 作为同步对照，不写 field.stringValue，也不手调 delegate。
        trace.coordinator.parent.text = "甲\n乙"
        try await SystemPageHost.settle(fixture.window)
        trace.record("\(kind).externalBinding")
        #expect(trace.coordinator.parent.text == "甲\n乙")
        #expect(editor.string == "甲\n乙")
        trace.reset()
        try await Self.key(in: fixture.window)
        trace.record("\(kind).external.return")
        let expected = kind == .capture ? "甲 // 乙" : (kind == .clipboard ? "甲\n乙" : "甲 乙")
        #expect(trace.coordinator.parent.text == expected)
        #expect(field.stringValue == expected && editor.string == expected)
        if kind == .capture {
            let parsed = NaturalLanguageParser.parseTaskCapture(fixture.draft.text)
            #expect(parsed.cleanTitle == "甲" && parsed.notes == "乙")
            #expect(fixture.draft.commits == 1)
        } else if kind == .clipboard {
            fixture.assertResults(space: false, slash: false)
            #expect(fixture.session.visibleItems.map(\.plainText) == ["甲\n乙 CLIP_LF"])
        } else {
            fixture.assertResults(space: true, slash: kind != .tags)
        }
    }

    @Test(arguments: SearchMultilineConsumer.searches + [.capture, .form])
    func selectionUndoAndBlur(kind: SearchMultilineConsumer) async throws {
        let fixture = try SearchMultilineFixture(kind)
        defer { fixture.cleanup() }
        if kind == .form { fixture.draft.text = "头尾" }
        let field = try await fixture.prepare()
        let editor = try #require(field.currentEditor() as? NSTextView)
        // 外部初值没有原生撤销记录，避免两次无键盘事件的 insertText 落入同一个隐式撤销组。
        if let coordinator = field.delegate as? DaybookTextField.Coordinator { coordinator.parent.text = "头尾" }
        try await SystemPageHost.settle(fixture.window)
        #expect(editor.string == "头尾")
        #expect(editor.undoManager?.canUndo != true)
        editor.setSelectedRange(NSRange(location: 1, length: 0))
        editor.insertText("甲\n乙", replacementRange: editor.selectedRange())
        try await SystemPageHost.settle(fixture.window)
        #expect(editor.string == ((kind == .form || kind == .clipboard) ? "头甲\n乙尾" : "头甲 乙尾"))
        #expect(editor.selectedRange() == NSRange(location: 4, length: 0))
        let trace = (kind == .form || kind == .clipboard) ? nil : try SearchMultilineTrace(field)
        defer { trace?.restore() }
        trace?.record("\(kind).middle.beforeUndo")
        try #require(editor.tryToPerform(Selector(("undo:")), with: nil))
        try await SystemPageHost.settle(fixture.window)
        trace?.record("\(kind).middle.afterUndo")
        print("SEARCH_I_UNDO \(kind) field=\(field.stringValue.debugDescription) selection=\(editor.selectedRange()) redo=\(editor.undoManager?.canRedo == true)")
        #expect(editor.string == "头尾" && field.stringValue == "头尾")
        #expect(editor.selectedRange() == NSRange(location: 1, length: 0))
        // 专门的失焦观察发生在导入与撤销断言之后，不用于绕过转换或补全。
        #expect(fixture.window.makeFirstResponder(nil))
        try await SystemPageHost.settle(fixture.window)
        #expect(field.stringValue == "头尾")
    }

    static func importText(_ raw: String, editor: NSTextView, namedBoard: Bool) throws {
        if namedBoard {
            let board = NSPasteboard(name: NSPasteboard.Name("areachain.search-multiline.\(UUID())"))
            defer { board.releaseGlobally() }
            board.declareTypes([.string], owner: nil)
            #expect(board.setString(raw, forType: .string))
            #expect(board.string(forType: .string) == raw)
            #expect(editor.readSelection(from: board, type: .string))
        } else {
            editor.insertText(raw, replacementRange: editor.selectedRange())
        }
    }

    @Test(arguments: SearchMultilineConsumer.ordinarySearches, [false, true])
    func externalSubmissionPreservesUTF16Selection(kind: SearchMultilineConsumer, command: Bool) async throws {
        let fixture = try SearchMultilineFixture(kind)
        defer { fixture.cleanup() }
        let field = try await fixture.prepare()
        let editor = try #require(field.currentEditor() as? NSTextView)
        let coordinator = try #require(field.delegate as? DaybookTextField.Coordinator)
        let raw = " e\u{301}🧪\r\n甲\u{0085}乙\u{2028}丙\u{2029}丁 // ／／ \\n "
        let expected = " e\u{301}🧪  甲 乙 丙 丁 // ／／ \\n "
        coordinator.parent.text = raw
        try await SystemPageHost.settle(fixture.window)
        #expect(editor.undoManager?.canUndo != true)
        SearchMultilineUndoTests.assertValue(raw, field: field, fixture: fixture)
        let selection = NSRange(location: 5, length: 7)
        editor.setSelectedRange(selection)
        try await Self.key(command: command, in: fixture.window)
        SearchMultilineUndoTests.assertValue(expected, field: field, fixture: fixture)
        #expect(editor.selectedRange() == selection)
        #expect(fixture.window.firstResponder === editor)
        try #require(editor.tryToPerform(Selector(("undo:")), with: nil))
        try await SystemPageHost.settle(fixture.window)
        SearchMultilineUndoTests.assertValue(raw, field: field, fixture: fixture)
        try #require(editor.tryToPerform(Selector(("redo:")), with: nil))
        try await SystemPageHost.settle(fixture.window)
        SearchMultilineUndoTests.assertValue(expected, field: field, fixture: fixture)
        #expect(fixture.window.makeFirstResponder(nil))
        try await SystemPageHost.settle(fixture.window)
        #expect(field.stringValue == expected && coordinator.parent.text == expected)
        #expect(fixture.draft.commits == 0 && fixture.draft.diaryCommits == 0)
    }

    static func key(command: Bool = false, shift: Bool = false, code: UInt16 = 36,
                    text: String = "\r", in window: NSWindow) async throws {
        try #require(window.isKeyWindow && NSApp.isActive)
        var received = 0
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated { if event.window === window && event.keyCode == code { received += 1 } }
            return event
        }
        defer { if let monitor { NSEvent.removeMonitor(monitor) } }
        // 原 sendEvent 不更新 currentEvent；队列派发让捕获的快捷键判断得到真实按键上下文。
        var flags: NSEvent.ModifierFlags = command ? .command : []
        if shift { flags.insert(.shift) }
        let event: NSEvent
        if command && code == 6 {
            // 原 keyEvent 工厂的合成 ⌘⇧Z 不派发菜单 action；原生键盘构造经桌面对照验证。
            // 只在进程内 postEvent，不向系统或其他进程投递 CGEvent。
            let native = try #require(CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true))
            native.flags = CGEventFlags(rawValue: UInt64(flags.rawValue))
            event = try #require(NSEvent(cgEvent: native))
            try #require(event.characters == text && event.charactersIgnoringModifiers == (shift ? text.uppercased() : text))
        } else {
            event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero,
                modifierFlags: flags, timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, characters: shift && !command ? text.uppercased() : text,
                charactersIgnoringModifiers: shift ? text.uppercased() : text, isARepeat: false, keyCode: code))
        }
        try #require(event.keyCode == code && event.modifierFlags == flags)
        NSApp.postEvent(event, atStart: false)
        try await FormInputTestSupport.wait { received == 1 }
        try await SystemPageHost.settle(window)
        #expect(received == 1)
    }

    static let samples: [(String, String)] = [
        ("ordinary", "ordinary"), ("甲\n乙", "甲 乙"), ("甲\n乙\n丙", "甲 乙 丙"),
        ("甲\r\n乙", "甲  乙"), ("甲\r乙", "甲 乙"),
        ("甲\u{2028}乙", "甲 乙"), ("甲\u{2029}乙", "甲 乙"), ("甲\u{0085}乙", "甲 乙"),
        ("甲\u{000B}乙", "甲 乙"), ("甲\u{000C}乙", "甲 乙"),
        (" 甲\n\n 乙 ", " 甲   乙 "), ("\n甲\n", " 甲 "),
        ("甲 // 原注\n乙", "甲 // 原注 乙"), ("甲 ／／ 原注\n乙", "甲 ／／ 原注 乙"),
        ("e\u{301}\n中文🧪", "e\u{301} 中文🧪"), ("#工作\n!p1 @12:00", "#工作 !p1 @12:00"),
        (#"甲\n乙"#, #"甲\n乙"#)
    ]
}
