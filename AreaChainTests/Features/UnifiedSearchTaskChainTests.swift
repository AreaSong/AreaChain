import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchTaskChainTests {
    @Test(arguments: [false, true]) func nativePlanOutputAndSecondConfirmation(failSecond: Bool) async throws {
        let io = try TaskChainCommandIO()
        let fixture = try UnifiedSearchResultsFixture(QueryBatchFixture.empty("/tasks"), privacyCenter: NotificationCenter(), taskChainIO: io)
        defer { fixture.stop() }
        let controller = fixture.controller!
        _ = try await fixture.publish()
        let host = UnifiedSearchTestHost(layout: failSecond ? .compact : .standard, width: failSecond ? 304 : 620,
            locale: failSecond ? "zh-Hans" : "en", dark: failSecond, results: controller, operations: true)
        defer { host.close() }
        try await host.start()
        try await begin("/tasks/add", host: host)
        let first = try await host.focusParameter(.title)
        first.insertText("Native created", replacementRange: first.selectedRange())
        try await host.settle()
        try await host.key(36, "\r")
        try await host.clickCompositionControl("unified.parameter.date")
        try await host.revealTaskDatePicker()
        try await host.clickCompositionControl("daybook.date." + DayKey.today())
        try await host.clickCompositionControl("unified.plan.enqueue")
        let producer = try #require(controller.plan?.items.first)
        try await begin("/tasks/title", host: host)
        let second = try await host.focusParameter(.title)
        second.insertText("Native changed #chain !p3 @09:30", replacementRange: second.selectedRange())
        try await host.settle()
        try await host.key(36, "\r")
        try await host.clickCompositionControl("unified.plan.enqueue")
        let consumer = try #require(controller.plan?.items.last)
        try await host.clickCompositionControl("unified.plan.edit." + consumer.id.uuidString)
        try await host.clickCompositionControl("unified.plan.reference.target." + producer.id.uuidString)
        try await host.clickCompositionControl("unified.plan.close")
        #expect(controller.plan?.items[1].draft.targets == CommandDraftTargets.none)
        #expect(controller.plan?.items[1].draft.baseline == CommandDraftBaseline())
        #expect(controller.taskTitleAcceptance == nil && controller.taskTitlePreview == nil)
        try await host.clickCompositionControl("unified.chain.prepare")
        let prepared = try #require(controller.chainCreationPreparation)
        #expect(try io.creation.capture.readTodos().isEmpty)
        #expect(io.creation.capture.trace.isEmpty)
        try host.snapshot("tm1-chain-before-\(failSecond)")
        try await host.clickCompositionControl("unified.chain.create")
        #expect(controller.taskCreateUnit?.taskCreation?.savedID == prepared.creationID)
        #expect(try io.creation.capture.readTodos().count == 1)
        #expect(try io.creation.capture.readTodos().first?.title == "Native created")
        #expect(controller.taskTitleAcceptance == nil && controller.taskTitlePreview == nil)
        try await host.revealSettingControlInsidePanel("unified.chain.waiting")
        try host.snapshot("tm1-chain-waiting-\(failSecond)")
        try await host.clickCompositionControl("unified.chain.prepareTitle")
        let preview = try #require(controller.currentTaskTitlePreview)
        #expect(preview.impact.target.id == prepared.creationID && preview.impact.originalValues[.title] == .text("Native created"))
        #expect(preview.impact.tags.associations.map(\.effect) == [.createAndAssociate])
        #expect(try io.creation.capture.context.fetchCount(FetchDescriptor<TagItem>()) == 0)
        try await host.revealSettingControlInsidePanel("unified.title.tagSummary")
        try host.snapshot("tm1-chain-real-preview-\(failSecond)")
        try await host.clickCompositionControl("unified.chain.acceptTitle")
        #expect(io.creation.capture.trace.filter { $0 == "saveTitle" }.isEmpty)
        let old = controller.buffer
        if failSecond { io.titleBeforeTransaction = { throw TaskCreateCommandIO.Failure.injected } }
        if failSecond { try await host.clickCompositionControl("unified.chain.saveTitle") }
        else {
            host.window.makeFirstResponder(try host.field)
            try await host.settle()
            try await host.key(36, "\r", flags: .command)
        }
        #expect(controller.taskTitleUnit?.taskTitle?.state == (failSecond ? .notSubmitted : .saved))
        let rows = try io.creation.capture.readTodos()
        #expect(rows.count == 1 && rows[0].id == prepared.creationID)
        #expect(rows[0].title == (failSecond ? "Native created" : "Native changed"))
        #expect(rows[0].dayKey == DayKey.today() && rows[0].notes.isEmpty)
        #expect(rows[0].remindMinutes == (failSecond ? nil : 570))
        #expect(rows[0].isUrgent == !failSecond && !rows[0].isImportant)
        #expect(io.creation.capture.trace.filter { $0 == "save" }.count == 1)
        #expect(io.creation.capture.trace.filter { $0 == "saveTitle" }.count == (failSecond ? 0 : 1))
        #expect(io.creation.capture.trace.filter { $0 == "ui" }.count == (failSecond ? 1 : 2))
        #expect(io.titleNotifications == (failSecond ? 0 : 1) && io.titleCalendars == (failSecond ? 0 : 1))
        controller.requestOperationSubmit(old)
        controller.acceptTaskChainTitle(preview, source: old)
        controller.submitTaskChain(old)
        #expect(io.creation.capture.trace.filter { $0 == "save" }.count == 1)
        #expect(io.creation.capture.trace.filter { $0 == "saveTitle" }.count == (failSecond ? 0 : 1))
        try await host.revealSettingControlInsidePanel("unified.title.status")
        try host.snapshot("tm1-chain-result-\(failSecond)")
    }

    private func begin(_ path: String, host: UnifiedSearchTestHost) async throws {
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        let editor = try host.editor
        editor.insertText(path, replacementRange: .init(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        try await host.key(48, "\t")
    }

    @Test func nativeUnfinishedProducerBlocksSecondStep() async throws {
        let io = try TaskChainCommandIO()
        let fixture = try UnifiedSearchResultsFixture(QueryBatchFixture.empty("/tasks"),
            privacyCenter: NotificationCenter(), taskChainIO: io)
        defer { fixture.stop() }
        let controller = fixture.controller!
        _ = try fixture.enqueueOperation("todo.create", arguments: TaskCreateCommandFixture.arguments())
        let producer = try #require(controller.plan?.items.first)
        let consumer = try fixture.enqueueOperation("todo.title", arguments: [
            .init(parameter: .title, operation: .assign, value: .shortText("不得执行"))])
        controller.setCreationReference(producer.stamp, parameter: .target, item: consumer.stamp, source: controller.buffer)
        _ = try await fixture.publish()
        let host = UnifiedSearchTestHost(results: controller, operations: true)
        defer { host.close() }
        try await host.start()
        try await host.clickCompositionControl("unified.chain.prepare")
        // 本地已经保存，但原必要发布阶段失败；不能由 UI 忽略依赖状态。
        io.createEnvironment.beforePublication = { throw TaskCreateCommandIO.Failure.injected }
        try await host.clickCompositionControl("unified.chain.create")
        let saved = try #require(controller.taskCreateUnit?.taskCreation?.savedID)
        #expect(!controller.chainCanPrepareTitle && controller.taskTitleUnit?.state == .blocked)
        try await host.revealSettingControlInsidePanel("unified.chain.blocked")
        try host.snapshot("tm1-chain-dependency-blocked")
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        try await host.key(36, "\r", flags: .command)
        #expect(controller.taskTitleAcceptance == nil && controller.taskTitlePreview == nil)
        #expect(try io.creation.capture.readTodos().map(\.id) == [saved])
        #expect(io.creation.capture.trace.filter { $0 == "save" }.count == 1)
        #expect(io.creation.capture.trace.filter { $0 == "saveTitle" }.isEmpty)
    }

    @Test func nativeMarkedTextBlocksBothStepsAndLockRevokesConsumer() async throws {
        let io = try TaskChainCommandIO()
        let privacy = NotificationCenter()
        let fixture = try UnifiedSearchResultsFixture(QueryBatchFixture.empty("/tasks"), privacyCenter: privacy, taskChainIO: io)
        defer { fixture.stop() }
        let controller = fixture.controller!
        _ = try fixture.enqueueOperation("todo.create", arguments: TaskCreateCommandFixture.arguments())
        let producer = try #require(controller.plan?.items.first)
        let consumer = try fixture.enqueueOperation("todo.title", arguments: [.init(parameter: .title, operation: .assign, value: .shortText("第二步"))])
        controller.setCreationReference(producer.stamp, parameter: .target, item: consumer.stamp, source: controller.buffer)
        _ = try await fixture.publish()
        let host = UnifiedSearchTestHost(results: controller, operations: true)
        defer { host.close() }
        try await host.start()
        let editor = try host.editor
        editor.setMarkedText("组合", selectedRange: .init(location: 2, length: 0), replacementRange: editor.selectedRange())
        controller.prepareTaskChain(controller.buffer)
        try await host.key(36, "\r", flags: .command)
        #expect(controller.chainCreationPreparation == nil && controller.settingExecution == nil)
        editor.unmarkText()
        try await host.clickCompositionControl("unified.chain.prepare")
        try await host.clickCompositionControl("unified.chain.create")
        try await host.clickCompositionControl("unified.chain.prepareTitle")
        try await host.clickCompositionControl("unified.chain.acceptTitle")
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        let active = try host.editor
        active.setMarkedText("组合", selectedRange: .init(location: 2, length: 0), replacementRange: active.selectedRange())
        controller.requestOperationSubmit(controller.buffer)
        try await host.key(36, "\r", flags: .command)
        #expect(controller.taskTitleUnit?.taskTitle == nil)
        active.unmarkText()
        let old = controller.buffer
        privacy.post(name: .privacyWillLock, object: fixture.vault)
        #expect(controller.currentTaskTitleAcceptance == nil && !controller.operationVisible)
        controller.requestOperationSubmit(old)
        #expect(try io.creation.capture.readTodos().count == 1)
        #expect(io.creation.capture.trace.filter { $0 == "saveTitle" }.isEmpty)
    }
}
