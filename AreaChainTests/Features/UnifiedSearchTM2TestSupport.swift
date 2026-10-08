import AppKit
import SwiftData
import Testing
@testable import AreaChain

@MainActor final class UnifiedSearchTM2Fixture {
    let service: TaskTM2Fixture
    let results: UnifiedSearchResultsFixture
    let privacy = NotificationCenter()
    var controller: UnifiedSearchController { results.controller }
    var target: CommandObjectReference { .init(type: .todo, id: service.base.todo.id) }

    init(done: Bool = true) throws {
        service = try TaskTM2Fixture()
        service.base.todo.isDone = done
        _ = try service.child("Synthetic child · 合成子任务")
        _ = try service.child("Completed child", done: true)
        _ = try service.child("Deleted child", deleted: true)
        var batch = QueryBatchFixture.empty("/tasks")
        var parent = service.base.todo.snapshot
        batch.snapshots.subtasks = .complete(parent.subtasks)
        parent.subtasks = []
        batch.snapshots.todos = .complete([parent])
        batch.facts.metadata = .init(tagNames: [service.base.live.id: service.base.live.name,
            service.base.deleted.id: service.base.deleted.name], privateTagIDs: [])
        results = try .init(batch, privacyCenter: privacy, taskFieldEnvironment: service.environment, taskFieldCapability: .milestone2)
    }

    func start(_ command: String, argument: CommandArgument) async throws {
        try results.startOperation(command)
        try await results.acceptObjects([target])
        _ = controller.editParameter(argument, source: controller.buffer)
        await controller.objectSelectionTask?.value
    }

    func host(_ style: Int = 0) async throws -> UnifiedSearchTestHost {
        _ = try await results.publish()
        let host = UnifiedSearchTestHost(layout: style % 2 == 0 ? .standard : .compact,
            width: style % 2 == 0 ? 444 : 304, locale: style < 2 ? "en" : "zh-Hans",
            dark: style == 1 || style == 2, results: controller, operations: true)
        try await host.start()
        return host
    }

    func selectCommand(_ path: String, host: UnifiedSearchTestHost) async throws {
        let editor = try host.editor
        editor.insertText(path, replacementRange: .init(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        try await host.key(48, "\t")
        try await host.clickCompositionControl("unified.objects.choose.target")
        await controller.objectSelectionTask?.value
        try await host.settle()
        // 混合候选保留子任务；用原键盘导航滚动到明确父目标，再点击该行。
        host.window.makeFirstResponder(try host.field)
        for _ in 0..<4 {
            if controller.objectSelection?.browse.active == target { break }
            try await host.key(125, "\u{F701}")
        }
        try #require(controller.objectSelection?.browse.active == target)
        try await host.clickCompositionControl("unified.select." + target.searchIdentifier)
        try await host.clickCompositionControl("unified.objects.accept")
    }

    func mode(_ parameter: CommandParameterID, _ mode: CommandFieldOperation, host: UnifiedSearchTestHost) async throws {
        for _ in 0..<6 {
            if controller.editingDraft?.arguments.first(where: { $0.parameter == parameter })?.operation == mode { return }
            let picker = try await host.compositionPicker("unified.parameter.mode." + parameter.rawValue)
            try await PickerNativeTestSupport.keyboardSelection(picker, moveDown: true, in: host.window)
            try await host.settle()
        }
        try #require(controller.editingDraft?.arguments.first { $0.parameter == parameter }?.operation == mode)
    }

    func prepare(_ host: UnifiedSearchTestHost, name: String) async throws -> CommandTaskFieldAcceptance {
        try await host.clickCompositionControl("unified.field.prepare")
        let preview = try #require(controller.currentTaskFieldPreview,
                                  "真实影响未准备：\(controller.taskFieldFailure ?? "none")")
        #expect(service.count("save") == 0 && service.count("ui") == 0 && !service.context.hasChanges)
        try await host.revealSettingControlInsidePanel("unified.field.values")
        try SettingsButtonTestSupport.assertBounds([host.resultNode("unified.field.values")], in: host.window)
        try host.snapshot("tm2-" + name + "-preview")
        try await host.clickCompositionControl("unified.field.accept")
        let accepted = try #require(controller.currentTaskFieldAcceptance)
        #expect(accepted.preview == preview && service.count("save") == 0 && service.count("ui") == 0)
        return accepted
    }

    func submit(_ host: UnifiedSearchTestHost, name: String, chord: Bool) async throws -> CommandTaskFieldFacts {
        let old = controller.buffer
        if chord {
            host.window.makeFirstResponder(try host.field)
            try await host.settle()
            try await host.key(36, "\r", flags: .command)
        } else { try await host.clickCompositionControl("unified.field.save") }
        let facts = try #require(controller.taskFieldUnit?.taskField)
        #expect(facts.state == .saved && service.count("save") == 1 && service.count("ui") == 1)
        #expect(service.io.notificationProcessed == 1 && service.io.calendarProcessed == 1)
        #expect(service.base.io.authorizations.isEmpty)
        controller.requestOperationSubmit(old)
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        try await host.key(36, "\r", flags: .command)
        #expect(service.count("save") == 1 && service.count("ui") == 1)
        try await host.revealSettingControlInsidePanel("unified.field.status")
        try host.snapshot("tm2-" + name + "-saved")
        return facts
    }
}
