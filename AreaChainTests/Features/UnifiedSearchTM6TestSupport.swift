import AppKit
import SwiftData
import Testing
@testable import AreaChain

/// T-M6 原生夹具：合成内存库、私有事件、计数 fake 刷新、注入剪贴板与临时附件目录、固定今天。
/// 排序与延至今日沿 X-1 骨架装配；剪贴板加今天沿 todo.copy 的无 Run 模式装配。只在此显式装配。
@MainActor final class UnifiedSearchTM6Fixture {
    let service: TaskSimpleFixture
    let results: UnifiedSearchResultsFixture
    /// 注入的剪贴板：只计读取次数，不碰系统剪贴板。
    @MainActor final class ClipboardFake {
        var text: String?
        var reads = 0
    }
    let clipboard: ClipboardFake
    let routines: [DailyRoutine]
    let overdue: [TodoItem]
    var controller: UnifiedSearchController { results.controller }

    init() throws {
        let service = try TaskSimpleFixture()
        self.service = service
        routines = try [("晨跑 · Run", 0), ("读书 · Read", 1), ("冥想 · Meditate", 2)].map {
            try service.insert(DailyRoutine(title: $0.0, sortOrder: $0.1, createdDayKey: "2026-10-01"))
        }
        overdue = try [("昨天没做 · Missed", TaskSimpleFixture.yesterday), ("更早没做 · Older", "2026-10-12")].map {
            try service.insert(TodoItem(title: $0.0, dayKey: $0.1))
        }
        var batch = QueryBatchFixture.empty("/routines")
        _ = RoutineContentQueryReader(reads: .init(context: service.context)).readSources(
            into: &batch, observation: RoutineContentQueryFixture.observation(batch.dates.todayKey))
        let environment = service.environment!
        let specs = TaskCommandSpecs.all(service.dependencies)
        let clipboard = ClipboardFake()
        self.clipboard = clipboard
        let clipboardEnvironment = try ClipboardCaptureCommandEnvironment(context: service.context, center: service.io.center,
            capture: .init(read: { clipboard.reads += 1; return .init(text: clipboard.text, image: nil) },
                           storage: AttachmentStore(root: service.root), locale: { Locale(identifier: "zh-Hans") },
                           today: { TaskSimpleFixture.today }, sourceBundleID: { "" }),
            stampsSource: { false }, transaction: service.io.boundary)
        results = try .init(batch, pageSize: 20, simple: { coordinator in
            SimpleCommandAdapter(coordinator: coordinator, environment: environment, specs: specs, capability: .open)
        }, clipboard: { ClipboardCaptureCommandAdapter(coordinator: $0, environment: clipboardEnvironment) })
    }

    /// 0 标准英文浅色、1 紧凑英文深色、2 标准中文深色、3 紧凑中文浅色；紧凑 304pt 为最小支持宽度代表。
    func host(_ style: Int) async throws -> UnifiedSearchTestHost {
        _ = try await results.publish()
        let host = UnifiedSearchTestHost(layout: style % 2 == 0 ? .standard : .compact,
            width: style % 2 == 0 ? 444 : 304, locale: style < 2 ? "en" : "zh-Hans",
            dark: style == 1 || style == 2, results: controller, operations: true)
        try await host.start()
        return host
    }

    func begin(_ path: String, host: UnifiedSearchTestHost) async throws {
        let editor = try host.editor
        editor.insertText(path, replacementRange: .init(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        try await host.key(48, "\t")
    }

    /// 经原参数文本框输入数字：原生插入文本后 Return 确认，与其他文本参数同一入口。
    func type(_ text: String, into parameter: CommandParameterID, host: UnifiedSearchTestHost) async throws {
        let editor = try await host.focusParameter(parameter)
        editor.insertText(text, replacementRange: editor.selectedRange())
        try await host.settle()
        try await host.key(36, "\r")
    }

    func prepareAndAccept(_ host: UnifiedSearchTestHost, name: String) async throws -> CommandSimpleAcceptance {
        try await host.clickCompositionControl("unified.simple.prepare")
        let preview = try #require(controller.currentSimplePreview, "准备失败：\(controller.simpleFailure ?? "none")")
        #expect(service.count("save") == 0 && !service.context.hasChanges)
        try await host.revealSettingControlInsidePanel("unified.simple.values")
        try host.snapshot("tm6-" + name + "-preview")
        try await host.clickCompositionControl("unified.simple.accept")
        let accepted = try #require(controller.currentSimpleAcceptance)
        #expect(accepted.preview == preview && service.count("save") == 0)
        return accepted
    }

    func save(_ host: UnifiedSearchTestHost, name: String, chord: Bool) async throws -> CommandSimpleFacts {
        if chord {
            host.window.makeFirstResponder(try host.field)
            try await host.settle()
            try await host.key(36, "\r", flags: .command)
        } else { try await host.clickCompositionControl("unified.simple.save") }
        let facts = try #require(controller.simpleUnit?.simple, "未执行：\(controller.simpleFailure ?? "none")")
        #expect(facts.state == .saved && service.count("save") == 1)
        controller.requestOperationSubmit(controller.buffer)
        try await host.settle()
        #expect(service.count("save") == 1)
        try await host.revealSettingControlInsidePanel("unified.simple.status")
        try host.snapshot("tm6-" + name + "-saved")
        return facts
    }

    func text(_ identifier: String, host: UnifiedSearchTestHost) throws -> String? {
        try UnifiedSearchCommandDriver.text(identifier, host: host)
    }
}
