import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct ControlsPlatformLifecycleTests {
    @Test func repeatedStartAndCloseReleaseOnce() throws {
        let session = ControlsPlatformAcceptance()
        let gallery = ControlsPlatformTestSupport.gallery()
        session.start(gallery: gallery)
        let file = try #require(session.evidenceURL)
        let original = try Data(contentsOf: file)
        session.start(gallery: gallery)
        #expect(try Data(contentsOf: file) == original)
        session.openSelected()
        let child = try #require(session.auxiliary)
        session.close()
        let finished = try Data(contentsOf: file)
        session.close()
        session.start(gallery: gallery)
        session.openSelected()
        session.recordObservation()
        #expect(try Data(contentsOf: file) == finished)
        #expect(session.state == .ended && session.listenersReleased)
        #expect(session.input == nil && child.contentView == nil && gallery.contentView == nil)
        #expect(session.evidence.closed && session.evidence.handle == nil)
        let rows = try ControlsPlatformTestSupport.rows(session)
        #expect(rows.filter { $0["kind"] as? String == "closed" }.count == 1)
        #expect(rows.filter { $0["kind"] as? String == "scene-closed" }.count == 1)
    }

    @Test func sceneSwitchAndManualClosesRejectOldIdentity() throws {
        let session = ControlsPlatformAcceptance()
        defer { session.close() }
        let gallery = ControlsPlatformTestSupport.gallery()
        session.start(gallery: gallery)
        session.openSelected()
        let old = try #require(session.auxiliary)
        let stamp = try #require(session.activeStamp)
        let late = try #require(session.input?.draft.didSubmit)
        session.selection = .search
        session.openSelected()
        #expect(old.contentView == nil && session.generation == 2)
        let current = try #require(session.auxiliary)
        let count = session.evidence.sequence
        let queued = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: stamp.openedUptime, windowNumber: current.windowNumber, context: nil,
            characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
        session.observe(queued)
        session.windowClosed(old, stamp: stamp)
        // 即使将旧代次用于当前系统窗口号，仍须同时核对对象及唯一 stamp。
        let reused = ControlsPlatformEvents.WindowStamp(generation: stamp.generation,
                                                        scene: stamp.scene, number: current.windowNumber)
        session.windowClosed(current, stamp: reused)
        late(.init(kind: "todo", before: 0, after: 1, uptime: 1, wallTime: 1))
        #expect(session.auxiliary === current && session.evidence.sequence == count)
        current.performClose(nil)
        #expect(session.auxiliary == nil && current.contentView == nil)
        session.openSelected()
        gallery.performClose(nil)
        #expect(session.state == .ended && session.listenersReleased && session.auxiliary == nil)
        let endCount = session.evidence.sequence
        late(.init(kind: "todo", before: 1, after: 2, uptime: 2, wallTime: 2))
        #expect(session.evidence.sequence == endCount)
    }

    @Test func deadlineWindDownAndCancellation() async throws {
        var time: TimeInterval = 100
        let session = ControlsPlatformAcceptance(now: { time })
        session.start(gallery: ControlsPlatformTestSupport.gallery(), seconds: 9_000)
        #expect(session.deadline == 700)
        session.openSelected()
        time = 670
        session.tick()
        #expect(session.state == .windingDown && !session.canOpen)
        #expect(session.status.contains("收尾期"))
        session.openSelected()
        #expect(session.recordedOpens == 1)
        time = 700
        session.tick()
        #expect(session.state == .ended && session.listenersReleased)
        let cancelled = ControlsPlatformAcceptance()
        cancelled.start(gallery: ControlsPlatformTestSupport.gallery())
        let task = Task { try await cancelled.waitUntilFinished() }
        task.cancel()
        do { try await task.value; Issue.record("取消应抛出 CancellationError") }
        catch { #expect(error is CancellationError) }
        #expect(cancelled.state == .ended && cancelled.listenersReleased)
        #expect(try ControlsPlatformTestSupport.rows(cancelled).last?["reason"] as? String == "cancelled")
    }

    @Test func fixtureErrorUsesSameCleanup() throws {
        let session = ControlsPlatformAcceptance()
        session.start(gallery: ControlsPlatformTestSupport.gallery())
        session.openSelected()
        let window = try #require(session.auxiliary)
        session.beforeOpen = { throw ControlsPlatformTestSupport.Failure.synthetic }
        session.openSelected()
        #expect(session.state == .ended && session.fixtureFailures == 1)
        #expect(window.contentView == nil && session.listenersReleased)
        #expect(try ControlsPlatformTestSupport.rows(session).last?["reason"] as? String == "fixtureError")
    }

    @Test func simultaneousSessionsKeepSeparateRecords() throws {
        let first = ControlsPlatformAcceptance()
        let second = ControlsPlatformAcceptance()
        defer { first.close(); second.close() }
        first.start(gallery: ControlsPlatformTestSupport.gallery())
        second.start(gallery: ControlsPlatformTestSupport.gallery())
        first.openSelected()
        second.openSelected()
        let firstSequence = first.evidence.sequence
        second.input?.draft.submit("todo")
        #expect(first.evidence.sequence == firstSequence && first.todoCount == 0 && second.todoCount == 1)
        #expect(first.evidence.url != second.evidence.url)
        first.close()
        #expect(second.state == .running && second.auxiliary != nil)
        second.close()
        for session in [first, second] {
            #expect(try ControlsPlatformTestSupport.rows(session).allSatisfy {
                $0["sessionID"] as? String == session.evidence.sessionID
            })
        }
    }

    @Test(arguments: ["create", "serialize", "write", "close"])
    func evidenceFailuresAreVisibleAndNeverComplete(stage: String) throws {
        var io = ControlsPlatformEvidence.FileIO()
        var failures: [String] = []
        var output: [String] = []
        var closes = 0
        if stage == "create" { io.create = { _ in throw ControlsPlatformTestSupport.Failure.synthetic } }
        if stage == "serialize" { io.encode = { _ in throw ControlsPlatformTestSupport.Failure.synthetic } }
        if stage == "write" { io.write = { _, _ in throw ControlsPlatformTestSupport.Failure.synthetic } }
        io.close = { handle in
            closes += 1
            if stage == "close" { throw ControlsPlatformTestSupport.Failure.synthetic }
            try handle.close()
        }
        let evidence = ControlsPlatformEvidence(io: io, reportFailure: { failures.append($0) }, output: { output.append($0) })
        let session = ControlsPlatformAcceptance(evidence: evidence)
        session.start(gallery: ControlsPlatformTestSupport.gallery())
        session.close()
        session.close()
        #expect(evidence.failure == stage && failures.count == 1)
        #expect(session.status.contains("证据不完整") && evidence.handle == nil)
        #expect(closes == (stage == "create" ? 0 : 1))
        #expect(output.contains { $0.contains("complete=false") })
        #expect(!output.contains { $0.contains("complete=true") })
    }

    @Test func exclusiveCreationPreservesExistingFile() throws {
        var failures: [String] = []
        let evidence = ControlsPlatformEvidence(reportFailure: { failures.append($0) }, output: { _ in })
        try Data("existing synthetic evidence".utf8).write(to: evidence.url)
        evidence.start()
        evidence.finish()
        #expect(evidence.failure == "create" && failures.count == 1)
        #expect(try String(contentsOf: evidence.url, encoding: .utf8) == "existing synthetic evidence")
    }

    @Test func midstreamFailureDoesNotHideIncompleteEvidence() throws {
        var writes = 0
        var failures = 0
        var io = ControlsPlatformEvidence.FileIO()
        io.write = { handle, data in
            writes += 1
            if writes == 2 { throw ControlsPlatformTestSupport.Failure.synthetic }
            try handle.write(contentsOf: data)
        }
        let evidence = ControlsPlatformEvidence(io: io, reportFailure: { _ in failures += 1 }, output: { _ in })
        let session = ControlsPlatformAcceptance(evidence: evidence)
        session.start(gallery: ControlsPlatformTestSupport.gallery())
        session.openSelected()
        #expect(evidence.failure == "write" && !session.canOpen)
        session.input?.draft.submit("todo")
        #expect(session.todoCount == 1 && failures == 1)
        session.tick()
        #expect(session.state == .ended && session.listenersReleased && evidence.handle == nil)
        let rows = try ControlsPlatformTestSupport.rows(session)
        #expect(rows.last?["kind"] as? String != "closed")
    }
}

@MainActor
enum ControlsPlatformTestSupport {
    enum Failure: Error { case synthetic }
    static func gallery() -> NSWindow {
        NSApp.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface"))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 640),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: Text("P synthetic QA"))
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        return window
    }
    static func rows(_ session: ControlsPlatformAcceptance) throws -> [[String: Any]] {
        try String(contentsOf: session.evidence.url, encoding: .utf8).split(separator: "\n").map {
            try #require(JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any])
        }
    }
    static func key(_ type: NSEvent.EventType = .keyDown, repeatKey: Bool = false,
                    command: Bool = false, code: UInt16 = 36, window: NSWindow) throws -> NSEvent {
        try #require(NSEvent.keyEvent(with: type, location: .zero, modifierFlags: command ? .command : [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, characters: code == 36 ? "\r" : "x", charactersIgnoringModifiers: code == 36 ? "\r" : "x",
            isARepeat: repeatKey, keyCode: code))
    }
}
