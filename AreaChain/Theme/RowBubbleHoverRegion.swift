import AppKit
import SwiftUI

/// 只观察当前气泡所属窗口；几何不取祖先行的 visibleRect，命中仍完全交给原 SwiftUI 内容。
struct RowBubbleHoverRegion: NSViewRepresentable {
    let lifetime: RowBubbleHoverLifetime
    var onHover: (Bool) -> Void
    var onInvalidate: () -> Void

    func makeNSView(context: Context) -> RowBubbleHoverView {
        let view = RowBubbleHoverView()
        lifetime.view = view
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: RowBubbleHoverView, context: Context) {
        view.onHover = onHover
        view.onInvalidate = onInvalidate
        view.refreshAfterLayout()
    }

    static func dismantleNSView(_ view: RowBubbleHoverView, coordinator: ()) {
        view.stop()
    }
}

/// SwiftUI 开始移除时即停止观察，不等淡出视图最终从 AppKit 树拆除。
final class RowBubbleHoverLifetime {
    weak var view: RowBubbleHoverView?
}

final class RowBubbleHoverView: NSView {
    var onHover: ((Bool) -> Void)?
    var onInvalidate: (() -> Void)?
    private var monitor: Any?
    private var notifications: [NSObjectProtocol] = []
    private var hovered = false
    private var generation = 0
    private var refreshPending = false
    private weak var observedWindow: NSWindow?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        start()
    }

    func start() {
        stop()
        guard let window else { return }
        observedWindow = window
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .mouseEntered, .mouseExited,
            .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .scrollWheel]) { [weak self, weak window] event in
            MainActor.assumeIsolated {
                if let window, event.window === window {
                    self?.refresh(at: event.locationInWindow)
                    self?.refreshAfterLayout()
                }
            }
            return event
        }
        for name in [NSWindow.didResignKeyNotification, NSWindow.willCloseNotification] {
            notifications.append(NotificationCenter.default.addObserver(
                forName: name, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.stop()
                    self?.onInvalidate?()
                }
            })
        }
        refreshAfterLayout()
    }

    override func layout() {
        super.layout()
        refreshAfterLayout()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        // 祖先移动或滚动时由 AppKit 通知；每次重新换算，不保留旧窗口坐标。
        refreshAfterLayout()
    }

    func refreshAfterLayout() {
        guard observedWindow != nil, !refreshPending else { return }
        refreshPending = true
        let current = generation
        DispatchQueue.main.async { [weak self] in
            guard let self, self.generation == current else { return }
            self.refreshPending = false
            guard let window = self.observedWindow else { return }
            self.refresh(at: window.convertPoint(fromScreen: NSEvent.mouseLocation))
        }
    }

    private func refresh(at point: NSPoint) {
        guard let window = observedWindow, self.window === window, window.isKeyWindow,
              !isHiddenOrHasHiddenAncestor, let root = window.contentView,
              root.convert(root.bounds, to: nil).contains(point) else {
            publish(false)
            return
        }
        var ancestor = superview
        while let view = ancestor {
            if let clip = view as? NSClipView, !clip.convert(clip.bounds, to: nil).contains(point) {
                publish(false)
                return
            }
            ancestor = view.superview
        }
        let local = convert(point, from: nil)
        let shape = RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
        publish(shape.path(in: bounds).contains(local))
    }

    private func publish(_ value: Bool) {
        guard hovered != value else { return }
        hovered = value
        onHover?(value)
    }

    func stop() {
        generation += 1
        refreshPending = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        notifications.forEach(NotificationCenter.default.removeObserver)
        notifications.removeAll()
        observedWindow = nil
        publish(false)
    }
}
