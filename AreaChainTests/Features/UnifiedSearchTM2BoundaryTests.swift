import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchTM2BoundaryTests {
    @Test(arguments: [false, true]) func noChangeOrStaleCascadeKeepsInput(conflict: Bool) async throws {
        let fixture = try UnifiedSearchTM2Fixture(done: !conflict)
        defer { fixture.results.stop() }
        try await fixture.start("todo.completion", argument: TaskTM2Fixture.completion(true))
        let host = try await fixture.host()
        defer { host.close() }
        let accepted = try await fixture.prepare(host, name: conflict ? "conflict-before" : "noChange-before")
        if conflict { _ = try fixture.service.child("Late child") }
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        try await host.key(36, "\r", flags: .command)
        if conflict {
            #expect(fixture.controller.settingExecution == nil && fixture.controller.taskFieldFailure == "unified.field.fields")
            #expect(fixture.controller.plan?.items.first?.draft.arguments == accepted.preview.arguments)
        } else { #expect(fixture.controller.taskFieldUnit?.taskField?.state == .noChange) }
        #expect(fixture.service.count("save") == 0 && fixture.service.count("ui") == 0)
        try await host.revealSettingControlInsidePanel(conflict ? "unified.field.issue" : "unified.field.status")
        try host.snapshot(conflict ? "tm2-conflict-retained" : "tm2-noChange")
    }

    @Test(arguments: [false, true]) func unknownAndPublicationFailureShowActualFacts(unknown: Bool) async throws {
        let fixture = try UnifiedSearchTM2Fixture()
        defer { fixture.results.stop() }
        try await fixture.start("todo.createTag", argument: TaskTM2Fixture.name("New"))
        let host = try await fixture.host(1)
        defer { host.close() }
        let accepted = try await fixture.prepare(host, name: unknown ? "unknown-before" : "publication-before")
        if unknown { fixture.service.io.saveMode = .throwAfter }
        else { fixture.service.environment.beforePublication = { throw CocoaError(.fileWriteUnknown) } }
        try await host.clickCompositionControl("unified.field.save")
        let facts = try #require(fixture.controller.taskFieldUnit?.taskField)
        #expect(facts.state == (unknown ? .unknown : .saved) && facts.publicationFailed == !unknown)
        #expect(try fixture.service.tags().count == 3)
        #expect(fixture.controller.settingExecution?.snapshot.items.first?.draft.arguments == accepted.preview.arguments)
        if unknown {
            try await host.clickCompositionControl("unified.field.verify")
            #expect(fixture.controller.taskFieldUnit?.local == .unknown)
        }
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        try await host.key(36, "\r", flags: .command)
        #expect(fixture.service.count("save") == 1 && fixture.service.count("ui") == 0)
        try await host.revealSettingControlInsidePanel("unified.field.status")
        try host.snapshot(unknown ? "tm2-unknown" : "tm2-publication-failure")
    }

    @Test func newNameMarkedTextDoesNotPrepareOrSubmit() async throws {
        let fixture = try UnifiedSearchTM2Fixture()
        defer { fixture.results.stop() }
        try await fixture.start("todo.createTag", argument: TaskTM2Fixture.name("Original"))
        let host = try await fixture.host()
        defer { host.close() }
        let editor = try await host.focusParameter(.name)
        let original = fixture.controller.editingDraft?.arguments
        editor.setMarkedText("组合输入", selectedRange: .init(location: 4, length: 0), replacementRange: editor.selectedRange())
        fixture.controller.prepareTaskField(fixture.controller.buffer)
        try await host.key(36, "\r", flags: .command)
        #expect(fixture.controller.taskFieldPreview == nil && fixture.controller.editingDraft?.arguments == original)
        editor.unmarkText()
        editor.insertText("New name", replacementRange: .init(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        try await host.key(36, "\r")
        try await host.key(48, "\t")
        #expect(fixture.controller.settingExecution == nil && fixture.service.count("save") == 0)
        _ = try await fixture.prepare(host, name: "marked-completed")
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        let input = try host.editor
        input.setMarkedText("组合", selectedRange: .init(location: 2, length: 0), replacementRange: input.selectedRange())
        fixture.controller.requestOperationSubmit(fixture.controller.buffer)
        try await host.key(36, "\r", flags: .command)
        #expect(fixture.controller.settingExecution == nil && fixture.service.count("save") == 0)
        input.unmarkText()
    }

    @Test(arguments: [false, true]) func focusLossOrLockRevokesAcceptance(locked: Bool) async throws {
        let fixture = try UnifiedSearchTM2Fixture()
        defer { fixture.results.stop() }
        try await fixture.start("todo.due", argument: TaskTM2Fixture.due(nil))
        let host = try await fixture.host()
        defer { host.close() }
        let accepted = try await fixture.prepare(host, name: locked ? "lock-before" : "focus-before")
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
        let panel = try #require(SettingsButtonTestSupport.elements(host.window.contentView)
            .compactMap { $0 as? UnifiedSearchOperationBoundary }.first)
        #expect(panel.subviews.isEmpty && fixture.controller.taskFieldAcceptance == nil)
        fixture.controller.acceptTaskField(accepted.preview, source: old)
        fixture.controller.requestOperationSubmit(old)
        #expect(fixture.controller.plan?.items.first?.draft.arguments == accepted.preview.arguments)
        #expect(fixture.service.count("save") == 0 && fixture.service.count("ui") == 0)
    }

    @Test func parameterEditingRevokesAndTagCancelDoesNotChangeDraft() async throws {
        let fixture = try UnifiedSearchTM2Fixture()
        defer { fixture.results.stop() }
        try await fixture.start("todo.tags", argument: TaskTM2Fixture.tags(.clear))
        let host = try await fixture.host(3)
        defer { host.close() }
        try await fixture.mode(.tags, .add, host: host)
        try await host.clickCompositionControl("unified.tags.choose")
        try await host.clickCompositionControl("unified.tags.row." + fixture.service.base.deleted.id.uuidString)
        try await host.clickCompositionControl("unified.tags.accept")
        let accepted = try await fixture.prepare(host, name: "edit-before")
        let old = fixture.controller.buffer
        fixture.controller.beginPlanEditing(accepted.preview.item, source: old)
        await fixture.controller.objectSelectionTask?.value
        try await host.settle()
        #expect(fixture.controller.currentTaskFieldAcceptance == nil)
        try await host.clickCompositionControl("unified.tags.choose")
        try await host.clickCompositionControl("unified.tags.row." + fixture.service.base.live.id.uuidString)
        try await host.key(53, "\u{1b}")
        #expect(fixture.controller.editingDraft?.arguments == accepted.preview.arguments)
        fixture.controller.requestOperationSubmit(old)
        #expect(fixture.service.count("save") == 0 && fixture.service.count("ui") == 0)
    }
}
