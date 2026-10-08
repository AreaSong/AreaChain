import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchRoutineCreateBoundaryTests {
    @Test func markedTextAndCompletionKeysNeverSubmit() async throws {
        let fixture = try UnifiedSearchRoutineCreateFixture()
        defer { fixture.results.stop() }
        let host = try await fixture.host()
        defer { host.close() }
        try await fixture.begin(host)
        let editor = try await host.focusParameter(.title)
        let original = fixture.controller.editingDraft?.arguments
        editor.setMarkedText("组合", selectedRange: .init(location: 2, length: 0), replacementRange: editor.selectedRange())
        fixture.controller.prepareRoutineCreation(fixture.controller.buffer)
        try await host.key(36, "\r", flags: .command)
        #expect(fixture.controller.routineCreatePreview == nil && fixture.controller.editingDraft?.arguments == original)
        editor.unmarkText()
        try await fixture.title("Native", host: host)
        try await fixture.weekdays([2], locale: "en", host: host)
        try await host.key(48, "\t")
        #expect(fixture.controller.settingExecution == nil)
        _ = try await fixture.prepare(host, name: "marked")
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        let input = try host.editor
        input.setMarkedText("组合", selectedRange: .init(location: 2, length: 0), replacementRange: input.selectedRange())
        fixture.controller.requestOperationSubmit(fixture.controller.buffer)
        try await host.key(36, "\r", flags: .command)
        #expect(fixture.controller.settingExecution == nil && fixture.service.base.count("save") == 0)
        input.unmarkText()
    }

    @Test(arguments: [false, true]) func lossOfDisplayRevokesAcceptance(locked: Bool) async throws {
        let fixture = try UnifiedSearchRoutineCreateFixture()
        defer { fixture.results.stop() }
        let host = try await fixture.host()
        defer { host.close() }
        try await fixture.begin(host)
        try await fixture.title("Native", host: host)
        try await fixture.weekdays([2], locale: "en", host: host)
        let accepted = try await fixture.prepare(host, name: locked ? "lock" : "focus")
        let old = fixture.controller.buffer
        if locked { fixture.privacy.post(name: .privacyWillLock, object: fixture.results.vault) }
        else {
            let other = NSWindow(contentRect: .init(x: 20, y: 20, width: 100, height: 100),
                                 styleMask: [.titled], backing: .buffered, defer: false)
            other.isReleasedWhenClosed = false
            other.makeKeyAndOrderFront(nil)
            try await SystemPageHost.settle(other)
            SystemPageHost.release(other)
        }
        #expect(fixture.controller.routineCreateAcceptance == nil)
        fixture.controller.acceptRoutineCreation(accepted.preview, source: old)
        fixture.controller.requestOperationSubmit(old)
        #expect(fixture.controller.plan?.items.first?.draft.arguments == accepted.preview.arguments)
        #expect(fixture.service.base.count("save") == 0 && fixture.service.base.count("ui") == 0)
    }

    @Test(arguments: [false, true]) func unknownAndPublicationFailureKeepOneIdentity(unknown: Bool) async throws {
        let fixture = try UnifiedSearchRoutineCreateFixture()
        defer { fixture.results.stop() }
        let host = try await fixture.host(1)
        defer { host.close() }
        try await fixture.begin(host)
        try await fixture.title("Native #New #恢复", host: host)
        try await fixture.weekdays([2], locale: "en", host: host)
        let accepted = try await fixture.prepare(host, name: unknown ? "unknown" : "publication")
        if unknown { fixture.service.base.saveMode = .throwAfter }
        else { fixture.service.environment.beforePublication = { throw CocoaError(.fileWriteUnknown) } }
        try await host.clickCompositionControl("unified.routineCreate.create")
        let facts = try #require(fixture.controller.routineCreationUnit?.routineCreation)
        #expect(facts.state == (unknown ? .unknown : .saved) && facts.creationID == accepted.creationID)
        #expect(try fixture.service.context.fetchCount(FetchDescriptor<DailyRoutine>()) == 3)
        #expect(try fixture.service.base.tags().count == 3)
        if unknown {
            try await host.clickCompositionControl("unified.routineCreate.verify")
            #expect(fixture.controller.routineCreateVerification == .singleLive && fixture.controller.routineCreationUnit?.local == .unknown)
        }
        fixture.controller.requestOperationSubmit(fixture.controller.buffer)
        #expect(fixture.service.base.count("save") == 1 && fixture.service.base.count("ui") == 0)
        try await host.revealSettingControlInsidePanel("unified.routineCreate.status")
        try host.snapshot(unknown ? "rm2-unknown-result" : "rm2-publication-result")
    }
}
