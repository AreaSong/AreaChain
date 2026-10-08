import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchCompositionBoundaryTests {
    @Test(arguments: [0, 1, 2, 3, 4, 5, 6]) func nativeRejectsUnsafeOrConflictingInput(kind: Int) async throws {
        let fixture = try UnifiedSearchTaskCreateFixture(capability: .ordinaryComposition)
        defer { fixture.stop() }
        var title = "Task #new"
        if kind == 0 { title += " !p1" }
        if kind == 1 { title += " @09:30" }
        if kind == 2 { _ = try fixture.seedTag("private", privateTag: true); title += " #private" }
        if kind == 3 { title += " #" + DiaryMemoTags.idea }
        if kind == 4 {
            _ = try fixture.seedTag("ambiguous"); _ = try fixture.seedTag("AMBIGUOUS", deleted: true)
            title += " #ambiguous"
        }
        if kind == 5 { title += " // notes" }
        try fixture.start(title: title, day: kind == 6 ? nil : "2026-10-06")
        if kind == 0 {
            _ = fixture.controller.editParameter(.init(parameter: .priority, operation: .assign, value: .choice("p2")),
                                                 source: fixture.controller.buffer)
        }
        if kind == 1 {
            _ = fixture.controller.editParameter(.init(parameter: .time, operation: .cancelReminder), source: fixture.controller.buffer)
        }
        let host = try await fixture.host(width: 444)
        defer { host.close() }
        try await host.clickCompositionControl("unified.task.prepare")
        #expect(fixture.controller.currentTaskComposition?.canPrepareExecution != true)
        if kind < 5 { try #require(fixture.controller.currentTaskComposition != nil) }
        if kind == 5 { #expect(fixture.controller.compositionFailure == "unified.composition.notes") }
        if kind == 6 { #expect(fixture.controller.compositionFailure == "unified.composition.arguments") }
        if let preview = fixture.controller.currentTaskComposition {
            fixture.controller.acceptTaskComposition(preview, source: fixture.controller.buffer)
        }
        try await host.key(36, "\r", flags: .command)
        #expect(fixture.controller.currentTaskAcceptance == nil && fixture.controller.settingExecution == nil)
        try fixture.noCompositionWrites()
        #expect(try fixture.readTags().contains { $0.name == "new" } == false)
        if kind < 2 { try host.snapshot("composition-conflict-\(kind)") }
    }

    @Test(arguments: [0, 1, 2, 3]) func nativeCatalogChangesInvalidateAcceptedEffects(kind: Int) async throws {
        let fixture = try UnifiedSearchTaskCreateFixture(capability: .ordinaryComposition)
        defer { fixture.stop() }
        let restored = try fixture.seedTag("restore", deleted: true)
        try fixture.start(title: "Task #new #restore")
        let host = try await fixture.host()
        defer { host.close() }
        _ = try await host.prepareAndAcceptComposition(fixture)
        let plan = fixture.controller.plan
        let old = fixture.controller.buffer
        switch kind {
        case 0: restored.name = "renamed"
        case 1: restored.deletedAt = nil
        case 2: restored.isPrivateDiary = true
        default: fixture.io.capture.context.insert(TagItem(name: "new", sortOrder: 1))
        }
        try fixture.io.capture.context.save()
        try await host.settle()
        #expect(fixture.controller.currentTaskAcceptance == nil && fixture.controller.currentTaskComposition == nil)
        fixture.controller.requestOperationSubmit(old)
        try await host.key(36, "\r", flags: .command)
        #expect(fixture.controller.plan == plan)
        try fixture.noCompositionWrites()
    }

    @Test(arguments: [0, 1, 2]) func nativeUnknownAndExternalFailureDoNotRecreate(kind: Int) async throws {
        let fixture = try UnifiedSearchTaskCreateFixture(capability: .ordinaryComposition)
        defer { fixture.stop() }
        let tag = try fixture.seedTag("restore", deleted: true)
        try fixture.start(title: "Task #new #restore @09:30")
        let host = try await fixture.host(width: 444, locale: "zh-Hans", dark: true)
        defer { host.close() }
        let accepted = try await host.prepareAndAcceptComposition(fixture)
        fixture.io.authorizationResult = .denied
        fixture.io.notificationResult = .succeeded
        fixture.io.calendarResult = .failed
        if kind == 0 { fixture.io.saveMode = .throwAfter }
        if kind == 1 { fixture.environment.beforePublication = { throw TaskCreateCommandIO.Failure.injected } }
        try await host.clickCompositionControl("unified.task.create")
        let facts = try fixture.facts
        #expect(facts.state == (kind == 0 ? .unknown : .saved))
        #expect((facts.savedTagEffects == nil) == (kind == 0))
        #expect(facts.savedID == (kind == 0 ? nil : accepted.creationID))
        #expect(tag.deletedAt == nil && fixture.count("save") == 1)
        #expect(try fixture.readTags().count == 2 && fixture.io.capture.readTodos().count == 1)
        if kind == 0 {
            try await host.clickCompositionControl("unified.task.verify")
            #expect(fixture.controller.taskCreateVerification == .singleLive)
        } else {
            #expect(facts.authorizationRequest == .returned && facts.authorizationResult == .denied)
            #expect(fixture.io.capture.authorizations == [570])
        }
        #expect(fixture.count("ui") == (kind == 2 ? 1 : 0))
        #expect(fixture.io.notificationProcessed == (kind == 2 ? 1 : 0))
        #expect(fixture.io.calendarProcessed == (kind == 2 ? 1 : 0))
        try await host.key(36, "\r", flags: .command)
        #expect(fixture.count("save") == 1 && fixture.controller.settingExecution != nil)
        try await host.revealSettingControlInsidePanel("unified.task.status")
        try host.snapshot("composition-feedback-\(kind)")
    }

    @Test func nativeMarkedTextFocusLockAndOldLeaseRevokeAcceptance() async throws {
        let fixture = try UnifiedSearchTaskCreateFixture(capability: .ordinaryComposition)
        defer { fixture.stop() }
        try fixture.start(title: "Task #new")
        let host = try await fixture.host()
        defer { host.close() }
        let editor = try await host.focusParameter(.title)
        editor.setMarkedText("合成", selectedRange: .init(location: 2, length: 0), replacementRange: editor.selectedRange())
        fixture.controller.prepareTaskComposition(fixture.controller.buffer)
        try await host.key(36, "\r", flags: .command)
        #expect(fixture.controller.currentTaskComposition == nil && editor.hasMarkedText())
        editor.unmarkText()
        try await host.settle()
        _ = try await host.prepareAndAcceptComposition(fixture)
        let old = fixture.controller.buffer
        let plan = fixture.controller.plan
        let other = NSWindow(contentRect: .init(x: 20, y: 20, width: 100, height: 100),
                             styleMask: [.titled], backing: .buffered, defer: false)
        other.isReleasedWhenClosed = false
        defer { other.close() }
        other.makeKeyAndOrderFront(nil)
        try await host.settle()
        #expect(!fixture.controller.operationVisible && fixture.controller.taskCompositionAccepted == nil)
        fixture.controller.requestOperationSubmit(old)
        other.orderOut(nil)
        host.window.makeKeyAndOrderFront(nil)
        try await NativeSyntaxUI.prepareFocus(in: host.window)
        try fixture.results.session.resumeDisplay(expecting: fixture.controller.buffer.lease)
        fixture.controller.refreshOperationPresentation()
        try await host.settle()
        #expect(fixture.controller.currentTaskAcceptance == nil)
        fixture.privacy.post(name: .privacyWillLock, object: fixture.results.vault)
        fixture.controller.requestOperationSubmit(old)
        #expect(!fixture.controller.operationVisible && fixture.controller.plan == plan)
        try fixture.noCompositionWrites()
        _ = try fixture.results.handoff.transfer()
        fixture.controller.requestOperationSubmit(old)
        try fixture.noCompositionWrites()
    }

    @Test(arguments: [0, 1, 2]) func injectedCallbacksCannotBypassReadSession(kind: Int) throws {
        let fixture = try UnifiedSearchTaskCreateFixture(capability: .ordinaryComposition)
        defer { fixture.stop() }
        try fixture.start(title: "Task #new")
        let revoke = { [fixture] in try fixture.results.session.loseFocus(expecting: fixture.controller.buffer.lease.ownership) }
        if kind == 0 { fixture.io.sourceRead = revoke }
        fixture.controller.prepareTaskComposition(fixture.controller.buffer)
        if kind > 0 {
            let preview = try #require(fixture.controller.currentTaskComposition)
            if kind == 1 { fixture.io.sourceRead = revoke }
            fixture.controller.acceptTaskComposition(preview, source: fixture.controller.buffer)
            if kind == 2 { fixture.io.beforeTransaction = revoke; fixture.submit() }
        }
        try fixture.noCompositionWrites()
        #expect(!fixture.controller.operationVisible)
    }

    @Test func nativeMinimalRejectsExtendedContentWithoutDroppingIt() async throws {
        let fixture = try UnifiedSearchTaskCreateFixture()
        defer { fixture.stop() }
        let restored = try fixture.seedTag("restore", deleted: true)
        try fixture.start(title: "Task #new #restore !p1 @09:30")
        let original = fixture.controller.operations?.active
        let host = try await fixture.host(width: 444)
        defer { host.close() }
        try await host.revealSettingControlInsidePanel("unified.task.create")
        try await host.key(36, "\r", flags: .command)
        #expect(fixture.controller.operations?.active == original)
        #expect(fixture.controller.taskCreateIssue == .invalidInput)
        #expect(!fixture.controller.hasTaskComposition && fixture.controller.tagSelection == nil)
        #expect(try fixture.readTags().count == 1 && restored.deletedAt != nil)
        try fixture.noCompositionWrites()
        try host.snapshot("composition-minimal-rejected")
    }
}
