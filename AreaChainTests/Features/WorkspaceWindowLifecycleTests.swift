import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct WorkspaceWindowLifecycleTests {
    @Test func fullScreenRoundTripPreservesHeaderAndSearchIdentity() async throws {
        let host = try WorkspaceWindowHost()
        defer { host.close() }
        try await NativeSyntaxUI.prepareFocus(in: host.window)
        try await SystemPageHost.settle(host.window)
        let field = try host.search()
        try #require(host.window.makeFirstResponder(field))
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.insertText("Synthetic", replacementRange: editor.selectedRange())
        try await SystemPageHost.settle(host.window)
        try host.assertHeader()
        host.window.collectionBehavior.remove(.moveToActiveSpace)
        host.window.collectionBehavior.insert(.fullScreenPrimary)
        host.window.toggleFullScreen(nil)
        do {
            try await host.wait { host.entered }
            #expect(host.window.styleMask.contains(.fullScreen))
            try host.assertHeader()
            #expect(try host.search() === field)
            #expect(field.stringValue == "Synthetic")
            host.window.toggleFullScreen(nil)
            try await host.wait { host.exited }
            #expect(!host.window.styleMask.contains(.fullScreen))
            try host.assertHeader()
            #expect(try host.search() === field)
            #expect(field.stringValue == "Synthetic")
        } catch {
            if host.window.styleMask.contains(.fullScreen) {
                host.window.toggleFullScreen(nil)
                try? await host.wait { host.exited }
            }
            throw error
        }
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func composedWindowAndScrollStates(scheme: ColorScheme) async throws {
        let host = try WorkspaceWindowHost(scheme: scheme)
        defer { host.close() }
        try await NativeSyntaxUI.prepareFocus(in: host.window)
        try await SystemPageHost.settle(host.window)
        for minimum in [false, true] {
            host.window.setFrame(.init(origin: host.window.frame.origin,
                size: minimum ? DaybookMetrics.Window.workspaceMinSize : .init(width: 1200, height: 760)), display: true)
            try await SystemPageHost.settle(host.window)
            try host.assertHeader()
            for kind in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                let button = try #require(host.window.standardWindowButton(kind))
                #expect(!button.isHiddenOrHasHiddenAncestor && !button.visibleRect.isEmpty)
            }
            let tag = "\(scheme == .light ? "light" : "dark")-\(minimum ? "minimum" : "default")"
            try await host.capture("window-\(tag)-top")
            let edges = ScrollNativeEvidence.views(host.window).compactMap { $0 as? DaybookScrollEdgeObserverNSView }
            let targets = edges.compactMap(\.currentScrollView)
            let header = try NativeSyntaxUI.frame("syntax.workspace.header.bounds", in: host.window)
            for scroll in targets { scroll.contentView.scroll(to: .init(x: 0, y: 100)) }
            try await SystemPageHost.settle(host.window)
            #expect(try NativeSyntaxUI.frame("syntax.workspace.header.bounds", in: host.window) == header)
            try await host.capture("window-\(tag)-scrolled")
            for scroll in targets { scroll.contentView.scroll(to: .zero) }
            try await SystemPageHost.settle(host.window)
            #expect(try NativeSyntaxUI.frame("syntax.workspace.header.bounds", in: host.window) == header)
            try await host.capture("window-\(tag)-returned")
        }
    }
}

@MainActor
private final class WorkspaceWindowHost: NSObject, NSWindowDelegate {
    let fixture: SettingsButtonTestSupport
    let window: NSWindow
    let restore: () -> Void
    var entered = false
    var exited = false

    init(scheme: ColorScheme = .light) throws {
        fixture = try SettingsButtonTestSupport(isolatedPreferences: true)
        restore = CalendarSpanTestSupport.preserveState()
        for index in 0..<35 {
            fixture.container.mainContext.insert(TodoItem(title: "Synthetic item \(index)", dayKey: DayClock.shared.todayKey))
        }
        try fixture.container.mainContext.save()
        WorkspaceNavigation.shared.clearSearch()
        WorkspaceNavigation.shared.revealTab(.today)
        let root = MainSplitWorkspaceView().modelContainer(fixture.container).environment(fixture.prefs)
            .environment(\.locale, Locale(identifier: "zh-Hans")).preferredColorScheme(scheme)
            .transaction { $0.disablesAnimations = true }
        UserDefaults.standard.register(defaults: [
            "NSSplitViewItemSidebarDefaultsToFloatingAppearance": false
        ])
        window = NSWindow(contentViewController: NSHostingController(rootView: root))
        super.init()
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.minSize = DaybookMetrics.Window.workspaceMinSize
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.toolbarStyle = .unified
        let toolbar = NSToolbar(identifier: "AreaChainWorkspaceToolbar")
        window.toolbar = toolbar
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.delegate = self
        window.setContentSize(.init(width: 1200, height: 760))
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func windowDidEnterFullScreen(_ notification: Notification) { entered = true }
    func windowDidExitFullScreen(_ notification: Notification) { exited = true }

    func search() throws -> DaybookAppKitTextField {
        let fields = ScrollNativeEvidence.views(window).compactMap { $0 as? DaybookAppKitTextField }.filter {
            $0.placeholderString == L10n.string("workspace.search.placeholder", locale: Locale(identifier: "zh-Hans"))
                && !$0.isHiddenOrHasHiddenAncestor && !$0.visibleRect.isEmpty
        }
        try #require(fields.count == 1)
        return try #require(fields.first)
    }

    func assertHeader() throws {
        let header = try NativeSyntaxUI.frame("syntax.workspace.header.bounds", in: window)
        let search = try NativeSyntaxUI.frame("syntax.workspace.search.bounds", in: window)
        let actions = try NativeSyntaxUI.frame("syntax.workspace.actions.bounds", in: window)
        #expect(abs(header.height - 50) < 1 && abs(header.midX - search.midX) < 1)
        #expect(abs(header.midY - search.midY) < 1 && !actions.intersects(search))
    }

    func wait(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(8)
        while !condition() && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        try #require(condition(), "系统全屏转换未完成")
        try await SystemPageHost.settle(window)
    }

    func capture(_ name: String) async throws {
        // 不触发授权弹窗；只有既有权限可用时，截取本 QA 的单一系统合成窗口。
        guard CGPreflightScreenCaptureAccess() else {
            print("WORKSPACE_COMPOSITE unavailable: existing screen capture permission absent")
            return
        }
        let root = ProcessInfo.processInfo.environment["AREACHAIN_WORKSPACE_EVIDENCE"]
        guard let root else { return }
        let file = URL(fileURLWithPath: root).appendingPathComponent(name + ".png")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-o", "-l", String(window.windowNumber), file.path]
        try process.run()
        let deadline = ContinuousClock.now + .seconds(5)
        while process.isRunning && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
        if process.isRunning { process.terminate(); throw CocoaError(.userCancelled) }
        #expect(process.terminationStatus == 0 && FileManager.default.fileExists(atPath: file.path))
    }

    func close() {
        window.makeFirstResponder(nil)
        window.orderOut(nil)
        window.toolbar = nil
        window.styleMask.remove(.fullSizeContentView)
        window.contentViewController = nil
        window.delegate = nil
        restore()
        WorkspaceNavigation.shared.updateInspectorSpace(available: true)
        fixture.cleanup()
    }
}
