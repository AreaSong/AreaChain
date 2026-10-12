import AppKit
import SwiftUI

enum GanttSortMode: String, CaseIterable {
    case stable
    case priority
    case day

    func label(locale: Locale) -> String {
        let isZh = locale.identifier.hasPrefix("zh")
        switch self {
        case .stable: return isZh ? "默认顺序" : "Default Order"
        case .priority: return isZh ? "按优先级" : "By Priority"
        case .day: return isZh ? "按日期" : "By Date"
        }
    }

    func sortedBars(todos: [TodoItem], monthDays: [String], filter: BoardFilter) -> [GanttTodoBar] {
        let monthSet = Set(monthDays)
        let filtered = todos.filter { todo in
            todo.deletedAt == nil && !todo.isDone && monthSet.contains(todo.dayKey)
                && Classification.matches(todo.classifyBits, filter: filter)
        }
        return filtered.sorted { lhs, rhs in
            switch self {
            case .stable:
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
                return lhs.id.uuidString < rhs.id.uuidString
            case .priority:
                let lp = Classification.priorityRank(important: lhs.isImportant, urgent: lhs.isUrgent)
                let rp = Classification.priorityRank(important: rhs.isImportant, urgent: rhs.isUrgent)
                if lp != rp { return lp < rp }
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
                return lhs.id.uuidString < rhs.id.uuidString
            case .day:
                if lhs.dayKey != rhs.dayKey { return lhs.dayKey < rhs.dayKey }
                return lhs.createdAt < rhs.createdAt
            }
        }.map { GanttTodoBar(id: $0.id, title: $0.title, dayKey: $0.dayKey) }
    }
}

enum GanttSpanStore {
    private static let storageKey = "areachain.gantt.spanDays"
    private static let titleWidthKey = "areachain.gantt.titleWidth"

    static func load() -> [UUID: Int] {
        guard let raw = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: Int] else { return [:] }
        var result: [UUID: Int] = [:]
        for (key, value) in raw where value > 1 {
            if let id = UUID(uuidString: key) { result[id] = value }
        }
        return result
    }

    static func save(_ spans: [UUID: Int]) {
        var raw: [String: Int] = [:]
        for (id, value) in spans where value > 1 { raw[id.uuidString] = value }
        UserDefaults.standard.set(raw, forKey: storageKey)
    }

    static func loadTitleWidth() -> CGFloat? {
        let val = UserDefaults.standard.double(forKey: titleWidthKey)
        return val >= 108 ? CGFloat(val) : nil
    }

    static func saveTitleWidth(_ width: CGFloat) {
        UserDefaults.standard.set(Double(width), forKey: titleWidthKey)
    }
}

enum GanttRowMetrics {
    static let dayWidth: CGFloat = 22
    static let titleWidth: CGFloat = 108
    static let height: CGFloat = 28
    static let checkboxWidth: CGFloat = 22

    struct Resolved: Equatable {
        let titleWidth: CGFloat
        let dayWidth: CGFloat
        let height: CGFloat
    }

    static func resolve(
        availableWidth: CGFloat,
        dayCount: Int,
        preferredTitleWidth: CGFloat? = nil
    ) -> Resolved {
        let count = CGFloat(max(dayCount, 1))
        let maxTitle = min(480, max(260, floor(availableWidth * 0.55)))
        let defaultTitle = min(240, max(168, floor(availableWidth * 0.22)))
        if let preferredTitleWidth {
            let resolvedTitle = min(max(preferredTitleWidth, 120), maxTitle)
            let resolvedDay = max(dayWidth, (availableWidth - resolvedTitle) / count)
            return Resolved(titleWidth: resolvedTitle, dayWidth: resolvedDay, height: height)
        }
        let minTotalWidth = titleWidth + count * dayWidth
        guard availableWidth > minTotalWidth else {
            return Resolved(titleWidth: titleWidth, dayWidth: dayWidth, height: height)
        }
        let resolvedDay = max(dayWidth, (availableWidth - defaultTitle) / count)
        return Resolved(titleWidth: defaultTitle, dayWidth: resolvedDay, height: height)
    }
}

enum GanttPointerAction {
    case select(TaskSelectionModifiers), inspect, dragBegan, dragChanged(CGFloat), dragEnded
    case resizeSpan(Int), resizeTitleColumn(CGFloat), reorderRow(Int), commitReorder(Int), hoverDivider(Bool)
    case cancel, moveByDays(Int), complete
}

struct GanttColumnDividerRegion: NSViewRepresentable {
    var titleWidth: CGFloat
    var onHover: (Bool) -> Void
    var onResize: (CGFloat) -> Void

    func makeNSView(context: Context) -> GanttColumnDividerView {
        let view = GanttColumnDividerView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: GanttColumnDividerView, context: Context) {
        view.titleWidth = titleWidth; view.onHover = onHover; view.onResize = onResize
    }
}

final class GanttColumnDividerView: NSView {
    var titleWidth: CGFloat = GanttRowMetrics.titleWidth
    var onHover: ((Bool) -> Void)?
    var onResize: ((CGFloat) -> Void)?
    private var startWindowX: CGFloat?
    private var startWidth: CGFloat = 0
    private var trackingArea: NSTrackingArea?

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect], owner: self)
        addTrackingArea(area); trackingArea = area
    }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .resizeLeftRight) }
    override func mouseEntered(with event: NSEvent) { NSCursor.resizeLeftRight.set(); onHover?(true) }
    override func mouseMoved(with event: NSEvent) { NSCursor.resizeLeftRight.set(); onHover?(true) }
    override func mouseExited(with event: NSEvent) { if startWindowX == nil { NSCursor.arrow.set(); onHover?(false) } }

    override func mouseDown(with event: NSEvent) {
        startWindowX = event.locationInWindow.x; startWidth = titleWidth
        NSCursor.resizeLeftRight.set(); onHover?(true)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startWindowX else { return }
        NSCursor.resizeLeftRight.set()
        onResize?(startWidth + (event.locationInWindow.x - startWindowX))
    }

    override func mouseUp(with event: NSEvent) {
        startWindowX = nil
        let inside = bounds.contains(convert(event.locationInWindow, from: nil))
        onHover?(inside)
        if !inside { NSCursor.arrow.set() }
    }
}

struct GanttRowPointerRegion: NSViewRepresentable {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    var bar: GanttTodoBar
    var displayedDay: String
    var spanDays: Int = 1
    var days: [String]
    var isSelected: Bool
    var titleWidth: CGFloat = GanttRowMetrics.titleWidth
    var dayWidth: CGFloat = GanttRowMetrics.dayWidth
    var onHover: ((Bool, Bool) -> Void)? = nil
    var dispatch: (GanttPointerAction) -> Void

    func makeNSView(context: Context) -> GanttRowPointerView {
        let view = GanttRowPointerView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: GanttRowPointerView, context: Context) {
        view.identifier = NSUserInterfaceItemIdentifier("gantt.todo.\(bar.id)")
        view.originBarIndex = days.firstIndex(of: bar.dayKey) ?? 0
        view.barIndex = days.firstIndex(of: displayedDay) ?? 0
        view.spanDays = max(spanDays, 1)
        view.dayCount = days.count
        view.isSelected = isSelected
        view.titleWidth = titleWidth
        view.dayWidth = dayWidth
        view.onHover = onHover
        view.dispatch = dispatch
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.button)
        view.setAccessibilityIdentifier(view.identifier?.rawValue)
        view.setAccessibilityLabel(bar.title)
        view.setAccessibilityValue(DayKey.displayName(displayedDay, calendar: calendar, locale: locale))
        view.setAccessibilitySelected(isSelected)
        view.toolTip = bar.title + " · " + DayKey.displayName(displayedDay, calendar: calendar, locale: locale)
        if !view.isTrackingDrag { view.window?.invalidateCursorRects(for: view) }
    }
}

/// 不启动系统拖拽会话：时间轴自身显示唯一的吸附预览，鼠标松开前不写模型。
final class GanttRowPointerView: NSView {
    var originBarIndex = 0, barIndex = 0, spanDays = 1, dayCount = 0, isSelected = false
    var titleWidth: CGFloat = GanttRowMetrics.titleWidth
    var dayWidth: CGFloat = GanttRowMetrics.dayWidth
    var onHover: ((Bool, Bool) -> Void)?
    var dispatch: ((GanttPointerAction) -> Void)?
    private var startPoint: NSPoint?
    private var startWindowPoint: NSPoint = .zero
    private var startTitleWidth: CGFloat = 0
    private var modifiers: TaskSelectionModifiers = []
    private var canDrag = false, isResizingSpan = false, isResizingColumn = false
    private var isReorderingRow = false, dragsToCursorDay = false, didDrag = false, pendingSelection = false
    private var trackingArea: NSTrackingArea?
    private var lastHoverState: (Bool, Bool) = (false, false)

    var isTrackingDrag: Bool { startPoint != nil || didDrag }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    /// 工作台开启了 isMovableByWindowBackground，透明交互层必须禁止拖动窗口，否则甘特拖拽会变成移动整扇窗口。
    override var mouseDownCanMoveWindow: Bool { false }

    private var barRect: NSRect {
        let clampedSpan = min(max(spanDays, 1), max(1, dayCount - barIndex))
        return NSRect(x: titleWidth + CGFloat(barIndex) * dayWidth, y: 0, width: CGFloat(clampedSpan) * dayWidth, height: bounds.height)
    }
    private var resizeHandleRect: NSRect { NSRect(x: barRect.maxX - 6, y: 0, width: 9, height: bounds.height) }
    private var columnDividerRect: NSRect { NSRect(x: titleWidth - 5, y: 0, width: 10, height: bounds.height) }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect], owner: self)
        addTrackingArea(area); trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { if !isTrackingDrag { updateHover(with: event) } }
    override func mouseMoved(with event: NSEvent) { if !isTrackingDrag { updateHover(with: event) } }
    override func mouseExited(with event: NSEvent) {
        guard !isTrackingDrag else { return }
        dispatch?(.hoverDivider(false)); reportHover(row: false, title: false)
    }

    override func resetCursorRects() {
        let divider = columnDividerRect.intersection(visibleRect)
        if !divider.isEmpty { addCursorRect(divider, cursor: .resizeLeftRight) }
        let resize = resizeHandleRect.intersection(visibleRect)
        if !resize.isEmpty { addCursorRect(resize, cursor: .resizeLeftRight) }
        var bodyRect = barRect; bodyRect.size.width = max(0, bodyRect.width - 6)
        let bar = bodyRect.intersection(visibleRect)
        if !bar.isEmpty { addCursorRect(bar, cursor: .openHand) }
        let title = NSRect(x: 0, y: 0, width: max(0, titleWidth - 5), height: bounds.height).intersection(visibleRect)
        if !title.isEmpty { addCursorRect(title, cursor: .openHand) }
    }

    override func mouseDown(with event: NSEvent) {
        guard !event.modifierFlags.contains(.control) else { super.mouseDown(with: event); return }
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        startPoint = point; startWindowPoint = event.locationInWindow; startTitleWidth = titleWidth
        let hitResize = resizeHandleRect.contains(point)
        let hitBar = !hitResize && barRect.insetBy(dx: -2, dy: 0).contains(point)
        let hitColumnDivider = !hitResize && !hitBar && columnDividerRect.contains(point)
        isResizingColumn = hitColumnDivider; isResizingSpan = hitResize; isReorderingRow = false
        canDrag = hitColumnDivider || hitResize || hitBar || point.x >= GanttRowMetrics.checkboxWidth
        dragsToCursorDay = !hitColumnDivider && !hitResize && !hitBar
        didDrag = false; modifiers = []
        if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
        if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }
        reportHover(row: true, title: false)
        if hitColumnDivider || (point.x < GanttRowMetrics.checkboxWidth && modifiers.isEmpty) {
            if hitColumnDivider { dispatch?(.hoverDivider(true)) }
            pendingSelection = false; return
        }
        if hitResize {
            pendingSelection = false
            if !isSelected { dispatch?(.select([])) }
            return
        }
        pendingSelection = isSelected && modifiers.isEmpty
        if !pendingSelection { dispatch?(.select(modifiers)) }
    }

    override func mouseDragged(with event: NSEvent) {
        guard canDrag, let startPoint else { return }
        var point = convert(event.locationInWindow, from: nil)
        let winDeltaX = event.locationInWindow.x - startWindowPoint.x
        let winDeltaY = startWindowPoint.y - event.locationInWindow.y
        if isResizingColumn {
            didDrag = true; NSCursor.resizeLeftRight.set()
            dispatch?(.resizeTitleColumn(startTitleWidth + winDeltaX)); return
        }
        guard didDrag || hypot(winDeltaX, winDeltaY) >= 4 else { return }
        if isResizingSpan {
            didDrag = true; autoscrollHorizontally(with: event)
            point = convert(event.locationInWindow, from: nil); NSCursor.resizeLeftRight.set()
            let originX = titleWidth + CGFloat(originBarIndex) * dayWidth
            let rawSpan = Int(round((point.x - originX) / dayWidth))
            dispatch?(.resizeSpan(min(max(rawSpan, 1), max(1, dayCount - originBarIndex)))); return
        }
        if dragsToCursorDay && !didDrag && point.x < titleWidth && abs(winDeltaY) >= abs(winDeltaX) {
            isReorderingRow = true
        }
        if isReorderingRow {
            didDrag = true; NSCursor.closedHand.set()
            dispatch?(.reorderRow(Int((winDeltaY / max(bounds.height, 1)).rounded()))); return
        }
        if dragsToCursorDay && point.x < titleWidth { return }
        if !didDrag { dispatch?(.dragBegan) }
        didDrag = true; autoscrollHorizontally(with: event)
        point = convert(event.locationInWindow, from: nil); NSCursor.closedHand.set()
        dispatch?(.dragChanged(dragTranslation(for: point, startPoint: startPoint)))
    }

    override func mouseUp(with event: NSEvent) {
        guard let startPoint else { return }
        let point = convert(event.locationInWindow, from: nil)
        let wasDragging = didDrag, wasResizing = isResizingSpan || isResizingColumn, wasReordering = isReorderingRow
        let winDeltaY = startWindowPoint.y - event.locationInWindow.y
        let reorderOffset = Int((winDeltaY / max(bounds.height, 1)).rounded())
        let wasClick = !wasDragging && !wasResizing && hypot(point.x - startPoint.x, point.y - startPoint.y) < 4 && bounds.contains(point)
        let isCheckboxClick = wasClick && modifiers.isEmpty
            && startPoint.x < GanttRowMetrics.checkboxWidth && point.x < GanttRowMetrics.checkboxWidth
        let isEmptyDayCellClick = wasClick && modifiers.isEmpty && startPoint.x >= titleWidth && !barRect.contains(startPoint)
        let shouldSelect = pendingSelection && wasClick
        let shouldInspect = wasClick && modifiers.isEmpty && !isCheckboxClick && !isEmptyDayCellClick
            && (startPoint.x < titleWidth || event.clickCount == 2)
        let validDrop = isValidDrop(event)
        let translation = dragTranslation(for: point, startPoint: startPoint)
        resetPointer()
        if wasDragging {
            if wasResizing { dispatch?(.hoverDivider(false)); return }
            if wasReordering { dispatch?(.commitReorder(reorderOffset)); return }
            if validDrop { dispatch?(.dragChanged(translation)) }
            dispatch?(validDrop ? .dragEnded : .cancel)
        } else if isCheckboxClick {
            dispatch?(.complete)
        } else if isEmptyDayCellClick && event.clickCount == 2 {
            let targetIndex = min(max(Int(floor((point.x - titleWidth) / dayWidth)), 0), max(dayCount - 1, 0))
            dispatch?(.moveByDays(targetIndex - originBarIndex))
        } else {
            if shouldSelect { dispatch?(.select([])) }
            if shouldInspect { dispatch?(.inspect) }
        }
    }

    private func dragTranslation(for point: NSPoint, startPoint: NSPoint) -> CGFloat {
        guard dragsToCursorDay else { return point.x - startPoint.x }
        let targetIndex = Int(floor((point.x - titleWidth) / dayWidth))
        return CGFloat(targetIndex - originBarIndex) * dayWidth
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        guard flags.isEmpty else { super.keyDown(with: event); return }
        switch event.keyCode {
        case 53: cancelOperation(nil)
        case 36, 76: dispatch?(.inspect)
        case 123: dispatch?(.moveByDays(-1))
        case 124: dispatch?(.moveByDays(1))
        case 49: dispatch?(.complete)
        default: super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) { resetPointer(); dispatch?(.cancel) }
    override func resignFirstResponder() -> Bool { if didDrag { cancelOperation(nil) }; return super.resignFirstResponder() }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil, didDrag { cancelOperation(nil) }
        if newWindow == nil { reportHover(row: false, title: false) }
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
        reportHover(row: false, title: false)
    }

    override func accessibilityPerformPress() -> Bool {
        dispatch?(.select([])); dispatch?(.inspect); return true
    }

    private func updateHover(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let rowHover = bounds.contains(point)
        let hitResize = rowHover && resizeHandleRect.contains(point)
        let hitBar = rowHover && !hitResize && barRect.insetBy(dx: -2, dy: 0).contains(point)
        let hitDivider = rowHover && !hitResize && !hitBar && columnDividerRect.contains(point)
        if hitDivider || hitResize {
            NSCursor.resizeLeftRight.set()
        } else if hitBar || (rowHover && point.x >= GanttRowMetrics.checkboxWidth && point.x < titleWidth) {
            NSCursor.openHand.set()
        } else {
            NSCursor.arrow.set()
        }
        dispatch?(.hoverDivider(hitDivider))
        let titleHover = rowHover && !hitDivider && point.x >= GanttRowMetrics.checkboxWidth && point.x < titleWidth
        reportHover(row: rowHover, title: titleHover)
    }

    private func reportHover(row: Bool, title: Bool) {
        guard lastHoverState != (row, title) else { return }
        lastHoverState = (row, title); onHover?(row, title)
    }

    private func isValidDrop(_ event: NSEvent) -> Bool {
        let x = convert(event.locationInWindow, from: nil).x - titleWidth
        guard x >= 0, x < CGFloat(dayCount) * dayWidth else { return false }
        var ancestor = superview
        while let view = ancestor {
            if let clip = view as? NSClipView,
               !clip.bounds.contains(clip.convert(event.locationInWindow, from: nil)) { return false }
            ancestor = view.superview
        }
        return true
    }

    private func resetPointer() {
        startPoint = nil; canDrag = false; isResizingSpan = false; isResizingColumn = false
        isReorderingRow = false; dragsToCursorDay = false; didDrag = false; pendingSelection = false
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
            let step = dayWidth
            let delta: CGFloat = x < clip.bounds.minX + step ? -step : (x > clip.bounds.maxX - step ? step : 0)
            guard delta != 0 else { return }
            clip.scroll(to: NSPoint(x: min(max(clip.bounds.minX + delta, 0), maxX), y: clip.bounds.minY))
            scroll.reflectScrolledClipView(clip)
            return
        }
    }
}

struct GanttDropTarget: Equatable { let rowID: UUID; let dayKey: String }

struct GanttStandaloneView: View {
    private var dayClock: DayClock { DayClock.shared }
    @State private var dayTick = Date()

    var body: some View {
        let todayKey: String = { _ = dayTick; return dayClock.todayKey }()
        GanttPage(todayKey: todayKey)
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                DayClock.shared.refresh(); dayTick = Date()
            }
    }
}
