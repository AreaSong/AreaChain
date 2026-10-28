import AppKit
import SwiftUI

/// 列表行的单击选中、双击主动作和悬停。任务用修饰键做多选，手记双击打开小窗。
struct BoardRowPointerRegion: NSViewRepresentable {
    var id: UUID
    var plainDoubleClick = false
    var dragPayload: String? = nil
    var onSelect: (_ shift: Bool, _ command: Bool) -> Void
    var onDoubleClick: () -> Void
    var onHover: ((Bool) -> Void)? = nil

    func makeNSView(context: Context) -> BoardRowPointerView {
        let view = BoardRowPointerView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: BoardRowPointerView, context: Context) {
        view.identifier = NSUserInterfaceItemIdentifier(id.uuidString)
        view.plainDoubleClick = plainDoubleClick
        view.dragPayload = dragPayload
        view.onSelect = onSelect
        view.onDoubleClick = onDoubleClick
        view.onHover = onHover
    }
}

final class BoardRowPointerView: NSView, NSDraggingSource {
    private static var activeViews: NSHashTable<BoardRowPointerView> = .weakObjects()

    static func containsWindowPoint(_ windowPoint: NSPoint, in window: NSWindow?) -> Bool {
        guard let window else { return false }
        for view in activeViews.allObjects {
            guard view.window === window, !view.isHiddenOrHasHiddenAncestor else { continue }
            let local = view.convert(windowPoint, from: nil)
            if view.bounds.contains(local) {
                return true
            }
        }
        return false
    }

    var plainDoubleClick = false
    var dragPayload: String?
    var onSelect: ((_ shift: Bool, _ command: Bool) -> Void)?
    var onDoubleClick: (() -> Void)?
    var onHover: ((Bool) -> Void)?
    private var mouseDownLocation: NSPoint?
    private var didDrag = false
    private var dragSessionStarted = false
    private var trackingArea: NSTrackingArea?
    private var isHandlingRightMouseDown = false
    private var isHovering = false

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    /// 工作台允许拖背景移动窗口。行本身不透明点击区不能算背景，否则排序拖动会变成拖整扇窗口。
    override var mouseDownCanMoveWindow: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            Self.activeViews.add(self)
        } else {
            Self.activeViews.remove(self)
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if let superview {
            let windowPoint = superview.convert(point, to: nil)
            if RowBubbleClickShieldView.containsWindowPoint(windowPoint, in: window)
                || SyntaxOverlayEventView.containsWindowPoint(windowPoint, in: window) {
                return nil
            }
        }
        return super.hitTest(point)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .mouseMoved,
            .activeInActiveApp,
            .inVisibleRect
        ]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        self.trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateHover(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateHover(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if isHovering {
            isHovering = false
        }
        onHover?(false)
    }

    private func updateHover(with event: NSEvent) {
        let windowPoint = event.locationInWindow
        if SyntaxOverlayEventView.containsWindowPoint(windowPoint, in: window) {
            if isHovering {
                isHovering = false
                onHover?(false)
            }
            return
        }
        if !isHovering && RowBubbleClickShieldView.containsWindowPoint(windowPoint, in: window) {
            return
        }
        if !isHovering {
            isHovering = true
            onHover?(true)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        onSelect?(event.modifierFlags.contains(.shift), event.modifierFlags.contains(.command))
        guard !event.modifierFlags.contains(.control) else {
            super.mouseDown(with: event)
            return
        }
        mouseDownLocation = event.locationInWindow
        didDrag = false
        dragSessionStarted = false
        super.mouseDown(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        onSelect?(event.modifierFlags.contains(.shift), event.modifierFlags.contains(.command))
        isHandlingRightMouseDown = true
        super.rightMouseDown(with: event)
        isHandlingRightMouseDown = false
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        if !isHandlingRightMouseDown {
            window?.makeFirstResponder(self)
            onSelect?(event.modifierFlags.contains(.shift), event.modifierFlags.contains(.command))
        }
        return super.menu(for: event)
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            mouseDownLocation = nil
            dragSessionStarted = false
        }
        let stayedNearStart = mouseDownLocation.map {
            hypot(event.locationInWindow.x - $0.x, event.locationInWindow.y - $0.y) < 4
        } ?? false
        let plain = !plainDoubleClick || (!event.modifierFlags.contains(.shift) && !event.modifierFlags.contains(.command))
        let shouldActivate = event.clickCount == 2 && !didDrag
            && !event.modifierFlags.contains(.control) && plain
            && stayedNearStart && bounds.contains(convert(event.locationInWindow, from: nil))
        super.mouseUp(with: event)
        if shouldActivate { onDoubleClick?() }
    }

    override func mouseDragged(with event: NSEvent) {
        if let start = mouseDownLocation,
           hypot(event.locationInWindow.x - start.x, event.locationInWindow.y - start.y) >= 4 {
            didDrag = true
        }
        guard didDrag, !dragSessionStarted, let dragPayload, !dragPayload.isEmpty else { return }
        dragSessionStarted = true
        let item = NSDraggingItem(pasteboardWriter: dragPayload as NSString)
        item.setDraggingFrame(bounds, contents: nil as NSImage?)
        beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        context == .outsideApplication ? [] : .move
    }

    override func scrollWheel(with event: NSEvent) {
        // 行点击层盖住整行。滚轮不继续交给所在滚动视图时，任务清单在行上滚不动。
        guard let scrollView = enclosingScrollView else {
            super.scrollWheel(with: event)
            return
        }
        scrollView.scrollWheel(with: event)
    }
}
