import AppKit
import SwiftData
import Testing
@testable import AreaChain

/// T-M4 原生夹具：合成内存库、私有事件与 fake 剪贴板；回收与复制只在此显式装配。
@MainActor final class UnifiedSearchTrashFixture {
    let service: TrashCommandFixture
    let results: UnifiedSearchResultsFixture
    let writer = FakeClipboardWriter()
    let privacy = NotificationCenter()
    var controller: UnifiedSearchController { results.controller }
    var base: BatchCommandFixture { service.base }

    init(count: Int = 3) throws {
        service = try TrashCommandFixture(count: count)
        service.base.routine.isEnabled = true
        service.base.todos[1].notes = "  第二项备注\n第二行 👩🏽‍💻  "
        try service.context.save()
        var batch = QueryBatchFixture.empty("/tasks")
        var issues: [TaskContentQueryReadIssue] = []
        TaskContentQueryReader(context: service.context).readSources(into: &batch, issues: &issues)
        #expect(issues.isEmpty)
        _ = RoutineContentQueryReader(reads: .init(context: service.context)).readSources(
            into: &batch, observation: RoutineContentQueryFixture.observation(batch.dates.todayKey))
        batch.facts.metadata = .init(tagNames: Dictionary(uniqueKeysWithValues: service.base.tags.map { ($0.id, $0.name) }),
                                     privateTagIDs: [])
        let base = service.base
        let copy = try TaskCopyCommandEnvironment(context: service.context, source: { _ in
            .init(revision: base.sourceRevision, protection: .ordinary)
        }, writer: writer)
        results = try .init(batch, pageSize: 20, privacyCenter: privacy, trashEnvironment: service.base.environment,
                            trashCapability: .softTrash, taskCopyEnvironment: copy)
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

    func command(_ path: String, host: UnifiedSearchTestHost) async throws {
        try await UnifiedSearchCommandDriver.command(path, controller: controller, host: host)
    }

    func select(_ objects: [CommandObjectReference], host: UnifiedSearchTestHost) async throws {
        try await UnifiedSearchCommandDriver.select(objects, controller: controller, host: host)
    }

    func prepareAndAccept(_ host: UnifiedSearchTestHost, name: String) async throws -> CommandTrashAcceptance {
        try await host.clickCompositionControl("unified.trash.prepare")
        let preview = try #require(controller.currentTrashPreview, "回收准备失败：\(controller.trashFailure ?? "none")")
        #expect(service.count("save") == 0 && service.count("ui") == 0)
        try await host.revealSettingControlInsidePanel("unified.trash.values")
        try host.snapshot("tm4-" + name + "-preview")
        try await host.clickCompositionControl("unified.trash.accept")
        let accepted = try #require(controller.currentTrashAcceptance)
        #expect(accepted.preview == preview && service.count("save") == 0)
        return accepted
    }

    /// ⌘Return 与“检查后移到回收站”同一入口：只打开确认，绝不写入。
    func openConfirmation(_ host: UnifiedSearchTestHost, chord: Bool) async throws -> CommandTrashConfirmation {
        if chord {
            host.window.makeFirstResponder(try host.field)
            try await host.settle()
            try await host.key(36, "\r", flags: .command)
        } else { try await host.clickCompositionControl("unified.trash.review") }
        let confirmation = try #require(controller.trashConfirmation, "确认未打开：\(controller.trashFailure ?? "none")")
        #expect(service.count("save") == 0 && controller.settingExecution == nil)
        return confirmation
    }

    func focused(_ identifier: String, host: UnifiedSearchTestHost) throws -> Bool {
        try UnifiedSearchCommandDriver.focused(identifier, host: host)
    }

    func label(_ identifier: String, host: UnifiedSearchTestHost) throws -> String? {
        try UnifiedSearchCommandDriver.label(identifier, host: host)
    }

    func has(_ identifier: String, host: UnifiedSearchTestHost) -> Bool {
        UnifiedSearchCommandDriver.has(identifier, host: host)
    }
}
