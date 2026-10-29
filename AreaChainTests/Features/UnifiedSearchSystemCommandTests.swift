import AppKit
import SwiftData
import Testing
@testable import AreaChain

/// 系统指令的隔离 fake：激活、显示、浮层、关闭、退出全部只计数，绝不真的退出测试宿主。
@MainActor final class SystemCommandFakes {
    var dismisses = 0, activations = 0, shows = 0, closes = 0, toggles = 0, modes: [BoardTab] = []
    var quitAlerts: [String] = [], diaryConfirms = 0, terminations = 0
    var quitResponse: NSApplication.ModalResponse = .alertSecondButtonReturn
    var diaryConfirmation = true
    let windows = DiaryWindows()
    let delegate = AppDelegate()

    func install(_ fixture: UnifiedSearchNavigationFixture, overlayMode: Bool = false) -> WorkspacePageCommands {
        let pages = WorkspacePageCommands(router: fixture.router, host: fixture.hostContext, context: fixture.context)
        let opening = AppWindows.WorkspaceOpening(navigation: fixture.navigation,
            dismissOverlay: { [unowned self] in dismisses += 1 }, activate: { [unowned self] in activations += 1 },
            show: { [unowned self] in shows += 1 })
        delegate.terminationPolicy = .application
        delegate.terminationLocale = { Locale(identifier: "en") }
        delegate.presentQuitConfirmation = { [unowned self] alert in quitAlerts.append(alert.messageText); return quitResponse }
        delegate.confirmDiaryTermination = { [unowned self] in diaryConfirms += 1; return diaryConfirmation }
        pages.system = .init(opening: opening, closeWorkspace: { [unowned self] in closes += 1 },
            toggleOverlay: { [unowned self] in toggles += 1 },
            overlayMode: overlayMode ? { [unowned self] in modes.append($0) } : nil,
            diaryWindows: windows,
            requestTermination: { [unowned self] in delegate.applicationShouldTerminate(NSApp) },
            terminate: { [unowned self] in terminations += 1 }, vault: fixture.vault, today: { fixture.day })
        fixture.controller.pageCommands = pages
        return pages
    }

    func closeAll() { for controller in windows.openControllers { controller.window.close() } }
}

@Suite(.serialized, .tags(.backgroundWindow)) @MainActor struct UnifiedSearchSystemCommandTests {
    @Test func windowAndPanelCommandsReuseExistingWindows() async throws {
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        let fakes = SystemCommandFakes()
        _ = fakes.install(fixture)
        try await fixture.start(focus: .background)
        // 只数可见的顶层窗口：今日页面板是原有的 sheet，收起后 AppKit 仍可能把 sheet 窗口留在 NSApp.windows 里。
        let topLevel = { NSApp.windows.filter { $0.isVisible && $0.sheetParent == nil }.count }
        let windows = topLevel()
        try await fixture.enter("/window/workspace/open")
        #expect(SettingsButtonTestSupport.elements(fixture.window?.contentView).contains {
            SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String == "unified.system.preview"
        })
        try await run(fixture)
        #expect(fixture.router.mounted("page.dashboard"))
        #expect((fakes.dismisses, fakes.activations, fakes.shows) == (1, 1, 1))
        #expect(fixture.controller.returnSearch != nil, "沿 N-M1 导航，保留返回票据")
        try await fixture.go("/window/workspace/reveal")
        #expect(fakes.shows == 2 && fixture.router.mounted("page.dashboard"))
        try await fixture.go("/window/overlay/toggle")
        #expect(fakes.toggles == 1)
        try await fixture.go("/window/overlay/mode/diaries")
        #expect(fixture.controller.navigationMessage == "unified.system.overlay.modeUnavailable" && fakes.modes.isEmpty)
        // 没有指令草稿时只调注入的关闭；有草稿时不关工作台。
        try await fixture.back()
        try await fixture.go("/window/workspace/close")
        #expect(fakes.closes == 1, "只调注入的关闭")
        try await fixture.enter("/tasks/add")
        _ = fixture.controller.beginOperation(.init(rawValue: "todo.create"), source: fixture.controller.buffer)
        #expect(fixture.controller.operations?.active != nil)
        _ = fixture.controller.navigationInput("/window/workspace/close")
        #expect(fixture.controller.systemActionBlocked && fixture.controller.hidesResultsForCommand)
        // 被挡时候选标签不再写“Return 前往”；Return 不关工作台，但要给一句明确的拒绝反馈。
        #expect(fixture.controller.disposition(for: .init(rawValue: "workspace.close")) == .blockedByUnsavedWork)
        fixture.controller.executeNavigation(source: fixture.controller.buffer)
        #expect(fixture.controller.navigationMessage == UnifiedSearchController.closeRefusedKey)
        #expect(fixture.controller.showsNavigationMessage)
        #expect(fakes.closes == 1)
        // 就地放弃草稿后解除阻挡，输入仍是关闭指令。
        fixture.controller.discardActiveOperation(source: fixture.controller.buffer)
        #expect(fixture.controller.operations?.active == nil && !fixture.controller.systemActionBlocked)
        #expect(fixture.controller.disposition(for: .init(rawValue: "workspace.close")) == .navigates)
        #expect(!fixture.controller.showsNavigationMessage, "放弃草稿后不再留着“没有关闭”")
        #expect(fixture.controller.buffer.text == "/window/workspace/close")
        fixture.controller.executeNavigation(source: fixture.controller.buffer)
        #expect(fakes.closes == 2)
        try await fixture.go("/window/routines/manage")
        #expect(fixture.router.mounted("page.today"))
        #expect(fixture.window?.attachedSheet != nil, "今日页原有的管理面板")
        try await dismissSheet(fixture)
        try await fixture.go("/window/routines/add")
        #expect(fixture.window?.attachedSheet != nil, "今日页原有的新建面板")
        try await dismissSheet(fixture)
        #expect(topLevel() == windows, "不新建窗口")
        #expect(fixture.saves == 0 && !fixture.context.hasChanges)
    }

    @Test func diaryWindowsOpenOnceRefuseProtectedAndKeepCloseConfirmation() async throws {
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        let fakes = SystemCommandFakes()
        defer { fakes.closeAll() }
        let pages = fakes.install(fixture)
        let plain = DiaryEntry(text: "m3 plain diary", dayKey: fixture.day)
        let secret = DiaryEntry(text: "m3 secret diary", dayKey: fixture.day)
        secret.isPrivate = true
        fixture.context.insert(plain)
        fixture.context.insert(secret)
        try fixture.context.save()
        let saves = fixture.saves
        try await fixture.start(focus: .background)
        try pages.openDiaryWindow(.init(type: .diary, id: plain.id))
        try pages.openDiaryWindow(.init(type: .diary, id: plain.id))
        #expect(fakes.windows.openControllers.count == 1, "同一手记只有一个小窗")
        #expect(throws: CommandPageIssue.protectedContent) { try pages.openDiaryWindow(.init(type: .diary, id: secret.id)) }
        try await fixture.go("/window/diary/pinned")
        let window = try #require(fakes.windows.openControllers.first)
        #expect(window.window.level == .floating && !plain.isPinned)
        try await fixture.go("/window/diary/pinned/false")
        #expect(window.window.level == .normal)
        // 有未保存内容：沿小窗自己的关闭，出现原有确认；取消后窗口仍在。
        window.session.text += " edited"
        try await fixture.go("/window/diary/close")
        let sheet = try #require(window.window.attachedSheet)
        window.window.endSheet(sheet, returnCode: .alertThirdButtonReturn)
        try await fixture.settle()
        #expect(fakes.windows.openControllers.count == 1)
        window.session.text = String(window.session.text.dropLast(" edited".count))
        try await fixture.go("/window/diary/close")
        #expect(fakes.windows.openControllers.isEmpty)
        // 手记页草稿转小窗：窗口持有、来源清空，不写库；受保护草稿留给原页面。
        fixture.navigation.diaryDraft.text = "m3 draft"
        try await fixture.go("/window/diary/draft")
        #expect(fakes.windows.openControllers.count == 1 && fixture.navigation.diaryDraft.text.isEmpty)
        #expect(fakes.windows.openControllers.first?.session.text == "m3 draft")
        fixture.navigation.diaryDraft.needsProtection = true
        try await fixture.go("/window/diary/draft")
        #expect(fixture.controller.navigationMessage == "unified.system.diary.draftProtected")
        #expect(fixture.saves == saves)
        #expect(try fixture.context.fetchCount(FetchDescriptor<DiaryEntry>()) == 2)
        #expect(CommandSystemAction.commands.contains("diaryWindow.save"), "合并批 M-4 已接小窗会话保存")
    }

    @Test func statsMatchDashboardAndHidePrivateDiaries() async throws {
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        let fakes = SystemCommandFakes()
        let pages = fakes.install(fixture)
        fixture.todo.isDone = true
        let secret = DiaryEntry(text: "m3 hidden words", dayKey: fixture.day)
        secret.isPrivate = true
        fixture.context.insert(secret)
        fixture.context.insert(DiaryEntry(text: "m3 public", dayKey: fixture.day))
        try fixture.context.save()
        try await fixture.start(focus: .background)
        let snapshot = try pages.statsSnapshot(day: nil)
        let direct = DashboardStatsReader.snapshot(
            todos: try fixture.context.fetch(FetchDescriptor<TodoItem>()), routines: try fixture.context.fetch(FetchDescriptor<DailyRoutine>()),
            checks: try fixture.context.fetch(FetchDescriptor<RoutineCheck>()), diaries: try fixture.context.fetch(FetchDescriptor<DiaryEntry>()),
            tags: try fixture.context.fetch(FetchDescriptor<TagItem>()), todayKey: fixture.day)
        #expect(snapshot == direct)
        #expect(snapshot.summary.todayDiaryCount == 1, "私密手记不计入，与总览页同一口径")
        let locale = Locale(identifier: "en")
        let all = CommandStatsKind.allCases.flatMap { UnifiedSearchSystemBlock.lines($0, snapshot: snapshot, locale: locale) }
            + snapshot.activities.map { $0.displayTitle(locale: locale) }
        #expect(!all.contains { $0.contains("hidden words") })
        #expect(UnifiedSearchSystemBlock.lines(.today, snapshot: snapshot, locale: locale)
            == [L10n.format("unified.stats.today", locale: locale, snapshot.summary.todayStat.completedCount,
                            snapshot.summary.todayStat.scheduledCount, snapshot.summary.todayStat.skippedCount,
                            snapshot.summary.todayStat.openCount)])
        try await fixture.enter("/stats/today")
        let lines = SettingsButtonTestSupport.elements(fixture.window?.contentView).filter {
            SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String == "unified.stats.line"
        }
        #expect(lines.count == 1)
        try await fixture.go("/stats/open-day/2026-10-07")
        #expect(fixture.router.mounted("page.calendar") && fixture.navigation.inspectingDayKey == fixture.day)
        try await fixture.back()
        if let todoActivity = snapshot.activities.first(where: {
            if case .inspectItem(let id, _, _) = $0.route { return id == fixture.todo.id } else { return false }
        }) {
            fixture.controller.openStatsActivity(todoActivity, source: fixture.controller.buffer)
            await fixture.controller.navigationTask?.value
            #expect(fixture.navigation.selectedTaskID == fixture.todo.id)
        }
        #expect(!fixture.context.hasChanges)
    }

    @Test func quitKeepsOriginalConfirmationAndNeverTerminatesHost() async throws {
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        let fakes = SystemCommandFakes()
        _ = fakes.install(fixture)
        try await fixture.start(focus: .background)
        try await fixture.go("/quit")
        #expect(fakes.quitAlerts == [L10n.string("alert.quit.title", locale: Locale(identifier: "en"))])
        #expect(fakes.diaryConfirms == 0 && fakes.terminations == 0)
        #expect(fixture.controller.navigationMessage == "unified.system.quit.cancelled")
        fakes.quitResponse = .alertFirstButtonReturn
        fakes.diaryConfirmation = false
        try await fixture.go("/quit")
        #expect(fakes.diaryConfirms == 1 && fakes.terminations == 0, "未保存手记取消时不退出")
        fakes.diaryConfirmation = true
        try await fixture.go("/quit")
        #expect(fakes.diaryConfirms == 2 && fakes.terminations == 1, "只调注入的 fake，不真正退出")
        #expect(fixture.controller.navigationMessage == "unified.system.quit.confirmed")
        #expect(NSApp.isRunning)
    }

    private func run(_ fixture: UnifiedSearchNavigationFixture) async throws {
        fixture.controller.intent(.open, source: fixture.controller.buffer)
        await fixture.controller.navigationTask?.value
        try await fixture.settle()
    }

    private func dismissSheet(_ fixture: UnifiedSearchNavigationFixture) async throws {
        let window = try #require(fixture.window)
        if let sheet = window.attachedSheet { window.endSheet(sheet) }
        for _ in 0..<50 where window.attachedSheet != nil { try await Task.sleep(for: .milliseconds(20)) }
        try await fixture.settle()
        try await fixture.back()
    }
}
