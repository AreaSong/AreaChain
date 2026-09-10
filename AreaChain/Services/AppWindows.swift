import AppKit
import SwiftUI

@MainActor
enum AppWindows {
    /// 注入的工作台主视图构造器，由 App 启动时或 Features 协调层注册
    static var workspaceViewProvider: (@MainActor () -> AnyView)?

    static func openWorkspace(tab: WorkspaceTab = .today) {
        StatusItemController.shared.close()
        becomeActive()
        WorkspaceNavigation.shared.revealTab(tab)
        PanelWindowController.workspace.show()
    }

    static func revealWorkspace() {
        StatusItemController.shared.close()
        becomeActive()
        PanelWindowController.workspace.show()
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
            window !== closing && window.isVisible
        }
        if !leftover {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    /// 关掉设置后，SwiftUI Scene 里多出来的窗不要当成「下一扇」打开。
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
    }
}

@MainActor
final class PanelWindowController: NSObject, NSWindowDelegate {
    static let workspace = PanelWindowController(
        titleKey: "window.workspace",
        size: DaybookTheme.workspaceSize,
        minSize: DaybookTheme.workspaceMinSize,
        root: {
            AppWindows.workspaceViewProvider?() ?? AnyView(EmptyView())
        }
    )

    private let titleKey: String
    private let size: NSSize
    private let minSize: NSSize?
    private let root: @MainActor () -> AnyView
    private var window: NSWindow?

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
        NotificationCenter.default.addObserver(
            forName: .appPreferencesDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshChrome()
            }
        }
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
            next.styleMask = [.titled, .closable, .miniaturizable, .resizable]
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
        let locale = AppPreferences.shared.resolvedLocale
        window?.title = L10n.string(String.LocalizationValue(stringLiteral: titleKey), locale: locale)
    }
}
