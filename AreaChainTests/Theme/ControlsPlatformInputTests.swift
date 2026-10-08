import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct ControlsPlatformInputTests {
    @Test func shortcutAllowlistAndReleasePairing() throws {
        let session = ControlsPlatformAcceptance()
        session.start(gallery: ControlsPlatformTestSupport.gallery())
        defer { session.close() }
        session.openSelected()
        let window = try #require(session.auxiliary)
        let stamp = try #require(session.activeStamp)
        for (code, flags, expected) in [(6, NSEvent.ModifierFlags.command, "Undo"),
            (6, [.command, .shift], "Redo"), (9, .command, "Paste")] {
            let down = try key(code: UInt16(code), flags: flags, window: window)
            session.events.observe(down, stamp: stamp, editor: nil)
            session.events.observe(down, stamp: stamp, editor: nil)
            // Command 先释放也只能匹配已观察到的这一轮快捷操作。
            session.events.observe(try key(.keyUp, code: UInt16(code), window: window), stamp: stamp, editor: nil)
            let rows = try ControlsPlatformTestSupport.rows(session).filter { $0["kind"] as? String == "event" }
            let pair = Array(rows.suffix(2))
            #expect(pair.map { $0["controlKey"] as? String } == [expected, expected])
            #expect(pair[1]["pressSequence"] as? Int == pair[0]["sequence"] as? Int)
        }
        let count = session.evidence.sequence
        for flags: NSEvent.ModifierFlags in [[], .shift, [.command, .option], [.command, .control]] {
            for code: UInt16 in [6, 9, 7] {
                session.events.observe(try key(code: code, flags: flags, window: window), stamp: stamp, editor: nil)
                session.events.observe(try key(.keyUp, code: code, window: window), stamp: stamp, editor: nil)
            }
        }
        #expect(session.evidence.sequence == count && session.events.callbackCount == 0)
        #expect(try ControlsPlatformTestSupport.rows(session).allSatisfy { $0["characters"] == nil && $0["keyCode"] == nil })
    }

    @Test(arguments: SearchMultilineConsumer.ordinarySearches)
    func sampledOrdinaryUndoRedoDoesNotEdit(kind: SearchMultilineConsumer) async throws {
        let session = opened(kind)
        defer { session.close() }
        let fixture = try #require(session.input)
        let field = try await fixture.prepare()
        let editor = try #require(field.currentEditor() as? NSTextView)
        let stored = try Data(contentsOf: fixture.base.root.appendingPathComponent("history.json"))
        let todos = try fixture.base.native.container.mainContext.fetch(FetchDescriptor<TodoItem>()).map(\.snapshot)
        try #require(editor.string.isEmpty && editor.undoManager?.canUndo != true)
        try SearchMultilineBoundaryTests.importText("甲\n乙", editor: editor, namedBoard: true)
        try await SystemPageHost.settle(fixture.window)
        assertSample(session, field: field, expected: "甲 乙", location: 3)
        #expect(fixture.inputEvidence()["resultsMatchExpected"] as? Bool == true)
        try await SearchMultilineBoundaryTests.key(command: true, code: 6, text: "z", in: fixture.window)
        assertSample(session, field: field, expected: "", location: 0)
        try await SearchMultilineBoundaryTests.key(command: true, shift: true, code: 6, text: "z", in: fixture.window)
        assertSample(session, field: field, expected: "甲 乙", location: 3)
        try await SearchMultilineBoundaryTests.key(command: true, code: 6, text: "z", in: fixture.window)
        try await SearchMultilineBoundaryTests.key(code: 7, text: "x", in: fixture.window)
        assertSample(session, field: field, expected: "x", location: 1)
        #expect(fixture.inputEvidence()["resultsMatchExpected"] as? Bool == true)
        #expect(fixture.draft.commits == 0 && fixture.draft.diaryCommits == 0)
        #expect(try Data(contentsOf: fixture.base.root.appendingPathComponent("history.json")) == stored)
        #expect(try fixture.base.native.container.mainContext.fetch(FetchDescriptor<TodoItem>()).map(\.snapshot) == todos)
        let root = fixture.base.root
        session.close()
        #expect(session.listenersReleased && session.evidence.closed && fixture.window.contentView == nil)
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }

    @Test func middleInitialAndSelectionAreExplicitPreparation() async throws {
        let session = opened(.workspace, middle: true)
        defer { session.close() }
        let fixture = try #require(session.input)
        let field = try await fixture.prepare()
        let editor = try #require(field.currentEditor() as? NSTextView)
        try #require(editor.string == "头🧪尾" && editor.undoManager?.canUndo != true)
        editor.setSelectedRange(NSRange(location: 3, length: 0))
        try SearchMultilineBoundaryTests.importText("甲\n乙", editor: editor, namedBoard: true)
        try await SystemPageHost.settle(fixture.window)
        assertSample(session, field: field, expected: "头🧪甲 乙尾", location: 6)
        try #require(editor.tryToPerform(Selector(("undo:")), with: nil))
        assertSample(session, field: field, expected: "头🧪尾", location: 3)
        try #require(editor.tryToPerform(Selector(("redo:")), with: nil))
        assertSample(session, field: field, expected: "头🧪甲 乙尾", location: 6)
    }

    @Test(arguments: ["甲\n乙", #"甲\n乙"#])
    func clipboardModesAndUndoKeepRawInput(raw: String) async throws {
        let session = opened(.clipboard)
        defer { session.close() }
        let fixture = try #require(session.input)
        let field = try await fixture.prepare()
        let editor = try #require(field.currentEditor() as? NSTextView)
        try SearchMultilineBoundaryTests.importText(raw, editor: editor, namedBoard: true)
        try await SystemPageHost.settle(fixture.window)
        for mode in [ClipboardSearchMode.mixed, .exact, .regex] {
            fixture.session.searchMode = mode
            try await SystemPageHost.settle(fixture.window)
            assertSample(session, field: field, expected: raw, location: raw.utf16.count)
            #expect(fixture.inputEvidence()["resultsMatchExpected"] as? Bool == true)
            try #require(editor.tryToPerform(Selector(("undo:")), with: nil))
            assertSample(session, field: field, expected: "", location: 0)
            try #require(editor.tryToPerform(Selector(("redo:")), with: nil))
            assertSample(session, field: field, expected: raw, location: raw.utf16.count)
        }
        #expect(fixture.draft.commits == 0 && fixture.draft.diaryCommits == 0)
    }

    @Test func submittedCaptureReopenHasFreshCountersAndRejectsOldCallback() async throws {
        let session = opened(.capture)
        defer { session.close() }
        let old = try #require(session.input)
        old.draft.text = "中文"
        _ = try await old.prepare()
        try await SearchMultilineBoundaryTests.key(in: old.window)
        try #require(old.draft.commits == 1 && old.draft.text == "中文")
        let stamp = session.activeStamp
        let late = try #require(old.draft.didSubmit)
        old.window.performClose(nil)
        #expect(old.window.contentView == nil && old.draft.didSubmit == nil)
        session.openSelected()
        let fresh = try #require(session.input)
        #expect(session.activeStamp != stamp && fresh.draft.text.isEmpty && session.todoCount == 0 && session.diaryCount == 0)
        let count = session.evidence.sequence
        late(.init(kind: "todo", before: 1, after: 2, uptime: 0, wallTime: 0))
        #expect(session.evidence.sequence == count)
        fresh.draft.text = "中文"
        _ = try await fresh.prepare()
        try await SearchMultilineBoundaryTests.key(in: fresh.window)
        #expect(fresh.draft.commits == 1 && old.draft.commits == 1)
        #expect(session.events.callbackCount == 2)
    }

    private func opened(_ kind: SearchMultilineConsumer, middle: Bool = false) -> ControlsPlatformAcceptance {
        let session = ControlsPlatformAcceptance()
        session.selection = kind == .capture ? .capture : (kind == .clipboard ? .clipboard : .search)
        session.searchConsumer = kind
        session.middleInsertion = middle
        session.start(gallery: ControlsPlatformTestSupport.gallery())
        session.openSelected()
        return session
    }

    private func assertSample(_ session: ControlsPlatformAcceptance, field: NSTextField, expected: String, location: Int) {
        guard let fixture = session.input, let editor = field.currentEditor() as? NSTextView else {
            Issue.record("缺少本场景原生编辑器"); return
        }
        let undo = editor.undoManager
        let before = (undo?.groupingLevel, undo?.canUndo, undo?.canRedo, editor.selectedRange())
        for _ in 0..<3 { session.tick(); session.recordObservation() }
        SearchMultilineUndoTests.assertValue(expected, field: field, fixture: fixture)
        #expect(editor.undoManager === undo && before.0 == undo?.groupingLevel && before.1 == undo?.canUndo && before.2 == undo?.canRedo)
        #expect(editor.selectedRange() == before.3 && editor.selectedRange() == NSRange(location: location, length: 0))
        #expect(fixture.window.firstResponder === editor && field.currentEditor() === editor)
        let sample = fixture.inputEvidence()
        #expect(sample["editorMatchesQuery"] as? Bool == true && sample["fieldMatchesQuery"] as? Bool == true)
        #expect(sample.values.allSatisfy {
            $0 is Bool || $0 is Int || ($0 as? String) == fixture.kind.rawValue || ($0 as? String) == fixture.session.searchMode.rawValue
        })
    }

    private func key(_ type: NSEvent.EventType = .keyDown, code: UInt16, flags: NSEvent.ModifierFlags = [], window: NSWindow) throws -> NSEvent {
        try #require(NSEvent.keyEvent(with: type, location: .zero, modifierFlags: flags,
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            characters: "synthetic-unrecorded", charactersIgnoringModifiers: "synthetic-unrecorded", isARepeat: false, keyCode: code))
    }
}
