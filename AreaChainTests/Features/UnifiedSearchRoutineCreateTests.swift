import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchRoutineCreateTests {
    @Test func explicitTagPickerAndParameterChangeUseOriginalDraft() async throws {
        let fixture = try UnifiedSearchRoutineCreateFixture()
        defer { fixture.results.stop() }
        let host = try await fixture.host()
        defer { host.close() }
        try await fixture.begin(host)
        try await fixture.title("Native #New", host: host)
        try await fixture.weekdays([2], locale: "en", host: host)
        for _ in 0..<6 {
            if fixture.controller.editingDraft?.arguments.first(where: { $0.parameter == .tags })?.operation == .add { break }
            let mode = try await host.compositionPicker("unified.parameter.mode.tags")
            try await PickerNativeTestSupport.keyboardSelection(mode, moveDown: true, in: host.window)
            try await host.settle()
        }
        try #require(fixture.controller.editingDraft?.arguments.first(where: { $0.parameter == .tags })?.operation == .add)
        let oldArguments = fixture.controller.editingDraft?.arguments
        try await host.clickCompositionControl("unified.tags.choose")
        try await host.clickCompositionControl("unified.tags.row." + fixture.service.base.base.live.id.uuidString)
        #expect(fixture.controller.editingDraft?.arguments == oldArguments)
        try await host.clickCompositionControl("unified.tags.accept")
        let accepted = try await fixture.prepare(host, name: "tag-picker")
        let old = fixture.controller.buffer
        try await host.clickCompositionControl("unified.plan.edit." + accepted.preview.item.id.uuidString)
        try await fixture.title("Changed #New", host: host)
        #expect(fixture.controller.routineCreateAcceptance == nil)
        fixture.controller.acceptRoutineCreation(accepted.preview, source: old)
        fixture.controller.requestOperationSubmit(old)
        #expect(fixture.service.base.count("save") == 0)
        // 计划编辑沿原保存入口完成，随后必须重新准备并接受。
        try await host.clickCompositionControl("unified.plan.close")
        try await host.settle()
        let updated = try await fixture.prepare(host, name: "tag-picker-edited")
        #expect(updated.creationID == accepted.creationID)
        let facts = try await fixture.submit(host, name: "tag-picker-edited", chord: false)
        #expect(facts.savedRoutine?.title == "Changed")
        let tagIDs = TagIDList.parse(facts.savedRoutine?.tagIDs ?? "")
        #expect(tagIDs.contains(fixture.service.base.base.live.id))
    }

    @Test(arguments: [0, 3]) func fullNativeCreationFromEmptyResults(style: Int) async throws {
        let fixture = try UnifiedSearchRoutineCreateFixture()
        defer { fixture.results.stop() }
        let before = try fixture.service.snapshots()
        let checks = try fixture.service.base.checks()
        let host = try await fixture.host(style)
        defer { host.close() }
        try await fixture.begin(host)
        try await fixture.title("Native 散步", host: host)
        try await fixture.weekdays([1, 7], locale: style == 0 ? "en" : "zh-Hans", host: host)
        let accepted = try await fixture.prepare(host, name: "minimal-\(style)")
        let facts = try await fixture.submit(host, name: "minimal-\(style)", chord: style == 3)
        let row = try fixture.service.stored(accepted.creationID)
        #expect(row.title == "Native 散步" && row.weekdayMask == 65 && row.sortOrder == 31 && row.isEnabled)
        #expect(facts.savedRoutine == row.snapshot && row.checks.isEmpty)
        #expect(try fixture.service.snapshots().filter { $0.id != row.id } == before)
        #expect(try fixture.service.base.checks() == checks)
        #expect(fixture.service.base.notificationProcessed == 1 && fixture.service.base.calendarProcessed == 1)
        #expect(fixture.service.base.base.io.authorizations.isEmpty)
    }

    @Test(arguments: [1, 2]) func attributesAndTagEffectsNeedExplicitAcceptance(style: Int) async throws {
        let fixture = try UnifiedSearchRoutineCreateFixture()
        defer { fixture.results.stop() }
        let host = try await fixture.host(style)
        defer { host.close() }
        try await fixture.begin(host)
        try await fixture.title("散步 !p3 @09:30 #New #恢复", host: host)
        try await fixture.weekdays([2], locale: style == 1 ? "en" : "zh-Hans", host: host)
        let accepted = try await fixture.prepare(host, name: "attributes-\(style)")
        #expect(accepted.preview.composition.tags.final.map(\.effect) == [.createAndAssociate, .restoreAndAssociate])
        try await host.revealSettingControlInsidePanel("unified.routineCreate.tags")
        try host.snapshot("rm2-tags-\(style)")
        let facts = try await fixture.submit(host, name: "attributes-\(style)", chord: style == 2)
        let row = try fixture.service.stored(accepted.creationID)
        #expect(row.remindMinutes == 570 && !row.isImportant && row.isUrgent && TagIDList.parse(row.tagIDs).count == 2)
        #expect(try fixture.service.base.tags().count == 3 && fixture.service.base.base.deleted.deletedAt == nil)
        #expect(facts.authorizationRequest == .returned && fixture.service.base.base.io.authorizations == [570])
    }

    @Test func weekdayEmptyAndConflictKeepInput() async throws {
        let fixture = try UnifiedSearchRoutineCreateFixture()
        defer { fixture.results.stop() }
        let host = try await fixture.host(2)
        defer { host.close() }
        try await fixture.begin(host)
        try await fixture.title("散步 !p1", host: host)
        let labels = DetailCompletionFixture.strings(in: host.window)
        #expect(!labels.contains { $0.contains("保持原值") })
        try await host.clickCompositionControl("unified.routineCreate.prepare")
        #expect(fixture.controller.routineCreateFailure == "unified.routineCreate.weekdays")
        try await host.revealSettingControlInsidePanel("unified.routineCreate.issue")
        try host.snapshot("rm2-empty-weekdays")
        try await fixture.weekdays([1], locale: "zh-Hans", host: host)
        // 显式字段经原参数事件输入；本方法的原生证据重点是空星期和拒绝反馈。
        _ = fixture.controller.editParameter(.init(parameter: .priority, operation: .assign, value: .choice("p2")),
                                              source: fixture.controller.buffer)
        try await host.settle()
        try await host.clickCompositionControl("unified.routineCreate.prepare")
        let preview = try #require(fixture.controller.currentRoutineCreatePreview)
        #expect(preview.composition.priority.hasConflict && !preview.canAccept)
        fixture.controller.acceptRoutineCreation(preview, source: fixture.controller.buffer)
        fixture.controller.requestOperationSubmit(fixture.controller.buffer)
        #expect(fixture.controller.settingExecution == nil && fixture.service.base.count("save") == 0)
        #expect(fixture.controller.plan?.items.first?.draft.arguments.first?.value == .shortText("散步 !p1"))
        try await host.revealSettingControlInsidePanel("unified.routineCreate.title")
        try host.snapshot("rm2-priority-conflict")
    }

    @Test(arguments: [0, 1, 2]) func staleDateCatalogOrSortKeepsAcceptedInput(kind: Int) async throws {
        let fixture = try UnifiedSearchRoutineCreateFixture()
        defer { fixture.results.stop() }
        let host = try await fixture.host()
        defer { host.close() }
        try await fixture.begin(host)
        try await fixture.title("保留输入 #New", host: host)
        try await fixture.weekdays([2], locale: "en", host: host)
        let accepted = try await fixture.prepare(host, name: "stale-\(kind)")
        if kind == 0 { fixture.service.now += 86400 }
        if kind == 1 { fixture.service.base.base.live.name = "Changed"; try fixture.service.context.save() }
        if kind == 2 { fixture.service.base.other.sortOrder += 1; try fixture.service.context.save() }
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        try await host.key(36, "\r", flags: .command)
        #expect(fixture.controller.settingExecution == nil && fixture.controller.routineCreateAcceptance == nil)
        #expect(fixture.controller.plan?.items.first?.draft.arguments == accepted.preview.arguments)
        #expect(fixture.service.base.count("save") == 0 && fixture.controller.routineCreateFailure != nil)
        try await host.revealSettingControlInsidePanel("unified.routineCreate.issue")
        try host.snapshot("rm2-stale-result-\(kind)")
    }
}
