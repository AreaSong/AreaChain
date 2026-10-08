import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchSubtaskBoundaryTests {
    @Test(arguments: [false, true]) func parentAndChildSwitchRevokeOldAcceptance(creation: Bool) async throws {
        let fixture = try UnifiedSearchSubtaskFixture()
        defer { fixture.results.stop() }
        try await fixture.start(creation ? "subtask.create" : "subtask.title", arguments: [SubtaskCommandFixture.title("唯一草稿 #New")])
        let host = try await fixture.host(creation ? 0 : 3)
        defer { host.close() }
        let accepted = try await fixture.prepare(host, name: creation ? "parent-switch" : "child-switch")
        let old = fixture.controller.buffer
        try await host.clickCompositionControl("unified.plan.edit." + accepted.preview.item.id.uuidString)
        let object = CommandObjectReference(type: creation ? .todo : .subtask,
                                            id: creation ? fixture.secondParent.id : fixture.secondChild.id)
        try await fixture.select(object, location: creation ? "parent" : "target", host: host)
        #expect(fixture.controller.currentSubtaskAcceptance == nil)
        #expect(fixture.controller.editingDraft?.arguments.first { $0.parameter == .title }?.value == .shortText("唯一草稿 #New"))
        if creation {
            #expect(fixture.controller.editingDraft?.arguments.first { $0.parameter == .parent }?.value == .object(object))
            #expect(fixture.controller.editingDraft?.targets == CommandDraftTargets.none)
        } else { #expect(fixture.controller.editingDraft?.targets.objects == [object]) }
        fixture.controller.acceptSubtask(accepted.preview, source: old)
        fixture.controller.requestOperationSubmit(old)
        #expect(fixture.service.count("save") == 0 && fixture.service.count("ui") == 0)
        try host.snapshot(creation ? "tm3-parent-switched" : "tm3-child-switched")
    }

    @Test(arguments: [0, 1, 2]) func staleRelationshipDirtyInputAndNoChangeAreDistinct(kind: Int) async throws {
        let fixture = try UnifiedSearchSubtaskFixture()
        defer { fixture.results.stop() }
        try await fixture.start("subtask.title", arguments: [SubtaskCommandFixture.title(kind == 2 ? "子标题" : "修改")])
        let host = try await fixture.host()
        defer { host.close() }
        let accepted = try await fixture.prepare(host, name: "conflict-\(kind)")
        if kind == 0 { fixture.service.child.todo = fixture.secondParent; try fixture.service.context.save() }
        if kind == 1 { fixture.service.base.todo.title = "未保存父标题" }
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        try await host.key(36, "\r", flags: .command)
        if kind == 2 { #expect(fixture.controller.subtaskUnit?.subtask?.state == .noChange) }
        else {
            #expect(fixture.controller.settingExecution == nil && fixture.controller.subtaskFailure != nil)
            #expect(fixture.controller.plan?.items.first?.draft.arguments == accepted.preview.arguments)
        }
        if kind == 1 { #expect(fixture.service.context.hasChanges && fixture.service.base.todo.title == "未保存父标题") }
        #expect(fixture.service.count("save") == 0 && fixture.service.count("ui") == 0)
        try await host.revealSettingControlInsidePanel(kind == 2 ? "unified.subtask.status" : "unified.subtask.issue")
        try host.snapshot("tm3-conflict-result-\(kind)")
    }

    @Test(arguments: [false, true]) func unknownAndPublicationFailureRetainActualRun(unknown: Bool) async throws {
        let fixture = try UnifiedSearchSubtaskFixture()
        defer { fixture.results.stop() }
        try await fixture.start("subtask.create", arguments: [SubtaskCommandFixture.title("New #New #恢复")])
        let host = try await fixture.host(1)
        defer { host.close() }
        let accepted = try await fixture.prepare(host, name: unknown ? "unknown" : "publication")
        if unknown { fixture.service.saveMode = .throwAfter }
        else { fixture.service.environment.beforePublication = { throw CocoaError(.fileWriteUnknown) } }
        try await host.clickCompositionControl("unified.subtask.save")
        let facts = try #require(fixture.controller.subtaskUnit?.subtask)
        #expect(facts.state == (unknown ? .unknown : .saved) && facts.publicationFailed == !unknown)
        #expect(facts.object == accepted.object && facts.createdObject == (unknown ? nil : accepted.object))
        #expect(try fixture.service.children().count == 5 && fixture.service.tags().count == 3)
        #expect(fixture.controller.settingExecution?.snapshot.items.first?.draft.arguments == accepted.preview.arguments)
        if unknown {
            try await host.clickCompositionControl("unified.subtask.verify")
            #expect(fixture.controller.subtaskVerification == .singleLive && fixture.controller.subtaskUnit?.local == .unknown)
        }
        fixture.controller.requestOperationSubmit(fixture.controller.buffer)
        #expect(fixture.service.count("save") == 1 && fixture.service.count("ui") == 0)
        try await host.revealSettingControlInsidePanel("unified.subtask.status")
        try host.snapshot(unknown ? "tm3-unknown-result" : "tm3-publication-result")
    }

    @Test func markedTextReturnAndTabDoNotPrepareOrSubmit() async throws {
        let fixture = try UnifiedSearchSubtaskFixture()
        defer { fixture.results.stop() }
        try await fixture.start("subtask.create", arguments: [SubtaskCommandFixture.title("Original")])
        let host = try await fixture.host()
        defer { host.close() }
        let editor = try await host.focusParameter(.title)
        let original = fixture.controller.editingDraft?.arguments
        editor.setMarkedText("组合输入", selectedRange: .init(location: 4, length: 0), replacementRange: editor.selectedRange())
        fixture.controller.prepareSubtask(fixture.controller.buffer)
        try await host.key(36, "\r", flags: .command)
        #expect(fixture.controller.subtaskPreview == nil && fixture.controller.editingDraft?.arguments == original)
        editor.unmarkText()
        try await fixture.title("New", host: host)
        try await host.key(48, "\t")
        #expect(fixture.controller.settingExecution == nil && fixture.service.count("save") == 0)
        _ = try await fixture.prepare(host, name: "marked")
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        let input = try host.editor
        input.setMarkedText("组合", selectedRange: .init(location: 2, length: 0), replacementRange: input.selectedRange())
        fixture.controller.requestOperationSubmit(fixture.controller.buffer)
        try await host.key(36, "\r", flags: .command)
        #expect(fixture.controller.settingExecution == nil && fixture.service.count("save") == 0)
        input.unmarkText()
    }

    @Test(arguments: [false, true]) func focusLossAndLockRevokeAcceptance(locked: Bool) async throws {
        let fixture = try UnifiedSearchSubtaskFixture()
        defer { fixture.results.stop() }
        try await fixture.start("subtask.completion", arguments: [TaskTM2Fixture.completion(true)])
        let host = try await fixture.host()
        defer { host.close() }
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
        let panel = try #require(SettingsButtonTestSupport.elements(host.window.contentView)
            .compactMap { $0 as? UnifiedSearchOperationBoundary }.first)
        #expect(panel.subviews.isEmpty && fixture.controller.subtaskAcceptance == nil)
        fixture.controller.acceptSubtask(accepted.preview, source: old)
        fixture.controller.requestOperationSubmit(old)
        #expect(fixture.controller.plan?.items.first?.draft.arguments == accepted.preview.arguments)
        #expect(fixture.service.count("save") == 0 && fixture.service.count("ui") == 0)
    }

    @Test func staleCandidatesAndTagCancelKeepOneDraft() async throws {
        let fixture = try UnifiedSearchSubtaskFixture()
        defer { fixture.results.stop() }
        try await fixture.start("subtask.tags", arguments: [TaskTM2Fixture.tags(.clear)])
        let host = try await fixture.host(3)
        defer { host.close() }
        try await host.clickCompositionControl("unified.objects.choose.target")
        await fixture.controller.objectSelectionTask?.value
        let oldPicker = try #require(fixture.controller.objectSelection?.stamp)
        _ = try await fixture.results.publish()
        #expect(!fixture.controller.acceptObjects(oldPicker))
        try await host.clickCompositionControl("unified.objects.cancel")
        try await fixture.mode(.add, host: host)
        let original = fixture.controller.editingDraft?.arguments
        try await host.clickCompositionControl("unified.tags.choose")
        try await host.clickCompositionControl("unified.tags.row." + fixture.service.base.deleted.id.uuidString)
        try await host.key(53, "\u{1b}")
        #expect(fixture.controller.editingDraft?.arguments == original && fixture.service.count("save") == 0)
    }
}
