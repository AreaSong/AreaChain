import AppKit
import SwiftData
import Testing
@testable import AreaChain

/// T-M6 原生交互：排序位置数字输入、昨天全部延至今日预览、剪贴板加今天的读取提示。只发合成原生事件、只用合成数据。
@Suite(.serialized) @MainActor struct UnifiedSearchTM6InteractionTests {
    private static func localized(_ key: String, style: Int) -> String {
        L10n.format(key, locale: Locale(identifier: style < 2 ? "en" : "zh-Hans"))
    }

    /// 排序用 position 数字参数表达新位置，不依赖选择器登记顺序；预览逐项列出位置变化。
    @Test(arguments: [0, 1, 2, 3]) func routineOrderTakesTypedPosition(style: Int) async throws {
        let f = try UnifiedSearchTM6Fixture()
        defer { f.results.stop() }
        let host = try await f.host(style)
        defer { host.close() }
        let target = CommandObjectReference(type: .routine, id: f.routines[2].id)
        try await UnifiedSearchCommandDriver.command("/routines/order", controller: f.controller, host: host)
        try await UnifiedSearchCommandDriver.select([target], controller: f.controller, host: host)
        try await f.type("1", into: .position, host: host)
        #expect(f.controller.editingDraft?.arguments.first { $0.parameter == .position }?.value == .number(1))
        let accepted = try await f.prepareAndAccept(host, name: "order-\(style)")
        #expect(accepted.preview.after.rows.map(\.title) == ["冥想 · Meditate", "晨跑 · Run", "读书 · Read"])
        let changes = accepted.preview.before.changes(to: accepted.preview.after)
        let moved = try #require(changes.first { $0.title == "冥想 · Meditate" })
        #expect(moved.before == .verbatim("3") && moved.after == .verbatim("1"))
        #expect(UnifiedSearchCommandDriver.has("unified.simple.change.position", host: host))
        _ = try await f.save(host, name: "order-\(style)", chord: style % 2 == 0)
        #expect(f.routines.map(\.sortOrder) == [1, 2, 0])
        #expect(try f.text("unified.simple.status", host: host) == Self.localized("unified.simple.order.saved", style: style))
    }

    /// 越界位置在准备时就被拒绝，显示原因，不写入。
    @Test func outOfRangePositionShowsReason() async throws {
        let f = try UnifiedSearchTM6Fixture()
        defer { f.results.stop() }
        let host = try await f.host(2)
        defer { host.close() }
        try await UnifiedSearchCommandDriver.command("/routines/order", controller: f.controller, host: host)
        try await UnifiedSearchCommandDriver.select([.init(type: .routine, id: f.routines[0].id)], controller: f.controller, host: host)
        try await f.type("9", into: .position, host: host)
        try await host.clickCompositionControl("unified.simple.prepare")
        #expect(f.controller.currentSimplePreview == nil && f.controller.simpleFailure == "unified.simple.problem.outOfRange")
        #expect(try f.text("unified.simple.issue", host: host) == Self.localized("unified.simple.problem.outOfRange", style: 2))
        #expect(f.service.count("save") == 0)
    }

    /// 预览列出目标数量与每项日期变化；一次保存全部延至今天。
    @Test(arguments: [0, 1, 2, 3]) func postponeYesterdayPreviewsCountAndTitles(style: Int) async throws {
        let f = try UnifiedSearchTM6Fixture()
        defer { f.results.stop() }
        let host = try await f.host(style)
        defer { host.close() }
        try await f.begin("/tasks/postpone-yesterday", host: host)
        try await host.clickCompositionControl("unified.parameter.date")
        // 原生日期格在本宿主里找不到按钮标识（与 §9.90 记录的既有失败同因）；改走日期选择器绑定背后的同一参数入口。
        _ = f.controller.editParameter(.init(parameter: .day, operation: .assign, value: .day(TaskSimpleFixture.today)),
                                       source: f.controller.buffer)
        try await host.settle()
        #expect(f.controller.editingDraft?.arguments.first { $0.parameter == .day }?.value == .day(TaskSimpleFixture.today))
        let accepted = try await f.prepareAndAccept(host, name: "postpone-\(style)")
        #expect(Set(accepted.preview.before.rows.map(\.title)) == ["昨天没做 · Missed", "更早没做 · Older"])
        let count = L10n.format("unified.simple.count", locale: Locale(identifier: style < 2 ? "en" : "zh-Hans"), 2)
        #expect(try f.text("unified.simple.count", host: host) == count)
        #expect(UnifiedSearchCommandDriver.has("unified.simple.change.day", host: host))
        _ = try await f.save(host, name: "postpone-\(style)", chord: style % 2 == 1)
        #expect(f.overdue.allSatisfy { $0.dayKey == TaskSimpleFixture.today } && f.service.count("save") == 1)
    }

    /// 准备阶段只提示“将读取当前剪贴板”，不读取；提交后才读一次并加到今天。
    @Test(arguments: [0, 1, 2, 3]) func clipboardCaptureReadsOnlyAfterSubmit(style: Int) async throws {
        let f = try UnifiedSearchTM6Fixture()
        defer { f.results.stop() }
        f.clipboard.text = "剪贴板文字 · Clip #标签"
        let host = try await f.host(style)
        defer { host.close() }
        try await f.begin("/capture/clipboard", host: host)
        try await host.clickCompositionControl("unified.clipboardCapture.prepare")
        #expect(f.controller.currentClipboardCapturePreview != nil && f.clipboard.reads == 0)
        #expect(try f.text("unified.clipboardCapture.notice", host: host)
                == Self.localized("unified.clipboardCapture.readNotice", style: style))
        try await host.revealSettingControlInsidePanel("unified.clipboardCapture.submit")
        try host.snapshot("tm6-clipboard-\(style)-preview")
        if style % 2 == 0 {
            host.window.makeFirstResponder(try host.field)
            try await host.settle()
            try await host.key(36, "\r", flags: .command)
        } else { try await host.clickCompositionControl("unified.clipboardCapture.submit") }
        #expect(f.clipboard.reads == 1 && f.controller.clipboardCapture.facts?.state == .saved)
        #expect(try f.text("unified.clipboardCapture.status", host: host)
                == Self.localized("unified.clipboardCapture.state.saved", style: style))
        try host.snapshot("tm6-clipboard-\(style)-saved")
        let todo = try #require(try f.service.stored(TodoItem.self).first { $0.title == "剪贴板文字 · Clip #标签" })
        #expect(todo.dayKey == TaskSimpleFixture.today && f.service.count("save") == 1)
        // 同一份预览已用过：再按一次不会再读剪贴板或重复新建。
        f.controller.requestOperationSubmit(f.controller.buffer)
        try await host.settle()
        let todos = try f.service.stored(TodoItem.self)
        #expect(f.clipboard.reads == 1 && todos.count == 3)
    }
}
