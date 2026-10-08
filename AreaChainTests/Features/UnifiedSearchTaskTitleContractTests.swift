import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchTaskTitleContractTests {
    @Test func explicitAssemblyAndOriginalDraftIdentity() async throws {
        let fixture = try UnifiedSearchTaskTitleFixture(assembled: false)
        defer { fixture.stop() }
        try await fixture.start()
        fixture.controller.prepareTaskTitle(fixture.controller.buffer)
        fixture.controller.requestOperationSubmit(fixture.controller.buffer)
        #expect(fixture.controller.taskTitleFailure == "unified.title.unassembled")
        #expect(fixture.controller.operations?.active != nil && fixture.controller.settingExecution == nil)
        try fixture.noWrites()
        #expect(fixture.controller.taskTitle == nil)
    }

    @Test func prepareAcceptAreReadOnlyAndPreserveOriginalPlanIdentity() async throws {
        let fixture = try UnifiedSearchTaskTitleFixture()
        defer { fixture.stop() }
        try await fixture.start("新标题 #新建 #恢复 !p1 @09:30")
        let draft = try #require(fixture.controller.editingDraft)
        let accepted = try fixture.prepareAndAccept()
        #expect(accepted.preview.binding.draft == draft.stamp)
        #expect(accepted.preview.arguments == draft.arguments && accepted.preview.draftBaseline == draft.baseline)
        #expect(accepted.preview.impact.originalValues[.title] == .text("原标题"))
        #expect(accepted.preview.impact.tags.original.count == 1)
        #expect(accepted.preview.impact.tags.original.first == accepted.preview.impact.tags.final.first)
        #expect(fixture.controller.plan?.items.first?.draft.id == draft.id && fixture.controller.operations?.active == nil)
        #expect(fixture.base.deleted.deletedAt == TaskTitleFixture.deletion)
        #expect(try fixture.base.io.context.fetchCount(FetchDescriptor<TagItem>()) == 2)
        try fixture.noWrites()
    }

    @Test(arguments: ["修改 // 备注", "修改\n第二行", "修改 // ", "#新标签", "   "])
    func unsupportedInputRemainsVerbatim(text: String) async throws {
        let fixture = try UnifiedSearchTaskTitleFixture()
        defer { fixture.stop() }
        try await fixture.start(text)
        fixture.controller.prepareTaskTitle(fixture.controller.buffer)
        #expect(fixture.controller.taskTitlePreview == nil)
        #expect(fixture.controller.plan?.items.first?.draft.arguments.first?.value == .shortText(text)
            || fixture.controller.operations?.active?.arguments.first?.value == .shortText(text)
            || fixture.controller.parameterText.values.contains { $0[.title]?.text == text })
        try fixture.noWrites()
    }

    @Test(arguments: [0, 1, 2, 3]) func narrowPlanAndProtectionRemainClosed(kind: Int) async throws {
        let fixture = try UnifiedSearchTaskTitleFixture()
        defer { fixture.stop() }
        try await fixture.start()
        if kind == 0 { fixture.io.notes = .present }
        if kind == 1 { fixture.base.protection = .unknown }
        if kind == 2 {
            let draft = try #require(fixture.controller.editingDraft)
            try #require(fixture.controller.enqueue(draft.stamp, source: fixture.controller.buffer))
            try fixture.results.startOperation("todo.create")
            try fixture.results.typeParameter(.title, text: "多步禁止")
        }
        if kind == 3 {
            let stamp = try #require(fixture.controller.editingDraft?.stamp)
            _ = fixture.controller.sendOperation(.selectTargets(stamp,
                .init(.selected, objects: [fixture.target, .init(type: .todo, id: UUID())])), source: fixture.controller.buffer)
        }
        fixture.controller.prepareTaskTitle(fixture.controller.buffer)
        fixture.controller.requestOperationSubmit(fixture.controller.buffer)
        #expect(fixture.controller.taskTitlePreview == nil && fixture.controller.settingExecution == nil)
        try fixture.noWrites()
    }

    @Test(arguments: [false, true]) func lastDisplayGateAndPostSaveFacts(afterSave: Bool) async throws {
        let fixture = try UnifiedSearchTaskTitleFixture()
        defer { fixture.stop() }
        try await fixture.start()
        _ = try fixture.prepareAndAccept()
        let revoke = { [fixture] in
            try fixture.results.session.loseFocus(expecting: fixture.controller.buffer.lease.ownership)
        }
        if afterSave { fixture.io.afterRegistration = revoke } else { fixture.io.beforeTransaction = revoke }
        let old = fixture.controller.buffer
        fixture.controller.requestOperationSubmit(old)
        #expect(try fixture.facts.state == (afterSave ? .saved : .notSubmitted))
        #expect(fixture.count("save") == (afterSave ? 1 : 0) && !fixture.controller.operationVisible)
        #expect(try fixture.stored.title == (afterSave ? "合成修改" : "原标题"))
        fixture.io.beforeTransaction = nil
        fixture.io.afterRegistration = nil
        try fixture.results.session.resumeDisplay(expecting: fixture.controller.buffer.lease)
        _ = try await fixture.results.publish()
        fixture.controller.requestOperationSubmit(old)
        fixture.controller.requestOperationSubmit(fixture.controller.buffer)
        #expect(fixture.count("save") == (afterSave ? 1 : 0))
    }

    @Test(arguments: [false, true]) func sourceCallbackCannotAcceptOrPrepareAfterDisplayLoss(atAccept: Bool) async throws {
        let fixture = try UnifiedSearchTaskTitleFixture()
        defer { fixture.stop() }
        try await fixture.start()
        if atAccept { fixture.controller.prepareTaskTitle(fixture.controller.buffer) }
        let preview = fixture.controller.taskTitlePreview
        fixture.io.sourceRead = { [fixture] in
            try fixture.results.session.loseFocus(expecting: fixture.controller.buffer.lease.ownership)
        }
        if let preview { fixture.controller.acceptTaskTitle(preview, source: fixture.controller.buffer) }
        else { fixture.controller.prepareTaskTitle(fixture.controller.buffer) }
        #expect(fixture.controller.taskTitleAcceptance == nil && !fixture.controller.operationVisible)
        try fixture.noWrites()
    }

    @Test func modelRefreshNeverOverwritesTitleInputOrInstallsSummaryBaseline() async throws {
        let fixture = try UnifiedSearchTaskTitleFixture()
        defer { fixture.stop() }
        fixture.controller.syntheticBaselines[.init(rawValue: "todo.title")] = .init([
            .init(subject: .object(fixture.target), parameter: .title): .uniform(.shortText("假的摘要基线"))])
        try await fixture.start("保留用户原始标题 #新建")
        for _ in 0..<2 { _ = try await fixture.results.publish() }
        let draft = try #require(fixture.controller.editingDraft)
        #expect(draft.baseline == CommandDraftBaseline())
        #expect(draft.arguments.first?.value == .shortText("保留用户原始标题 #新建"))
        try fixture.noWrites()
    }

    @Test func titleFeedbackNeverUsesCreationResults() {
        for state in [CommandTaskTitleFacts.State.pending, .notSubmitted, .noChange, .saved, .unknown] {
            let key = UnifiedSearchTaskTitleCopy.result(.init(targetID: UUID(), state: state))
            for language in ["en", "zh-Hans"] {
                let text = L10n.format(key, locale: Locale(identifier: language))
                #expect(text != key && !text.contains("创建") && !text.contains("Creation"))
            }
        }
    }
}
