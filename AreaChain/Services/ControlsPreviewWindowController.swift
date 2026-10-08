import AppKit
import SwiftUI

/// 独立于工作台 provider；关闭即卸载展示树，重开使用调用方当前外观初值。
@MainActor
final class ControlsPreviewWindowController: NSObject, NSWindowDelegate {
    static let shared = ControlsPreviewWindowController()
    static let contentSize = NSSize(width: 760, height: 640)
    static let minimumContentSize = NSSize(width: 680, height: 560)

    private(set) var hostedWindow: NSWindow?

    func show(localeID: String, dark: Bool) {
        if hostedWindow == nil {
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: Self.contentSize),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                  backing: .buffered, defer: false)
            window.identifier = NSUserInterfaceItemIdentifier("controls.preview.window")
            window.contentMinSize = Self.minimumContentSize
            window.isReleasedWhenClosed = false
            window.isRestorable = false
            window.title = title(localeID)
            window.delegate = self
            window.contentViewController = NSHostingController(rootView: AnyView(DaybookControlsPreview(
                localeID: localeID, dark: dark, onLocaleChange: { [weak window] identifier in
                    window?.title = L10n.string("controls.preview.title", locale: Locale(identifier: identifier))
                })))
            window.setContentSize(Self.contentSize)
            window.center()
            hostedWindow = window
        }
        if hostedWindow?.isMiniaturized == true { hostedWindow?.deminiaturize(nil) }
        hostedWindow?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow, closing === hostedWindow else { return }
        closing.makeFirstResponder(nil)
        // AppKit 可延后释放 hosting controller；先撤去样例树以立即拆卸本地控件与监听。
        if let host = closing.contentViewController as? NSHostingController<AnyView> {
            host.rootView = AnyView(EmptyView())
            host.view.layoutSubtreeIfNeeded()
        }
        closing.contentViewController = nil
        closing.contentView = nil
        closing.delegate = nil
        hostedWindow = nil
        AppWindows.resignIfIdle(closing: closing)
        DispatchQueue.main.async { [weak closing] in
            AppWindows.resignIfIdle(closing: closing)
        }
    }

    private func title(_ localeID: String) -> String {
        L10n.string("controls.preview.title", locale: Locale(identifier: localeID))
    }
}
