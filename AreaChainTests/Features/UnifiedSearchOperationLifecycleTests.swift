import AppKit
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchOperationLifecycleTests {
    @Test func nativeSwitchKeepRestoreCancelAndOldConfirmation() async throws {
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        _ = try await fixture.publish()
        try fixture.startOperation("clipboard.limit")
        try fixture.typeParameter(.value, text: "-")
        let original = try fixture.draft
        let host = UnifiedSearchTestHost(results: fixture.controller, operations: true)
        defer { host.close() }
        try await host.start()
        try fixture.startOperation("setting.language")
        try await host.settle()
        try host.snapshot("operation-switch")
        try await host.clickResult("unified.operation.cancel")
        #expect(try fixture.draft == original)
        try fixture.startOperation("setting.language")
        try await host.settle()
        let oldDecision = try #require(fixture.controller.operations?.pending)
        let oldSource = fixture.controller.buffer
        try await host.clickResult("unified.operation.retain")
        #expect(fixture.controller.operations?.retained.first?.id == original.id)
        try await host.clickResult("unified.operation.restore.clipboard.limit")
        #expect(try fixture.draft.id == original.id && fixture.draft.version > original.version)
        let field = try host.parameterField(.value)
        #expect(field.stringValue == "-")
        fixture.controller.resolveOperation(oldDecision, choice: .discard, source: oldSource)
        #expect(try fixture.draft.id == original.id)
        try await host.clickResult("unified.operation.disclosure")
        #expect(try fixture.draft.id == original.id)
        try host.snapshot("operation-retained-restored-collapsed")
    }

    @Test func maskAndLockRemoveNativePanelButKeepOrdinaryDraft() async throws {
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        _ = try await fixture.publish()
        try fixture.startOperation("clipboard.limit")
        let host = UnifiedSearchTestHost(results: fixture.controller, operations: true)
        defer { host.close() }
        try await host.start()
        let editor = try await host.focusParameter(.value)
        editor.insertText("42", replacementRange: editor.selectedRange())
        try await host.settle()
        let before = try fixture.draft
        let field = try host.parameterField(.value)
        let state = try #require((field.delegate as? DaybookTextField.Coordinator)?.parent.unifiedSearch)
        let old = state.buffer
        let boundary = try #require(SettingsButtonTestSupport.elements(host.window.contentView).first { $0 is UnifiedSearchOperationBoundary })
        NotificationCenter.default.post(name: .privacyMask, object: fixture.vault)
        #expect((boundary as? NSView)?.subviews.isEmpty == true && editor.string.isEmpty)
        #expect(try fixture.draft == before)
        #expect(editor.undoManager?.canUndo == false)
        #expect(!fixture.controller.operationVisible)
        try await host.settle()
        try host.snapshot("operation-masked")
        try fixture.session.resumeDisplay(expecting: fixture.controller.buffer.lease)
        fixture.controller.refreshOperationPresentation()
        try await host.settle()
        #expect((boundary as? NSView)?.subviews.isEmpty == false)
        #expect((try host.parameterField(.value)).stringValue == "42")
        NotificationCenter.default.post(name: .privacyWillLock, object: fixture.vault)
        #expect((boundary as? NSView)?.subviews.isEmpty == true)
        #expect(try fixture.draft == before)
        #expect(fixture.controller.buffer.text.isEmpty)
        #expect(fixture.controller.editParameter(.init(parameter: .value, operation: .assign, value: .number(43)), source: old) == nil)
        try host.snapshot("operation-locked")
    }

    @Test func timePartialInputCannotCommitAfterAnotherDraftRevision() async throws {
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        _ = try await fixture.publish()
        try fixture.startOperation("todo.create")
        try fixture.typeParameter(.time, text: "12:00")
        let host = UnifiedSearchTestHost(locale: "zh-Hans", results: fixture.controller, operations: true)
        defer { host.close() }
        try await host.start()
        let time = try TimePickerNativeTestSupport.picker(in: host.window)
        try await SettingsButtonTestSupport.reveal(time, in: host.window)
        let rect = time.convert(time.bounds, to: nil)
        try await TimePickerNativeTestSupport.click(NSPoint(x: rect.minX + 10, y: rect.midY), in: host.window)
        try await TimePickerNativeTestSupport.key(124, "\u{F703}", in: host.window)
        try await TimePickerNativeTestSupport.key(21, "4", in: host.window)
        #expect(try fixture.draft.arguments.first { $0.parameter == .time }?.value == .time(720))
        try fixture.typeParameter(.title, text: "新的合成参数版本")
        try await host.settle()
        let version = try fixture.draft.version
        host.window.makeFirstResponder(nil)
        try await host.settle()
        #expect(try fixture.draft.version == version)
        #expect(try fixture.draft.arguments.first { $0.parameter == .time }?.value == .time(720))
    }

    @Test func windowBlurKeepsDraftAndRequiresExplicitDisplayResume() async throws {
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        _ = try await fixture.publish()
        try fixture.startOperation("clipboard.limit")
        try fixture.typeParameter(.value, text: "28")
        let host = UnifiedSearchTestHost(results: fixture.controller, operations: true)
        defer { host.close() }
        try await host.start()
        let before = try fixture.draft
        let other = NSWindow(contentRect: .init(x: 20, y: 20, width: 100, height: 100),
            styleMask: [.titled], backing: .buffered, defer: false)
        other.isReleasedWhenClosed = false
        defer { SystemPageHost.release(other) }
        other.makeKeyAndOrderFront(nil)
        try await SystemPageHost.settle(other)
        #expect(try !fixture.controller.operationVisible && fixture.draft == before)
        host.window.makeKeyAndOrderFront(nil)
        try await host.settle()
        #expect(!fixture.controller.operationVisible)
    }

    @Test func noSettingsOrBusinessExecutionAndExternalOwnershipRejectsEdits() async throws {
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        _ = try await fixture.publish()
        let preferences = UserDefaults.standard.dictionaryRepresentation()
        try fixture.startOperation("setting.language")
        _ = fixture.controller.editParameter(.init(parameter: .value, operation: .assign, value: .choice("chinese")),
            source: fixture.controller.buffer)
        let old = fixture.controller.buffer
        for _ in 0..<3 { fixture.controller.requestOperationSubmit(old) }
        #expect(UserDefaults.standard.dictionaryRepresentation() as NSDictionary == preferences as NSDictionary)
        #expect(try fixture.handoff.state().execution == nil && fixture.handoff.state().plan.items.isEmpty)
        #expect(fixture.reads == 1 && fixture.opens.isEmpty)
        _ = try fixture.handoff.transfer()
        #expect(fixture.controller.editParameter(.init(parameter: .value, operation: .assign, value: .choice("english")), source: old) == nil)
        #expect(fixture.controller.operations == nil)
        #expect(try fixture.handoff.state(HandoffFixture.target).operations.active?.arguments.first?.value == .choice("chinese"))
    }
}
