import AppKit
import SwiftUI

/// 原生 clickCount 让第一次点击立即选中，双击直接打开独立编辑小窗
struct DiaryRowPointerRegion: NSViewRepresentable {
    var id: UUID
    var onSelect: () -> Void
    var onOpen: () -> Void

    func makeNSView(context: Context) -> DiaryRowPointerView {
        let view = DiaryRowPointerView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: DiaryRowPointerView, context: Context) {
        view.identifier = NSUserInterfaceItemIdentifier(id.uuidString)
        view.onSelect = onSelect
        view.onOpen = onOpen
    }
}

final class DiaryRowPointerView: NSView {
    var onSelect: (() -> Void)?
    var onOpen: (() -> Void)?
    private var mouseDownLocation: NSPoint?

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard !event.modifierFlags.contains(.control) else {
            super.mouseDown(with: event)
            return
        }
        mouseDownLocation = event.locationInWindow
        window?.makeFirstResponder(self)
        onSelect?()
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        defer { mouseDownLocation = nil }
        let stayedNearStart = mouseDownLocation.map {
            hypot(event.locationInWindow.x - $0.x, event.locationInWindow.y - $0.y) < 4
        } ?? false
        let shouldOpen = event.clickCount == 2
            && !event.modifierFlags.contains(.control)
            && stayedNearStart && bounds.contains(convert(event.locationInWindow, from: nil))
        super.mouseUp(with: event)
        if shouldOpen { onOpen?() }
    }
}
