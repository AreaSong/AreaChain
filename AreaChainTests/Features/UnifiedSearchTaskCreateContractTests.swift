import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct UnifiedSearchTaskCreateContractTests {
    @Test func singleDraftMovesWithoutBaselineAndDoubleSubmitKeepsOriginalRun() throws {
        let fixture = try UnifiedSearchTaskCreateFixture()
        defer { fixture.stop() }
        try fixture.start()
        let draft = try #require(fixture.controller.operations?.active)
        #expect(draft.baseline == CommandDraftBaseline())
        let source = fixture.controller.buffer
        let query = try fixture.results.handoff.state().query
        fixture.submit()
        fixture.controller.requestOperationSubmit(source)
        fixture.submit()
        #expect(try fixture.facts.state == .saved)
        #expect(try fixture.io.capture.readTodos().first?.id == fixture.facts.savedID)
        #expect(try fixture.io.capture.readTodos().count == 1)
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 1)
        #expect(fixture.controller.settingExecution?.snapshot.items.first?.draft.id == draft.id)
        #expect(fixture.controller.operations?.active == nil && fixture.controller.plan?.items.isEmpty == true)
        #expect(try fixture.results.handoff.state().query == query)
        fixture.controller.acknowledgeTaskCreate(fixture.controller.buffer)
        #expect(fixture.controller.settingExecution != nil, "外部仍未知时不能释放运行")
    }

    @Test(arguments: ["任务 #标签", "任务 // 备注", "任务\n备注", "任务 !p4", "任务 @09:00"])
    func derivedAndMultilineInputIsRetainedAndRejected(title: String) throws {
        let fixture = try UnifiedSearchTaskCreateFixture()
        defer { fixture.stop() }
        try fixture.start(title: title)
        fixture.submit()
        #expect(fixture.controller.settingExecution == nil)
        #expect(fixture.controller.operations?.active != nil)
        #expect(try fixture.io.capture.readTodos().isEmpty && fixture.count("save") == 0)
    }

    @Test(arguments: [CommandParameterID.tags, .priority, .time])
    func unassembledCompositionCannotSubmitExplicitFields(parameter: CommandParameterID) throws {
        let fixture = try UnifiedSearchTaskCreateFixture()
        defer { fixture.stop() }
        try fixture.start()
        let argument: CommandArgument
        switch parameter {
        case .tags: argument = .init(parameter: .tags, operation: .clear)
        case .priority: argument = .init(parameter: .priority, operation: .assign, value: .choice("p2"))
        default: argument = .init(parameter: .time, operation: .setReminder, value: .time(510))
        }
        if parameter == .tags {
            // 旧标签编辑尚未装配；原草稿可含该参数，但不能因此获得 UI 提交资格。
            #expect(fixture.controller.editParameter(argument, source: fixture.controller.buffer) == nil)
            let draft = try #require(fixture.controller.operations?.active)
            try fixture.results.handoff.send(.operation(.edit(draft.stamp, argument)))
            _ = fixture.controller.publishOperation(text: fixture.controller.buffer.text)
        } else {
            try #require(fixture.controller.editParameter(argument, source: fixture.controller.buffer) != nil)
        }
        #expect(fixture.controller.operations?.active?.arguments.contains(argument) == true)
        fixture.submit()
        #expect(fixture.controller.settingExecution == nil && fixture.controller.operations?.active != nil)
        #expect(try fixture.io.capture.readTodos().isEmpty && fixture.count("save") == 0)
        #expect(try fixture.io.capture.context.fetchCount(FetchDescriptor<TagItem>()) == 0)
        #expect(fixture.io.capture.authorizations.isEmpty && fixture.count("ui") == 0)
    }

    @Test func missingInvalidDateAndNotesCannotBeBypassed() throws {
        let fixture = try UnifiedSearchTaskCreateFixture()
        defer { fixture.stop() }
        try fixture.start(day: nil)
        fixture.submit()
        #expect(fixture.controller.settingExecution == nil)
        #expect(fixture.controller.editParameter(.init(parameter: .day, operation: .assign, value: .day("2026-02-30")),
                                                source: fixture.controller.buffer) == nil)
        try #require(fixture.controller.editParameter(.init(parameter: .day, operation: .assign, value: .day("2026-10-05")),
                                                     source: fixture.controller.buffer) != nil)
        let draft = try #require(fixture.controller.operations?.active)
        try fixture.results.handoff.send(.operation(.edit(draft.stamp, .init(parameter: .notes, operation: .unspecified))))
        _ = fixture.controller.publishOperation(text: fixture.controller.buffer.text)
        fixture.submit()
        #expect(try fixture.io.capture.readTodos().isEmpty && fixture.count("save") == 0)
    }

    @Test func preparationIsStableAndEditsDoNotAllocateAnotherIdentity() throws {
        let fixture = try UnifiedSearchTaskCreateFixture()
        defer { fixture.stop() }
        try fixture.start()
        let queued = try #require(fixture.controller.operations?.active)
        try #require(fixture.controller.enqueue(queued.stamp, source: fixture.controller.buffer))
        fixture.controller.requestTaskCreate(fixture.controller.buffer, prepareOnly: true)
        let prepared = try #require(fixture.controller.currentTaskPreparation)
        fixture.controller.requestTaskCreate(fixture.controller.buffer, prepareOnly: true)
        #expect(fixture.controller.currentTaskPreparation == prepared)
        let item = try #require(fixture.controller.plan?.items.first)
        fixture.controller.beginPlanEditing(item.stamp, source: fixture.controller.buffer)
        _ = fixture.controller.editParameter(.init(parameter: .title, operation: .assign, value: .shortText("修改的合成任务")),
                                             source: fixture.controller.buffer)
        let edited = try #require(fixture.controller.editingPlanItem)
        fixture.controller.endPlanEditing(edited.stamp, source: fixture.controller.buffer)
        #expect(fixture.controller.currentTaskPreparation == nil)
        fixture.submit()
        #expect(fixture.controller.taskCreateFailure == .stale)
        #expect(fixture.controller.taskCreatePreparation?.creationID == prepared.creationID)
        #expect(try fixture.io.capture.readTodos().isEmpty)
    }

    @Test func dirtyContextPreservesOtherInputAndOriginalPlan() throws {
        let fixture = try UnifiedSearchTaskCreateFixture()
        defer { fixture.stop() }
        try fixture.start()
        let unrelated = TodoItem(title: "未保存的合成输入", dayKey: "2026-10-04")
        fixture.io.capture.context.insert(unrelated)
        fixture.submit()
        #expect(fixture.controller.taskCreateFailure == .dirtyContext)
        #expect(fixture.io.capture.context.hasChanges && unrelated.title == "未保存的合成输入")
        #expect(fixture.controller.plan?.items.count == 1 && fixture.controller.settingExecution == nil)
        #expect(fixture.count("save") == 0 && fixture.count("preSave") == 0)
    }

    @Test(arguments: [false, true]) func unknownVerificationDoesNotReplay(afterSave: Bool) throws {
        let fixture = try UnifiedSearchTaskCreateFixture()
        defer { fixture.stop() }
        fixture.io.saveMode = afterSave ? .throwAfter : .throwBefore
        try fixture.start()
        fixture.submit()
        let original = try fixture.facts
        fixture.controller.verifyTaskCreate(fixture.controller.buffer)
        #expect(fixture.controller.taskCreateVerification == (afterSave ? .singleLive : .absent))
        fixture.submit()
        #expect(try fixture.facts == original && original.state == .unknown)
        #expect(fixture.count("save") == 1 && fixture.count("ui") == 0)
        #expect(try fixture.io.capture.readTodos().count == (afterSave ? 1 : 0))
    }

    @Test(arguments: [0, 1, 2]) func originalOwnershipBlocksAmbiguity(kind: Int) throws {
        let fixture = try UnifiedSearchTaskCreateFixture(assembled: kind != 0)
        defer { fixture.stop() }
        try fixture.start()
        if kind > 0 {
            let draft = try #require(fixture.controller.operations?.active)
            try #require(fixture.controller.enqueue(draft.stamp, source: fixture.controller.buffer))
            try fixture.start(title: "另一合成任务")
            if kind == 2 {
                let next = try #require(fixture.controller.operations?.active)
                try #require(fixture.controller.enqueue(next.stamp, source: fixture.controller.buffer))
            }
        }
        fixture.submit()
        #expect(fixture.controller.settingExecution == nil)
        #expect(fixture.count("save") == 0 && fixture.count("ui") == 0)
    }
}
