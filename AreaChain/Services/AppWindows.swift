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
        title: "设置",
        size: NSSize(width: 460, height: 520),
        root: { AnyView(SettingsView().modelContainer(Persistence.session.container)) }
    )
    static let diary = PanelWindowController(
        title: "日记",
        size: NSSize(width: 420, height: 520),
        root: { AnyView(DiaryStandaloneView().modelContainer(Persistence.session.container)) }
    )

    private let title: String
    private let size: NSSize
    private let root: () -> AnyView
    private var window: NSWindow?

    init(title: String, size: NSSize, root: @escaping () -> AnyView) {
        self.title = title
        self.size = size
        self.root = root
        super.init()
    }

    func show() {
        if window == nil {
            let next = NSWindow(contentViewController: NSHostingController(rootView: root()))
            next.title = title
            next.setContentSize(size)
            next.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            next.isReleasedWhenClosed = false
            next.delegate = self
            window = next
        }
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        AppWindows.resignIfIdle(closing: notification.object as? NSWindow)
    }
}
