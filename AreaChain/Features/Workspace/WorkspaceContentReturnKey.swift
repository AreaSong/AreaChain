import SwiftUI
import AppKit

/// 纯查阅没有输入焦点；Esc 仍只属于这扇真实内容窗，组合输入先留给原生编辑器。
struct WorkspaceContentReturnKey: NSViewRepresentable {
    let controller: UnifiedSearchController
    func makeNSView(context: Context) -> Host { Host() }
    func updateNSView(_ view: Host, context: Context) { view.controller = controller }
    static func dismantleNSView(_ view: Host, coordinator: ()) { view.remove() }

    final class Host: NSView {
        weak var controller: UnifiedSearchController?
        private var token: Any?
        private var focusObserver: NSObjectProtocol?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            remove()
            guard window != nil else { return }
            focusObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification,
                object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated {
                        guard let controller = self?.controller else { return }
                        try? controller.session.loseFocus(expecting: controller.buffer.lease.ownership)
                    }
                }
            token = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, event.window === self.window, event.keyCode == 53,
                      event.modifierFlags.isDisjoint(with: [.command, .control, .option, .shift]),
                      let controller = self.controller, controller.isNavigationPresented,
                      !controller.inputFocused, let ticket = controller.returnSearch else { return event }
                if let editor = self.window?.firstResponder as? NSTextView, editor.hasMarkedText() { return event }
                Task { await controller.returnToSearch(ticket.id) }
                return nil
            }
        }
        func remove() {
            if let token { NSEvent.removeMonitor(token) }; token = nil
            if let focusObserver { NotificationCenter.default.removeObserver(focusObserver) }; focusObserver = nil
        }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
