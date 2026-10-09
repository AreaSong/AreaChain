import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchPlanRevisionTests {
    let support = UnifiedSearchMultiPlanOutputTests()

    @Test(arguments: [false, true]) func nativeMergeReadsAndExecutesOnlyFinalAssignment(compact: Bool) async throws {
        let fields = try TaskFieldCommandFixture()
        let fixture = try fieldFixture(fields)
        defer { fixture.stop() }
        let controller = fixture.controller!
        try queueFields(fixture, fields: fields, kinds: [1, 1])
        let items = try #require(controller.plan?.items)
        _ = try await fixture.publish()
        let host = support.makeHost(controller, compact: compact)
        defer { host.close() }
        try await host.start()
        try await host.clickCompositionControl("unified.plan.merge." + items[1].id.uuidString)
        #expect(controller.plan?.items.count == 2 && fields.count("save") == 0)
        try await host.revealSettingControlInsidePanel("unified.plan.merge.accept")
        try host.snapshot("pm3-merge-review-\(compact)")
        try await host.clickCompositionControl("unified.plan.merge.accept")
        #expect(controller.plan?.items.count == 1 && controller.currentMultiPlanPreview == nil)
        try await host.clickCompositionControl("unified.multi.prepare")
        try await submit(host, controller: controller, commandReturn: !compact)
        #expect(controller.settingExecution?.units[0].state == .succeeded)
        #expect(!fields.base.todo.isImportant && fields.base.todo.isUrgent)
        #expect(fields.count("save") == 1 && fields.count("ui") == 1)
        try await host.revealSettingControlInsidePanel("unified.multi.progress")
        try host.snapshot("pm3-merge-result-\(compact)")
    }

    @Test(arguments: [false, true]) func nativePartialSuccessReturnEditAndReaccept(compact: Bool) async throws {
        let fields = try TaskFieldCommandFixture()
        let fixture = try fieldFixture(fields)
        defer { fixture.stop() }
        let controller = fixture.controller!
        try queueFields(fixture, fields: fields, kinds: [0, 1])
        let last = try #require(controller.plan?.items.last)
        fields.io.beforeTransaction = {
            if controller.settingExecution?.units.first?.state == .succeeded { throw TaskCreateCommandIO.Failure.injected }
        }
        _ = try await fixture.publish()
        let host = support.makeHost(controller, compact: compact)
        defer { host.close() }
        try await host.start()
        try await host.clickCompositionControl("unified.multi.prepare")
        try await submit(host, controller: controller)
        let original = try #require(controller.settingExecution)
        #expect(original.units[0].state == .succeeded && original.units[1].hasSafeLocalFailure)
        try await host.clickCompositionControl("unified.revision.return")
        #expect(controller.settingExecution == nil && controller.plan?.items.map(\.id) == [last.id])
        try await host.revealSettingControlInsidePanel("unified.revision.history")
        try host.snapshot("pm3-return-history-\(compact)")
        try await host.clickCompositionControl("unified.plan.edit." + last.id.uuidString)
        let picker = try await host.compositionPicker("unified.parameter.choice.priority")
        try await PickerNativeTestSupport.keyboardSelection(picker, moveDown: true, in: host.window)
        try await host.settle()
        #expect(controller.editingDraft?.arguments[0].value == .choice("p4"))
        try await host.clickCompositionControl("unified.plan.close")
        #expect(fields.count("save") == 1 && controller.currentMultiPlanPreview == nil)
        fields.io.beforeTransaction = nil
        try await host.clickCompositionControl("unified.multi.prepare")
        try await submit(host, controller: controller, commandReturn: compact)
        #expect(!fields.base.todo.isImportant && !fields.base.todo.isUrgent && fields.base.todo.dayKey == "2026-10-09")
        #expect(fields.count("save") == 2 && fields.count("ui") == 2)
        #expect(controller.coordinator.revisionChain(HandoffFixture.source).first?.run == original)
        try await host.revealSettingControlInsidePanel("unified.multi.progress")
        try host.snapshot("pm3-return-result-\(compact)")
    }

    @Test func nativeSavedProducerReturnsConsumerAndKeepsRealObject() async throws {
        let io = try MultiPlanOutputFixture()
        let fixture = try outputFixture(io)
        defer { fixture.stop() }
        let controller = fixture.controller!
        let producer = try fixture.enqueueOperation("todo.create", arguments: TaskCreateCommandFixture.arguments("唯一父对象"))
        let consumer = try fixture.enqueueOperation("todo.title", arguments: [SubtaskCommandFixture.title("失败标题")])
        _ = try await fixture.publish()
        let host = support.makeHost(controller, compact: true)
        defer { host.close() }
        try await host.start()
        try await support.link(host, consumer: consumer, producer: producer)
        io.io.titleBeforeTransaction = { throw TaskCreateCommandIO.Failure.injected }
        try await host.clickCompositionControl("unified.multi.prepare")
        try await submit(host, controller: controller)
        try await host.clickCompositionControl("unified.multi.confirm")
        try await support.settle(host, controller)
        let original = try #require(controller.settingExecution)
        let object = try #require(original.outputs[producer.id])
        try await host.clickCompositionControl("unified.revision.return")
        try await editTitle("重新接受后的标题", item: consumer, host: host)
        let reference = try #require(controller.plan?.items[0].links.results[.target])
        #expect(reference.history?.object == object)
        #expect(controller.creationReferenceLabel(reference, parameter: .target, locale: Locale(identifier: "zh-Hans")).contains("唯一父对象"))
        io.io.titleBeforeTransaction = nil
        try await host.clickCompositionControl("unified.multi.prepare")
        try await host.revealSettingControlInsidePanel("unified.multi.submit")
        try host.snapshot("pm3-saved-output-reaccept")
        try await submit(host, controller: controller)
        let todos = try io.io.creation.capture.readTodos()
        #expect(todos.count == 1 && todos[0].id == object.id && todos[0].title == "重新接受后的标题")
        #expect(io.count("save") == 1 && io.count("saveTitle") == 1 && io.count("ui") == 2)
        #expect(controller.coordinator.revisionChain(HandoffFixture.source).first?.run == original)
        try await host.revealSettingControlInsidePanel("unified.multi.progress")
        try host.snapshot("pm3-saved-output-result")
    }

    @Test func nativeUnsubmittedBranchMigratesAndExecutesMultilevelChain() async throws {
        let io = try MultiPlanOutputFixture()
        let fixture = try outputFixture(io)
        defer { fixture.stop() }
        let controller = fixture.controller!
        let items = try support.queueChain(fixture)
        let branch = try fixture.enqueueOperation("todo.title", arguments: [SubtaskCommandFixture.title("分支标题")])
        _ = try await fixture.publish()
        let host = support.makeHost(controller, compact: false)
        defer { host.close() }
        try await host.start()
        try await support.link(host, consumer: items[1], producer: items[0], parameter: .parent)
        try await support.link(host, consumer: items[2], producer: items[1])
        try await support.link(host, consumer: branch, producer: items[0])
        io.io.creation.beforeTransaction = { throw TaskCreateCommandIO.Failure.injected }
        try await host.clickCompositionControl("unified.multi.prepare")
        try await submit(host, controller: controller)
        let reserved = try #require(controller.coordinator.taskCreations.preparations[items[0].draft.id]?.creationID)
        try await host.clickCompositionControl("unified.revision.return")
        try await editTitle("更新父标题", item: items[0], host: host)
        let revised = try #require(controller.plan?.items)
        #expect(CommandPlanValidation.structure(revised).isEmpty)
        #expect(revised[1].links.results[.parent]?.producer == revised[0].stamp)
        #expect(revised[2].links.results[.target]?.producer == revised[1].stamp)
        #expect(revised[3].links.results[.target]?.producer == revised[0].stamp)
        io.io.creation.beforeTransaction = nil
        try await host.clickCompositionControl("unified.multi.prepare")
        try await submit(host, controller: controller)
        for _ in 0..<4 where controller.multiPlan?.pending != nil {
            try await host.clickCompositionControl("unified.multi.confirm")
            try await support.settle(host, controller)
        }
        #expect(controller.settingExecution?.units.allSatisfy { $0.state == .succeeded } == true)
        #expect(try io.children().count == 1 && io.children()[0].todo?.id == reserved)
        #expect(io.count("save") == 1 && io.count("saveSubtask") == 2 && io.count("saveTitle") == 1)
        try await host.revealSettingControlInsidePanel("unified.multi.progress")
        try host.snapshot("pm3-branch-result")
    }

    func outputFixture(_ io: MultiPlanOutputFixture) throws -> UnifiedSearchResultsFixture {
        try .init(QueryBatchFixture.empty("/tasks"), privacyCenter: NotificationCenter(), taskChainIO: io.io,
                  subtaskEnvironment: io.subtaskEnvironment, enableMultiPlan: true, outputCapability: .typedCreation, enablePlanRevisions: true)
    }
    func fieldFixture(_ fields: TaskFieldCommandFixture, privacy: NotificationCenter = NotificationCenter()) throws -> UnifiedSearchResultsFixture {
        fields.io.notificationResult = .succeeded
        fields.io.calendarResult = .succeeded
        return try .init(QueryBatchFixture.empty("/tasks"), privacyCenter: privacy, taskFieldEnvironment: fields.environment,
                         enableMultiPlan: true, outputCapability: .typedCreation, enablePlanRevisions: true)
    }
    func queueFields(_ fixture: UnifiedSearchResultsFixture, fields: TaskFieldCommandFixture, kinds: [Int]) throws {
        for kind in kinds {
            try fixture.handoff.queue(.init(id: UUID(), hostID: HandoffFixture.source,
                commandID: .init(rawValue: TaskFieldCommandFixture.command(kind)),
                targets: .init(.single, objects: [.init(type: .todo, id: fields.base.todo.id)]),
                arguments: [TaskFieldCommandFixture.argument(kind)]))
        }
        _ = fixture.controller.publishOperation(text: "")
    }
    func submit(_ host: UnifiedSearchTestHost, controller: UnifiedSearchController, commandReturn: Bool = false) async throws {
        if commandReturn {
            host.window.makeFirstResponder(try host.field)
            try await host.settle()
            try await host.key(36, "\r", flags: .command)
        } else { try await host.clickCompositionControl("unified.multi.submit") }
        try await support.settle(host, controller)
    }
    func editTitle(_ title: String, item: CommandPlanItem, host: UnifiedSearchTestHost) async throws {
        try await host.clickCompositionControl("unified.plan.edit." + item.id.uuidString)
        let editor = try await host.focusParameter(.title)
        editor.insertText(title, replacementRange: .init(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        try await host.clickCompositionControl("unified.plan.close")
    }
}
