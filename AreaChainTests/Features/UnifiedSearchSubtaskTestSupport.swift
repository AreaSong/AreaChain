import AppKit
import SwiftData
import Testing
@testable import AreaChain

@MainActor final class UnifiedSearchSubtaskFixture {
    let service: SubtaskCommandFixture
    let results: UnifiedSearchResultsFixture
    let privacy = NotificationCenter()
    let secondParent: TodoItem
    let secondChild: SubtaskItem
    var controller: UnifiedSearchController { results.controller }
    var parent: CommandObjectReference { .init(type: .todo, id: service.base.todo.id) }
    var child: CommandObjectReference { .init(type: .subtask, id: service.child.id) }

    init(done: Bool = false, assembled: Bool = true) throws {
        service = try SubtaskCommandFixture()
        service.child.isDone = done
        secondParent = TodoItem(title: "Second parent · 另一父任务", dayKey: "2026-10-05")
        secondChild = SubtaskItem(title: "Second child · 另一子任务", todo: secondParent)
        service.context.insert(secondParent)
        service.context.insert(secondChild)
        try service.context.save()
        var batch = QueryBatchFixture.empty("/tasks")
        var parents = [service.base.todo.snapshot, secondParent.snapshot]
        batch.snapshots.subtasks = .complete(parents.flatMap(\.subtasks))
        for index in parents.indices { parents[index].subtasks = [] }
        batch.snapshots.todos = .complete(parents)
        batch.facts.metadata = .init(tagNames: [service.base.live.id: service.base.live.name,
            service.base.deleted.id: service.base.deleted.name], privateTagIDs: [])
        results = try .init(batch, pageSize: 20, privacyCenter: privacy,
                            subtaskEnvironment: assembled ? service.environment : nil)
    }

    func start(_ command: String, arguments: [CommandArgument]) async throws {
        try results.startOperation(command)
        if command == "subtask.create" { try await results.acceptObjects([parent], location: .parameter(.parent)) }
        else { try await results.acceptObjects([child]) }
        for argument in arguments where argument.parameter != .parent {
            _ = controller.editParameter(argument, source: controller.buffer)
            await controller.objectSelectionTask?.value
        }
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
        try await select(path == "/subtasks/add" ? parent : child,
                         location: path == "/subtasks/add" ? "parent" : "target", host: host)
    }

    func select(_ object: CommandObjectReference, location: String, host: UnifiedSearchTestHost) async throws {
        try await host.clickCompositionControl("unified.objects.choose." + location)
        await controller.objectSelectionTask?.value
        try await host.settle()
        let picker = try #require(controller.objectSelection)
        let candidates = picker.browse.snapshot.units.flatMap(\.hits)
        #expect(candidates.contains(parent) && candidates.contains(child))
        host.window.makeFirstResponder(try host.field)
        for _ in 0...candidates.count {
            if controller.objectSelection?.browse.active == object { break }
            try await host.key(125, "\u{F701}")
        }
        try #require(controller.objectSelection?.browse.active == object)
        try await host.clickCompositionControl("unified.select." + object.searchIdentifier)
        try await host.clickCompositionControl("unified.objects.accept")
        await controller.objectSelectionTask?.value
        try await host.settle()
    }

    func title(_ text: String, host: UnifiedSearchTestHost) async throws {
        let editor = try await host.focusParameter(.title)
        editor.insertText(text, replacementRange: .init(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        try await host.key(36, "\r")
        await controller.objectSelectionTask?.value
        try await host.settle()
    }

    func mode(_ mode: CommandFieldOperation, host: UnifiedSearchTestHost) async throws {
        for _ in 0..<6 {
            if controller.editingDraft?.arguments.first(where: { $0.parameter == .tags })?.operation == mode { return }
            let picker = try await host.compositionPicker("unified.parameter.mode.tags")
            try await PickerNativeTestSupport.keyboardSelection(picker, moveDown: true, in: host.window)
            try await host.settle()
        }
        try #require(controller.editingDraft?.arguments.first { $0.parameter == .tags }?.operation == mode)
    }

    func prepare(_ host: UnifiedSearchTestHost, name: String) async throws -> CommandSubtaskAcceptance {
        try await host.clickCompositionControl("unified.subtask.prepare")
        let preview = try #require(controller.currentSubtaskPreview, "真实影响未准备：\(controller.subtaskFailure ?? "none")")
        #expect(service.count("save") == 0 && service.count("ui") == 0 && !service.context.hasChanges)
        try await host.revealSettingControlInsidePanel("unified.subtask.values")
        try SettingsButtonTestSupport.assertBounds([host.resultNode("unified.subtask.values")], in: host.window)
        try host.snapshot("tm3-" + name + "-preview")
        try await host.clickCompositionControl("unified.subtask.accept")
        let accepted = try #require(controller.currentSubtaskAcceptance)
        #expect(accepted.preview == preview && service.count("save") == 0 && service.count("ui") == 0)
        return accepted
    }

    func submit(_ host: UnifiedSearchTestHost, name: String, chord: Bool) async throws -> CommandSubtaskFacts {
        let old = controller.buffer
        if chord {
            host.window.makeFirstResponder(try host.field)
            try await host.settle()
            try await host.key(36, "\r", flags: .command)
        } else { try await host.clickCompositionControl("unified.subtask.save") }
        let facts = try #require(controller.subtaskUnit?.subtask)
        #expect(facts.state == .saved && service.count("save") == 1 && service.count("ui") == 1)
        #expect(service.notificationProcessed == 1 && service.calendarProcessed == 1 && service.base.io.authorizations.isEmpty)
        controller.requestOperationSubmit(old)
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        try await host.key(36, "\r", flags: .command)
        #expect(service.count("save") == 1 && service.count("ui") == 1)
        try await host.revealSettingControlInsidePanel("unified.subtask.status")
        try host.snapshot("tm3-" + name + "-saved")
        return facts
    }
}
