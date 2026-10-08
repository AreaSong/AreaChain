import AppKit
import SwiftUI
import Testing
@testable import AreaChain

/// 只在 XCTest 内装配生产设置区与生产窗口；不触发设置页的系统状态查询。
@MainActor
final class ControlsPreviewTestSupport {
    typealias Native = SettingsButtonTestSupport
    let fixture: SettingsButtonTestSupport
    let workspace: NSWindow
    private let previousProvider = AppWindows.workspaceViewProvider
    private let previousDiary = AppWindows.diaryWindowsProvider
    private let previousClipboard = AppWindows.clipboardWindowProvider
    private let previousPolicy = NSApp.activationPolicy()
    private let previousContent = PanelWindowController.workspace.hostedWindow?.contentViewController
    private var observations: [NSObjectProtocol] = []
    private(set) var businessEvents = 0

    init(locale: String = "en", dark: Bool = false) throws {
        try #require(NotificationScheduler.isRunningTests)
        try #require(ControlsPreviewWindowController.shared.hostedWindow == nil)
        fixture = try SettingsButtonTestSupport(isolatedPreferences: true)
        fixture.prefs.language = locale == "en" ? .english : .chinese
        fixture.prefs.appearance = dark ? .dark : .light
        let prefs = fixture.prefs
        let root = AnyView(Form {
            GeneralSettingsSection(prefs: prefs, launchesAtLogin: .constant(false), loginNeedsApproval: false,
                statusMessage: nil, onUpdateLoginItem: { _ in Issue.record("预览不能调用登录设置") })
        }.formStyle(.grouped).environment(\.locale, Locale(identifier: locale))
            .preferredColorScheme(dark ? .dark : .light))
        NSApp.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface"))
        AppWindows.workspaceViewProvider = { root }
        AppWindows.becomeActive()
        PanelWindowController.workspace.show()
        workspace = try #require(PanelWindowController.workspace.hostedWindow)
        workspace.contentViewController = NSHostingController(rootView: root)
        workspace.setContentSize(NSSize(width: 760, height: 640))
        for name in [Notification.Name.boardDidChange, .appPreferencesDidChange, .localPreferenceDidChange] {
            observations.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.businessEvents += 1 }
            })
        }
    }

    func open() async throws -> NSWindow {
        // 最后一扇窗口关闭后已回到 accessory；重开必须走生产工作台的激活与 show。
        AppWindows.becomeActive()
        PanelWindowController.workspace.show()
        try await NativeSyntaxUI.prepareFocus(in: workspace)
        try await SystemPageHost.settle(workspace)
        let button = try Native.button("settings.controlsPreview", in: workspace)
        try await Native.reveal(button, in: workspace)
        try await Native.click(button, in: workspace)
        let window = try #require(ControlsPreviewWindowController.shared.hostedWindow)
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        return window
    }

    func cleanup() {
        observations.forEach(NotificationCenter.default.removeObserver)
        ControlsPreviewWindowController.shared.hostedWindow?.close()
        workspace.close()
        workspace.contentViewController = previousContent
        AppWindows.workspaceViewProvider = previousProvider
        AppWindows.diaryWindowsProvider = previousDiary
        AppWindows.clipboardWindowProvider = previousClipboard
        fixture.cleanup()
        NSApp.setActivationPolicy(previousPolicy)
    }

    static func node(_ identifier: String, in window: NSWindow) throws -> NSObject {
        try #require(Native.elements(window.contentView).first {
            Native.value($0, "accessibilityIdentifier") as? String == identifier
        }, "找不到展示节点：\(identifier)")
    }

    static func press(_ identifier: String, in window: NSWindow) async throws {
        let item = try node(identifier, in: window)
        try await Native.reveal(item, in: window)
        try await Native.click(item, in: window)
    }

    static func actions(in window: NSWindow) throws -> String {
        let nodes = Native.elements(window.contentView).filter {
            Native.value($0, "accessibilityIdentifier") as? String == "preview.actions"
        }
        let values = nodes.compactMap { Native.value($0, "accessibilityValue") as? String }
        if values.isEmpty {
            print("PREVIEW_COUNTER", nodes.map { node in
                ["accessibilityRole", "accessibilityLabel", "accessibilityTitle", "accessibilityValue"].map {
                    String(describing: Native.value(node, $0))
                }
            })
        }
        return try #require(values.first { Int($0) != nil })
    }

    static func commandReturn(in window: NSWindow) async throws {
        let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
        _ = window.performKeyEquivalent(with: event)
        try await SystemPageHost.settle(window)
    }

    static func snapshot(_ window: NSWindow, name: String) throws {
        try Native.snapshot(window, name: name)
        let file = FileManager.default.temporaryDirectory.appending(path: "AreaChainButtonConsumersQA/settings-\(name).png")
        Attachment.record(Array(try Data(contentsOf: file)), named: name + ".png")
    }
}
