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

    static func becomeActive() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func resignIfIdle(closing: NSWindow? = nil) {
        let leftover = NSApp.windows.contains { window in
            window !== closing
                && window.isVisible
                && window.canBecomeKey
                && window.level == .normal
        }
        if !leftover {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

@MainActor
final class PanelWindowController: NSObject, NSWindowDelegate {
    static let settings = PanelWindowController(
        titleKey: "window.settings",
        size: NSSize(width: 420, height: 400),
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

    private let titleKey: String
    private let size: NSSize
    private let root: () -> AnyView
    private var window: NSWindow?

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
            next.delegate = self
            window = next
        } else {
            window?.contentViewController = NSHostingController(rootView: root())
        }
        refreshChrome()
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        AppWindows.resignIfIdle(closing: notification.object as? NSWindow)
    }

    private func refreshChrome() {
        let locale = AppPreferences.shared.resolvedLocale
        window?.title = L10n.string(String.LocalizationValue(stringLiteral: titleKey), locale: locale)
    }
}
