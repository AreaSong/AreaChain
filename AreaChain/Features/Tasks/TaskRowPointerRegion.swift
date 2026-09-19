import AppKit
import SwiftUI

/// 原生 clickCount 让第一次点击立即选中，不必等双击手势失败。
struct TaskRowPointerRegion: NSViewRepresentable {
    var id: UUID
    var tooltip: String? = nil
    var onSelect: (TaskSelectionModifiers) -> Void
    var onEdit: () -> Void
    var onHover: ((Bool) -> Void)? = nil

    func makeNSView(context: Context) -> TaskRowPointerView {
        let view = TaskRowPointerView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: TaskRowPointerView, context: Context) {
        view.identifier = NSUserInterfaceItemIdentifier(id.uuidString)
        view.toolTip = tooltip
        view.onSelect = onSelect
        view.onEdit = onEdit
        view.onHover = onHover
    }
}

final class TaskRowPointerView: NSView {
    var onSelect: ((TaskSelectionModifiers) -> Void)?
    var onEdit: (() -> Void)?
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
        guard !event.modifierFlags.contains(.control) else {
            super.mouseDown(with: event)
            return
        }
        mouseDownLocation = event.locationInWindow
        didDrag = false
        window?.makeFirstResponder(self)
        onSelect?(selectionModifiers(event))
        // 保留上层 SwiftUI 的拖拽处理；本区域只负责选择与编辑。
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        defer { mouseDownLocation = nil }
        let stayedNearStart = mouseDownLocation.map {
            hypot(event.locationInWindow.x - $0.x, event.locationInWindow.y - $0.y) < 4
        } ?? false
        let shouldEdit = event.clickCount == 2 && !didDrag
            && !event.modifierFlags.contains(.control) && selectionModifiers(event).isEmpty
            && stayedNearStart && bounds.contains(convert(event.locationInWindow, from: nil))
        super.mouseUp(with: event)
        if shouldEdit { onEdit?() }
    }

    override func mouseDragged(with event: NSEvent) {
        if let start = mouseDownLocation,
           hypot(event.locationInWindow.x - start.x, event.locationInWindow.y - start.y) >= 4 {
            didDrag = true
        }
        super.mouseDragged(with: event)
    }

    private func selectionModifiers(_ event: NSEvent) -> TaskSelectionModifiers {
        var modifiers: TaskSelectionModifiers = []
        if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }
        if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
        return modifiers
    }
}
