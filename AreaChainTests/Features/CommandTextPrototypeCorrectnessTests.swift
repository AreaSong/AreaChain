#if AREACHAIN_QA
import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct CommandTextPrototypeCorrectnessTests {
    @Test func nativeTextKitNetworkIdentity() throws {
        let f = try ProtectedDraftFixture(configured: false)
        try f.start()
        let system = CommandTextSystem.textKit2()
        let layout = try #require(system.container.textLayoutManager)
        let content = try #require(layout.textContentManager as? NSTextContentStorage)
        let storage = try #require(content.textStorage)
        let editor = CommandProtectedTextView(session: f.service, textSystem: system)
        defer { editor.end() }
        try editor.begin(using: f.service.explicitlyEditOrdinary(f.draft().stamp, expecting: f.host.owned().lease))
        editor.insertText("文本🙂", replacementRange: .init(location: 0, length: editor.string.utf16.count))
        #expect(content === editor.textContentStorage && storage === editor.textStorage)
        #expect(layout === editor.textLayoutManager && storage.length == 4)
    }

    @Test(arguments: CommandTextPrototype.allCases, [false, true])
    func acceptedTextKeepsHostFontAndColor(engine: CommandTextPrototype, protected: Bool) throws {
        let f = try ProtectedDraftFixture()
        try f.start()
        if protected { _ = try f.service.protect(f.draft().stamp, expecting: f.host.owned().lease) }
        let editor = CommandProtectedTextView(session: f.service, textSystem: engine.system())
        let font = NSFont.systemFont(ofSize: DaybookType.bodySize)
        let color = NSColor(DaybookPalette.text.primary)
        editor.font = font
        editor.textColor = color
        defer { editor.end() }
        try editor.begin(using: protected ? f.restore() : f.service.explicitlyEditOrdinary(f.draft().stamp, expecting: f.host.owned().lease))
        editor.insertText("原文🙂\n第二段", replacementRange: .init(location: 0, length: editor.string.utf16.count))
        let storage = try #require(editor.textStorage)
        for index in [0, storage.length - 1] {
            // AppKit 可为中文解析出 PingFang 回退字体；宿主字号不能变成缺属性时的 Helvetica 12。
            let renderedFont = try #require(storage.attribute(.font, at: index, effectiveRange: nil) as? NSFont)
            #expect(renderedFont.pointSize == font.pointSize)
            #expect(storage.attribute(.foregroundColor, at: index, effectiveRange: nil) as? NSColor == color)
        }
        editor.setSelectedRange(.init(location: 0, length: 2))
        editor.insertText("替换", replacementRange: editor.selectedRange())
        editor.undoManager?.undo()
        #expect(editor.string == "原文🙂\n第二段")
        #expect(storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor == color)
        _ = try CommandTextPrototypeChecks.current(editor, service: f.service, vault: f.vault)
    }

    @Test(arguments: CommandTextPrototype.allCases, [false, true])
    func unicodeCompositionFailureUndoAndRevocation(engine: CommandTextPrototype, protected: Bool) throws {
        let f = try ProtectedDraftFixture()
        try f.start()
        if protected { _ = try f.service.protect(f.draft().stamp, expecting: f.host.owned().lease) }
        let editor = CommandProtectedTextView(session: f.service, textSystem: engine.system())
        let observation = CommandTextPrototypeObservation(editor, engine: engine)
        defer { SealedCommandDraft.testingBeforeSeal = nil; editor.end() }
        try editor.begin(using: protected ? f.restore() : f.service.explicitlyEditOrdinary(f.draft().stamp, expecting: f.host.owned().lease))
        try observation.check()
        let original = "中文🙂e\u{301}\n尾部 / # ! @"
        editor.insertText(original, replacementRange: .init(location: 0, length: editor.string.utf16.count))
        editor.undoManager?.removeAllActions()
        editor.setSelectedRange(.init(location: 0, length: 2))
        for fragment in ["p", "pin", "拼音"] {
            editor.setMarkedText(fragment, selectedRange: .init(location: fragment.utf16.count, length: 0),
                                 replacementRange: .init(location: NSNotFound, length: 0))
            #expect(try CommandTextPrototypeChecks.current(editor, service: f.service, vault: f.vault).confirmedText == original)
            try observation.check()
        }
        editor.cancelOperation(nil)
        #expect(editor.string == original && editor.selectedRange() == NSRange(location: 0, length: 2))
        editor.setMarkedText("中", selectedRange: .init(location: 1, length: 0), replacementRange: editor.selectedRange())
        editor.unmarkText()
        #expect(editor.string == "中🙂e\u{301}\n尾部 / # ! @")
        editor.undoManager?.undo()
        #expect(editor.string == original)
        editor.undoManager?.redo()
        #expect(editor.string == "中🙂e\u{301}\n尾部 / # ! @")
        editor.undoManager?.undo()
        let oldAccess = try #require(editor.access)
        let accepted = try f.host.owned()
        editor.setSelectedRange(.init(location: 3, length: 0))
        #expect(try f.host.owned() == accepted)
        SealedCommandDraft.testingBeforeSeal = { throw PrivacyError.corruptData }
        if protected {
            editor.insertText("拒绝", replacementRange: .init(location: 0, length: 0))
        } else {
            #expect(throws: (any Error).self) { try f.service.protect(f.draft().stamp, expecting: f.host.owned().lease) }
        }
        #expect(try f.host.owned() == accepted && editor.string == original)
        SealedCommandDraft.testingBeforeSeal = nil
        editor.setMarkedText("zhong🙂", selectedRange: .init(location: 7, length: 0), replacementRange: .init(location: 0, length: 2))
        let spelling = editor.string
        _ = try CommandTextPrototypeChecks.current(editor, service: f.service, vault: f.vault)
        f.vault.lock()
        #expect(editor.string.isEmpty && !editor.hasMarkedText() && editor.access == nil)
        #expect(editor.undoManager?.canUndo == false && editor.undoManager?.canRedo == false)
        try f.unlock()
        #expect(editor.string.isEmpty)
        try editor.begin(using: protected ? f.restore() : f.service.explicitlyEditOrdinary(f.draft().stamp, expecting: f.host.owned().lease))
        #expect(editor.pendingConfirmation && !editor.hasMarkedText() && editor.string == spelling)
        editor.synchronize("旧事件", selection: .init(location: 0, length: 0), expecting: oldAccess)
        #expect(editor.string == spelling)
        editor.cancelOperation(nil)
        #expect(editor.string == original)
        try observation.check()
        _ = try CommandTextPrototypeChecks.current(editor, service: f.service, vault: f.vault)
        Attachment.record(try JSONSerialization.data(withJSONObject: observation.metadata), named: "prototype-engine.json")
    }

    @Test(arguments: CommandTextPrototype.allCases)
    func planItemAndOldOwnerCannotRenewAccess(engine: CommandTextPrototype) throws {
        let f = try ProtectedDraftFixture()
        try f.start()
        _ = try f.service.protect(f.draft().stamp, expecting: f.host.owned().lease)
        try f.host.send(.enqueue(f.draft().stamp, itemID: UUID(), plan: f.host.state().plan.stamp))
        let item = try #require(f.host.state().plan.items.first)
        try f.host.send(.plan(.beginEditing(item.stamp), f.host.state().plan.stamp))
        let access = try f.service.explicitlyRestore(item.draft.stamp, expecting: f.host.owned().lease)
        let editor = CommandProtectedTextView(session: f.service, textSystem: engine.system())
        defer { editor.end() }
        try editor.begin(using: access)
        editor.insertText("计划🙂", replacementRange: .init(location: 0, length: editor.string.utf16.count))
        #expect(try f.host.state().operations.active == nil)
        let next = try #require(f.host.state().plan.items.first)
        #expect(next.draft.version > item.draft.version)
        try f.host.send(.plan(.endEditing(next.stamp, .cancelKeepingChanges), f.host.state().plan.stamp))
        #expect(editor.access == nil && editor.string.isEmpty)
        #expect(throws: (any Error).self) { try editor.begin(using: access) }
        #expect(throws: (any Error).self) { try f.host.seal() }
    }

    @Test(arguments: CommandTextPrototype.allCases, [false, true])
    func visibleCrossViewportReplacementAndAnchors(engine: CommandTextPrototype, protected: Bool) async throws {
        let f = try ProtectedDraftFixture(configured: protected)
        try f.start()
        let original = String(repeating: "中文🙂e\u{301} 跨视口选择\n", count: 40)
        try f.host.send(.operation(.edit(f.draft().stamp, .init(parameter: .notes, operation: .replace, value: .longText(original)))))
        if protected { _ = try f.service.protect(f.draft().stamp, expecting: f.host.owned().lease) }
        let editor = CommandProtectedTextView(session: f.service, textSystem: engine.system())
        let observation = CommandTextPrototypeObservation(editor, engine: engine)
        editor.isVerticallyResizable = true
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        scroll.documentView = editor
        scroll.hasVerticalScroller = true
        let window = NSWindow(contentRect: scroll.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = scroll
        defer { editor.end(); SystemPageHost.release(window); window.close() }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        try editor.begin(using: protected ? f.restore() : f.service.explicitlyEditOrdinary(f.draft().stamp, expecting: f.host.owned().lease))
        try #require(window.makeFirstResponder(editor))
        let middle = (original as NSString).rangeOfComposedCharacterSequence(at: original.utf16.count / 2).location
        for location in [0, middle, original.utf16.count] {
            editor.setSelectedRange(.init(location: location, length: 0))
            editor.scrollRangeToVisible(editor.selectedRange())
            _ = try CommandTextPrototypeChecks.anchor(editor, range: editor.selectedRange())
            try observation.check()
        }
        editor.setSelectedRange(.init(location: 0, length: middle))
        editor.setMarkedText("替换🙂", selectedRange: .init(location: 4, length: 0), replacementRange: editor.selectedRange())
        editor.cancelOperation(nil)
        #expect(editor.string == original && editor.selectedRange() == NSRange(location: 0, length: middle))
        editor.insertText("替换🙂", replacementRange: editor.selectedRange())
        #expect(editor.string == "替换🙂" + (original as NSString).substring(from: middle))
        editor.undoManager?.undo()
        #expect(editor.string == original)
        editor.undoManager?.redo()
        _ = try CommandTextPrototypeChecks.current(editor, service: f.service, vault: f.vault)
        try observation.check()
        try CommandTextPrototypeChecks.snapshot(window, name: "CM2-correctness-\(engine.rawValue)-\(protected)")
    }
}
#endif
