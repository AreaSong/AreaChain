import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct CommandTextPerformanceTests {
    @Test(arguments: [false, true])
    func inputCompositionConfirmationCheckpointAndUndoCosts(protected: Bool) throws {
        let f = try ProtectedDraftFixture(configured: protected)
        try f.start()
        if protected { _ = try f.service.protect(f.draft().stamp, expecting: f.host.owned().lease) }
        let editor = CommandProtectedTextView(session: f.service)
        let phases = CommandTextPerformancePhases()
        phases.install(in: editor)
        defer { editor.end(); CommandTextTiming.observe = nil }
        try editor.begin(using: protected ? f.restore() : f.service.explicitlyEditOrdinary(f.draft().stamp, expecting: f.host.owned().lease))
        var rows = ["mode,bytes,sample,operation,milliseconds,acceptedRevisions"]
        func measure(_ operation: String, bytes: Int, sample: Int, _ body: () -> Void) {
            phases.begin()
            let before = editor.checkpointCount
            let start = ContinuousClock.now
            body()
            let elapsed = start.duration(to: .now).components
            let milliseconds = Double(elapsed.seconds) * 1_000 + Double(elapsed.attoseconds) / 1e15
            phases.record(mode: protected ? "protected" : "ordinary", bytes: bytes, sample: sample, operation: operation, total: milliseconds)
            #expect(editor.issue == nil)
            rows.append("\(protected ? "protected" : "ordinary"),\(bytes),\(sample),\(operation),\(milliseconds),\(editor.checkpointCount - before)")
        }
        // 最大档为上限内留出 18 字节输入空间的单段；原 1MiB 档改为下方断言拒绝。
        for bytes in [1_024, CommandLongTextLimit.maxUTF8Bytes - 24] {
            editor.insertText(String(repeating: "中a🙂", count: bytes / 8),
                              replacementRange: NSRange(location: 0, length: editor.string.utf16.count))
            editor.undoManager?.removeAllActions()
            for sample in 0..<6 {
                measure("input", bytes: bytes, sample: sample) { editor.insertText("字", replacementRange: .init(location: NSNotFound, length: 0)) }
                measure("compositionBegin", bytes: bytes, sample: sample) {
                    editor.setMarkedText("z", selectedRange: .init(location: 1, length: 0), replacementRange: .init(location: NSNotFound, length: 0))
                }
                measure("compositionUpdate", bytes: bytes, sample: sample) {
                    editor.setMarkedText("zhong", selectedRange: .init(location: 5, length: 0), replacementRange: .init(location: NSNotFound, length: 0))
                }
                measure("confirm", bytes: bytes, sample: sample) { editor.insertText("中", replacementRange: editor.markedRange()) }
                measure("selectionCheckpoint", bytes: bytes, sample: sample) { editor.setSelectedRange(.init(location: 0, length: 0)) }
                measure("undo", bytes: bytes, sample: sample) { editor.undoManager?.undo() }
                editor.setSelectedRange(.init(location: editor.string.utf16.count, length: 0))
            }
            #expect(editor.string.utf8.count == bytes + 18)
        }
        let accepted = editor.string
        editor.insertText(String(repeating: "中a🙂", count: 131_072), replacementRange: NSRange(location: 0, length: accepted.utf16.count))
        #expect(editor.issue == .tooLong && editor.string == accepted)
        try phases.export()
        Attachment.record(Data(rows.joined(separator: "\n").utf8), named: "CM1-input-costs.csv")
    }

    /// 引擎取舍依据：默认 legacy 引擎在上限内最大单段的“打开到首键可用”和“首次组词”。
    /// 普通先、受保护后，在同一测试进程内各一次；3 秒只是本批是否下调上限的判断线，不是产品预算。
    @Test(.serialized, arguments: [false, true])
    func defaultEngineLimitOpenAndFirstComposition(protected: Bool) async throws {
        let f = try ProtectedDraftFixture(configured: protected)
        try f.start()
        // 单段“中a🙂”填到上限前一个块，留出首键与首次组词确认的 6 字节。
        let body = String(repeating: "中a🙂", count: CommandLongTextLimit.maxUTF8Bytes / 8 - 1)
        try f.host.send(.operation(.edit(f.draft().stamp, .init(parameter: .notes, operation: .replace, value: .longText(body)))))
        if protected { _ = try f.service.protect(f.draft().stamp, expecting: f.host.owned().lease) }
        let editor = CommandProtectedTextView(session: f.service)
        editor.font = NSFont.systemFont(ofSize: DaybookType.bodySize)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        scroll.hasVerticalScroller = true
        scroll.documentView = editor
        let window = NSWindow(contentRect: scroll.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = scroll
        defer { editor.end(); SystemPageHost.release(window); window.close() }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        try await SystemPageHost.settle(window)
        try await NativeSyntaxUI.prepareFocus(in: window)
        let open = ContinuousClock.now
        try editor.begin(using: protected ? f.restore() : f.service.explicitlyEditOrdinary(f.draft().stamp, expecting: f.host.owned().lease))
        try #require(window.makeFirstResponder(editor))
        editor.layoutManager?.ensureLayout(forBoundingRect: editor.visibleRect, in: try #require(editor.textContainer))
        window.displayIfNeeded()
        editor.insertText("字", replacementRange: .init(location: 0, length: 0))
        let openMS = Self.milliseconds(since: open)
        try #require(editor.issue == nil && editor.string.hasPrefix("字") && window.firstResponder === editor)
        let compose = ContinuousClock.now
        editor.setMarkedText("z", selectedRange: .init(location: 1, length: 0), replacementRange: .init(location: NSNotFound, length: 0))
        let composeMS = Self.milliseconds(since: compose)
        try #require(editor.hasMarkedText())
        let confirm = ContinuousClock.now
        editor.insertText("中", replacementRange: editor.markedRange())
        let confirmMS = Self.milliseconds(since: confirm)
        #expect(editor.issue == nil && editor.string.utf8.count == body.utf8.count + 6)
        let row: [String: Any] = ["engine": "legacy", "protected": protected, "bytes": body.utf8.count, "paragraphs": 1,
            "width": 400, "fontSize": DaybookType.bodySize, "openToFirstKeyMS": openMS, "firstCompositionMS": composeMS,
            "confirmMS": confirmMS, "os": ProcessInfo.processInfo.operatingSystemVersionString, "configuration": "Debug",
            "processOrder": protected ? "second-warm" : "first", "readyMeans": "restore-attach-visible-key-first-input-accepted"]
        let data = try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys])
        print("CM3_DEFAULT_ENGINE " + String(decoding: data, as: UTF8.self))
        Attachment.record(data, named: "CM3-default-engine-\(protected ? "protected" : "ordinary").json")
    }

    private static func milliseconds(since start: ContinuousClock.Instant) -> Double {
        let elapsed = start.duration(to: .now).components
        return Double(elapsed.seconds) * 1_000 + Double(elapsed.attoseconds) / 1e15
    }
}
