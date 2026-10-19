import AppKit
import SwiftData
import Testing
@testable import AreaChain

/// T-M5 原生夹具：合成内存库、私有事件、固定时钟与计数 fake 日历刷新；转换只在此显式装配。
@MainActor final class UnifiedSearchConvertFixture {
    let service: ConvertCommandFixture
    let results: UnifiedSearchResultsFixture
    let privacy = NotificationCenter()
    let router: WorkspaceSearchRouter
    var controller: UnifiedSearchController { results.controller }
    var base: BatchCommandFixture { service.base }

    init(todoNotes: String = "") throws {
        let service = try ConvertCommandFixture()
        self.service = service
        service.routine.isEnabled = true
        service.todo.notes = todoNotes
        try service.context.save()
        var batch = QueryBatchFixture.empty("/tasks")
        var issues: [TaskContentQueryReadIssue] = []
        TaskContentQueryReader(context: service.context).readSources(into: &batch, issues: &issues)
        #expect(issues.isEmpty)
        _ = RoutineContentQueryReader(reads: .init(context: service.context)).readSources(
            into: &batch, observation: RoutineContentQueryFixture.observation(batch.dates.todayKey))
        batch.facts.metadata = .init(tagNames: Dictionary(uniqueKeysWithValues: service.base.tags.map { ($0.id, $0.name) }),
                                     privateTagIDs: [])
        let environment = service.base.environment!
        results = try .init(batch, pageSize: 20, privacyCenter: privacy, convert: { coordinator in
            ConvertCommandAdapter(coordinator: coordinator, environment: environment, capability: .convert,
                clock: .init(now: { ConvertCommandFixture.now }, today: { service.today }, calendar: ConvertCommandFixture.calendar),
                refreshCalendar: { service.refreshes += 1 })
        })
        router = WorkspaceSearchRouter(navigation: WorkspaceNavigation(boardSelection: BoardSelection()),
            objects: WorkspaceObjectNavigation(context: service.context, calendar: ConvertCommandFixture.calendar,
                                               allows: { _ in true }))
        results.controller.navigationRouter = router
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

    func choose(_ path: String, _ target: CommandObjectReference, host: UnifiedSearchTestHost) async throws {
        try await UnifiedSearchCommandDriver.command(path, controller: controller, host: host)
        try await UnifiedSearchCommandDriver.select([target], controller: controller, host: host)
    }

    func prepareAndAccept(_ host: UnifiedSearchTestHost, name: String) async throws -> CommandConvertAcceptance {
        try await host.clickCompositionControl("unified.convert.prepare")
        let preview = try #require(controller.currentConvertPreview, "转换准备失败：\(controller.convertFailure ?? "none")")
        #expect(service.count("save") == 0 && service.count("ui") == 0)
        try await host.revealSettingControlInsidePanel("unified.convert.values")
        try host.snapshot("tm5-" + name + "-preview")
        try await host.clickCompositionControl("unified.convert.accept")
        let accepted = try #require(controller.currentConvertAcceptance)
        #expect(accepted.preview == preview && service.count("save") == 0)
        return accepted
    }

    /// ⌘Return 与“检查后转换”同一入口：只打开确认，绝不写入。
    func openConfirmation(_ host: UnifiedSearchTestHost, chord: Bool) async throws -> CommandConvertConfirmation {
        if chord {
            host.window.makeFirstResponder(try host.field)
            try await host.settle()
            try await host.key(36, "\r", flags: .command)
        } else { try await host.clickCompositionControl("unified.convert.review") }
        let confirmation = try #require(controller.convertConfirmation, "确认未打开：\(controller.convertFailure ?? "none")")
        #expect(service.count("save") == 0 && controller.settingExecution == nil)
        return confirmation
    }

    /// 宿主里没有完整工作台：挂上页面与检查器占位视图，只验证复用的原导航把新对象定位到检查器。
    func mountWorkspace(for created: CommandObjectReference, host: UnifiedSearchTestHost) {
        router.host = host.window.contentView
        guard let view = host.window.contentView else { return }
        for tab in WorkspaceTab.allCases { router.mount(view, key: "page." + tab.rawValue) }
        router.mount(view, key: "object." + created.id.uuidString)
    }

    func focused(_ identifier: String, host: UnifiedSearchTestHost) throws -> Bool {
        try UnifiedSearchCommandDriver.focused(identifier, host: host)
    }
    func text(_ identifier: String, host: UnifiedSearchTestHost) throws -> String? {
        try UnifiedSearchCommandDriver.text(identifier, host: host)
    }
    func has(_ identifier: String, host: UnifiedSearchTestHost) -> Bool { UnifiedSearchCommandDriver.has(identifier, host: host) }
}
