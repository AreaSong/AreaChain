import AppKit
import SwiftUI

enum GanttRowMetrics {
    static let dayWidth: CGFloat = 22
    static let titleWidth: CGFloat = 108
    static let height: CGFloat = 22
}

enum GanttPointerAction {
    case select(TaskSelectionModifiers)
    case inspect
    case dragBegan
    case dragChanged(CGFloat)
    case dragEnded
    case cancel
    case moveByDays(Int)
}

struct GanttRowPointerRegion: NSViewRepresentable {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    var bar: GanttTodoBar
    var displayedDay: String
    var days: [String]
    var isSelected: Bool
    var dispatch: (GanttPointerAction) -> Void

    func makeNSView(context: Context) -> GanttRowPointerView {
        let view = GanttRowPointerView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: GanttRowPointerView, context: Context) {
        view.identifier = NSUserInterfaceItemIdentifier("gantt.todo.\(bar.id)")
        view.barIndex = days.firstIndex(of: displayedDay) ?? 0
        view.dayCount = days.count
        view.isSelected = isSelected
        view.dispatch = dispatch
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.button)
        view.setAccessibilityIdentifier(view.identifier?.rawValue)
        view.setAccessibilityLabel(bar.title)
        view.setAccessibilityValue(DayKey.displayName(displayedDay, calendar: calendar, locale: locale))
        view.setAccessibilitySelected(isSelected)
        view.toolTip = bar.title + " · " + DayKey.displayName(displayedDay, calendar: calendar, locale: locale)
        view.window?.invalidateCursorRects(for: view)
    }
}

/// 不启动系统拖拽会话：时间轴自身显示唯一的吸附预览，鼠标松开前不写模型。
final class GanttRowPointerView: NSView {
    var barIndex = 0
    var dayCount = 0
    var isSelected = false
    var dispatch: ((GanttPointerAction) -> Void)?
    private var startPoint: NSPoint?
    private var modifiers: TaskSelectionModifiers = []
    private var canDrag = false
    private var didDrag = false
    private var pendingSelection = false

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var barRect: NSRect {
        NSRect(x: GanttRowMetrics.titleWidth + CGFloat(barIndex) * GanttRowMetrics.dayWidth,
               y: 0, width: GanttRowMetrics.dayWidth, height: bounds.height)
    }

    override func resetCursorRects() {
        addCursorRect(barRect.intersection(visibleRect), cursor: .openHand)
        addCursorRect(NSRect(x: 0, y: 0, width: GanttRowMetrics.titleWidth, height: bounds.height)
            .intersection(visibleRect), cursor: .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {
        guard !event.modifierFlags.contains(.control) else { super.mouseDown(with: event); return }
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        startPoint = point
        canDrag = barRect.contains(point)
        didDrag = false
        modifiers = []
        if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
        if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }
        // 已选色块的普通按下可能是批量拖动，等确定为点击后才收缩选择。
        pendingSelection = isSelected && modifiers.isEmpty
        if !pendingSelection { dispatch?(.select(modifiers)) }
    }

    override func mouseDragged(with event: NSEvent) {
        guard canDrag, let startPoint else { return }
        var point = convert(event.locationInWindow, from: nil)
        guard didDrag || hypot(point.x - startPoint.x, point.y - startPoint.y) >= 4 else { return }
        if !didDrag { dispatch?(.dragBegan) }
        didDrag = true
        autoscrollHorizontally(with: event)
        point = convert(event.locationInWindow, from: nil)
        NSCursor.closedHand.set()
        dispatch?(.dragChanged(point.x - startPoint.x))
    }

    override func mouseUp(with event: NSEvent) {
        guard let startPoint else { return }
        let point = convert(event.locationInWindow, from: nil)
        let wasDragging = didDrag
        let wasClick = !wasDragging && hypot(point.x - startPoint.x, point.y - startPoint.y) < 4 && bounds.contains(point)
        let shouldSelect = pendingSelection && wasClick
        let shouldInspect = wasClick && modifiers.isEmpty
            && (startPoint.x < GanttRowMetrics.titleWidth || event.clickCount == 2)
        let validDrop = isValidDrop(event)
        resetPointer()
        if wasDragging {
            if validDrop { dispatch?(.dragChanged(point.x - startPoint.x)) }
            dispatch?(validDrop ? .dragEnded : .cancel)
        } else {
            if shouldSelect { dispatch?(.select([])) }
            if shouldInspect { dispatch?(.inspect) }
        }
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        guard flags.isEmpty else { super.keyDown(with: event); return }
        switch event.keyCode {
        case 53: cancelOperation(nil)
        case 36, 76: dispatch?(.inspect)
        case 123: dispatch?(.moveByDays(-1))
        case 124: dispatch?(.moveByDays(1))
        default: super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        resetPointer()
        dispatch?(.cancel)
    }

    override func resignFirstResponder() -> Bool {
        if didDrag { cancelOperation(nil) }
        return super.resignFirstResponder()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil, didDrag { cancelOperation(nil) }
        super.viewWillMove(toWindow: newWindow)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: nil)
        if let window {
            NotificationCenter.default.addObserver(self, selector: #selector(windowDidResignKey),
                                                  name: NSWindow.didResignKeyNotification, object: window)
        }
    }

    @objc private func windowDidResignKey() {
        if didDrag { cancelOperation(nil) }
    }

    override func accessibilityPerformPress() -> Bool {
        dispatch?(.select([]))
        dispatch?(.inspect)
        return true
    }

    private func isValidDrop(_ event: NSEvent) -> Bool {
        let x = convert(event.locationInWindow, from: nil).x - GanttRowMetrics.titleWidth
        guard x >= 0, x < CGFloat(dayCount) * GanttRowMetrics.dayWidth else { return false }
        var ancestor = superview
        while let view = ancestor {
            if let clip = view as? NSClipView,
               !clip.bounds.contains(clip.convert(event.locationInWindow, from: nil)) { return false }
            ancestor = view.superview
        }
        return true
    }

    private func resetPointer() {
        startPoint = nil
        canDrag = false
        didDrag = false
        pendingSelection = false
        window?.invalidateCursorRects(for: self)
    }

    private func autoscrollHorizontally(with event: NSEvent) {
        var ancestor = superview
        while let view = ancestor {
            defer { ancestor = view.superview }
            guard let scroll = view as? NSScrollView, let document = scroll.documentView else { continue }
            let clip = scroll.contentView
            let maxX = max(0, document.frame.width - clip.bounds.width)
            guard maxX > 0 else { continue }
            let x = clip.convert(event.locationInWindow, from: nil).x
            let step = GanttRowMetrics.dayWidth
            let delta: CGFloat = x < clip.bounds.minX + step ? -step : (x > clip.bounds.maxX - step ? step : 0)
            guard delta != 0 else { return }
            clip.scroll(to: NSPoint(x: min(max(clip.bounds.minX + delta, 0), maxX), y: clip.bounds.minY))
            scroll.reflectScrolledClipView(clip)
            return
        }
    }
}
