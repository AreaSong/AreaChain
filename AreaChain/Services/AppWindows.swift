import AppKit
import SwiftUI

@MainActor
enum AppWindows {
    static func openSettings() {
        StatusItemController.shared.close()
        becomeActive()
        PanelWindowController.settings.show()
    }

    static func openDiary() {
        StatusItemController.shared.close()
        becomeActive()
        PanelWindowController.diary.show()
    }

    static func openTrash() {
        StatusItemController.shared.close()
        becomeActive()
        PanelWindowController.trash.show()
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
        [PanelWindowController.settings.hostedWindow, PanelWindowController.diary.hostedWindow, PanelWindowController.trash.hostedWindow]
            .compactMap { $0 }
    }
}

@MainActor
final class PanelWindowController: NSObject, NSWindowDelegate {
    static let settings = PanelWindowController(
        titleKey: "window.settings",
        size: NSSize(width: 420, height: 480),
        root: {
            AnyView(
                SettingsView()
                    .appChrome()
                    .modelContainer(Persistence.session.container)
            )
        }
    )
    static let diary = PanelWindowController(
        titleKey: "window.diary",
        size: NSSize(width: 420, height: 520),
        root: {
            AnyView(
                DiaryStandaloneView()
                    .appChrome()
                    .modelContainer(Persistence.session.container)
            )
        }
    )
    static let trash = PanelWindowController(
        titleKey: "window.trash",
        size: NSSize(width: 420, height: 520),
        root: {
            AnyView(
                TrashPage()
                    .appChrome()
                    .modelContainer(Persistence.session.container)
            )
        }
    )

    private let titleKey: String
    private let size: NSSize
    private let root: () -> AnyView
    private var window: NSWindow?

    var hostedWindow: NSWindow? { window }

    init(titleKey: String, size: NSSize, root: @escaping () -> AnyView) {
        self.titleKey = titleKey
        self.size = size
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
            let next = NSWindow(contentViewController: NSHostingController(rootView: root()))
            next.setContentSize(size)
            next.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            next.isReleasedWhenClosed = false
            next.isRestorable = false
            next.delegate = self
            window = next
        } else {
            window?.contentViewController = NSHostingController(rootView: root())
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
