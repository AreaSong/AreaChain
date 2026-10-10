import AppKit
import SwiftUI

/// 固定下方区域的原生撤显示边界；草稿留在协调者，锁定/窗口失焦同步卸载控件。
struct UnifiedSearchOperationPanel: NSViewRepresentable {
    let controller: UnifiedSearchController
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var scheme

    func makeNSView(context: Context) -> UnifiedSearchOperationBoundary {
        let view = UnifiedSearchOperationBoundary()
        view.attach(controller)
        return view
    }

    func updateNSView(_ view: UnifiedSearchOperationBoundary, context: Context) {
        _ = controller.revision
        _ = controller.buffer
        view.attach(controller)
        view.locale = locale
        view.scheme = scheme
        view.render()
    }

    static func dismantleNSView(_ view: UnifiedSearchOperationBoundary, coordinator: ()) { view.detach() }
}

@MainActor
final class UnifiedSearchOperationBoundary: NSView {
    var locale = Locale(identifier: "en")
    var scheme = ColorScheme.light
    private weak var controller: UnifiedSearchController?
    private var observer: UUID?
    private var focusObserver: NSObjectProtocol?
    private var hosting: NSHostingView<AnyView>?

    func attach(_ controller: UnifiedSearchController) {
        guard self.controller !== controller else { return }
        detach()
        self.controller = controller
        observer = controller.session.displayUpdates.observe { [weak self] _ in
            guard let self else { return }
            if controller.operationVisible { self.render() } else { self.removePresentation() }
        }
        let ownership = controller.buffer.lease.ownership
        focusObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification,
            object: nil, queue: .main) { [weak self, weak controller] note in
            MainActor.assumeIsolated {
                guard let self, let window = note.object as? NSWindow, window === self.window else { return }
                try? controller?.session.loseFocus(expecting: ownership)
                self.removePresentation()
            }
        }
    }

    func render() {
        guard let controller, controller.operationVisible else { removePresentation(); return }
        let root = AnyView(UnifiedSearchOperationPreview(controller: controller)
            .environment(\.locale, locale).preferredColorScheme(scheme))
        if let hosting { hosting.rootView = root }
        else {
            let view = NSHostingView(rootView: root)
            view.frame = bounds
            view.autoresizingMask = [.width, .height]
            hosting = view
            addSubview(view)
        }
    }

    func removePresentation() {
        controller?.endLongText()
        func clear(_ view: NSView) {
            if let field = view as? NSTextField,
               let state = (field.delegate as? DaybookTextField.Coordinator)?.parent.unifiedSearch {
                state.clearNative()
            }
            if let label = view as? SearchFragmentLabel { label.stringValue = "" }
            for child in view.subviews { clear(child) }
        }
        if let hosting {
            clear(hosting)
            hosting.rootView = AnyView(EmptyView())
            hosting.removeFromSuperview()
        }
        hosting = nil
    }

    func detach() {
        if let observer { controller?.session.displayUpdates.remove(observer) }
        if let focusObserver { NotificationCenter.default.removeObserver(focusObserver) }
        observer = nil
        focusObserver = nil
        controller = nil
        removePresentation()
    }
}
