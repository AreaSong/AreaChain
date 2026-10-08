import AppKit
import SwiftData
import Testing
@testable import AreaChain

@MainActor final class UnifiedSearchRoutineFixture {
    let service: RoutineCommandFixture
    let results: UnifiedSearchResultsFixture
    let privacy = NotificationCenter()
    var controller: UnifiedSearchController { results.controller }
    var target: CommandObjectReference { .init(type: .routine, id: service.routine.id) }
    var second: CommandObjectReference { .init(type: .routine, id: service.other.id) }

    init(enabled: Bool = true, assembled: Bool = true) throws {
        service = try RoutineCommandFixture(enabled: enabled)
        var batch = QueryBatchFixture.empty("/routines")
        let reads = RoutineContentQueryReads(context: service.context)
        let observation = RoutineContentQueryFixture.observation(batch.dates.todayKey)
        _ = RoutineContentQueryReader(reads: reads).readSources(into: &batch, observation: observation)
        batch.facts.metadata = .init(tagNames: [service.base.live.id: service.base.live.name,
            service.base.deleted.id: service.base.deleted.name], privateTagIDs: [])
        results = try .init(batch, pageSize: 20, privacyCenter: privacy,
                            routineEnvironment: assembled ? service.environment : nil)
    }

    func start(_ command: String, arguments: [CommandArgument]) async throws {
        try results.startOperation(command)
        try await results.acceptObjects([target])
        for argument in arguments {
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
        try await select(target, location: "target", host: host)
    }

    func select(_ object: CommandObjectReference, location: String, host: UnifiedSearchTestHost) async throws {
        try await host.clickCompositionControl("unified.objects.choose." + location)
        await controller.objectSelectionTask?.value
        try await host.settle()
        let picker = try #require(controller.objectSelection)
        let candidates = picker.browse.snapshot.units.flatMap(\.hits)
        #expect(candidates.contains(target) && candidates.contains(second))
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

    func prepare(_ host: UnifiedSearchTestHost, name: String) async throws -> CommandRoutineAcceptance {
        try await host.clickCompositionControl("unified.routine.prepare")
        let preview = try #require(controller.currentRoutinePreview, "真实影响未准备：\(controller.routineFailure ?? "none")")
        #expect(service.count("save") == 0 && service.count("ui") == 0 && !service.context.hasChanges)
        try await host.revealSettingControlInsidePanel("unified.routine.values")
        try SettingsButtonTestSupport.assertBounds([host.resultNode("unified.routine.values")], in: host.window)
        try host.snapshot("rm1-" + name + "-preview")
        let labels = DetailCompletionFixture.strings(in: host.window)
        #expect(!labels.contains("接受子任务影响") && !labels.contains("预览子任务影响"))
        try await host.clickCompositionControl("unified.routine.accept")
        let accepted = try #require(controller.currentRoutineAcceptance)
        #expect(accepted.preview == preview && service.count("save") == 0 && service.count("ui") == 0)
        return accepted
    }

    func submit(_ host: UnifiedSearchTestHost, name: String, chord: Bool) async throws -> CommandRoutineFacts {
        let old = controller.buffer
        if chord {
            host.window.makeFirstResponder(try host.field)
            try await host.settle()
            try await host.key(36, "\r", flags: .command)
        } else { try await host.clickCompositionControl("unified.routine.save") }
        let facts = try #require(controller.routineUnit?.routine)
        #expect(facts.state == .saved && service.count("save") == 1 && service.count("ui") == 1)
        #expect(service.notificationProcessed == 1 && service.calendarProcessed == 1)
        controller.requestOperationSubmit(old)
        host.window.makeFirstResponder(try host.field)
        try await host.settle()
        try await host.key(36, "\r", flags: .command)
        #expect(service.count("save") == 1 && service.count("ui") == 1)
        if facts.savedValues?.keys.contains(where: { [.weekdayMask, .remindMinutes, .isImportant].contains($0) }) == true {
            _ = try host.resultNode("unified.routine.savedValues")
        }
        try await host.revealSettingControlInsidePanel("unified.routine.status")
        try host.snapshot("rm1-" + name + "-saved")
        return facts
    }

}
