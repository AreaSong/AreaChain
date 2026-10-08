import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchTM1ContractTests {
    @Test(arguments: [0, 1, 2, 3]) func fieldControllerSavesOnlySelectedOperation(kind: Int) async throws {
        let fixture = try UnifiedSearchTaskFieldFixture()
        defer { fixture.results.stop() }
        try await fixture.start(kind)
        let accepted = try fixture.accepted()
        let source = fixture.controller.buffer
        fixture.controller.requestOperationSubmit(source)
        #expect(fixture.controller.taskFieldUnit?.taskField?.state == .saved)
        try fixture.assertStoredField(accepted.preview, kind: kind)
        fixture.controller.requestOperationSubmit(source)
        #expect(fixture.io.base.io.trace.filter { $0 == "save" }.count == 1)
        #expect(fixture.io.base.io.trace.filter { $0 == "ui" }.count == 1)
        #expect(try fixture.io.base.io.readTodos().count == 1)
    }

    @Test(arguments: [false, true]) func chainControllerWaitsForRealSecondAcceptance(failure: Bool) async throws {
        let io = try TaskChainCommandIO()
        let fixture = try UnifiedSearchResultsFixture(QueryBatchFixture.empty("/tasks"), privacyCenter: NotificationCenter(), taskChainIO: io)
        defer { fixture.stop() }
        let controller = fixture.controller!
        _ = try fixture.enqueueOperation("todo.create", arguments: TaskCreateCommandFixture.arguments("第一步"))
        let producer = try #require(controller.plan?.items.first)
        let consumer = try fixture.enqueueOperation("todo.title", arguments: [.init(parameter: .title, operation: .assign, value: .shortText("第二步 #标签"))])
        controller.setCreationReference(producer.stamp, parameter: .target, item: consumer.stamp, source: controller.buffer)
        controller.prepareTaskChain(controller.buffer)
        #expect(controller.chainCreationPreparation != nil)
        controller.requestOperationSubmit(controller.buffer)
        #expect(controller.taskCreateUnit?.taskCreation?.state == .saved)
        #expect(controller.taskTitleAcceptance == nil && controller.taskTitlePreview == nil)
        #expect(controller.chainCanPrepareTitle)
        controller.requestOperationSubmit(controller.buffer)
        #expect(try io.creation.capture.readTodos().first?.title == "第一步")
        controller.prepareTaskChainTitle(controller.buffer)
        let preview = try #require(controller.currentTaskTitlePreview)
        #expect(preview.impact.originalValues[.title] == .text("第一步"))
        #expect(try io.creation.capture.context.fetchCount(FetchDescriptor<TagItem>()) == 0)
        controller.acceptTaskChainTitle(preview, source: controller.buffer)
        #expect(controller.currentTaskTitleAcceptance != nil)
        if failure { io.titleBeforeTransaction = { throw TaskCreateCommandIO.Failure.injected } }
        let old = controller.buffer
        controller.requestOperationSubmit(old)
        #expect(controller.taskTitleUnit?.taskTitle?.state == (failure ? .notSubmitted : .saved))
        controller.requestOperationSubmit(old)
        #expect(try io.creation.capture.readTodos().count == 1)
        #expect(try io.creation.capture.readTodos().first?.title == (failure ? "第一步" : "第二步"))
        #expect(io.creation.capture.trace.filter { $0 == "save" }.count == 1)
        #expect(io.creation.capture.trace.filter { $0 == "ui" }.count == (failure ? 1 : 2))
    }

    @Test func chainDefaultAssemblyStaysClosed() throws {
        let fixture = try UnifiedSearchResultsFixture()
        defer { fixture.stop() }
        _ = try fixture.enqueueOperation("todo.create", arguments: TaskCreateCommandFixture.arguments())
        _ = try fixture.enqueueOperation("todo.title", arguments: [.init(parameter: .title, operation: .assign, value: .shortText("第二步"))])
        fixture.controller.prepareTaskChain(fixture.controller.buffer)
        fixture.controller.requestOperationSubmit(fixture.controller.buffer)
        #expect(fixture.controller.settingExecution == nil && fixture.controller.chainCreationPreparation == nil)
    }

    @Test(arguments: ["todo.move", "todo.priority", "todo.reminder"])
    func fieldPickerRejectsMultipleWithoutNarrowing(command: String) async throws {
        let fixture = try UnifiedSearchResultsFixture(.objectBatch())
        defer { fixture.stop() }
        try fixture.startOperation(command)
        let original = try fixture.draft
        let picker = try await fixture.chooseObjects()
        fixture.controller.toggleObject(.object(0), stamp: picker.stamp)
        fixture.controller.toggleObject(.object(1), stamp: picker.stamp)
        #expect(!fixture.controller.acceptObjects(picker.stamp))
        #expect(fixture.controller.objectSelection?.objects.count == 2)
        #expect(fixture.controller.objectSelectionMessage == "unified.objects.singleOnly")
        #expect(try fixture.draft == original)
    }
}
