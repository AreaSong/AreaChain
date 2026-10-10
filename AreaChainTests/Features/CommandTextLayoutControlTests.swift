import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct CommandTextLayoutControlTests {
    struct Case {
        let name: String
        var paragraphs = false
        var position = "end"
        var prelayout = false
        var nonContiguous = false
        var visible: String?
    }

    @Test(.serialized, arguments: [false, true])
    func sameSizeParagraphPositionAndVisibilityControls(protected: Bool) async throws {
        let cases = [Case(name: "single-start", position: "start"), Case(name: "single-middle", position: "middle"),
                     Case(name: "paragraphs-end", paragraphs: true), Case(name: "single-end-prelayout", prelayout: true),
                     Case(name: "visible-head", visible: "head"), Case(name: "visible-tail", visible: "tail"),
                     Case(name: "noncontiguous-end", nonContiguous: true)]
        let names = ProcessInfo.processInfo.environment["AREACHAIN_CM1_LAYOUT_CASES"]?.split(separator: ",").map(String.init)
        let selected = names.map { wanted in cases.filter { wanted.contains($0.name) } } ?? cases
        try #require(!selected.isEmpty && (names == nil || selected.count == names!.count))
        for test in selected { try await run(test, protected: protected) }
    }

    private func run(_ test: Case, protected: Bool) async throws {
        let f = try ProtectedDraftFixture(configured: protected)
        try f.start()
        if protected { _ = try f.service.protect(f.draft().stamp, expecting: f.host.owned().lease) }
        let editor = CommandProtectedTextView(session: f.service)
        let phases = CommandTextPerformancePhases()
        phases.install(in: editor)
        editor.layoutManager?.allowsNonContiguousLayout = test.nonContiguous
        var window: NSWindow?
        defer { editor.end(); window?.close(); CommandTextTiming.observe = nil }
        try editor.begin(using: protected ? f.restore() : f.service.explicitlyEditOrdinary(f.draft().stamp, expecting: f.host.owned().lease))
        let singleBlock = String(repeating: "中a🙂", count: 128)
        let multipleBlock = String(repeating: "中a🙂", count: 127) + "中\n🙂"
        let body = String(repeating: test.paragraphs ? multipleBlock : singleBlock, count: 1_024)
        #expect(body.utf8.count == 1_048_576)
        let preparation = ContinuousClock.now
        editor.insertText(body, replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
        editor.undoManager?.removeAllActions()
        if test.prelayout { editor.layoutManager?.ensureLayout(for: editor.textContainer!) }
        if let visible = test.visible {
            window = try await show(editor)
            if visible == "tail" { editor.scrollRangeToVisible(.init(location: editor.string.utf16.count, length: 0)) }
            else { editor.enclosingScrollView?.contentView.scroll(to: .zero) }
        }
        let prepareMS = milliseconds(since: preparation)
        for sample in 0..<6 {
            let location = location(test.position, in: editor.string)
            editor.setSelectedRange(.init(location: location, length: 0))
            editor.insertText("字", replacementRange: .init(location: NSNotFound, length: 0))
            phases.begin()
            let start = ContinuousClock.now
            editor.setMarkedText("z", selectedRange: .init(location: 1, length: 0), replacementRange: .init(location: NSNotFound, length: 0))
            let total = milliseconds(since: start)
            try #require(editor.hasMarkedText())
            var actual = NSRange()
            let caret = CommandTextTiming.measure("candidateRect") {
                editor.firstRect(forCharacterRange: editor.markedRange(), actualRange: &actual)
            }
            let current = try f.service.nativeState(#require(editor.access), owner: editor)
            let matches = (editor.string as NSString).isEqual(to: current.spelling)
            #expect(matches && editor.hasMarkedText() && editor.markedRange() == current.composition?.range)
            if let window {
                // NSTextInputClient 可以返回零宽插入点；高度、范围及可见位置才证明锚点有效。
                let visible = window.convertToScreen(editor.convert(editor.visibleRect, to: nil))
                #expect(caret.height > 0 && caret.width >= 0 && actual.location != NSNotFound)
                #expect(visible.insetBy(dx: -1, dy: -1).contains(caret.origin))
                if sample == 0, test.visible == "tail" { try snapshot(window, protected: protected) }
            }
            phases.record(mode: protected ? "protected" : "ordinary", bytes: body.utf8.count, sample: sample,
                operation: "compositionBegin", total: total,
                metadata: ["case": test.name, "paragraphs": test.paragraphs ? 1_025 : 1,
                           "position": test.position, "utf16Location": location, "visible": test.visible ?? "none",
                           "prelayout": test.prelayout, "nonContiguous": test.nonContiguous, "prepareMS": prepareMS, "candidateRectMeasuredAfterTotal": true,
                           "caretHeight": caret.height, "visibleY": editor.visibleRect.minY,
                           "frameHeight": editor.frame.height, "maxHeight": editor.maxSize.height])
            editor.insertText("中", replacementRange: editor.markedRange())
            editor.undoManager?.undo()
        }
        try phases.export()
    }

    private func snapshot(_ window: NSWindow, protected: Bool) throws {
        let view = try #require(window.contentView)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        Attachment.record(data, named: protected ? "CM1R-protected-tail.png" : "CM1R-ordinary-tail.png")
    }

    private func show(_ editor: CommandProtectedTextView) async throws -> NSWindow {
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        scroll.hasVerticalScroller = true
        scroll.documentView = editor
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        let window = NSWindow(contentRect: scroll.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = scroll
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        try await SystemPageHost.settle(window)
        try await NativeSyntaxUI.prepareFocus(in: window)
        try #require(window.makeFirstResponder(editor))
        return window
    }

    private func location(_ position: String, in text: String) -> Int {
        if position == "start" { return 0 }
        if position == "middle" { return (text as NSString).rangeOfComposedCharacterSequence(at: text.utf16.count / 2).location }
        return text.utf16.count
    }

    private func milliseconds(since start: ContinuousClock.Instant) -> Double {
        let duration = start.duration(to: .now).components
        return Double(duration.seconds) * 1_000 + Double(duration.attoseconds) / 1e15
    }
}
