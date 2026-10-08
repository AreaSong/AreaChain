import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchSubtaskInteractionTests {
    @Test(arguments: [0, 3]) func nativeCreationUsesParentParameterAndActualChildOutput(style: Int) async throws {
        let fixture = try UnifiedSearchSubtaskFixture()
        defer { fixture.results.stop() }
        let host = try await fixture.host(style)
        defer { host.close() }
        let before = fixture.service.base.todo.snapshot
        let startedAt = Date()
        try await fixture.selectCommand("/subtasks/add", host: host)
        #expect(fixture.controller.editingDraft?.targets == CommandDraftTargets.none)
        try await fixture.title("Native 子任务 !p1 @09:30 #New #恢复", host: host)
        try await fixture.mode(.add, host: host)
        try await host.clickCompositionControl("unified.tags.choose")
        try await host.clickCompositionControl("unified.tags.row." + fixture.service.base.live.id.uuidString)
        try await host.clickCompositionControl("unified.tags.accept")
        let accepted = try await fixture.prepare(host, name: "create-\(style)")
        let facts = try await fixture.submit(host, name: "create-\(style)", chord: style == 3)
        let child = try fixture.service.storedChild(accepted.object.id)
        #expect(facts.createdObject == accepted.object && child.id != fixture.parent.id && child.todo?.id == fixture.parent.id)
        #expect(child.title == "Native 子任务 !p1 @09:30" && child.sortOrder == 10 && !child.isDone)
        #expect(child.createdAt >= startedAt && child.createdAt <= Date() && child.deletedAt == nil)
        #expect(TagIDList.parse(child.tagIDs) == [try #require(accepted.tagCreationIDs["new"]), fixture.service.base.deleted.id, fixture.service.base.live.id])
        #expect(try fixture.service.children().count == 5 && fixture.service.tags().count == 3)
        #expect(try fixture.service.base.io.readTodos().count == 2)
        #expect(fixture.controller.settingExecution?.outputs.isEmpty == true)
        try fixture.service.assertParentUnchanged(before)
    }

    @Test(arguments: [1, 2]) func nativeTitleUsesOnlyTagSyntax(style: Int) async throws {
        let fixture = try UnifiedSearchSubtaskFixture()
        defer { fixture.results.stop() }
        let host = try await fixture.host(style)
        defer { host.close() }
        let before = fixture.service.base.todo.snapshot
        let childBefore = try #require(fixture.service.child.snapshot)
        try await fixture.selectCommand("/subtasks/title", host: host)
        #expect(fixture.controller.editingDraft?.targets.objects == [fixture.child])
        try await fixture.title("Native 标题 !p2 @18:00 #New #恢复", host: host)
        let accepted = try await fixture.prepare(host, name: "title-\(style)")
        let facts = try await fixture.submit(host, name: "title-\(style)", chord: style == 1)
        let child = try fixture.service.storedChild()
        #expect(facts.createdObject == nil && facts.object == fixture.child && facts.savedTitle == child.title)
        #expect(child.title == "Native 标题 !p2 @18:00" && !child.isDone && child.sortOrder == 3)
        #expect(TagIDList.parse(child.tagIDs) == [fixture.service.base.live.id, try #require(accepted.tagCreationIDs["new"]), fixture.service.base.deleted.id])
        try fixture.service.assertParentUnchanged(before)
        try fixture.assertChildPreserved(childBefore, except: "title")
    }

    @Test(arguments: [false, true]) func nativeCompletionAndReopeningAreExplicit(reopen: Bool) async throws {
        let fixture = try UnifiedSearchSubtaskFixture(done: reopen)
        defer { fixture.results.stop() }
        let host = try await fixture.host(reopen ? 1 : 2)
        defer { host.close() }
        let before = fixture.service.base.todo.snapshot
        let childBefore = try #require(fixture.service.child.snapshot)
        let siblingBefore = fixture.service.sibling.snapshot
        try await fixture.selectCommand("/subtasks/completion", host: host)
        for _ in 0..<(reopen ? 2 : 1) {
            let picker = try await host.compositionPicker("unified.parameter.boolean.enabled")
            try await PickerNativeTestSupport.keyboardSelection(picker, moveDown: true, in: host.window)
        }
        let name = reopen ? "reopen" : "complete"
        _ = try await fixture.prepare(host, name: name)
        let target = try host.resultNode("unified.subtask.targetTitle")
        let labels = ["accessibilityLabel", "accessibilityValue"].compactMap { SettingsButtonTestSupport.value(target, $0) as? String }
        #expect(labels.contains(reopen ? "Subtask: 子标题" : "子任务：子标题"))
        #expect(DetailCompletionFixture.strings(in: host.window).contains(reopen ? "Done → Open" : "未完成 → 已完成"))
        try await host.revealSettingControlInsidePanel("unified.subtask.targetTitle")
        try SettingsButtonTestSupport.assertBounds([target], in: host.window)
        try host.snapshot("tm3-" + name + "-target")
        let facts = try await fixture.submit(host, name: name, chord: reopen)
        #expect(facts.savedCompletion == !reopen && facts.createdObject == nil)
        #expect(try fixture.service.storedChild().isDone == !reopen)
        #expect(try fixture.service.storedChild(fixture.service.sibling.id).snapshot == siblingBefore)
        try fixture.service.assertParentUnchanged(before)
        try fixture.assertChildPreserved(childBefore, except: "completion")
    }

    @Test(arguments: [CommandFieldOperation.add, .remove, .replaceAll, .clear])
    func nativeTagSetsKeepTemporarySelectionAndRealAssociations(mode: CommandFieldOperation) async throws {
        let fixture = try UnifiedSearchSubtaskFixture()
        defer { fixture.results.stop() }
        let host = try await fixture.host(mode == .add ? 3 : 0)
        defer { host.close() }
        let before = fixture.service.base.todo.snapshot
        let childBefore = try #require(fixture.service.child.snapshot)
        try await fixture.selectCommand("/subtasks/tags", host: host)
        try await fixture.mode(mode, host: host)
        if mode.requiresValue {
            let original = fixture.controller.editingDraft?.arguments
            try await host.clickCompositionControl("unified.tags.choose")
            let id = mode == .remove ? fixture.service.base.live.id : fixture.service.base.deleted.id
            try await host.clickCompositionControl("unified.tags.row." + id.uuidString)
            #expect(fixture.controller.editingDraft?.arguments == original)
            try await host.clickCompositionControl("unified.tags.accept")
        }
        let name = "tags-" + mode.rawValue
        _ = try await fixture.prepare(host, name: name)
        let facts = try await fixture.submit(host, name: name, chord: mode == .replaceAll)
        let expected = mode == .add ? [fixture.service.base.live.id, fixture.service.base.deleted.id]
            : mode == .replaceAll ? [fixture.service.base.deleted.id] : []
        #expect(facts.savedTagIDs == expected && facts.createdObject == nil)
        #expect(try fixture.service.storedChild().tagIDs == TagIDList.encode(expected))
        #expect(try fixture.service.tags().count == 2)
        try fixture.service.assertParentUnchanged(before)
        try fixture.assertChildPreserved(childBefore, except: "tags")
        let count = try host.resultNode("unified.subtask.savedTagCount")
        let labels = ["accessibilityLabel", "accessibilityValue"].compactMap { SettingsButtonTestSupport.value(count, $0) as? String }
        #expect(labels.contains(mode == .add ? "已保存的关联标签：2 个" : "Saved linked tags: \(expected.count)"))
        try await host.revealSettingControlInsidePanel("unified.subtask.savedTagCount")
        try SettingsButtonTestSupport.assertBounds([count], in: host.window)
    }
}
