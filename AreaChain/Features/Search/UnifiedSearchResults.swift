import AppKit
import SwiftUI

/// 两宿主共用的受门禁原生边界。失效同步移除整个 hosting 子树，再等待下一次合法发布。
struct UnifiedSearchResults: NSViewRepresentable {
    let controller: UnifiedSearchController
    var layout: UnifiedSearchInputLayout = .standard
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme

    func makeNSView(context: Context) -> UnifiedSearchResultsBoundary {
        let view = UnifiedSearchResultsBoundary()
        view.attach(controller)
        return view
    }

    func updateNSView(_ view: UnifiedSearchResultsBoundary, context: Context) {
        _ = controller.revision
        view.attach(controller)
        view.layoutStyle = layout
        view.locale = locale
        view.scheme = colorScheme
        view.render()
    }

    static func dismantleNSView(_ view: UnifiedSearchResultsBoundary, coordinator: ()) { view.detach() }
}

@MainActor
final class UnifiedSearchResultsBoundary: NSView {
    var layoutStyle = UnifiedSearchInputLayout.standard
    var locale = Locale(identifier: "en")
    var scheme = ColorScheme.light
    private weak var controller: UnifiedSearchController?
    private var token: UUID?
    private var keys: Any?
    private var hosting: NSHostingView<AnyView>?
    private var renderedVersion: UUID?
    private var renderedBuffer: UnifiedSearchBuffer?
    private var rendering = false
    private var focusObserver: NSObjectProtocol?
    override var acceptsFirstResponder: Bool { true }
    // 方向键导航可显式聚焦边界；Tab 跳过边界自身，进入实际按钮。
    override var canBecomeKeyView: Bool { false }

    func attach(_ controller: UnifiedSearchController) {
        guard self.controller !== controller else { return }
        detach()
        self.controller = controller
        token = controller.session.displayUpdates.observe { [weak self] change in
            guard let self else { return }
            if change == .published { self.render() }
            else { self.removePresentation() }
        }
        controller.focusResults = { [weak self] focus in
            guard let self else { return }
            switch focus {
            case .hit: self.window?.makeFirstResponder(self)
            case .control: self.window?.makeFirstResponder(self.hosting)
            case .input: break
            }
        }
        keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let handled = MainActor.assumeIsolated { self?.handle(event) == true }
            return handled ? nil : event
        }
        let ownership = controller.buffer.lease.ownership
        focusObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification,
            object: nil, queue: .main) { [weak self, weak controller] note in
            MainActor.assumeIsolated {
                guard let self, let window = note.object as? NSWindow, window === self.window else { return }
                try? controller?.session.loseFocus(expecting: ownership)
            }
        }
    }

    func render() {
        guard !rendering, let controller else { return }
        rendering = true
        defer { rendering = false }
        let content: AnyView
        if controller.objectSelectionLocation != nil {
            renderedVersion = nil
            renderedBuffer = nil
            content = AnyView(EmptyView())
        } else if let publication = try? controller.session.presentation() {
            renderedVersion = publication.pagination.snapshot.version
            renderedBuffer = controller.buffer
            content = AnyView(UnifiedSearchResultsContent(controller: controller, publication: publication,
                source: controller.buffer, layout: layoutStyle))
        } else {
            renderedVersion = nil
            renderedBuffer = nil
            content = AnyView(DaybookEmptyState(title: LocalizedStringKey(controller.messageKey),
                                                systemImage: "magnifyingglass", compact: layoutStyle == .compact))
        }
        let root = AnyView(content.environment(\.locale, locale).preferredColorScheme(scheme))
        if let hosting { hosting.rootView = root }
        else {
            let view = NSHostingView(rootView: root)
            view.frame = bounds
            view.autoresizingMask = [.width, .height]
            hosting = view
            addSubview(view)
        }
    }

    /// 先清只读文本原生 storage，再移除子树；不依赖下一次 run loop 或 onDisappear。
    private func removePresentation() {
        func clear(_ view: NSView) {
            if let text = view as? SearchReadOnlyEditor { text.string = ""; text.collapse = nil; text.onFocus = nil }
            if let label = view as? SearchFragmentLabel { label.stringValue = "" }
            for child in view.subviews { clear(child) }
        }
        if let hosting {
            clear(hosting)
            hosting.rootView = AnyView(EmptyView())
            hosting.removeFromSuperview()
        }
        hosting = nil
        renderedVersion = nil
        renderedBuffer = nil
    }

    private func handle(_ event: NSEvent) -> Bool {
        guard event.window === window, let responder = window?.firstResponder as? NSView,
              responder === self || responder.isDescendant(of: self),
              !(responder is NSTextView), let controller, let source = renderedBuffer,
              let version = renderedVersion else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command), event.keyCode == 36 { return true }
        guard flags.isDisjoint(with: [.command, .control, .option]) else { return false }
        let action: ContentQueryBrowseAction
        switch event.keyCode {
        case 125: action = .move(.next, inputEditing: false)
        case 126: action = .move(.previous, inputEditing: false)
        case 36:
            guard !controller.isCommandInput else { return true }
            action = .open(inputEditing: false)
        case 53: action = .focusInput
        default: return false
        }
        controller.browse(.init(version: version, action: action), source: source)
        return true
    }

    func detach() {
        if let token { controller?.session.displayUpdates.remove(token) }
        if let keys { NSEvent.removeMonitor(keys) }
        if let focusObserver { NotificationCenter.default.removeObserver(focusObserver) }
        focusObserver = nil
        token = nil
        keys = nil
        controller?.focusResults = nil
        controller = nil
        removePresentation()
    }
}
