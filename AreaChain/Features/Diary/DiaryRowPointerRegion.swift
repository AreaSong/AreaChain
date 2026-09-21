import AppKit
import SwiftUI

/// 原生 clickCount 让第一次点击立即选中，双击直接打开独立编辑小窗
struct DiaryRowPointerRegion: NSViewRepresentable {
    var id: UUID
    var onSelect: () -> Void
    var onOpen: () -> Void
    var onHover: ((Bool) -> Void)? = nil

    func makeNSView(context: Context) -> DiaryRowPointerView {
        let view = DiaryRowPointerView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: DiaryRowPointerView, context: Context) {
        view.identifier = NSUserInterfaceItemIdentifier(id.uuidString)
        view.onSelect = onSelect
        view.onOpen = onOpen
        view.onHover = onHover
    }
}

final class DiaryRowPointerView: NSView {
    var onSelect: (() -> Void)?
    var onOpen: (() -> Void)?
    var onHover: ((Bool) -> Void)?
    private var mouseDownLocation: NSPoint?
    private var didDrag = false
    private var trackingArea: NSTrackingArea?

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .activeInActiveApp,
            .inVisibleRect
        ]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        self.trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onHover?(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onHover?(false)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        onSelect?()
        guard !event.modifierFlags.contains(.control) else {
            super.mouseDown(with: event)
            return
        }
        mouseDownLocation = event.locationInWindow
        didDrag = false
        super.mouseDown(with: event)
    }

    private var isHandlingRightMouseDown = false

    override func rightMouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        onSelect?()
        isHandlingRightMouseDown = true
        super.rightMouseDown(with: event)
        isHandlingRightMouseDown = false
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        if !isHandlingRightMouseDown {
            window?.makeFirstResponder(self)
            onSelect?()
        }
        return super.menu(for: event)
    }

    override func mouseUp(with event: NSEvent) {
        defer { mouseDownLocation = nil }
        let stayedNearStart = mouseDownLocation.map {
            hypot(event.locationInWindow.x - $0.x, event.locationInWindow.y - $0.y) < 4
        } ?? false
        let shouldOpen = event.clickCount == 2 && !didDrag
            && !event.modifierFlags.contains(.control)
            && stayedNearStart && bounds.contains(convert(event.locationInWindow, from: nil))
        super.mouseUp(with: event)
        if shouldOpen { onOpen?() }
    }

    override func mouseDragged(with event: NSEvent) {
        if let start = mouseDownLocation,
           hypot(event.locationInWindow.x - start.x, event.locationInWindow.y - start.y) >= 4 {
            didDrag = true
        }
        super.mouseDragged(with: event)
    }
}
