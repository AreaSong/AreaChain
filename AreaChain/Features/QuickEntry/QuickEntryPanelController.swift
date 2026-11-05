import AppKit
import SwiftUI

@MainActor
final class QuickEntryPanelController: BaseWindow {
    static let shared = QuickEntryPanelController()

    private var panel: NSPanel?
    private let size = NSSize(width: 480, height: 180)

    var isVisible: Bool { panel?.isVisible == true }

    override var windowID: String { "window.quickEntry" }
    override var windowCategory: String { "quickEntry" }
    override var windowTitle: String { L10n.string("quickEntry.window.title", locale: AppPreferences.shared.resolvedLocale) }
    override var defaultContentSize: NSSize { size }
    override var minimumContentSize: NSSize { size }
    override var defaultSize: NSSize { size }
    override var minSize: NSSize { size }

    override func openWindow() {
        show()
    }

    func show(mode: QuickEntryMode = .task) {
        let window = ensurePanel(initialMode: mode)
        attachHostedWindow(window)
        registry.markActivated(self)
        positionWindow(window)

        AppWindows.becomeActive()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        panel?.orderOut(nil)
        markWindowClosedInRegistry()
        AppWindows.resignIfIdle(closing: panel)
    }

    override func windowWillClose(_ notification: Notification) {
        super.windowWillClose(notification)
        AppWindows.resignIfIdle(closing: panel)
    }

    private func ensurePanel(initialMode: QuickEntryMode) -> NSPanel {
        if let existing = panel {
            // 重新设置根视图以更新初始模式
            existing.contentView = NSHostingView(
                rootView: QuickEntryView(mode: initialMode, onDismiss: { [weak self] in
                    self?.hide()
                })
                .environment(\.locale, AppPreferences.shared.resolvedLocale)
            )
            return existing
        }

        let window = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isFloatingPanel = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.hidesOnDeactivate = false
        window.hasShadow = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.delegate = self

        window.contentView = NSHostingView(
            rootView: QuickEntryView(mode: initialMode, onDismiss: { [weak self] in
                self?.hide()
            })
            .environment(\.locale, AppPreferences.shared.resolvedLocale)
        )

        panel = window
        attachHostedWindow(window)
        return window
    }

    private func positionWindow(_ window: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 100, y: 100, width: size.width, height: size.height)

        // Spotlight 黄金视觉中心位：水平正中，垂直靠上 1/3
        let x = round(visible.midX - size.width / 2)
        let y = round(visible.maxY - size.height - 160)

        window.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }
}
