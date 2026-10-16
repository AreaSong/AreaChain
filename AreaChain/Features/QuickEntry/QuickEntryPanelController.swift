import AppKit
import SwiftUI

@MainActor
final class QuickEntryPanelController: NSObject, NSWindowDelegate {
    static let shared = QuickEntryPanelController()

    private var panel: NSPanel?
    private let size = NSSize(width: 480, height: 180)

    var isVisible: Bool { panel?.isVisible == true }
    var hostedWindow: NSWindow? { panel }

    func show(mode: QuickEntryMode = .task) {
        let window = ensurePanel(initialMode: mode)
        positionWindow(window)

        AppWindows.becomeActive()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        panel?.orderOut(nil)
        AppWindows.resignIfIdle(closing: panel)
    }

    func windowWillClose(_ notification: Notification) {
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
