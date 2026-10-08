import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchSubtaskContractTests {
    @Test(arguments: 0..<4) func oneDraftOwnsPreparationAcceptanceAndActualResult(kind: Int) async throws {
        let fixture = try UnifiedSearchSubtaskFixture()
        defer { fixture.results.stop() }
        let commands = SubtaskCommandTransactionTests.commands
        let arguments = kind < 2 ? [SubtaskCommandFixture.title("Modified #New #恢复")]
            : kind == 2 ? [TaskTM2Fixture.completion(true)] : [TaskTM2Fixture.tags(.clear)]
        try await fixture.start(commands[kind], arguments: arguments)
        let draft = try #require(fixture.controller.editingDraft)
        fixture.controller.prepareSubtask(fixture.controller.buffer)
        let preview = try #require(fixture.controller.currentSubtaskPreview)
        #expect(preview.draft == draft.stamp && preview.arguments == draft.arguments)
        #expect(fixture.controller.operations?.active == nil && fixture.controller.plan?.items.first?.draft.id == draft.id)
        fixture.controller.acceptSubtask(preview, source: fixture.controller.buffer)
        let accepted = try #require(fixture.controller.currentSubtaskAcceptance)
        #expect(fixture.service.count("save") == 0 && fixture.service.count("ui") == 0)
        let old = fixture.controller.buffer
        fixture.controller.requestOperationSubmit(old)
        let facts = try #require(fixture.controller.subtaskUnit?.subtask)
        #expect(facts.state == .saved && facts.object == accepted.object)
        #expect(facts.createdObject == (kind == 0 ? accepted.object : nil))
        #expect(fixture.controller.settingExecution?.snapshot.items.first?.draft.arguments == draft.arguments)
        fixture.controller.requestOperationSubmit(old)
        #expect(fixture.service.count("save") == 1 && fixture.service.count("ui") == 1)
    }

    @Test(arguments: [false, true]) func lastDisplayGatePreservesLocalCommitWithoutReplaying(afterSave: Bool) async throws {
        let fixture = try UnifiedSearchSubtaskFixture()
        defer { fixture.results.stop() }
        try await fixture.start("subtask.create", arguments: [SubtaskCommandFixture.title("New")])
        fixture.controller.prepareSubtask(fixture.controller.buffer)
        fixture.controller.acceptSubtask(try #require(fixture.controller.currentSubtaskPreview), source: fixture.controller.buffer)
        let accepted = try #require(fixture.controller.currentSubtaskAcceptance)
        let revoke = { try fixture.results.session.loseFocus(expecting: fixture.controller.buffer.lease.ownership) }
        if afterSave { fixture.service.afterRegistration = revoke } else { fixture.service.beforeTransaction = revoke }
        fixture.controller.requestOperationSubmit(fixture.controller.buffer)
        let facts = try #require(fixture.results.handoff.state().execution?.units.first?.subtask)
        #expect(facts.state == (afterSave ? .saved : .notSubmitted))
        #expect(facts.createdObject == (afterSave ? accepted.object : nil))
        #expect(!fixture.controller.operationVisible && fixture.service.count("save") == (afterSave ? 1 : 0))
        fixture.service.beforeTransaction = nil
        fixture.service.afterRegistration = nil
        try fixture.results.session.resumeDisplay(expecting: fixture.controller.buffer.lease)
        _ = try await fixture.results.publish()
        fixture.controller.requestOperationSubmit(fixture.controller.buffer)
        #expect(fixture.service.count("save") == (afterSave ? 1 : 0))
    }

    @Test func unassembledAndMixedPlanNeverExecuteSubset() async throws {
        let closed = try UnifiedSearchSubtaskFixture(assembled: false)
        defer { closed.results.stop() }
        try await closed.start("subtask.title", arguments: [SubtaskCommandFixture.title("New")])
        closed.controller.prepareSubtask(closed.controller.buffer)
        closed.controller.requestOperationSubmit(closed.controller.buffer)
        #expect(!closed.controller.showsSubtask && closed.controller.settingExecution == nil && closed.service.count("save") == 0)
        let fixture = try UnifiedSearchSubtaskFixture()
        defer { fixture.results.stop() }
        try await fixture.start("subtask.title", arguments: [SubtaskCommandFixture.title("New")])
        fixture.controller.prepareSubtask(fixture.controller.buffer)
        _ = try fixture.results.enqueueOperation("todo.create", arguments: TaskCreateCommandFixture.arguments())
        fixture.controller.prepareSubtask(fixture.controller.buffer)
        fixture.controller.requestOperationSubmit(fixture.controller.buffer)
        #expect(fixture.controller.subtaskPreview == nil && fixture.controller.settingExecution == nil)
        #expect(fixture.controller.plan?.items.count == 2 && fixture.service.count("save") == 0)
    }

    @Test(arguments: ["", "  ", "one\ntwo", "one\rtwo", "#密码"])
    func invalidTextRemainsInOriginalDraftOrSpelling(text: String) async throws {
        let fixture = try UnifiedSearchSubtaskFixture()
        defer { fixture.results.stop() }
        try await fixture.start("subtask.title", arguments: [])
        try fixture.results.typeParameter(.title, text: text)
        await fixture.controller.objectSelectionTask?.value
        fixture.controller.prepareSubtask(fixture.controller.buffer)
        #expect(fixture.controller.subtaskPreview == nil)
        #expect(fixture.controller.plan?.items.first?.draft.arguments.first?.value == .shortText(text)
            || fixture.controller.operations?.active?.arguments.first?.value == .shortText(text)
            || fixture.controller.parameterText.values.contains { $0[.title]?.text == text })
        #expect(fixture.service.count("save") == 0)
    }

    @Test func independentSubtaskProofIsRequiredEvenForVisibleCandidate() async throws {
        let fixture = try UnifiedSearchSubtaskFixture()
        defer { fixture.results.stop() }
        try await fixture.start("subtask.completion", arguments: [TaskTM2Fixture.completion(true)])
        #expect(fixture.controller.objectPreview(fixture.child) != nil)
        fixture.service.childProtection = .unknown
        fixture.controller.prepareSubtask(fixture.controller.buffer)
        #expect(fixture.controller.subtaskPreview == nil && fixture.controller.subtaskFailure != nil)
        #expect(fixture.service.count("save") == 0 && fixture.service.count("ui") == 0)
    }
}
