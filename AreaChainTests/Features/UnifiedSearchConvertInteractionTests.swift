import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchConvertInteractionTests {
    private static let todoLosses = ["headline.toRoutine", "weekday", "dueAndDone", "subtasks", "attachments.toRoutine", "original.todo"]
    private static let routineLosses = ["headline.toTodo", "today", "schedule", "checks", "templates", "attachments.toTodo",
                                        "original.routine"]

    @Test(arguments: [0, 1, 2, 3]) func todoToRoutineLossesConfirmationKeyboardAndOpenNewRoutine(style: Int) async throws {
        let f = try UnifiedSearchConvertFixture()
        defer { f.results.stop() }
        let host = try await f.host(style)
        defer { host.close() }
        try await f.choose("/tasks/convert-to-routine", f.service.todoTarget, host: host)
        let accepted = try await f.prepareAndAccept(host, name: "toRoutine-\(style)")
        for key in Self.todoLosses { #expect(f.has("unified.convert.loss." + key, host: host), "缺少损失说明 \(key)") }
        let weekday = try #require(try f.text("unified.convert.loss.weekday", host: host))
        let locale = Locale(identifier: style < 2 ? "en" : "zh-Hans")
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        #expect(weekday.contains("2026-10-09") && weekday.contains(calendar.standaloneWeekdaySymbols[5]))
        let plan = try #require(f.controller.plan)
        let confirmation = try await f.openConfirmation(host, chord: style % 2 == 0)
        #expect(confirmation.summary == accepted.preview.impact.losses && confirmation.titles == [f.service.todo.title])
        _ = try host.resultNode("unified.convert.confirmTitle")
        for key in Self.todoLosses { #expect(f.has("unified.convert.loss." + key, host: host)) }
        // 默认焦点在取消；确认需要用户主动移过去。
        #expect(try f.focused("unified.convert.cancel", host: host))
        #expect(try !f.focused("unified.convert.confirm", host: host))
        try host.snapshot("tm5-toRoutine-confirm-\(style)")
        f.controller.requestOperationSubmit(f.controller.buffer)
        try await host.settle()
        #expect(f.service.count("save") == 0 && f.controller.convertConfirmation == confirmation)
        try await host.key(53, "\u{1B}")
        #expect(f.controller.convertConfirmation == nil && f.service.count("save") == 0)
        #expect(f.controller.plan?.items == plan.items && f.controller.currentConvertAcceptance == accepted)
        let second = try await f.openConfirmation(host, chord: false)
        #expect(second.id != confirmation.id)
        try await host.key(48, "\t")
        #expect(try f.focused("unified.convert.confirm", host: host))
        try await host.clickCompositionControl("unified.convert.confirm")
        let facts = try #require(f.controller.convertUnit?.conversion, "转换未执行：\(f.controller.convertFailure ?? "none")")
        #expect(facts.state == .saved && f.service.count("save") == 1 && f.service.count("ui") == 1 && f.service.refreshes == 1)
        #expect(try f.service.routines(accepted.createdID).count == 1 && f.service.todo.deletedAt != nil)
        try await host.revealSettingControlInsidePanel("unified.convert.open")
        try host.snapshot("tm5-toRoutine-result-\(style)")
        f.mountWorkspace(for: facts.created, host: host)
        try await host.clickCompositionControl("unified.convert.open")
        await f.controller.navigationTask?.value
        guard case .object(let location)? = f.router.destination else {
            Issue.record("未经原导航定位新习惯：\(f.controller.navigationMessage ?? "none") \(f.controller.convertFailure ?? "")"); return
        }
        #expect(location.object == .init(type: .routineOccurrence, id: accepted.createdID, dayKey: "2026-10-18"))
        #expect(f.router.navigation.inspectedReference == .recurring(accepted.createdID))
    }

    @Test(arguments: [1, 2]) func routineToTodoLossesAndOpenNewTask(style: Int) async throws {
        let f = try UnifiedSearchConvertFixture()
        defer { f.results.stop() }
        let host = try await f.host(style)
        defer { host.close() }
        try await f.choose("/routines/convert-to-task", f.service.routineTarget, host: host)
        let accepted = try await f.prepareAndAccept(host, name: "toTodo-\(style)")
        for key in Self.routineLosses { #expect(f.has("unified.convert.loss." + key, host: host), "缺少损失说明 \(key)") }
        #expect(try f.text("unified.convert.loss.today", host: host)?.contains("2026-10-18") == true)
        _ = try await f.openConfirmation(host, chord: true)
        #expect(try f.focused("unified.convert.cancel", host: host))
        try host.snapshot("tm5-toTodo-confirm-\(style)")
        try await host.clickCompositionControl("unified.convert.cancel")
        #expect(f.controller.convertConfirmation == nil && f.controller.currentConvertAcceptance == accepted)
        _ = try await f.openConfirmation(host, chord: false)
        try await host.clickCompositionControl("unified.convert.confirm")
        let facts = try #require(f.controller.convertUnit?.conversion)
        #expect(facts.state == .saved && f.service.count("save") == 1 && f.service.refreshes == 0)
        #expect(f.service.routine.deletedAt != nil && f.service.routine.checks.count == 1)
        try await host.revealSettingControlInsidePanel("unified.convert.open")
        try host.snapshot("tm5-toTodo-result-\(style)")
        f.mountWorkspace(for: facts.created, host: host)
        try await host.clickCompositionControl("unified.convert.open")
        await f.controller.navigationTask?.value
        guard case .object(let location)? = f.router.destination else {
            Issue.record("未经原导航定位新待办：\(f.controller.navigationMessage ?? "none")"); return
        }
        #expect(location.object == facts.created && location.dayKey == "2026-10-18")
    }

    @Test func targetChangedAfterConfirmationRequiresRepreview() async throws {
        let f = try UnifiedSearchConvertFixture()
        defer { f.results.stop() }
        let host = try await f.host(2)
        defer { host.close() }
        try await f.choose("/tasks/convert-to-routine", f.service.todoTarget, host: host)
        let accepted = try await f.prepareAndAccept(host, name: "changed")
        _ = try await f.openConfirmation(host, chord: false)
        f.service.todo.title = "确认后外部改名 · Renamed"
        try f.service.context.save()
        try await host.clickCompositionControl("unified.convert.confirm")
        #expect(f.controller.convertConfirmation == nil && f.controller.convertPreview == nil && f.controller.convertAcceptance == nil)
        #expect(f.controller.convertFailure == "unified.convert.problem.changed" && f.controller.settingExecution == nil)
        #expect(try f.service.routines(accepted.createdID).isEmpty && f.service.count("save") == 0 && f.service.todo.deletedAt == nil)
        try await host.revealSettingControlInsidePanel("unified.convert.issue")
        try host.snapshot("tm5-changed-rejected")
    }

    /// 合并批 M-1 B：带备注的待办可以转换；损失清单与独立确认面板都单列“备注原样搬到新对象”。
    @Test(arguments: [0, 3]) func todoWithNotesListsNotesInLossesAndConfirmation(style: Int) async throws {
        let f = try UnifiedSearchConvertFixture(todoNotes: "合成备注 · synthetic note")
        defer { f.results.stop() }
        let host = try await f.host(style)
        defer { host.close() }
        try await f.choose("/tasks/convert-to-routine", f.service.todoTarget, host: host)
        _ = try await f.prepareAndAccept(host, name: "notes-\(style)")
        let text = L10n.string("unified.convert.loss.notes", locale: Locale(identifier: style < 2 ? "en" : "zh-Hans"))
        #expect(try f.text("unified.convert.loss.notes", host: host) == text)
        _ = try await f.openConfirmation(host, chord: style % 2 == 0)
        #expect(try f.text("unified.convert.loss.notes", host: host) == text)
        #expect(f.service.count("save") == 0)
        try host.snapshot("m1-convert-notes-\(style)")
    }
}
