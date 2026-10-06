import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchTaskCreateRecoveryTests {
    @Test(arguments: [0, 1, 2, 3, 4]) func nativeFailureFeedbackUsesRealAdapter(kind: Int) async throws {
        let fixture = try UnifiedSearchTaskCreateFixture()
        defer { fixture.stop() }
        try fixture.start()
        if kind == 0 { fixture.io.capture.context.insert(TodoItem(title: "unsaved synthetic", dayKey: "2026-10-05")) }
        if kind == 1 { fixture.io.repositoryFactory = { TaskCreateFailureRepository($0) } }
        if kind == 2 { fixture.io.saveMode = .throwAfter }
        if kind == 3 { fixture.environment.beforePublication = { throw TaskCreateCommandIO.Failure.injected } }
        if kind == 4 { fixture.io.calendarResult = .failed }
        let host = try await fixture.host(width: 444, locale: "zh-Hans", dark: true)
        defer { host.close() }
        try await host.clickResult("unified.task.create")
        if kind == 0 {
            #expect(fixture.controller.taskCreateFailure == .dirtyContext && fixture.io.capture.context.hasChanges)
            #expect(fixture.controller.plan?.items.count == 1)
        } else {
            #expect(try fixture.facts.state == (kind == 1 ? .notSubmitted : kind == 2 ? .unknown : .saved))
            #expect(fixture.controller.planMessage == "unified.plan.notExecutable")
        }
        if kind == 2 {
            try await host.clickResult("unified.task.verify")
            #expect(fixture.controller.taskCreateVerification == .singleLive)
        }
        let saves = fixture.count("save")
        try await host.key(36, "\r", flags: .command)
        #expect(fixture.count("save") == saves)
        #expect(try fixture.io.capture.readTodos().count == (kind >= 2 ? 1 : 0))
        #expect(fixture.count("ui") == (kind == 4 ? 1 : 0))
        try await host.revealSettingControlInsidePanel("unified.task.status")
        try host.snapshot("task-create-failure-\(kind)")
    }

    @Test func nativeMaskLockAndFocusRejectOldSubmission() async throws {
        let fixture = try UnifiedSearchTaskCreateFixture()
        defer { fixture.stop() }
        try fixture.start()
        let host = try await fixture.host()
        defer { host.close() }
        let old = fixture.controller.buffer
        let other = NSWindow(contentRect: .init(x: 20, y: 20, width: 100, height: 100),
                             styleMask: [.titled], backing: .buffered, defer: false)
        other.isReleasedWhenClosed = false
        defer { other.close() }
        other.makeKeyAndOrderFront(nil)
        try await host.settle()
        fixture.controller.requestOperationSubmit(old)
        #expect(fixture.count("save") == 0 && !fixture.controller.operationVisible)
        other.orderOut(nil)
        host.window.makeKeyAndOrderFront(nil)
        try await NativeSyntaxUI.prepareFocus(in: host.window)
        try fixture.results.session.resumeDisplay(expecting: fixture.controller.buffer.lease)
        fixture.controller.refreshOperationPresentation()
        try await host.settle()
        NotificationCenter.default.post(name: .privacyWillLock, object: fixture.results.vault)
        fixture.controller.requestOperationSubmit(old)
        #expect(fixture.count("save") == 0 && fixture.controller.operations?.active != nil)
        #expect(!fixture.controller.operationVisible)
        try host.snapshot("task-create-locked")
    }

    @Test func originalLeaseAndOtherCommandStayBlocked() throws {
        let fixture = try UnifiedSearchTaskCreateFixture()
        defer { fixture.stop() }
        try fixture.start()
        let source = fixture.controller.buffer
        _ = try fixture.results.handoff.transfer()
        fixture.controller.requestOperationSubmit(source)
        #expect(fixture.count("save") == 0)
        let other = try UnifiedSearchTaskCreateFixture()
        defer { other.stop() }
        try other.results.startOperation("setting.language")
        _ = other.controller.editParameter(.init(parameter: .value, operation: .assign, value: .choice("chinese")),
                                           source: other.controller.buffer)
        other.submit()
        #expect(other.controller.settingExecution == nil && other.count("save") == 0)
    }

    @Test func unknownTombstoneAndAmbiguousRemainHistoricalUnknown() throws {
        let fixture = try UnifiedSearchTaskCreateFixture()
        defer { fixture.stop() }
        fixture.io.saveMode = .throwBefore
        try fixture.start()
        fixture.submit()
        let facts = try fixture.facts
        let context = fixture.io.capture.context
        context.insert(TodoItem(id: facts.creationID, title: "synthetic tombstone", dayKey: "2026-10-05", deletedAt: .now))
        try context.save()
        fixture.controller.verifyTaskCreate(fixture.controller.buffer)
        #expect(fixture.controller.taskCreateVerification == .tombstone)
        context.insert(TodoItem(id: facts.creationID, title: "synthetic duplicate", dayKey: "2026-10-05"))
        try context.save()
        fixture.controller.verifyTaskCreate(fixture.controller.buffer)
        #expect(fixture.controller.taskCreateVerification == .ambiguous)
        fixture.submit()
        #expect(try fixture.facts == facts && fixture.count("save") == 1)
        #expect(UnifiedSearchTaskCreateCopy.verification(.unreadable) == "unified.task.unreadable")
    }
}
