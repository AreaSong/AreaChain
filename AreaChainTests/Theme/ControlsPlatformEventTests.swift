import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct ControlsPlatformEventTests {
    @Test func nestedRunLoopCallbackRemainsUnassociated() throws {
        let session = ControlsPlatformAcceptance()
        session.start(gallery: ControlsPlatformTestSupport.gallery())
        defer { session.close() }
        session.openSelected()
        let fixture = try #require(session.input)
        // 使用确定的嵌套 entry 回调；Timer 可能被 AppKit 提前 stop 的循环留到外层，不能假定已触发。
        var nestedEntries = 0
        let callbackObserver = try #require(CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.entry.rawValue, false, 1) { _, _ in
            MainActor.assumeIsolated {
                nestedEntries += 1
                fixture.draft.submit("todo")
            }
        })
        CFRunLoopAddObserver(CFRunLoopGetMain(), callbackObserver, .defaultMode)
        defer { CFRunLoopObserverInvalidate(callbackObserver) }
        session.withDispatch(try ControlsPlatformTestSupport.key(window: fixture.window), in: fixture.window) {
            CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0.05, false)
        }
        #expect(nestedEntries == 1)
        #expect(fixture.draft.commits == 1)
        let rows = try ControlsPlatformTestSupport.rows(session)
        let callbacks = rows.filter { $0["kind"] as? String == "callback" }
        #expect(callbacks.count == 1)
        let callback = try #require(callbacks.first)
        #expect(callback["association"] as? String == "unassociated" && callback["eventSequence"] is NSNull)
        #expect(rows.last { $0["kind"] as? String == "dispatch-end" }?["synchronousCallbacks"] as? Int == 0)
    }

    @Test func zeroMultipleAndForeignCallbacksKeepExactScope() throws {
        let session = ControlsPlatformAcceptance()
        session.start(gallery: ControlsPlatformTestSupport.gallery())
        defer { session.close() }
        session.openSelected()
        let fixture = try #require(session.input)
        session.withDispatch(try ControlsPlatformTestSupport.key(window: fixture.window), in: fixture.window) {}
        session.withDispatch(try ControlsPlatformTestSupport.key(window: fixture.window), in: fixture.window) {
            fixture.draft.submit("todo")
            fixture.draft.submit("todo")
        }
        let rows = try ControlsPlatformTestSupport.rows(session)
        let ends = rows.filter { $0["kind"] as? String == "dispatch-end" }
        #expect(ends.map { $0["synchronousCallbacks"] as? Int } == [0, 2])
        let callbacks = rows.filter { $0["kind"] as? String == "callback" }
        #expect(callbacks.map { $0["countAfter"] as? Int } == [1, 2])
        #expect(callbacks.allSatisfy { $0["eventSequence"] as? Int == ends[1]["eventSequence"] as? Int })
    }

    @Test func repeatPairingUnknownAndTextOmission() throws {
        let session = ControlsPlatformAcceptance()
        session.start(gallery: ControlsPlatformTestSupport.gallery())
        defer { session.close() }
        session.openSelected()
        let window = try #require(session.auxiliary)
        let stamp = try #require(session.activeStamp)
        let initial = try ControlsPlatformTestSupport.key(window: window)
        for event in [initial, initial, try ControlsPlatformTestSupport.key(repeatKey: true, window: window),
                      try ControlsPlatformTestSupport.key(.keyUp, window: window),
                      try ControlsPlatformTestSupport.key(code: 7, window: window)] {
            session.events.observe(event, stamp: stamp, editor: nil)
        }
        let events = try ControlsPlatformTestSupport.rows(session).filter { $0["kind"] as? String == "event" }
        #expect(events.count == 3)
        #expect(events.map { $0["isARepeat"] as? Bool } == [false, true, false])
        #expect(events.allSatisfy { $0["pressSequence"] as? Int == events[0]["sequence"] as? Int })
        #expect(events[0]["marked"] as? String == "unknown")
        #expect(events.allSatisfy { $0["characters"] == nil && $0["keyCode"] == nil })
        #expect(session.events.callbackCount == 0)
    }

    @Test func nativeReturnAndCommandReturnRecordActualCallbacks() async throws {
        let session = ControlsPlatformAcceptance()
        session.chinese = false
        session.start(gallery: ControlsPlatformTestSupport.gallery())
        defer { session.close() }
        session.openSelected()
        let fixture = try #require(session.input)
        fixture.draft.text = "abc"
        _ = try await fixture.prepare()
        for command in [false, true] {
            try await SearchMultilineBoundaryTests.key(command: command, in: fixture.window)
            NSApp.postEvent(try ControlsPlatformTestSupport.key(.keyUp, command: command, window: fixture.window), atStart: false)
            try await SystemPageHost.settle(fixture.window)
        }
        #expect(fixture.draft.commits == 1 && fixture.draft.diaryCommits == 1 && fixture.draft.text == "abc")
        let rows = try ControlsPlatformTestSupport.rows(session)
        let callbacks = rows.filter { $0["kind"] as? String == "callback" }
        #expect(callbacks.count == 2)
        #expect(callbacks.map { $0["callbackType"] as? String } == ["todo", "diary"])
        #expect(callbacks.allSatisfy { $0["countBefore"] as? Int == 0 && $0["countAfter"] as? Int == 1 })
        #expect(rows.filter { $0["kind"] as? String == "event" && $0["eventType"] as? String == "keyDown" }.count == 2)
        #expect(session.lastCallback.contains("0 → 1"))
        #expect(FormInputTestSupport.labels(in: fixture.window).joined(separator: " ").contains("Synthetic counters"))
    }

    @Test func exactNativeScopeAndAsynchronousCallbackStayDistinct() async throws {
        let session = ControlsPlatformAcceptance()
        session.chinese = false
        session.start(gallery: ControlsPlatformTestSupport.gallery())
        defer { session.close() }
        session.openSelected()
        let fixture = try #require(session.input)
        fixture.draft.text = "abc"
        let field = try await fixture.prepare()
        let event = try ControlsPlatformTestSupport.key(command: true, window: fixture.window)
        // 原支持的原生字段优先分支；只标记同步调用范围，不提前更改合成计数。
        session.withDispatch(event, in: fixture.window) {
            #expect(field.performKeyEquivalent(with: event))
        }
        #expect(fixture.draft.diaryCommits == 1)
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                fixture.draft.submit("diary")
                continuation.resume()
            }
        }
        let rows = try ControlsPlatformTestSupport.rows(session)
        let callbacks = rows.filter { $0["kind"] as? String == "callback" }
        #expect(callbacks.count == 2)
        #expect(callbacks[0]["association"] as? String == "synchronous-window-dispatch")
        #expect(callbacks[0]["eventSequence"] is Int)
        #expect(callbacks[1]["association"] as? String == "unassociated")
        #expect(callbacks[1]["eventSequence"] is NSNull)
        #expect(callbacks[1]["countBefore"] as? Int == 1 && callbacks[1]["countAfter"] as? Int == 2)
        #expect(rows.last { $0["kind"] as? String == "dispatch-end" }?["synchronousCallbacks"] as? Int == 1)
    }

    @Test func markedCompositionHasNoCallbackAndOtherWindowDoesNotLeak() async throws {
        let session = ControlsPlatformAcceptance()
        session.chinese = false
        session.start(gallery: ControlsPlatformTestSupport.gallery())
        defer { session.close() }
        session.openSelected()
        let fixture = try #require(session.input)
        fixture.draft.text = "abc"
        let field = try await fixture.prepare()
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.setMarkedText("拼音", selectedRange: NSRange(location: 1, length: 0),
                             replacementRange: NSRange(location: 0, length: 0))
        try await SearchMultilineBoundaryTests.key(command: true, in: fixture.window)
        #expect(fixture.draft.commits == 0 && fixture.draft.diaryCommits == 0 && editor.hasMarkedText())
        let rows = try ControlsPlatformTestSupport.rows(session)
        #expect(rows.contains { $0["kind"] as? String == "event" && $0["marked"] as? String == "true" })
        #expect(!rows.contains { $0["kind"] as? String == "callback" })
        let other = ControlsPlatformTestSupport.gallery()
        defer { SystemPageHost.release(other) }
        let before = session.evidence.sequence
        session.observe(try ControlsPlatformTestSupport.key(window: other))
        #expect(session.evidence.sequence == before)
        editor.insertText("中文", replacementRange: editor.markedRange())
        try await NativeSyntaxUI.prepareFocus(in: fixture.window)
        try await SearchMultilineBoundaryTests.key(command: true, in: fixture.window)
        #expect(fixture.draft.diaryCommits == 1 && session.events.callbackCount == 1)
    }
}
