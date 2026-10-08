import AppKit
import SwiftData
import Testing
@testable import AreaChain

@MainActor final class UnifiedSearchRoutineCreateFixture {
    let service: RoutineCreateFixture
    let results: UnifiedSearchResultsFixture
    let privacy = NotificationCenter()
    var controller: UnifiedSearchController { results.controller }

    init() throws {
        service = try RoutineCreateFixture()
        // 没有任何搜索命中仍可进入新增；写入库含用于不变性核对的合成旧定义。
        results = try .init(QueryBatchFixture.empty("/routines"), pageSize: 20,
                            privacyCenter: privacy, routineEnvironment: service.environment)
    }
    func host(_ style: Int = 0) async throws -> UnifiedSearchTestHost {
        _ = try await results.publish()
        let host = UnifiedSearchTestHost(layout: style % 2 == 0 ? .standard : .compact,
            width: style % 2 == 0 ? 444 : 304, locale: style < 2 ? "en" : "zh-Hans",
            dark: style == 1 || style == 2, results: controller, operations: true)
        try await host.start()
        return host
    }
    func begin(_ host: UnifiedSearchTestHost) async throws {
        let editor = try host.editor
        editor.insertText("/routines/add", replacementRange: .init(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        try await host.key(48, "\t")
        #expect(controller.editingDraft?.commandID.rawValue == "routine.create")
        #expect(controller.editingDraft?.targets == CommandDraftTargets.none && controller.objectSelection == nil)
    }
    func title(_ raw: String, host: UnifiedSearchTestHost) async throws {
        let editor = try await host.focusParameter(.title)
        editor.insertText(raw, replacementRange: .init(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        try await host.key(36, "\r")
        await controller.objectSelectionTask?.value
        try await host.settle()
    }
    func weekdays(_ days: [Int], locale: String, host: UnifiedSearchTestHost) async throws {
        try await host.revealSettingControlInsidePanel("unified.parameter.weekdays")
        for day in days {
            let button = try WeekdayPickerTestSupport.day(day, locale: locale, in: host.window)
            try await SettingsButtonTestSupport.click(button, in: host.window)
            try await host.settle()
        }
    }
    func prepare(_ host: UnifiedSearchTestHost, name: String) async throws -> CommandRoutineCreateAcceptance {
        try await host.clickCompositionControl("unified.routineCreate.prepare")
        let preview = try #require(controller.currentRoutineCreatePreview, "预览失败：\(controller.routineCreateFailure ?? "none")")
        #expect(service.base.count("save") == 0 && !service.context.hasChanges)
        if name.hasPrefix("minimal-") || name.hasPrefix("attributes-") {
            try await host.revealSettingControlInsidePanel("unified.routineCreate.title")
            try host.snapshot("rm2-" + name + "-values")
        }
        try await host.revealSettingControlInsidePanel("unified.routineCreate.defaults")
        try host.snapshot("rm2-" + name + "-preview")
        try await host.clickCompositionControl("unified.routineCreate.accept")
        let accepted = try #require(controller.currentRoutineCreateAcceptance)
        #expect(accepted.preview == preview && service.base.count("save") == 0)
        return accepted
    }
    func submit(_ host: UnifiedSearchTestHost, name: String, chord: Bool) async throws -> CommandRoutineCreateFacts {
        let old = controller.buffer
        if chord {
            host.window.makeFirstResponder(try host.field)
            try await host.settle()
            try await host.key(36, "\r", flags: .command)
        } else { try await host.clickCompositionControl("unified.routineCreate.create") }
        let facts = try #require(controller.routineCreationUnit?.routineCreation)
        #expect(facts.state == .saved && facts.createdObject?.type == .routine)
        #expect(service.base.count("save") == 1 && service.base.count("ui") == 1)
        controller.requestOperationSubmit(old)
        controller.requestOperationSubmit(controller.buffer)
        #expect(service.base.count("save") == 1)
        try await host.revealSettingControlInsidePanel("unified.routineCreate.status")
        try host.snapshot("rm2-" + name + "-saved")
        return facts
    }
}
