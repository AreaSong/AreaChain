import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

/// 菜单栏把自己没接上的指令交给工作台：真实两个窗口（菜单栏浮层窗口与工作台窗口），在菜单栏输入框里打字、按 Return，
/// 由装配里唯一的转交入口显示工作台（测试里让工作台窗口成为 key）、等窗口可见、再由工作台走它自己的 Return 路径。
/// 前台套件：发真实键盘事件，不打 .backgroundWindow。只用内存库与合成文字。
@Suite(.serialized) @MainActor struct UnifiedSearchWorkspaceHandoffTests {
    @Test func navigationCommandFromMenuBarReachesWorkspacePage() async throws {
        let host = try UnifiedSearchHandoffHost()
        defer { host.close() }
        try await host.start()
        try await host.typeInMenuBar("/go/tags")
        let label = host.assembly.menubar.disposition(for: .init(rawValue: "go.tags"))
        #expect(label == .workspaceHandoff)
        // 等工作台自己的导航完成反馈（切页签先于页面挂载完成）。
        try await host.pressReturnInMenuBar { host.assembly.workspace.navigationMessage == "unified.navigation.displayed" }
        #expect(host.workspaceWindow.isVisible && host.workspaceWindow.isKeyWindow)
        #expect(host.fixture.navigation.selectedTab == .tags)
        #expect(host.assembly.router.mounted("page.tags"))
        #expect(host.assembly.workspace.buffer.text == "/go/tags")
        #expect(host.assembly.menubar.buffer.text == "/go/tags", "菜单栏原文字保留")
        #expect(host.assembly.menubar.operations?.active == nil, "菜单栏不另建草稿")
    }

    @Test func originalPageCommandFromMenuBarOpensTrashPage() async throws {
        let host = try UnifiedSearchHandoffHost()
        defer { host.close() }
        try await host.start()
        try await host.typeInMenuBar("/trash/empty")
        #expect(host.assembly.menubar.disposition(for: .init(rawValue: "trash.empty")) == .workspaceHandoff)
        try await host.pressReturnInMenuBar { host.assembly.workspace.navigationMessage == "unified.originalPage.displayed" }
        #expect(host.fixture.navigation.selectedTab == .trash)
        #expect(host.assembly.router.mounted("page.trash"))
        #expect(host.fixture.saves == 0, "打开原页面不写数据")
    }

    /// 打开结果与指令转交走同一入口：菜单栏选中结果按 Return，工作台显示后用同一查询打开同一对象。
    @Test func resultFromMenuBarOpensSameObjectInWorkspace() async throws {
        let host = try UnifiedSearchHandoffHost()
        defer { host.close() }
        let todo = try host.fixture.insert(TodoItem(title: "needle 合成转交任务", dayKey: UnifiedSearchProductionFixture.today))
        try await host.start()
        try await host.typeInMenuBar("needle")
        try await host.waitPublished(host.assembly.menubar)
        try await host.key(125, "\u{F701}", in: host.menubarWindow)
        let object = CommandObjectReference(type: .todo, id: todo.id)
        try #require(try host.assembly.menubar.session.presentation().pagination.browse.active == object)
        try await host.pressReturnInMenuBar { host.fixture.navigation.navigationObject?.object == object }
        #expect(host.assembly.router.outcome == .displayed)
        #expect(host.assembly.workspace.buffer.text == "needle")
    }

    @Test func workspaceDraftBlocksHandoffAndStaysUnchanged() async throws {
        let host = try UnifiedSearchHandoffHost()
        defer { host.close() }
        try await host.start(workspaceFirst: true)
        try await host.typeInWorkspace("/setting/appearance")
        try await host.pressReturnInWorkspace { host.assembly.workspace.operations?.active != nil }
        let draft = try #require(host.assembly.workspace.operations?.active)
        let workspaceText = host.assembly.workspace.buffer.text
        try await host.showMenuBar()
        try await host.typeInMenuBar("/go/tags")
        try await host.pressReturnInMenuBar { host.assembly.workspace.showsBlockedHandoff }
        try await host.settle(host.workspaceWindow)
        #expect(host.workspaceWindow.isVisible)
        #expect(host.assembly.workspace.operations?.active?.id == draft.id, "工作台草稿不被替换")
        #expect(host.assembly.workspace.buffer.text == workspaceText)
        #expect(host.fixture.navigation.selectedTab != .tags)
        #expect(NativeSyntaxUI.identifiers(in: host.workspaceWindow).contains("unified.handoff.blocked"))
        #expect(NativeSyntaxUI.identifiers(in: host.workspaceWindow).contains("unified.system.unsaved.draft"))
        #expect(host.assembly.menubar.buffer.text == "/go/tags", "菜单栏原文字不丢")
    }
}

/// 两个真实窗口共用正式版唯一装配（内存容器、隔离保险箱、fake 副作用）；显示工作台的副作用在测试里换成让工作台窗口成为 key。
@MainActor final class UnifiedSearchHandoffHost {
    let fixture: UnifiedSearchProductionFixture
    let production = UnifiedSearchProduction()
    let toolbar = MenuBarToolbarState()
    var workspaceWindow: NSWindow!
    var menubarWindow: NSWindow!

    init() throws {
        fixture = try UnifiedSearchProductionFixture()
        production.start(center: fixture.center) { [weak self, fixture] in
            var services = fixture.services()
            services.effects.revealWorkspace = { [weak self] in
                guard let self else { return }
                self.fixture.probe.reveals += 1
                // 与正式版一样：浮层收起，工作台窗口前置并成为 key。
                self.menubarWindow?.orderOut(nil)
                self.workspaceWindow?.makeKeyAndOrderFront(nil)
            }
            return services
        }
        try #require(production.assembly != nil)
    }

    var assembly: UnifiedSearchProductionAssembly { production.assembly! }

    func start(workspaceFirst: Bool = false) async throws {
        workspaceWindow = window(AnyView(UnifiedSearchWorkspaceRoot(production: production)), size: NSSize(width: 1200, height: 800))
        menubarWindow = window(AnyView(MenuBarPopoverView(toolbar: toolbar, composer: BoardComposerSession(),
                                                          filterSession: BoardFilterSession(), production: production)),
                               size: DaybookMetrics.Window.popoverSize)
        NSApp.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface"))
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if workspaceFirst {
            workspaceWindow.makeKeyAndOrderFront(nil)
            try await NativeSyntaxUI.prepareFocus(in: workspaceWindow)
            try await settle(workspaceWindow)
        } else {
            // 工作台起初不可见：转交必须先显示它、等它可见，再写入文字。
            try await showMenuBar()
        }
    }

    private func window(_ root: AnyView, size: NSSize) -> NSWindow {
        let content = root.modelContainer(fixture.container).environment(\.modelContext, fixture.context)
            .environment(fixture.preferences).environment(\.locale, Locale(identifier: "zh-Hans"))
            .transaction { $0.disablesAnimations = true }
        let window = NSWindow(contentViewController: NSHostingController(rootView: content))
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.setContentSize(size)
        return window
    }

    func showMenuBar() async throws {
        menubarWindow.makeKeyAndOrderFront(nil)
        for _ in 0..<100 where !menubarWindow.isKeyWindow { try await Task.sleep(for: .milliseconds(10)) }
        try #require(menubarWindow.isKeyWindow, "菜单栏窗口未成为 key")
        try await NativeSyntaxUI.prepareFocus(in: menubarWindow)
        try await settle(menubarWindow)
        toolbar.focusSearch()
        try await settle(menubarWindow)
    }

    func field(in window: NSWindow) throws -> NSTextField {
        try #require(SettingsButtonTestSupport.elements(window.contentView).compactMap { $0 as? NSTextField }
            .first { $0.cell is UnifiedSearchFieldCell && !UnifiedSearchFocusHost.insideOperation($0) })
    }

    private func editor(in window: NSWindow) async throws -> NSTextView {
        let field = try field(in: window)
        if field.currentEditor() == nil { window.makeFirstResponder(field); try await settle(window) }
        return try #require(field.currentEditor() as? NSTextView)
    }

    private func type(_ text: String, in window: NSWindow) async throws {
        let input = try await editor(in: window)
        input.setSelectedRange(NSRange(location: 0, length: (input.string as NSString).length))
        input.insertText(text, replacementRange: input.selectedRange())
        try await settle(window)
    }

    func typeInMenuBar(_ text: String) async throws { try await type(text, in: menubarWindow) }
    func typeInWorkspace(_ text: String) async throws { try await type(text, in: workspaceWindow) }

    func key(_ code: UInt16, _ character: String, in window: NSWindow) async throws {
        try #require(window.isKeyWindow, "按键窗口不是 key window")
        let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            characters: character, charactersIgnoringModifiers: character, isARepeat: false, keyCode: code))
        NSApp.sendEvent(event)
        try await settle(window)
    }

    private func pressReturn(in window: NSWindow) async throws { try await key(36, "\r", in: window) }

    func waitPublished(_ controller: UnifiedSearchController) async throws {
        for _ in 0..<150 where (try? controller.session.presentation()) == nil { try await Task.sleep(for: .milliseconds(20)) }
        try await settle(menubarWindow)
    }

    /// 候选活动时第一次 Return 先接受候选；转交是异步的（等工作台可见），按完后等条件成立。
    func pressReturnInMenuBar(until condition: () -> Bool) async throws {
        for _ in 0..<3 where !condition() && menubarWindow.isKeyWindow {
            try await pressReturn(in: menubarWindow)
            for _ in 0..<150 where !condition() && !menubarWindow.isKeyWindow {
                try await Task.sleep(for: .milliseconds(20))
                try await settle(workspaceWindow)
            }
        }
        for _ in 0..<150 where !condition() { try await Task.sleep(for: .milliseconds(20)); try await settle(workspaceWindow) }
        try #require(condition(), "等待转交结果超时：\(assembly.menubar.navigationMessage)／\(assembly.workspace.navigationMessage)")
    }

    func pressReturnInWorkspace(until condition: () -> Bool) async throws {
        for _ in 0..<3 where !condition() { try await pressReturn(in: workspaceWindow) }
        try #require(condition())
    }

    func settle(_ window: NSWindow?) async throws { if let window { try await SystemPageHost.settle(window) } }

    func close() {
        for window in [menubarWindow, workspaceWindow].compactMap({ $0 }) { SystemPageHost.release(window) }
        production.stop(center: fixture.center)
        fixture.cleanup()
    }
}
