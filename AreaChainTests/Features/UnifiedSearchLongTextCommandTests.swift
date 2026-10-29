import AppKit
import SwiftData
import Testing
@testable import AreaChain

/// 长文受控借用原生夹具：合成内存库、私有事件中心（隐私事件同走此中心）、计数 fake 刷新与授权、临时附件目录、固定今天。
/// 长文三条只在此显式装配；规格的带键摘要取控制器所在协调者的密钥。
@MainActor final class UnifiedSearchLongTextCommandFixture {
    let service: TaskSimpleFixture
    let results: UnifiedSearchResultsFixture
    let router: WorkspaceSearchRouter
    let todo: TodoItem
    let routine: DailyRoutine
    var controller: UnifiedSearchController { results.controller }

    init() throws {
        let service = try TaskSimpleFixture()
        self.service = service
        todo = try service.insert(TodoItem(title: "备注对象 · Notes", dayKey: TaskSimpleFixture.today, notes: "原备注"))
        routine = try service.insert(DailyRoutine(title: "习惯对象 · Habit", sortOrder: 0, createdDayKey: "2026-10-01"))
        try service.insert(TagItem(name: "私密", sortOrder: 0, isPrivateDiary: true))
        var batch = QueryBatchFixture.empty("/tasks")
        var issues: [TaskContentQueryReadIssue] = []
        TaskContentQueryReader(context: service.context).readSources(into: &batch, issues: &issues)
        _ = RoutineContentQueryReader(reads: .init(context: service.context)).readSources(
            into: &batch, observation: RoutineContentQueryFixture.observation(batch.dates.todayKey))
        let environment = service.environment!
        results = try .init(batch, pageSize: 20, privacyCenter: service.io.center, simple: { coordinator in
            var dependencies = service.dependencies
            dependencies.digest = coordinator.textDigest
            return SimpleCommandAdapter(coordinator: coordinator, environment: environment,
                                        specs: TaskCommandSpecs.all(dependencies) + TaskCommandSpecs.longText(dependencies),
                                        capability: .open)
        })
        router = WorkspaceSearchRouter(navigation: WorkspaceNavigation(boardSelection: BoardSelection()),
            objects: WorkspaceObjectNavigation(context: service.context, calendar: TaskSimpleFixture.calendar, allows: { _ in true }))
        results.controller.assembleLongText(vault: results.vault)
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

    /// 经原长文编辑入口输入：点开参数、原生插入文本，再收起编辑器（不改变草稿）。
    func type(_ text: String, into parameter: CommandParameterID, host: UnifiedSearchTestHost) async throws {
        try await host.clickResult("unified.longText.open." + parameter.rawValue)
        try await host.settle()
        let editor = try #require(controller.longTextEditing?.editor, "长文编辑器未打开")
        try await SettingsButtonTestSupport.reveal(editor, in: host.window)
        try #require(host.window.makeFirstResponder(editor))
        editor.insertText(text, replacementRange: .init(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        controller.endLongText()
        try await host.settle()
    }

    func prepareAndAccept(_ host: UnifiedSearchTestHost, name: String) async throws -> CommandSimpleAcceptance {
        try await host.clickCompositionControl("unified.simple.prepare")
        let preview = try #require(controller.currentSimplePreview, "准备失败：\(controller.simpleFailure ?? "none")")
        #expect(service.count("save") == 0 && !service.context.hasChanges)
        try await host.revealSettingControlInsidePanel("unified.simple.values")
        try host.snapshot("lm1b-" + name + "-preview")
        try await host.clickCompositionControl("unified.simple.accept")
        let accepted = try #require(controller.currentSimpleAcceptance)
        #expect(accepted.preview == preview && service.count("save") == 0)
        return accepted
    }

    func save(_ host: UnifiedSearchTestHost, chord: Bool) async throws -> CommandSimpleFacts? {
        if chord {
            host.window.makeFirstResponder(try host.field)
            try await host.settle()
            try await host.key(36, "\r", flags: .command)
        } else { try await host.clickCompositionControl("unified.simple.save") }
        return controller.simpleUnit?.simple
    }

    func text(_ identifier: String, host: UnifiedSearchTestHost) throws -> String? {
        try UnifiedSearchCommandDriver.text(identifier, host: host)
    }

    static func localized(_ key: String, style: Int, _ argument: String? = nil) -> String {
        let locale = Locale(identifier: style < 2 ? "en" : "zh-Hans")
        return argument.map { L10n.format(key, locale: locale, $0) } ?? L10n.format(key, locale: locale)
    }

    static func surfaces(_ values: [Any]) -> String {
        values.map { value in
            var out = ""
            dump(value, to: &out, maxDepth: 64)
            return out + String(describing: value)
        }.joined()
    }
}

/// 原生交互：长文经原生长文编辑输入，预览逐项列出派生变化，保存只经托管借用；私密标签整条不可执行。
@Suite(.serialized) @MainActor struct UnifiedSearchLongTextCommandTests {
    static let sentinel = "SENTINEL-原生哨兵-51c2"

    @Test(arguments: [0, 1, 2, 3]) func todoNotesNativeEditPreviewAndSave(style: Int) async throws {
        let f = try UnifiedSearchLongTextCommandFixture()
        defer { f.results.stop() }
        let host = try await f.host(style)
        defer { host.close() }
        try await UnifiedSearchCommandDriver.command("/tasks/notes", controller: f.controller, host: host)
        try await UnifiedSearchCommandDriver.select([.init(type: .todo, id: f.todo.id)], controller: f.controller, host: host)
        let text = "新备注 \(Self.sentinel) #普通新标签 !p1 @18:00"
        try await f.type(text, into: .notes, host: host)
        #expect(f.controller.editingDraft?.arguments.first?.value == .longText(text))
        let accepted = try await f.prepareAndAccept(host, name: "notes-\(style)")
        for field in ["notes", "tags", "remind", "priority", "tagState"] {
            #expect(UnifiedSearchCommandDriver.has("unified.simple.change." + field, host: host), "缺少派生行 \(field)")
        }
        // 预览缓存与接受只含印记，不含正文。
        #expect(!UnifiedSearchLongTextCommandFixture.surfaces([f.controller.simplePreview as Any, accepted]).contains(Self.sentinel))
        let facts = try #require(try await f.save(host, chord: style % 2 == 0), "未执行：\(f.controller.simpleFailure ?? "none")")
        #expect(facts.state == .saved && f.service.count("save") == 1 && f.service.authorizations == [1080])
        try await host.revealSettingControlInsidePanel("unified.simple.status")
        try host.snapshot("lm1b-notes-\(style)-saved")
        #expect(try f.text("unified.simple.status", host: host)
                == UnifiedSearchLongTextCommandFixture.localized("unified.simple.notes.saved", style: style))
        let stored = try #require(try f.service.stored(TodoItem.self).first { $0.id == f.todo.id })
        #expect(stored.notes == text && stored.isImportant && stored.isUrgent && stored.remindMinutes == 1080)
        #expect(!UnifiedSearchLongTextCommandFixture.surfaces([facts, try #require(f.controller.settingExecution)]).contains(Self.sentinel))
        // 同一份已用过的接受：再按一次不会重复写入。
        f.controller.requestOperationSubmit(f.controller.buffer)
        try await host.settle()
        #expect(f.service.count("save") == 1)
    }

    @Test(arguments: [1, 2]) func routineCaptureSavesAndOpensNewHabit(style: Int) async throws {
        let f = try UnifiedSearchLongTextCommandFixture()
        defer { f.results.stop() }
        let host = try await f.host(style)
        defer { host.close() }
        let editor = try host.editor
        editor.insertText("/routines/capture", replacementRange: .init(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        try await host.key(48, "\t")
        try await f.type("晨跑 · Run #普通 @07:00 // 备注 \(Self.sentinel)", into: .body, host: host)
        let accepted = try await f.prepareAndAccept(host, name: "capture-\(style)")
        let creation = try #require(accepted.preview.creation)
        #expect(UnifiedSearchCommandDriver.has("unified.simple.change.title", host: host))
        let facts = try #require(try await f.save(host, chord: style % 2 == 0), "未执行：\(f.controller.simpleFailure ?? "none")")
        #expect(facts.state == .saved && facts.creation == creation)
        try await host.revealSettingControlInsidePanel("unified.simple.open")
        try host.snapshot("lm1b-capture-\(style)-saved")
        let created = try #require(try f.service.stored(DailyRoutine.self).first { $0.id == creation.id })
        #expect(created.title == "晨跑 · Run" && created.notes.contains(Self.sentinel) && created.remindMinutes == 420)
        f.router.host = host.window.contentView
        if let view = host.window.contentView {
            for tab in WorkspaceTab.allCases { f.router.mount(view, key: "page." + tab.rawValue) }
            f.router.mount(view, key: "object." + creation.id.uuidString)
        }
        try await host.clickCompositionControl("unified.simple.open")
        await f.controller.navigationTask?.value
        guard case .object(let location)? = f.router.destination else {
            Issue.record("未经原导航定位新习惯：\(f.controller.navigationMessage ?? "none") \(f.controller.simpleFailure ?? "")"); return
        }
        #expect(location.object == .init(type: .routineOccurrence, id: creation.id, dayKey: TaskSimpleFixture.today))
    }

    /// 正文里的私密标签让整条不可执行；预览说明是哪个标签、为什么，不出现接受，保存不可用。
    @Test(arguments: [0, 3]) func privateTagIsExplainedAndNotAcceptable(style: Int) async throws {
        let f = try UnifiedSearchLongTextCommandFixture()
        defer { f.results.stop() }
        let host = try await f.host(style)
        defer { host.close() }
        try await UnifiedSearchCommandDriver.command("/routines/notes", controller: f.controller, host: host)
        try await UnifiedSearchCommandDriver.select([.init(type: .routine, id: f.routine.id)], controller: f.controller, host: host)
        try await f.type("提醒自己 #私密", into: .notes, host: host)
        try await host.clickCompositionControl("unified.simple.prepare")
        let preview = try #require(f.controller.currentSimplePreview, "准备失败：\(f.controller.simpleFailure ?? "none")")
        #expect(!preview.executable)
        try await host.revealSettingControlInsidePanel("unified.simple.blocked")
        try host.snapshot("lm1b-private-\(style)")
        #expect(try f.text("unified.simple.notice", host: host)
                == UnifiedSearchLongTextCommandFixture.localized("unified.simple.notice.privateTag", style: style, "私密"))
        #expect(!UnifiedSearchCommandDriver.has("unified.simple.accept", host: host))
        f.controller.requestOperationSubmit(f.controller.buffer)
        try await host.settle()
        #expect(f.controller.settingExecution == nil && f.service.count("save") == 0 && f.routine.notes.isEmpty)
    }

    /// 保存失败：回执给出“返回编辑”，正文逐字回到草稿；重新预览、接受后保存成功。
    @Test func failedSaveReturnsTextToEditing() async throws {
        let f = try UnifiedSearchLongTextCommandFixture()
        defer { f.results.stop() }
        let host = try await f.host(2)
        defer { host.close() }
        try await UnifiedSearchCommandDriver.command("/tasks/notes", controller: f.controller, host: host)
        try await UnifiedSearchCommandDriver.select([.init(type: .todo, id: f.todo.id)], controller: f.controller, host: host)
        let text = "失败后返回\n第二行"
        try await f.type(text, into: .notes, host: host)
        _ = try await f.prepareAndAccept(host, name: "return")
        f.service.tasks = { TaskSimpleCommandFailureRepository($0, failOn: 1) }
        let failed = try #require(try await f.save(host, chord: false))
        #expect(failed.state == .notSubmitted && f.todo.notes == "原备注")
        try await host.revealSettingControlInsidePanel("unified.simple.return")
        try host.snapshot("lm1b-return")
        try await host.clickCompositionControl("unified.simple.return")
        #expect(f.controller.settingExecution == nil, "未返回：\(f.controller.simpleFailure ?? "none")")
        #expect(f.controller.plan?.items.first?.draft.arguments.first?.value == .longText(text))
        f.service.tasks = { SwiftDataTaskRepository(context: $0) }
        _ = try await f.prepareAndAccept(host, name: "return-again")
        let saved = try #require(try await f.save(host, chord: true))
        #expect(saved.state == .saved && f.todo.notes == text)
    }
}
