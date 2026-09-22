import AppKit
import SwiftUI

/// 列表行的单击选中、双击主动作和悬停。任务用修饰键做多选，手记双击打开小窗。
struct BoardRowPointerRegion: NSViewRepresentable {
    var id: UUID
    var plainDoubleClick = false
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
        view.onSelect = onSelect
        view.onDoubleClick = onDoubleClick
        view.onHover = onHover
    }
}

final class BoardRowPointerView: NSView {
    var plainDoubleClick = false
    var onSelect: ((_ shift: Bool, _ command: Bool) -> Void)?
    var onDoubleClick: (() -> Void)?
    var onHover: ((Bool) -> Void)?
    private var mouseDownLocation: NSPoint?
    private var didDrag = false
    private var trackingArea: NSTrackingArea?
    private var isHandlingRightMouseDown = false

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
        onSelect?(event.modifierFlags.contains(.shift), event.modifierFlags.contains(.command))
        guard !event.modifierFlags.contains(.control) else {
            super.mouseDown(with: event)
            return
        }
        mouseDownLocation = event.locationInWindow
        didDrag = false
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
        defer { mouseDownLocation = nil }
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
        super.mouseDragged(with: event)
    }
}
