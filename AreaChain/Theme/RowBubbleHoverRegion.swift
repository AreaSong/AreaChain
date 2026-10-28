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

/// 保护悬浮气泡在跨出父行 contentShape 或叠在原生 NSView（BoardRowPointerView / BlankClickNSView）上方时的悬停与点击响应，同时保持 hitTest 为 nil。
struct RowBubbleClickShield: NSViewRepresentable {
    let lifetime: RowBubbleClickShieldLifetime
    var isRounded: Bool
    var managesHover: Bool
    var onHover: (Bool) -> Void
    var onTap: () -> Void

    func makeNSView(context: Context) -> RowBubbleClickShieldView {
        let view = RowBubbleClickShieldView()
        lifetime.view = view
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: RowBubbleClickShieldView, context: Context) {
        view.isRounded = isRounded
        view.managesHover = managesHover
        view.onHover = onHover
        view.onTap = onTap
    }

    static func dismantleNSView(_ view: RowBubbleClickShieldView, coordinator: ()) {
        view.stop()
    }
}

final class RowBubbleClickShieldLifetime {
    weak var view: RowBubbleClickShieldView?
}

final class RowBubbleClickShieldView: NSView {
    private static let activeViews = NSHashTable<RowBubbleClickShieldView>.weakObjects()

    var isRounded = false
    var managesHover = true
    var onHover: ((Bool) -> Void)?
    var onTap: (() -> Void)?

    private var monitor: Any?
    private var hovered = false
    private var pressedInside = false
    private var pendingTapToken: UUID?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    static func containsWindowPoint(_ windowPoint: NSPoint, in window: NSWindow?) -> Bool {
        guard let window else { return false }
        for view in activeViews.allObjects where view.window === window {
            if view.contains(windowPoint: windowPoint) {
                return true
            }
        }
        return false
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            start()
        } else {
            stop()
        }
    }

    func start() {
        stop()
        guard let window else { return }
        Self.activeViews.add(self)
        monitor = NSEvent.addLocalMonitorForEvents(matching: [
            .mouseMoved, .mouseEntered, .mouseExited, .leftMouseDown, .leftMouseUp
        ]) { [weak self, weak window] event in
            MainActor.assumeIsolated {
                guard let self, let window, event.window === window else { return }
                self.handle(event)
            }
            return event
        }
    }

    func cancelPendingTap() {
        pendingTapToken = nil
    }

    private func handle(_ event: NSEvent) {
        let inside = contains(windowPoint: event.locationInWindow)
        switch event.type {
        case .mouseMoved, .mouseEntered, .mouseExited:
            if managesHover, inside != hovered {
                hovered = inside
                onHover?(inside)
            }
        case .leftMouseDown:
            pressedInside = inside
        case .leftMouseUp:
            let shouldTap = pressedInside && inside && !event.modifierFlags.contains(.control)
            pressedInside = false
            guard shouldTap else { return }
            let token = UUID()
            pendingTapToken = token
            DispatchQueue.main.async { [weak self] in
                guard let self, self.pendingTapToken == token else { return }
                self.pendingTapToken = nil
                self.onTap?()
            }
        default:
            break
        }
    }

    func contains(windowPoint: NSPoint) -> Bool {
        guard let window, window.isKeyWindow, !isHiddenOrHasHiddenAncestor,
              let root = window.contentView,
              root.convert(root.bounds, to: nil).contains(windowPoint) else {
            return false
        }
        var ancestor = superview
        while let view = ancestor {
            if let clip = view as? NSClipView, !clip.convert(clip.bounds, to: nil).contains(windowPoint) {
                return false
            }
            ancestor = view.superview
        }
        let local = convert(windowPoint, from: nil)
        if isRounded {
            let shape = RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
            return shape.path(in: bounds).contains(local)
        }
        return bounds.contains(local)
    }

    func stop() {
        pendingTapToken = nil
        pressedInside = false
        if hovered {
            hovered = false
            if managesHover { onHover?(false) }
        }
        Self.activeViews.remove(self)
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
