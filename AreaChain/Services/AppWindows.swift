import AppKit
import SwiftUI

@MainActor
enum AppWindows {
    /// 注入的工作台主视图构造器，由 App 启动时或 Features 协调层注册
    static var workspaceViewProvider: (@MainActor () -> AnyView)?
    static var diaryWindowsProvider: (@MainActor () -> [NSWindow])?
    /// 剪贴板小窗。关工作台时不能把它当成杂散窗口关掉。
    static var clipboardWindowProvider: (@MainActor () -> [NSWindow])?

    /// 测试替换这两处，避免为路由断言激活应用或创建窗口。
    static var activateForOpening: @MainActor () -> Void = { becomeActive() }
    static var showWorkspaceWindow: @MainActor () -> Void = { PanelWindowController.workspace.show() }

    static func openWorkspace(tab: WorkspaceTab = .dashboard, inspecting taskID: UUID? = nil, dayKey: String? = nil) {
        StatusItemController.shared.close()
        activateForOpening()
        WorkspaceNavigation.shared.revealTab(tab, inspecting: taskID, dayKey: dayKey)
        showWorkspaceWindow()
    }

    /// 应用菜单、⌘, 和浮层「设置」都进入工作台设置页。
    static func openSettings() {
        openWorkspace(tab: .settings)
    }

    static func revealWorkspace() {
        StatusItemController.shared.close()
        activateForOpening()
        showWorkspaceWindow()
    }

    static func openDiary() {
        openWorkspace(tab: .diary)
    }

    static func openCalendar() {
        openWorkspace(tab: .calendar)
    }

    static func becomeActive() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func resignIfIdle(closing: NSWindow? = nil) {
        hideStrayWindows(closing: closing)
        let leftover = panelWindows.contains { window in
            window !== closing && (window.isVisible || window.isMiniaturized)
        }
        if !leftover {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    /// 工作台和手记以外的可见窗口不要当成「下一扇」留在前台。
    static func hideStrayWindows(closing: NSWindow? = nil) {
        let panels = Set(panelWindows.map { ObjectIdentifier($0) })
        for window in NSApp.windows {
            if window === closing { continue }
            if panels.contains(ObjectIdentifier(window)) { continue }
            guard window.canBecomeKey, window.level == .normal, window.isVisible else { continue }
            window.orderOut(nil)
        }
    }

    private static var panelWindows: [NSWindow] {
        [PanelWindowController.workspace.hostedWindow].compactMap { $0 }
            + (diaryWindowsProvider?() ?? [])
            + (clipboardWindowProvider?() ?? [])
    }
}

@MainActor
final class PanelWindowController: NSObject, NSWindowDelegate {
    static let workspace = PanelWindowController(
        titleKey: "window.workspace",
        size: DaybookMetrics.Window.workspaceSize,
        minSize: DaybookMetrics.Window.workspaceMinSize,
        root: {
            AppWindows.workspaceViewProvider?() ?? AnyView(EmptyView())
        }
    )

    private let titleKey: String
    private let size: NSSize
    private let minSize: NSSize?
    private let root: @MainActor () -> AnyView
    private var window: NSWindow?
    private var preferenceObservation: PreferenceObservation?

    var hostedWindow: NSWindow? { window }

    init(
        titleKey: String,
        size: NSSize,
        minSize: NSSize? = nil,
        root: @escaping @MainActor () -> AnyView
    ) {
        self.titleKey = titleKey
        self.size = size
        self.minSize = minSize
        self.root = root
        super.init()
        preferenceObservation = PreferenceObservation(source: AppPreferences.shared.localPreferenceSource,
            consumer: .windowChrome, presentation: { [weak self] in self?.refreshChrome() },
            legacy: { [weak self] in self?.refreshChrome() })
    }

    func show() {
        if window == nil {
            guard let provider = AppWindows.workspaceViewProvider else {
                assertionFailure("AppWindows.workspaceViewProvider must be registered before showing workspace")
                return
            }
            let next = NSWindow(contentViewController: NSHostingController(rootView: provider()))
            next.setContentSize(size)
            next.minSize = minSize ?? size
            next.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            next.titlebarAppearsTransparent = true
            next.titleVisibility = .hidden
            next.isOpaque = false
            next.backgroundColor = .clear
            next.isMovableByWindowBackground = true
            next.isReleasedWhenClosed = false
            next.isRestorable = false
            next.delegate = self
            window = next
        }
        refreshChrome()
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        let closing = notification.object as? NSWindow
        AppWindows.resignIfIdle(closing: closing)
        DispatchQueue.main.async {
            AppWindows.resignIfIdle(closing: closing)
        }
    }

    private func refreshChrome() {
        window?.title = ""
        window?.titleVisibility = .hidden
    }
}
