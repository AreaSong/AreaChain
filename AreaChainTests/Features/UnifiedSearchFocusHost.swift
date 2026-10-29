import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

/// 前台宿主：正式版唯一装配（内存容器、隔离保险箱、fake 副作用），另一个普通窗口用来真实抢走 key。
@MainActor final class UnifiedSearchFocusHost {
    let kind: UnifiedSearchFocusRecoveryTests.Kind
    let fixture: UnifiedSearchProductionFixture
    let production = UnifiedSearchProduction()
    let toolbar = MenuBarToolbarState()
    var window: NSWindow!
    let away: NSWindow

    private var forwarders: [NSObjectProtocol] = []

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

    /// 连续发几个按键、中间不等渲染与异步任务（复现快速连按）。
    func keysWithoutWaiting(_ codes: [UInt16]) async throws {
        try #require(window.isKeyWindow, "测试窗口不是 key window")
        for code in codes {
            let character = code == 36 ? "\r" : ""
            let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
                characters: character, charactersIgnoringModifiers: character, isARepeat: false, keyCode: code))
            NSApp.sendEvent(event)
        }
    }

    /// 候选活动时第一次 Return 先接受候选；最多按三次，直到条件成立（B 的证据另由专门用例记录）。
    func pressReturnUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<3 where !condition() { try await key(36, "\r") }
    }

    /// 回到搜索页是异步的（先提交检查器、可能重读），等条件成立而不是多按键。
    func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<150 where !condition() { try await Task.sleep(for: .milliseconds(20)); try await settle() }
        try #require(condition(), "等待超时")
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

    static let password = "synthetic-rebuild-password"

    /// 保险箱把锁定与隐私变化发到 default；正式版装配也听 default，这里同步转到夹具的私有中心，时序与正式版一致（锁定前先发 willLock）。
    func forwardPrivacyEvents() {
        for name in [Notification.Name.privacyWillLock, .privacyDidChange] {
            forwarders.append(NotificationCenter.default.addObserver(forName: name, object: fixture.vault, queue: nil) { [fixture] note in
                MainActor.assumeIsolated { fixture.center.post(name: note.name, object: note.object) }
            })
        }
    }

    /// 应用所有窗口（含候选浮层）里可见的无障碍文字，用来断言受保护正文没有从任何地方露出。
    var allStrings: [String] {
        NSApp.windows.filter(\.isVisible).flatMap { SettingsButtonTestSupport.elements($0.contentView) }.flatMap { element in
            ["accessibilityLabel", "accessibilityValue", "accessibilityTitle"].compactMap { SettingsButtonTestSupport.value(element, $0) as? String }
        }
    }

    func settle() async throws { if let window { try await SystemPageHost.settle(window) } }

    func close() {
        for forwarder in forwarders { NotificationCenter.default.removeObserver(forwarder) }
        forwarders = []
        away.orderOut(nil)
        away.close()
        if let window { SystemPageHost.release(window) }
        production.stop(center: fixture.center)
        fixture.cleanup()
    }
}
