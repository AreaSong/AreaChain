import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

/// 修复批 M-7G 检查点 A：真实窗口 key 切换（另开一个窗口抢走 key 再交回），不直接调用 loseFocus。
/// 工作台与菜单栏各走一遍：什么都不做时仍遮罩；在搜索框里打字、Return 等显式动作才恢复并重读。
/// 前台套件：发真实键盘事件，不打 .backgroundWindow。
@Suite(.serialized) @MainActor struct UnifiedSearchFocusRecoveryTests {
    enum Kind: CaseIterable { case workspace, menubar }

    @Test(arguments: Kind.allCases) func refocusAloneKeepsMaskAndTypingRestoresResults(kind: Kind) async throws {
        let host = try UnifiedSearchFocusHost(kind)
        defer { host.close() }
        try host.fixture.insert(TodoItem(title: "needle 合成失焦任务", dayKey: UnifiedSearchProductionFixture.today))
        try await host.start()
        try await host.type("needle")
        try await host.waitPublished()
        try await host.switchAwayAndBack()
        // 重新拿到 key 本身不恢复：结果仍隐藏，提示告诉用户怎么恢复。
        #expect(host.controller.session.isMasked)
        #expect((try? host.controller.session.presentation()) == nil)
        #expect(host.controller.messageKey == "unified.results.masked")
        try await host.settle()
        #expect(host.controller.session.isMasked)
        // 显式动作：再打一个字，结果按当前文字重新出现。
        try await host.type("needle 合成")
        try await host.waitPublished()
        #expect(!host.controller.session.isMasked)
        let visible = try host.controller.session.presentation().pagination.snapshot.visible
        #expect(!visible.isEmpty)
    }

    @Test(arguments: Kind.allCases) func returnAfterRefocusNavigatesAndOpensSettingPanel(kind: Kind) async throws {
        let host = try UnifiedSearchFocusHost(kind)
        defer { host.close() }
        try host.fixture.insert(TodoItem(title: "needle 合成失焦任务", dayKey: UnifiedSearchProductionFixture.today))
        try await host.start()
        try await host.type("needle")
        try await host.waitPublished()
        try await host.switchAwayAndBack()
        try await host.type("/setting/appearance")
        try await host.pressReturnUntil { host.controller.operations?.active?.commandID.rawValue == "setting.appearance" }
        #expect(host.controller.operations?.active?.commandID.rawValue == "setting.appearance")
        #expect(host.operationPanelShown)
        try await host.switchAwayAndBack()
        // 面板随遮罩撤下；回到窗口后按 Return 恢复并重新出面板，不再静默。
        #expect(!host.operationPanelShown)
        try await host.pressReturnUntil { host.operationPanelShown }
        #expect(host.operationPanelShown)
        if kind == .workspace {
            try await host.switchAwayAndBack()
            try await host.type("/go/tags")
            try await host.pressReturnUntil { host.fixture.navigation.selectedTab == .tags }
            #expect(host.controller.navigationMessage != "unified.navigation.stale")
            #expect(host.fixture.navigation.selectedTab == .tags)
        }
    }

    /// 锁定按 D3 清掉查询后：切回窗口本身不重建；显式动作由宿主可信当前页面重建，只按这次新文字读取，旧文字与条件不回来；
    /// 仍锁定时受保护内容不出现在结果、摘要与候选里；解锁后再打字照常。
    @Test(arguments: Kind.allCases) func lockedQueryRebuildsFromTrustedPageOnNewInput(kind: Kind) async throws {
        let host = try UnifiedSearchFocusHost(kind)
        defer { host.close() }
        let secret = "M7G_SECRET_BODY"
        let privateTag = try host.fixture.insert(TagItem(name: "m7g-private", sortOrder: 0, isPrivateDiary: true))
        try host.fixture.insert(DiaryEntry(text: "needle \(secret)", dayKey: UnifiedSearchProductionFixture.today,
                                           tagIDs: privateTag.id.uuidString))
        let old = try host.fixture.insert(TodoItem(title: "needle 合成旧查询任务", dayKey: UnifiedSearchProductionFixture.today))
        let fresh = try host.fixture.insert(TodoItem(title: "fresh 合成新查询任务", dayKey: UnifiedSearchProductionFixture.today))
        try await host.fixture.vault.create(password: UnifiedSearchFocusHost.password, systemUnlock: false)
        host.forwardPrivacyEvents()
        try await host.start()
        try await host.type("needle")
        try await host.waitPublished()
        try await host.switchAway()
        host.fixture.vault.lock()
        try await host.settle()
        try await host.switchBack()
        // 被清掉的查询不恢复；重新拿到 key 本身不重建。
        #expect(host.controller.buffer.text.isEmpty && host.controller.queryInputText.isEmpty)
        #expect(host.controller.queryAwaitsTrustedPage, "切回窗口不应重建查询")
        try await host.type("fresh")
        try await host.waitPublished()
        #expect(!host.controller.queryAwaitsTrustedPage)
        #expect(host.controller.queryInputText == "fresh")
        let query = try host.controller.coordinator.host(host.controller.buffer.lease.ownership.hostID).session.query
        #expect(query.page.location.hostID == host.controller.buffer.lease.ownership.hostID)
        #expect(query.page.todayKey != "1970-01-01", "重建用宿主给出的可信页面，不用占位日期")
        let visible = try host.controller.session.presentation().pagination.snapshot.visible
        #expect(visible.contains(.init(type: .todo, id: fresh.id)))
        #expect(!visible.contains(.init(type: .todo, id: old.id)), "旧查询文字不回来")
        // 仍锁定：再搜旧词只能读到锁定可见范围，受保护正文不出现在任何结果、摘要与候选里。
        try await host.type("needle")
        try await host.waitPublished()
        #expect(try host.controller.session.presentation().pagination.snapshot.visible.contains(.init(type: .todo, id: old.id)))
        #expect(!host.allStrings.contains { $0.contains(secret) })
        // 解锁后照常再打字。
        try await host.fixture.vault.unlockWithPassword(UnifiedSearchFocusHost.password)
        try await host.settle()
        try await host.type("fresh 合成")
        try await host.waitPublished()
        #expect(host.controller.queryInputText == "fresh 合成")
        #expect(try host.controller.session.presentation().pagination.snapshot.visible.contains(.init(type: .todo, id: fresh.id)))
    }

    /// 锁定后 Return 也是显式动作：重建页面但只得到空查询，不读回旧文字。
    @Test(arguments: Kind.allCases) func returnAfterLockRebuildsEmptyQuery(kind: Kind) async throws {
        let host = try UnifiedSearchFocusHost(kind)
        defer { host.close() }
        try host.fixture.insert(TodoItem(title: "needle 合成公开任务", dayKey: UnifiedSearchProductionFixture.today))
        try await host.start()
        try await host.type("needle")
        try await host.waitPublished()
        try await host.switchAway()
        host.fixture.center.post(name: .privacyWillLock, object: host.fixture.vault)
        try await host.settle()
        try await host.switchBack()
        #expect(host.controller.queryAwaitsTrustedPage)
        try await host.key(36, "\r")
        #expect(!host.controller.queryAwaitsTrustedPage)
        #expect(host.controller.buffer.text.isEmpty && host.controller.queryInputText.isEmpty)
    }

    /// 认证中／更改方式中：重建不绕过 eligibleHost，仍拒绝并说明；门禁解除后打字照常重建。
    @Test(arguments: Kind.allCases) func rebuildStillHonorsVaultGates(kind: Kind) async throws {
        let host = try UnifiedSearchFocusHost(kind)
        defer { host.close() }
        try host.fixture.insert(TodoItem(title: "needle 合成公开任务", dayKey: UnifiedSearchProductionFixture.today))
        try await host.start()
        try await host.type("needle")
        try await host.waitPublished()
        host.fixture.center.post(name: .privacyWillLock, object: host.fixture.vault)
        try await host.settle()
        try host.fixture.vault.beginMethodChange()
        try await host.settle()
        try await host.type("needle")
        #expect(host.controller.queryAwaitsTrustedPage, "门禁拒绝时不重建")
        #expect(host.controller.queryInputText.isEmpty)
        #expect((try? host.controller.session.presentation()) == nil)
        #expect(host.controller.navigationMessage == "unified.gate.vaultBusy")
        host.fixture.vault.endMethodChange()
        try await host.settle()
        try await host.type("needle 合成")
        try await host.waitPublished()
        #expect(!host.controller.queryAwaitsTrustedPage && host.controller.queryInputText == "needle 合成")
    }

    /// 切回后输入指令（改字即显式动作）：解除遮罩后按保留的查询重读，结果重新可用，焦点对象类指令不会因结果为空而失败。
    @Test(arguments: Kind.allCases) func typingCommandAfterRefocusRereadsRetainedQuery(kind: Kind) async throws {
        let host = try UnifiedSearchFocusHost(kind)
        defer { host.close() }
        try host.fixture.insert(TodoItem(title: "needle 合成失焦任务", dayKey: UnifiedSearchProductionFixture.today))
        try await host.start()
        try await host.type("needle")
        try await host.waitPublished()
        try await host.switchAwayAndBack()
        #expect((try? host.controller.session.presentation()) == nil)
        try await host.type("/inspector/open")
        try await host.waitPublished()
        #expect(!host.controller.session.isMasked)
        let visible = try host.controller.session.presentation().pagination.snapshot.visible
        #expect(visible.contains { $0.type == .todo })
        if kind == .workspace {
            try await host.key(36, "\r")
            #expect(host.controller.navigationMessage != "unified.navigation.stale")
        }
    }

    /// 工作台刚打开、停在原页面（searchPresentation 为 false）时直接输入指令：输入即回到搜索页，Return 出面板，不再静默。
    @Test func commandTypedOnOriginalPageOpensPanel() async throws {
        let host = try UnifiedSearchFocusHost(.workspace)
        defer { host.close() }
        try await host.start()
        #expect(!host.fixture.navigation.isSearching)
        try await host.type("/setting/appearance")
        try await host.pressReturnUntil { host.operationPanelShown }
        #expect(host.controller.operations?.active?.commandID.rawValue == "setting.appearance")
        #expect(host.operationPanelShown && host.fixture.navigation.isSearching)
    }

    /// 从搜索导航到目的地（持有返回票据）后输入修改类指令：Return／⌘Return 先回到搜索页并保留指令，再出面板；
    /// 点“返回搜索”也不再用保留查询覆盖正在输入的指令。
    @Test(arguments: [false, true]) func commandOnNavigatedDestinationReturnsToSearch(command: Bool) async throws {
        let host = try UnifiedSearchFocusHost(.workspace)
        defer { host.close() }
        _ = try await navigatedWithCommand(host)
        try await host.key(36, "\r", flags: command ? .command : [])
        try await host.waitUntil { host.operationPanelShown }
        #expect(host.fixture.navigation.isSearching && host.controller.returnSearch == nil)
        #expect(host.controller.operations?.active?.commandID.rawValue == "setting.appearance")
        #expect(host.controller.buffer.text.hasPrefix("/setting/appearance"), "\(host.controller.buffer.text)")
        #expect(host.controller.navigationMessage != "unified.gate.navigationPresented")
    }

    @Test func returnButtonKeepsTypedCommand() async throws {
        let host = try UnifiedSearchFocusHost(.workspace)
        defer { host.close() }
        let ticket = try await navigatedWithCommand(host)
        await host.controller.returnToSearch(ticket.id)
        try await host.settle()
        #expect(host.fixture.navigation.isSearching)
        #expect(host.controller.buffer.text == "/setting/appearance", "\(host.controller.buffer.text)")
        #expect(host.controller.operations?.active == nil, "只回到搜索页，不替用户开始")
    }

    /// 已有草稿时在目的地按 ⌘Return：只回到搜索页与面板，不在用户看到预览前提交。
    @Test func commandReturnWithExistingDraftOnlyShowsPanel() async throws {
        let host = try UnifiedSearchFocusHost(.workspace)
        defer { host.close() }
        try host.fixture.insert(TodoItem(title: "needle 合成导航任务", dayKey: UnifiedSearchProductionFixture.today))
        try await host.start()
        try await host.type("needle")
        try await host.waitPublished()
        try await host.type("/setting/appearance")
        try await host.pressReturnUntil { host.controller.operations?.active != nil }
        let draft = try #require(host.controller.operations?.active)
        try await host.type("/go/tags")
        try await host.pressReturnUntil { host.fixture.navigation.selectedTab == .tags }
        try #require(host.controller.returnSearch != nil)
        try await host.focusField()
        try await host.type("/setting/appearance")
        try await host.key(36, "\r", flags: .command)
        try await host.waitUntil { host.operationPanelShown }
        #expect(host.controller.operations?.active?.id == draft.id, "仍是原草稿，没有提交或替换")
        #expect(!host.controller.settingSubmitting && host.controller.settingExecution == nil)
    }

    /// 目的地上的导航指令不回搜索页，仍跳转并保留同一张票据；接受带参数的修改类候选会回到搜索页且参数不丢。
    @Test func destinationKeepsNavigationAndAcceptsArgumentCandidate() async throws {
        let host = try UnifiedSearchFocusHost(.workspace)
        defer { host.close() }
        let ticket = try await navigatedWithCommand(host)
        try await host.type("/go/calendar")
        try await host.pressReturnUntil { host.fixture.navigation.selectedTab == .calendar }
        #expect(host.fixture.navigation.selectedTab == .calendar && host.controller.returnSearch?.id == ticket.id)
        try await host.focusField()
        try await host.type("/setting/appearance/")
        try await host.key(36, "\r")
        try await host.waitUntil { host.operationPanelShown }
        let active = try #require(host.controller.operations?.active)
        #expect(active.commandID.rawValue == "setting.appearance")
        #expect(!active.arguments.isEmpty, "接受的参数值随回到搜索页保留：\(host.controller.buffer.text)")
        #expect(host.fixture.navigation.isSearching)
    }

    /// 外观改一次已应用、结果卡未点“完成”时：再输入另一条外观指令，Return／⌘Return 不越过结果卡（不建第二份草稿、
    /// 不改偏好），反馈行给出原因；点“完成”收起结果卡后，同一指令再按 Return 照常开始草稿。
    @Test func secondAppearanceWaitsForAppliedResult() async throws {
        let host = try UnifiedSearchFocusHost(.workspace)
        defer { host.close() }
        try await host.start()
        try await host.type("/setting/appearance/dark")
        try await host.pressReturnUntil { host.controller.operations?.active != nil }
        try await host.key(36, "\r", flags: .command)
        try await host.settle()
        #expect(host.controller.settingExecution != nil && host.controller.operations?.active == nil, "首次应用后结果卡占用执行")
        try await host.type("/setting/appearance/system")
        for _ in 0..<3 { try await host.key(36, "\r") }
        #expect(host.controller.operations?.active == nil && host.controller.settingExecution != nil)
        #expect(host.controller.navigationMessage == "unified.gate.busy" && host.feedbackShown)
        try await host.key(36, "\r", flags: .command)
        #expect("\(host.fixture.preferences.appearance)" == "dark", "结果卡未收起时不应用第二条")
        let done = try #require(SettingsButtonTestSupport.elements(host.window.contentView).first {
            SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String == "unified.setting.done"
        })
        _ = done.perform(NSSelectorFromString("accessibilityPerformPress"))
        try await host.settle()
        #expect(host.controller.settingExecution == nil)
        try await host.focusField()
        try await host.type("/setting/appearance/system")
        try await host.pressReturnUntil { host.controller.operations?.active != nil }
        #expect(host.controller.operations?.active?.commandID.rawValue == "setting.appearance")
    }

    /// 目的地上为指令回到搜索页的过程中再按 Return：只回一次、只开一份草稿，结束后 commandReturnPending 复位。
    @Test func repeatedReturnDuringCommandReturnRunsOnce() async throws {
        let host = try UnifiedSearchFocusHost(.workspace)
        defer { host.close() }
        _ = try await navigatedWithCommand(host)
        try await host.keysWithoutWaiting([36, 36])
        #expect(host.controller.commandReturnPending, "第一次 Return 已开始回到搜索页")
        try await host.waitUntil { !host.controller.commandReturnPending && host.operationPanelShown }
        #expect(host.controller.operations?.active?.commandID.rawValue == "setting.appearance")
        #expect(host.controller.operations?.retained.isEmpty == true, "第二次 Return 不另开草稿")
        #expect(host.fixture.navigation.isSearching && host.controller.returnSearch == nil)
    }

    /// 回到搜索页被拒（工作台有附着的表单）：commandReturnPending 复位、不开草稿、停在目的地；表单关闭后 Return 照常。
    @Test func cancelledCommandReturnResetsPending() async throws {
        let host = try UnifiedSearchFocusHost(.workspace)
        defer { host.close() }
        _ = try await navigatedWithCommand(host)
        let sheet = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 80), styleMask: [.titled], backing: .buffered, defer: false)
        host.window.beginSheet(sheet, completionHandler: nil)
        try await host.settle()
        host.controller.intent(.open, source: host.controller.buffer)
        try await host.waitUntil { !host.controller.commandReturnPending }
        #expect(host.controller.operations?.active == nil && !host.fixture.navigation.isSearching)
        #expect(host.controller.returnSearch != nil, "被拒时票据保留，仍可返回")
        host.window.endSheet(sheet)
        try await host.settle()
        try await host.switchBack()
        try await host.focusField()
        try await host.key(36, "\r")
        try await host.waitUntil { host.operationPanelShown }
        #expect(host.controller.operations?.active?.commandID.rawValue == "setting.appearance")
    }

    /// 搜索 needle → /go/tags 导航（持有票据）→ 在目的地输入修改类指令；输入本身不切页。
    private func navigatedWithCommand(_ host: UnifiedSearchFocusHost) async throws -> UnifiedSearchReturnContext {
        try host.fixture.insert(TodoItem(title: "needle 合成导航任务", dayKey: UnifiedSearchProductionFixture.today))
        try await host.start()
        try await host.type("needle")
        try await host.waitPublished()
        try await host.type("/go/tags")
        try await host.pressReturnUntil { host.fixture.navigation.selectedTab == .tags }
        let ticket = try #require(host.controller.returnSearch, "从搜索导航应持有返回票据")
        try await host.focusField()
        try await host.type("/setting/appearance")
        #expect(host.controller.isNavigationPresented && !host.fixture.navigation.isSearching)
        return ticket
    }

    @Test(arguments: Kind.allCases) func gatedReturnExplainsWhyNothingStarted(kind: Kind) async throws {
        let host = try UnifiedSearchFocusHost(kind)
        defer { host.close() }
        try await host.start()
        try await host.type("/setting/appearance")
        try await host.switchAwayAndBack()
        // 隐私方式更改中（与认证中同一道门禁）：恢复入口不能绕过 eligibleHost 的门禁；Return 给出一句可见原因。
        try host.fixture.vault.beginMethodChange()
        defer { host.fixture.vault.endMethodChange() }
        try await host.settle()
        try await host.key(36, "\r")
        try await host.key(36, "\r")
        #expect(host.controller.operations?.active == nil && !host.operationPanelShown)
        #expect(host.controller.navigationMessage == "unified.gate.vaultBusy")
        #expect(host.feedbackShown)
    }
}
