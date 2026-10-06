import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct SearchMultilineModeTests {
    typealias Input = SearchMultilineBoundaryTests

    @Test(arguments: [ClipboardSearchMode.mixed, .exact, .regex])
    func clipboardModeEvidence(mode: ClipboardSearchMode) async throws {
        let fixture = try SearchMultilineFixture(.clipboard)
        defer { fixture.cleanup() }
        fixture.session.searchMode = mode
        let field = try await fixture.prepare()
        let editor = try #require(field.currentEditor() as? NSTextView)
        // 外部值是匹配器对照；真实导入仍走原字段/原 session。
        fixture.session.query = "甲\n乙"
        try await SystemPageHost.settle(fixture.window)
        #expect(fixture.session.visibleItems.map(\.plainText) == ["甲\n乙 CLIP_LF"])
        for namedBoard in [false, true] {
            for raw in ["甲\n乙", #"甲\n乙"#] {
                editor.setSelectedRange(NSRange(location: 0, length: (editor.string as NSString).length))
                try Input.importText(raw, editor: editor, namedBoard: namedBoard)
                try await SystemPageHost.settle(fixture.window)
                let expected: Set<String>
                if raw == "甲\n乙" {
                    expected = mode == .mixed ? ["甲 乙 CLIP_SPACE", "甲 // 乙 CLIP_SLASH"] : ["甲 乙 CLIP_SPACE"]
                } else {
                    expected = mode == .regex ? ["甲\n乙 CLIP_LF"] : [#"甲\n乙 CLIP_ESCAPE"#]
                }
                let actual = Set(fixture.session.visibleItems.map(\.plainText))
                print("SEARCH_I_MODE \(mode) board=\(namedBoard) raw=\(raw.debugDescription) query=\(fixture.session.query.debugDescription) hits=\(actual.sorted())")
                #expect(actual == expected)
            }
        }
        #expect(fixture.draft.commits == 0)
        fixture.session.query = "甲\n乙"
        try await SystemPageHost.settle(fixture.window)
        try await Input.key(in: fixture.window)
        #expect(fixture.session.query == "甲 // 乙")
        let slashID = try #require(fixture.session.items.first { $0.plainText == "甲 // 乙 CLIP_SLASH" }?.id)
        #expect(fixture.draft.committedIDs == [slashID])
    }

    @Test(arguments: SearchMultilineConsumer.searches + [.capture])
    func markedTextAndExternalSynchronization(kind: SearchMultilineConsumer) async throws {
        let fixture = try SearchMultilineFixture(kind)
        defer { fixture.cleanup() }
        let field = try await fixture.prepare()
        let editor = try #require(field.currentEditor() as? NSTextView)
        let trace = try SearchMultilineTrace(field)
        defer { trace.restore() }
        editor.setMarkedText("甲\n乙", selectedRange: NSRange(location: 3, length: 0),
                             replacementRange: NSRange(location: 0, length: 0))
        trace.record("\(kind).multiline.marked")
        #expect(editor.hasMarkedText())
        #expect(!editor.string.contains("//") && !trace.coordinator.parent.text.contains("//"))
        trace.coordinator.parent.text = "EXTERNAL"
        try await SystemPageHost.settle(fixture.window)
        trace.record("\(kind).external.during.marked")
        #expect(editor.hasMarkedText() && !editor.string.contains("EXTERNAL"))
        let before = fixture.draft.commits + fixture.draft.diaryCommits
        try await Input.key(command: true, in: fixture.window)
        trace.record("\(kind).commandReturn.during.marked")
        if kind == .capture {
            withKnownIssue("I 同步对照：外部非空草稿启用捕获按钮后，按钮快捷键绕过组合文本保护；只登记，不修生产") {
                #expect(fixture.draft.commits + fixture.draft.diaryCommits == before)
            }
        } else { #expect(fixture.draft.commits + fixture.draft.diaryCommits == before) }
        try #require(editor.hasMarkedText())
        editor.insertText("甲\n乙", replacementRange: editor.markedRange())
        try await SystemPageHost.settle(fixture.window)
        #expect(!editor.hasMarkedText() && editor.string == "甲 乙")
        #expect(trace.coordinator.parent.text == "甲 乙")
    }

    @Test(arguments: SearchMultilineConsumer.searches + [.capture])
    func externalCommandReturnAndBlur(kind: SearchMultilineConsumer) async throws {
        let fixture = try SearchMultilineFixture(kind)
        defer { fixture.cleanup() }
        let field = try await fixture.prepare()
        let editor = try #require(field.currentEditor() as? NSTextView)
        let trace = try SearchMultilineTrace(field)
        defer { trace.restore() }
        trace.coordinator.parent.text = "甲\n乙"
        try await SystemPageHost.settle(fixture.window)
        try await Input.key(command: true, in: fixture.window)
        trace.record("\(kind).external.commandReturn")
        let expected = kind == .capture || kind == .clipboard ? "甲\n乙" : "甲 乙"
        #expect(editor.string == expected && trace.coordinator.parent.text == expected)
        #expect(fixture.draft.diaryCommits == (kind == .capture ? 1 : 0))
        #expect(fixture.draft.commits == 0)
        #expect(fixture.window.makeFirstResponder(nil))
        try await SystemPageHost.settle(fixture.window)
        trace.record("\(kind).external.blur")
        #expect(field.stringValue == expected && trace.coordinator.parent.text == expected)
    }

    @Test(arguments: [SearchMultilineConsumer.workspace, .menu, .diary, .capture])
    func tagCompletionStillOwnsReturn(kind: SearchMultilineConsumer) async throws {
        let fixture = try SearchMultilineFixture(kind)
        defer { fixture.cleanup() }
        let field = try await fixture.prepare()
        let editor = try #require(field.currentEditor() as? NSTextView)
        let coordinator = try #require(field.delegate as? DaybookTextField.Coordinator)
        editor.insertText("#工", replacementRange: NSRange(location: 0, length: 0))
        try await SystemPageHost.settle(fixture.window)
        let autocomplete = try #require(coordinator.parent.autocomplete)
        let target = try #require(autocomplete.candidates.firstIndex { $0.insertText == "#工作 " })
        print("SEARCH_I_CANDIDATES \(kind) initial=\(String(describing: autocomplete.selectedCandidate()?.insertText)) existingIndex=\(target)")
        for _ in 0..<target { try await Input.key(code: 125, text: "\u{f701}", in: fixture.window) }
        try #require(autocomplete.selectedCandidate()?.insertText == "#工作 ")
        try await Input.key(in: fixture.window)
        #expect(editor.string == "#工作 ")
        #expect(coordinator.parent.text == "#工作 ")
        #expect(fixture.draft.commits == 0 && fixture.draft.diaryCommits == 0 && fixture.draft.tokenRemovals == 0)
        #expect(editor.selectedRange() == NSRange(location: 4, length: 0))
    }

    @Test(arguments: SearchMultilineConsumer.searches + [.capture])
    func returnWhileMarkedDoesNotSubmit(kind: SearchMultilineConsumer) async throws {
        let fixture = try SearchMultilineFixture(kind)
        defer { fixture.cleanup() }
        let field = try await fixture.prepare()
        let editor = try #require(field.currentEditor() as? NSTextView)
        let trace = try SearchMultilineTrace(field)
        defer { trace.restore() }
        editor.setMarkedText("拼音", selectedRange: NSRange(location: 2, length: 0),
                             replacementRange: NSRange(location: 0, length: 0))
        try await Input.key(in: fixture.window)
        trace.record("\(kind).return.whileMarked")
        #expect(fixture.draft.commits == 0 && fixture.draft.diaryCommits == 0)
        #expect(!trace.coordinator.parent.text.contains("//"))
    }

    @Test func pureCaptureRuleIsNotNativeReproduction() {
        for (raw, expected) in [
            ("甲\n乙", "甲 // 乙"), (" 甲\n\n乙\n丙 ", "甲 // 乙 丙"),
            ("甲 // 注\n乙", "甲 // 注 乙"), ("甲 ／／ 注\n乙", "甲 ／／ 注 乙"),
            ("甲\r\n乙", "甲\r\n乙"), ("甲\r乙", "甲\r乙"), ("甲\u{2028}乙", "甲\u{2028}乙")
        ] {
            #expect(DaybookTextField.sanitizeSingleLineText(raw) == expected)
        }
        let capture = NaturalLanguageParser.parseTaskCapture("甲\n乙")
        #expect(capture.cleanTitle == "甲" && capture.notes == "乙")
        #expect(BoardSearch.parseQuery("甲\n乙").textKeywords == ["甲", "乙"])
        #expect(BoardSearch.parseQuery("甲 // 乙").textKeywords == ["甲", "//", "乙"])
    }

    @Test(arguments: SearchMultilineConsumer.searches + [.capture])
    func syntheticMarkedNotificationsDoNotRewriteText(kind: SearchMultilineConsumer) async throws {
        let fixture = try SearchMultilineFixture(kind)
        defer { fixture.cleanup() }
        let field = try await fixture.prepare()
        let editor = try #require(field.currentEditor() as? NSTextView)
        let coordinator = try #require(field.delegate as? DaybookTextField.Coordinator)
        editor.setMarkedText("🧪甲\n乙", selectedRange: NSRange(location: 3, length: 0),
                             replacementRange: NSRange(location: 0, length: 0))
        let selection = editor.selectedRange()
        let markedRange = editor.markedRange()
        // 合成通知补足系统 IME 未主动发出多行变更通知的边界，不冒充真人 IME。
        coordinator.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
        NotificationCenter.default.post(name: NSText.didChangeNotification, object: editor)
        #expect(editor.hasMarkedText() && editor.string == "🧪甲\n乙")
        #expect(editor.selectedRange() == selection && editor.markedRange() == markedRange)
        #expect(coordinator.parent.text == editor.string)
        #expect(!coordinator.prepareSubmission(editor: editor))
        #expect(editor.string == "🧪甲\n乙" && editor.hasMarkedText())
        editor.insertText("甲乙", replacementRange: editor.markedRange())
        try await SystemPageHost.settle(fixture.window)
        SearchMultilineUndoTests.assertValue("甲乙", field: field, fixture: fixture)
        #expect(fixture.draft.commits == 0 && fixture.draft.diaryCommits == 0)
    }
}
