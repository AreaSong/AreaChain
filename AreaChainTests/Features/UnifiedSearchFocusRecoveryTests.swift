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
        #expect(host.controller.session.isMasked == false || host.controller.operationVisible == false)
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

    @Test(arguments: Kind.allCases) func lockedQueryNeverReturnsAfterRefocus(kind: Kind) async throws {
        let host = try UnifiedSearchFocusHost(kind)
        defer { host.close() }
        let secret = "M7G_SECRET_BODY"
        let privateTag = try host.fixture.insert(TagItem(name: "m7g-private", sortOrder: 0, isPrivateDiary: true))
        try host.fixture.insert(DiaryEntry(text: "needle \(secret)", dayKey: UnifiedSearchProductionFixture.today,
                                           tagIDs: privateTag.id.uuidString))
        try host.fixture.insert(TodoItem(title: "needle 合成公开任务", dayKey: UnifiedSearchProductionFixture.today))
        try await host.start()
        try await host.type("needle")
        try await host.waitPublished()
        try await host.switchAway()
        host.fixture.center.post(name: .privacyWillLock, object: host.fixture.vault)
        try await host.settle()
        try await host.switchBack()
        // D3：锁定清掉的查询不因恢复回来；按 Return 只得到空查询，不会重读旧文字。
        #expect(host.controller.buffer.text.isEmpty && host.controller.queryInputText.isEmpty)
        try await host.key(36, "\r")
        #expect(host.controller.buffer.text.isEmpty && host.controller.queryInputText.isEmpty)
        // 锁定后查询只能从可信页面重建（ContentQueryReducer.privacyReset）：再打字被拒绝，不露出任何结果，且给出可见原因。
        try await host.type("needle")
        #expect(host.controller.queryInputText.isEmpty)
        #expect((try? host.controller.session.presentation()) == nil)
        #expect(host.controller.navigationMessage == "unified.gate.pageContext")
        // 只看统一搜索的结果边界：工作台下方的原页面按原界面规则显示，不属于本断言。
        #expect(!host.resultStrings.contains { $0.contains(secret) })
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

/// 前台宿主：正式版唯一装配（内存容器、隔离保险箱、fake 副作用），另一个普通窗口用来真实抢走 key。
@MainActor final class UnifiedSearchFocusHost {
    let kind: UnifiedSearchFocusRecoveryTests.Kind
    let fixture: UnifiedSearchProductionFixture
    let production = UnifiedSearchProduction()
    let toolbar = MenuBarToolbarState()
    var window: NSWindow!
    let away: NSWindow

    init(_ kind: UnifiedSearchFocusRecoveryTests.Kind) throws {
        self.kind = kind
        fixture = try UnifiedSearchProductionFixture()
        production.start(center: fixture.center, makeServices: { [fixture] in fixture.services() })
        try #require(production.assembly != nil)
        away = NSWindow(contentRect: NSRect(x: 40, y: 40, width: 240, height: 120), styleMask: [.titled], backing: .buffered, defer: false)
        away.isReleasedWhenClosed = false
        away.title = "M7G away"
    }

    var controller: UnifiedSearchController {
        kind == .workspace ? production.assembly!.workspace! : production.assembly!.menubar!
    }

    func start() async throws {
        let root: AnyView = kind == .workspace
            ? AnyView(UnifiedSearchWorkspaceRoot(production: production))
            : AnyView(MenuBarPopoverView(toolbar: toolbar, composer: BoardComposerSession(), filterSession: BoardFilterSession(),
                                         production: production))
        let content = root.modelContainer(fixture.container).environment(\.modelContext, fixture.context)
            .environment(fixture.preferences).environment(\.locale, Locale(identifier: "zh-Hans"))
            .transaction { $0.disablesAnimations = true }
        let window = NSWindow(contentViewController: NSHostingController(rootView: content))
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.setContentSize(kind == .workspace ? NSSize(width: 1200, height: 800) : DaybookMetrics.Window.popoverSize)
        self.window = window
        NSApp.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface"))
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await settle()
        try await focusField()
    }

    var field: NSTextField {
        get throws {
            try #require(SettingsButtonTestSupport.elements(window.contentView).compactMap { $0 as? NSTextField }
                .first { $0.cell is UnifiedSearchFieldCell && !Self.insideOperation($0) })
        }
    }

    static func insideOperation(_ view: NSView) -> Bool {
        var ancestor = view.superview
        while let current = ancestor {
            if current is UnifiedSearchOperationBoundary { return true }
            ancestor = current.superview
        }
        return false
    }

    var editor: NSTextView { get throws { try #require(try field.currentEditor() as? NSTextView) } }
    var inputState: UnifiedSearchInputState {
        get throws { try #require((try field.delegate as? DaybookTextField.Coordinator)?.parent.unifiedSearch) }
    }

    /// 候选浮层里标题匹配的那一行在窗口坐标里的中心（取自实际无障碍树，不写死行高）。
    func candidateCenter(_ title: String) throws -> NSPoint {
        let node = try #require(SettingsButtonTestSupport.elements(window.contentView).first {
            (SettingsButtonTestSupport.value($0, "accessibilityLabel") as? String)?.hasPrefix(title) == true
        }, "候选行缺失：\(title)")
        let rect = try SettingsButtonTestSupport.frame(node, in: window)
        return NSPoint(x: rect.midX, y: rect.midY)
    }

    func click(_ point: NSPoint) async throws {
        try #require(window.isKeyWindow, "测试窗口不是 key window")
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            NSApp.sendEvent(event)
        }
        try await settle()
    }

    func focusField() async throws {
        if kind == .menubar { toolbar.focusSearch() } else { window.makeFirstResponder(try field) }
        try await settle()
        if (try? field.currentEditor()) == nil { window.makeFirstResponder(try field); try await settle() }
        _ = try editor
    }

    /// 原生输入：整段替换编辑器文字（与用户全选后输入同一路径）。
    func type(_ text: String) async throws {
        let input = try editor
        input.setSelectedRange(NSRange(location: 0, length: (input.string as NSString).length))
        input.insertText(text, replacementRange: input.selectedRange())
        try await settle()
    }

    func key(_ code: UInt16, _ character: String, flags: NSEvent.ModifierFlags = []) async throws {
        try #require(window.isKeyWindow, "测试窗口不是 key window")
        let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            characters: character, charactersIgnoringModifiers: character, isARepeat: false, keyCode: code))
        NSApp.sendEvent(event)
        try await settle()
        await controller.navigationTask?.value
        try await settle()
    }

    /// 候选活动时第一次 Return 先接受候选；最多按三次，直到条件成立（B 的证据另由专门用例记录）。
    func pressReturnUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<3 where !condition() { try await key(36, "\r") }
    }

    func waitPublished() async throws {
        for _ in 0..<150 where (try? controller.session.presentation()) == nil { try await Task.sleep(for: .milliseconds(20)) }
        try await settle()
    }

    func switchAway() async throws {
        away.makeKeyAndOrderFront(nil)
        for _ in 0..<100 where window.isKeyWindow || !away.isKeyWindow { try await Task.sleep(for: .milliseconds(10)) }
        try #require(!window.isKeyWindow && away.isKeyWindow, "未能真实切走 key")
        try await settle()
    }

    func switchBack() async throws {
        window.makeKeyAndOrderFront(nil)
        for _ in 0..<100 where !window.isKeyWindow { try await Task.sleep(for: .milliseconds(10)) }
        try #require(window.isKeyWindow, "未能切回 key")
        try await settle()
        if (try? field.currentEditor()) == nil { try await focusField() }
    }

    func switchAwayAndBack() async throws {
        try await switchAway()
        try await switchBack()
    }

    var operationPanelShown: Bool {
        SettingsButtonTestSupport.elements(window.contentView).compactMap { $0 as? UnifiedSearchOperationBoundary }
            .contains { !$0.subviews.isEmpty }
    }

    var resultStrings: [String] {
        let boundaries = SettingsButtonTestSupport.elements(window.contentView).compactMap { $0 as? UnifiedSearchResultsBoundary }
        return boundaries.flatMap { SettingsButtonTestSupport.elements($0) }.flatMap { element in
            ["accessibilityLabel", "accessibilityValue"].compactMap { SettingsButtonTestSupport.value(element, $0) as? String }
        }
    }

    var feedbackShown: Bool {
        let id = kind == .workspace ? "unified.navigation.feedback" : "menubar.unified.feedback"
        return NativeSyntaxUI.identifiers(in: window).contains(id)
    }

    func settle() async throws { if let window { try await SystemPageHost.settle(window) } }

    func close() {
        away.orderOut(nil)
        away.close()
        if let window { SystemPageHost.release(window) }
        production.stop(center: fixture.center)
        fixture.cleanup()
    }
}
