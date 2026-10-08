import AppKit
import SwiftData
import Testing
@testable import AreaChain

@MainActor final class UnifiedSearchTaskFieldFixture {
    let io: TaskTitleCommandIO
    let environment: TaskTitleCommandEnvironment
    let results: UnifiedSearchResultsFixture
    let privacy = NotificationCenter()
    var controller: UnifiedSearchController { results.controller }
    var target: CommandObjectReference { .init(type: .todo, id: io.base.todo.id) }
    init() throws {
        io = try TaskTitleCommandIO()
        io.notificationResult = .succeeded
        io.calendarResult = .succeeded
        environment = try io.environment()
        var batch = QueryBatchFixture.empty("/tasks")
        batch.snapshots.todos = .complete([.init(id: io.base.todo.id, title: "Synthetic task",
            isDone: true, dayKey: "2026-10-05", createdAt: io.base.todo.createdAt)])
        results = try .init(batch, privacyCenter: privacy, taskFieldEnvironment: environment)
    }
    func start(_ kind: Int) async throws {
        try results.startOperation(TaskFieldCommandFixture.command(kind))
        try await results.acceptObjects([target])
        _ = controller.editParameter(TaskFieldCommandFixture.argument(kind), source: controller.buffer)
        await controller.objectSelectionTask?.value
    }
    func accepted() throws -> CommandTaskFieldAcceptance {
        controller.prepareTaskField(controller.buffer)
        let preview = try #require(controller.currentTaskFieldPreview)
        controller.acceptTaskField(preview, source: controller.buffer)
        return try #require(controller.currentTaskFieldAcceptance)
    }

    func assertStoredField(_ preview: CommandTaskFieldPreview, kind: Int) throws {
        let todo = try #require(io.base.io.readTodos().first)
        switch preview.edit {
        case .move(let day): #expect(todo.dayKey == day && todo.remindMinutes == 420)
        case .priority(let important, let urgent): #expect(todo.isImportant == important && todo.isUrgent == urgent)
        case .reminder(let minutes): #expect(todo.remindMinutes == minutes && todo.dayKey == "2026-10-05")
        default: Issue.record("T-M1 夹具不接受后续字段")
        }
        #expect(todo.title == "原标题" && todo.tagIDs == io.base.live.id.uuidString && todo.isDone)
        if kind != 0 { #expect(todo.dayKey == "2026-10-05") }
        if kind != 1 { #expect(todo.isImportant && !todo.isUrgent) }
        if kind == 1 { #expect(todo.remindMinutes == 420) }
        #expect(todo.createdAt == Date(timeIntervalSince1970: 456) && todo.sortOrder == 7 && todo.dueMinutes == 600)
        #expect(todo.sourceBundleID == "qa.original" && todo.calendarEventID == "qa.calendar" && todo.notes.isEmpty)
        #expect(io.base.deleted.deletedAt == TaskTitleFixture.deletion)
    }
}

@Suite(.serialized) @MainActor struct UnifiedSearchTaskFieldTests {
    @Test(arguments: [0, 1, 2, 3]) func nativeFieldsFromControlsToSavedFeedback(kind: Int) async throws {
        let fixture = try UnifiedSearchTaskFieldFixture()
        defer { fixture.results.stop() }
        let host = UnifiedSearchTestHost(layout: kind % 2 == 0 ? .standard : .compact,
            width: kind % 2 == 0 ? 444 : 304, locale: kind == 1 || kind == 2 ? "zh-Hans" : "en",
            dark: kind == 1 || kind == 2, results: fixture.controller, operations: true)
        defer { host.close() }
        _ = try await fixture.results.publish()
        try await host.start()
        let editor = try host.editor
        let path = kind == 0 ? "/tasks/move" : kind == 1 ? "/tasks/priority" : "/tasks/reminder"
        editor.insertText(path, replacementRange: .init(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        try await host.key(48, "\t")
        try await host.clickCompositionControl("unified.objects.choose.target")
        await fixture.controller.objectSelectionTask?.value
        try await host.settle()
        try await host.clickCompositionControl("unified.select." + fixture.target.searchIdentifier)
        try await host.clickCompositionControl("unified.objects.accept")
        if kind == 0 {
            try await host.clickCompositionControl("unified.parameter.date")
            try await host.revealTaskDatePicker()
            try await host.clickCompositionControl("daybook.date." + DayKey.today())
        } else if kind == 1 {
            let picker = try await host.compositionPicker("unified.parameter.choice.priority")
            try await PickerNativeTestSupport.keyboardSelection(picker, moveDown: true, in: host.window)
        } else if kind == 2 {
            let time = try TimePickerNativeTestSupport.picker(in: host.window)
            try await SettingsButtonTestSupport.reveal(time, in: host.window)
            let frame = time.convert(time.bounds, to: nil)
            try await TimePickerNativeTestSupport.click(.init(x: frame.minX + 10, y: frame.midY), in: host.window)
            // 沿原 NSDatePicker 分段键入，不用 dateValue/sendAction 代替时间输入验收。
            try await TimePickerNativeTestSupport.key(25, "9", in: host.window)
            try await TimePickerNativeTestSupport.key(124, "\u{F703}", in: host.window)
            try await TimePickerNativeTestSupport.key(20, "3", in: host.window)
            try await TimePickerNativeTestSupport.key(29, "0", in: host.window)
            try await host.settle()
            #expect(RemindMinutes.from(date: time.dateValue, calendar: time.calendar ?? .current) == 570)
        } else {
            for _ in 0..<2 {
                let mode = try await host.compositionPicker("unified.parameter.mode.time")
                try await PickerNativeTestSupport.keyboardSelection(mode, moveDown: true, in: host.window)
            }
            #expect(fixture.controller.editingDraft?.arguments.first?.operation == .cancelReminder)
        }
        try await host.clickCompositionControl("unified.field.prepare")
        let preview = try #require(fixture.controller.currentTaskFieldPreview)
        #expect(fixture.io.base.io.trace.isEmpty)
        try await host.revealSettingControlInsidePanel("unified.field.values")
        try host.snapshot("tm1-field-preview-\(kind)")
        try await host.clickCompositionControl("unified.field.accept")
        #expect(fixture.io.base.io.trace.isEmpty)
        let old = fixture.controller.buffer
        if kind == 1 {
            host.window.makeFirstResponder(try host.field)
            try await host.settle()
            try await host.key(36, "\r", flags: .command)
        } else { try await host.clickCompositionControl("unified.field.save") }
        let facts = try #require(fixture.controller.taskFieldUnit?.taskField)
        #expect(facts.state == .saved)
        try fixture.assertStoredField(preview, kind: kind)
        #expect(fixture.io.base.io.trace.filter { $0 == "save" }.count == 1)
        #expect(fixture.io.base.io.trace.filter { $0 == "ui" }.count == 1)
        #expect(fixture.io.notificationProcessed == 1 && fixture.io.calendarProcessed == 1)
        fixture.controller.requestOperationSubmit(old)
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        try await host.key(36, "\r", flags: .command)
        #expect(fixture.io.base.io.trace.filter { $0 == "save" }.count == 1)
        #expect(fixture.io.base.io.trace.filter { $0 == "ui" }.count == 1)
        try await host.revealSettingControlInsidePanel("unified.field.status")
        try host.snapshot("tm1-field-saved-\(kind)")
    }

    @Test(arguments: [false, true]) func nativeNoChangeAndConflict(conflict: Bool) async throws {
        let fixture = try UnifiedSearchTaskFieldFixture()
        defer { fixture.results.stop() }
        try await fixture.start(1)
        _ = fixture.controller.editParameter(TaskFieldCommandFixture.argument(1, unchanged: true), source: fixture.controller.buffer)
        // 这次改参另起候选刷新；等其真实读取收尾，避免夹具主动 publish 抢占同一 pending ticket。
        await fixture.controller.objectSelectionTask?.value
        _ = try await fixture.results.publish()
        let host = UnifiedSearchTestHost(results: fixture.controller, operations: true)
        defer { host.close() }
        try await host.start()
        try await host.clickCompositionControl("unified.field.prepare")
        try await host.clickCompositionControl("unified.field.accept")
        if conflict {
            fixture.io.base.todo.isUrgent = true
            try fixture.io.base.io.context.save()
            host.window.makeFirstResponder(try host.field)
            try await host.settle()
            try await host.key(36, "\r", flags: .command)
            #expect(fixture.controller.settingExecution == nil && fixture.controller.taskFieldFailure == "unified.field.fields")
            #expect(fixture.controller.plan?.items.first?.draft.arguments == [TaskFieldCommandFixture.argument(1, unchanged: true)])
        } else {
            try await host.clickCompositionControl("unified.field.save")
            #expect(fixture.controller.taskFieldUnit?.taskField?.state == .noChange)
        }
        #expect(fixture.io.base.io.trace.filter { $0 == "save" || $0 == "ui" }.isEmpty)
        try await host.revealSettingControlInsidePanel(conflict ? "unified.field.issue" : "unified.field.status")
        try host.snapshot("tm1-field-noChange-conflict-\(conflict)")
    }

    @Test func parameterChangesAndLostFocusRevokeAcceptance() async throws {
        let fixture = try UnifiedSearchTaskFieldFixture()
        defer { fixture.results.stop() }
        try await fixture.start(0)
        _ = try fixture.accepted()
        let old = fixture.controller.buffer
        let item = try #require(fixture.controller.plan?.items.first)
        fixture.controller.beginPlanEditing(item.stamp, source: old)
        #expect(fixture.controller.currentTaskFieldAcceptance == nil)
        fixture.controller.requestOperationSubmit(old)
        #expect(fixture.io.base.io.trace.isEmpty)
        fixture.controller.endPlanEditing(try #require(fixture.controller.editingPlanItem?.stamp), source: fixture.controller.buffer)
        _ = try fixture.accepted()
        try fixture.results.session.loseFocus(expecting: fixture.controller.buffer.lease.ownership)
        #expect(fixture.controller.currentTaskFieldAcceptance == nil)
        #expect(fixture.io.base.io.trace.isEmpty)
    }

    @Test func nativeMarkedTextAndLockKeepOriginalOperation() async throws {
        let fixture = try UnifiedSearchTaskFieldFixture()
        defer { fixture.results.stop() }
        try await fixture.start(2)
        _ = try await fixture.results.publish()
        let host = UnifiedSearchTestHost(results: fixture.controller, operations: true)
        defer { host.close() }
        try await host.start()
        try await host.clickCompositionControl("unified.field.prepare")
        try await host.clickCompositionControl("unified.field.accept")
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        let editor = try host.editor
        editor.setMarkedText("组合", selectedRange: .init(location: 2, length: 0), replacementRange: editor.selectedRange())
        fixture.controller.requestOperationSubmit(fixture.controller.buffer)
        try await host.key(36, "\r", flags: .command)
        #expect(fixture.controller.settingExecution == nil && fixture.io.base.io.trace.isEmpty)
        editor.unmarkText()
        let old = fixture.controller.buffer
        fixture.privacy.post(name: .privacyWillLock, object: fixture.results.vault)
        #expect(fixture.controller.currentTaskFieldAcceptance == nil && !fixture.controller.operationVisible)
        fixture.controller.requestOperationSubmit(old)
        #expect(fixture.controller.settingExecution == nil && fixture.io.base.io.trace.isEmpty)
        #expect(fixture.controller.plan?.items.first?.draft.arguments == [TaskFieldCommandFixture.argument(2)])
    }

    @Test(arguments: [false, true]) func nativeTitleRepresentativeLayout(compact: Bool) async throws {
        let fixture = try UnifiedSearchTaskTitleFixture()
        defer { fixture.stop() }
        try await fixture.start("T-M1 long title 中英文标题 #恢复 !p1 @09:30")
        let host = try await fixture.host(layout: compact ? .compact : .standard, width: compact ? 304 : 444,
                                          locale: compact ? "en" : "zh-Hans", dark: compact)
        defer { host.close() }
        try await host.clickCompositionControl("unified.title.prepare")
        try await host.revealSettingControlInsidePanel("unified.title.field.title")
        let title = try host.resultNode("unified.title.field.title")
        try SettingsButtonTestSupport.assertBounds([title], in: host.window)
        #expect(fixture.controller.currentTaskTitlePreview?.impact.tags.associations.map(\.effect) == [.restoreAndAssociate])
        try host.snapshot("tm1-title-layout-\(compact)")
        try fixture.noWrites()
    }
}
