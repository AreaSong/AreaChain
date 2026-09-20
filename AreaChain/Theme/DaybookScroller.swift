import AppKit
import SwiftUI

// MARK: - 兼容 AppKit NSScrollView 的 DaybookScroller

/// 现代化细圆角胶囊滚动条：强制 overlay 风格，消除系统槽道
final class DaybookScroller: NSScroller {
    override class var isCompatibleWithOverlayScrollers: Bool { true }

    override var scrollerStyle: NSScroller.Style {
        get { .overlay }
        set { super.scrollerStyle = .overlay }
    }

    override class func scrollerWidth(for controlSize: NSControl.ControlSize, scrollerStyle: NSScroller.Style) -> CGFloat {
        10.0
    }

    override func draw(_ dirtyRect: NSRect) {
        drawKnob()
    }

    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {}

    override func drawKnob() {
        let knob = rect(for: .knob)
        guard knob.width > 0, knob.height > 0 else { return }
        let targetWidth: CGFloat = 3.5
        let rightMargin: CGFloat = 2.5
        let knobX = bounds.width - targetWidth - rightMargin
        let pillRect = NSRect(x: knobX, y: knob.origin.y, width: targetWidth, height: knob.height)
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let pillColor = isDark ? NSColor(white: 1.0, alpha: 0.32) : NSColor(white: 0.0, alpha: 0.32)
        pillColor.setFill()
        let path = NSBezierPath(roundedRect: pillRect, xRadius: targetWidth / 2, yRadius: targetWidth / 2)
        path.fill()
    }
}

// MARK: - 悬浮式极细水墨圆角胶囊滚动条 (DaybookFloatingScrollerOverlay)

/// 现代化悬浮微胶囊指示器：彻底摆脱系统 NSScroller 的 15pt Legacy 粗灰槽道束缚，
/// 漂浮在视口最右侧边缘，滚动时柔和淡入，停止后自动淡出，并支持鼠标悬浮展宽与拖拽。
final class DaybookFloatingScrollerOverlay: NSView {
    private weak var targetScrollView: NSScrollView?
    private var isHovered = false
    private var isDragging = false
    private var dragStartMouseY: CGFloat = 0
    private var dragStartProgress: CGFloat = 0

    private var currentKnobRect: NSRect = .zero
    private var fadeTimer: Timer?
    private var boundsObserver: NSObjectProtocol?
    private var liveScrollObserver: NSObjectProtocol?
    private var trackingArea: NSTrackingArea?

    override var isFlipped: Bool { true }

    init(scrollView: NSScrollView) {
        self.targetScrollView = scrollView
        super.init(frame: Self.calculateFrame(for: scrollView))
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    deinit {
        fadeTimer?.invalidate()
        if let boundsObserver {
            NotificationCenter.default.removeObserver(boundsObserver)
        }
        if let liveScrollObserver {
            NotificationCenter.default.removeObserver(liveScrollObserver)
        }
    }

    static func calculateFrame(for scrollView: NSScrollView) -> NSRect {
        let width: CGFloat = 12
        let bounds = scrollView.bounds
        return NSRect(x: max(0, bounds.width - width), y: 0, width: width, height: bounds.height)
    }

    private func setup() {
        wantsLayer = true
        alphaValue = 0
        autoresizingMask = [.height, .minXMargin]

        guard let scrollView = targetScrollView else { return }
        let clipView = scrollView.contentView
        clipView.postsBoundsChangedNotifications = true

        boundsObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak self] _ in
            self?.handleScroll()
        }

        liveScrollObserver = NotificationCenter.default.addObserver(
            forName: NSScrollView.didLiveScrollNotification,
            object: scrollView,
            queue: .main
        ) { [weak self] _ in
            self?.handleScroll()
        }
    }

    func syncFrame() {
        guard let scrollView = targetScrollView else { return }
        let targetFrame = Self.calculateFrame(for: scrollView)
        if frame != targetFrame {
            frame = targetFrame
        }
        updateKnobGeometry()
    }

    private func handleScroll() {
        updateKnobGeometry()
        reveal()
    }

    private func updateKnobGeometry() {
        guard let scrollView = targetScrollView, let docView = scrollView.documentView else {
            currentKnobRect = .zero
            needsDisplay = true
            return
        }

        let clipView = scrollView.contentView
        let visibleRect = clipView.bounds
        let docHeight = docView.bounds.height
        let visibleHeight = visibleRect.height

        guard docHeight > visibleHeight + 4 else {
            currentKnobRect = .zero
            alphaValue = 0
            needsDisplay = true
            return
        }

        let scrollableDoc = max(1.0, docHeight - visibleHeight)
        let progress: CGFloat
        if clipView.isFlipped {
            progress = max(0, min(1, visibleRect.minY / scrollableDoc))
        } else {
            let maxMinY = docHeight - visibleHeight
            progress = max(0, min(1, (maxMinY - visibleRect.minY) / scrollableDoc))
        }

        let ratio = visibleHeight / docHeight
        let minKnobHeight: CGFloat = 24.0
        let knobHeight = max(minKnobHeight, min(visibleHeight - 20, visibleHeight * ratio))
        let topPadding: CGFloat = 4.0
        let bottomPadding: CGFloat = 4.0
        let trackLength = max(1, bounds.height - knobHeight - (topPadding + bottomPadding))
        let knobY = topPadding + progress * trackLength

        let active = isHovered || isDragging
        let knobWidth: CGFloat = active ? 5.5 : 3.5
        let rightMargin: CGFloat = 2.5
        let knobX = bounds.width - knobWidth - rightMargin

        currentKnobRect = NSRect(x: knobX, y: knobY, width: knobWidth, height: knobHeight)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard currentKnobRect.width > 0, currentKnobRect.height > 0 else { return }
        let active = isHovered || isDragging
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let baseAlpha: CGFloat = active ? 0.55 : 0.32
        let pillColor = isDark ? NSColor(white: 1.0, alpha: baseAlpha) : NSColor(white: 0.0, alpha: baseAlpha)

        pillColor.setFill()
        let path = NSBezierPath(
            roundedRect: currentKnobRect,
            xRadius: currentKnobRect.width / 2,
            yRadius: currentKnobRect.width / 2
        )
        path.fill()
    }

    private func reveal() {
        fadeTimer?.invalidate()
        fadeTimer = nil

        if alphaValue < 1.0 {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                self.animator().alphaValue = 1.0
            }
        }
        scheduleFadeOut()
    }

    private func scheduleFadeOut() {
        guard !isHovered, !isDragging else { return }
        fadeTimer?.invalidate()
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 0.85, repeats: false) { [weak self] _ in
            guard let self, !self.isHovered, !self.isDragging else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.28
                self.animator().alphaValue = 0.0
            }
            self.fadeTimer = nil
        }
    }

    // MARK: - Hit Testing & Hover

    override func hitTest(_ point: NSPoint) -> NSView? {
        // 当完全淡出隐藏时，鼠标事件全部自然穿透到底层内容
        if alphaValue < 0.05 {
            return nil
        }
        let localPoint = convert(point, from: superview)
        if currentKnobRect.insetBy(dx: -4, dy: -2).contains(localPoint) {
            return self
        }
        return nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovered = true
        updateKnobGeometry()
        reveal()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovered = false
        updateKnobGeometry()
        scheduleFadeOut()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if currentKnobRect.contains(point) {
            isDragging = true
            dragStartMouseY = point.y
            guard let scrollView = targetScrollView, let docView = scrollView.documentView else { return }
            let clipView = scrollView.contentView
            let scrollableDoc = max(1.0, docView.bounds.height - clipView.bounds.height)
            if clipView.isFlipped {
                dragStartProgress = clipView.bounds.minY / scrollableDoc
            } else {
                let maxMinY = docView.bounds.height - clipView.bounds.height
                dragStartProgress = (maxMinY - clipView.bounds.minY) / scrollableDoc
            }
            updateKnobGeometry()
            reveal()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging, let scrollView = targetScrollView, let docView = scrollView.documentView else { return }
        let point = convert(event.locationInWindow, from: nil)
        let deltaY = point.y - dragStartMouseY

        let clipView = scrollView.contentView
        let visibleHeight = clipView.bounds.height
        let docHeight = docView.bounds.height
        let scrollableDoc = max(1.0, docHeight - visibleHeight)

        let topPadding: CGFloat = 4.0
        let bottomPadding: CGFloat = 4.0
        let trackLength = max(1.0, bounds.height - currentKnobRect.height - (topPadding + bottomPadding))

        let deltaProgress = deltaY / trackLength
        let newProgress = max(0, min(1, dragStartProgress + deltaProgress))

        let newScrollY: CGFloat
        if clipView.isFlipped {
            newScrollY = newProgress * scrollableDoc
        } else {
            let maxMinY = docHeight - visibleHeight
            newScrollY = maxMinY - (newProgress * scrollableDoc)
        }

        clipView.scroll(to: NSPoint(x: clipView.bounds.minX, y: newScrollY))
        scrollView.reflectScrolledClipView(clipView)
        updateKnobGeometry()
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        updateKnobGeometry()
        scheduleFadeOut()
    }
}

// MARK: - SwiftUI Bridge Configurator

struct DaybookScrollerConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> DaybookScrollerHostNSView {
        DaybookScrollerHostNSView()
    }

    func updateNSView(_ nsView: DaybookScrollerHostNSView, context: Context) {
        nsView.applyScroller()
    }
}

final class DaybookScrollerHostNSView: NSView {
    private weak var currentOverlay: DaybookFloatingScrollerOverlay?
    private weak var currentScrollView: NSScrollView?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        alphaValue = 0
        wantsLayer = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyScroller()
        DispatchQueue.main.async { [weak self] in
            self?.applyScroller()
        }
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        applyScroller()
        DispatchQueue.main.async { [weak self] in
            self?.applyScroller()
        }
    }

    override func layout() {
        super.layout()
        applyScroller()
    }

    func applyScroller() {
        guard let scrollView = locateTargetScrollView() else { return }
        if currentScrollView !== scrollView || currentOverlay == nil || currentOverlay?.superview !== scrollView {
            currentOverlay?.removeFromSuperview()
            let overlay = DaybookFloatingScrollerOverlay(scrollView: scrollView)
            scrollView.addSubview(overlay, positioned: .above, relativeTo: nil)
            currentOverlay = overlay
            currentScrollView = scrollView
        } else {
            currentOverlay?.syncFrame()
        }
    }

    private func locateTargetScrollView() -> NSScrollView? {
        if let direct = enclosingScrollView {
            return direct
        }
        if let siblings = superview?.subviews {
            for sibling in siblings where sibling !== self {
                if let sv = sibling as? NSScrollView {
                    return sv
                }
                if let child = findFirstScrollView(in: sibling) {
                    return child
                }
            }
        }
        var current = superview
        while let node = current {
            if let target = node as? NSScrollView {
                return target
            }
            current = node.superview
        }
        return nil
    }

    private func findFirstScrollView(in view: NSView) -> NSScrollView? {
        if let sv = view as? NSScrollView { return sv }
        for sub in view.subviews where sub !== self {
            if let found = findFirstScrollView(in: sub) {
                return found
            }
        }
        return nil
    }
}

// MARK: - 智能动态视口边缘羽化 (Fading Edges)

struct DaybookScrollEdgeObserver: NSViewRepresentable {
    var onEdgeChange: (Bool, Bool) -> Void

    func makeNSView(context: Context) -> DaybookScrollEdgeObserverNSView {
        let view = DaybookScrollEdgeObserverNSView()
        view.onEdgeChange = onEdgeChange
        return view
    }

    func updateNSView(_ nsView: DaybookScrollEdgeObserverNSView, context: Context) {
        nsView.onEdgeChange = onEdgeChange
        nsView.checkEdges()
    }
}

final class DaybookScrollEdgeObserverNSView: NSView {
    var onEdgeChange: ((Bool, Bool) -> Void)?
    private var observer: NSObjectProtocol?
    private var lastTop = false
    private var lastBottom = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        alphaValue = 0
        wantsLayer = true
        setupObserver()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupObserver()
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setupObserver() {
        observer = NotificationCenter.default.addObserver(
            forName: NSScrollView.didLiveScrollNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkEdges()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        checkEdges()
        DispatchQueue.main.async { [weak self] in self?.checkEdges() }
    }

    override func layout() {
        super.layout()
        checkEdges()
    }

    func checkEdges() {
        guard let scrollView = enclosingScrollView ?? findTargetScrollView() else { return }
        let visible = scrollView.documentVisibleRect
        guard let docView = scrollView.documentView else { return }
        let docHeight = docView.bounds.height

        let hasScrollableContent = docHeight > visible.height + 4
        let topFeather = hasScrollableContent && visible.minY > 3.0
        let bottomFeather = hasScrollableContent && (visible.maxY < docHeight - 3.0)

        if topFeather != lastTop || bottomFeather != lastBottom {
            lastTop = topFeather
            lastBottom = bottomFeather
            onEdgeChange?(topFeather, bottomFeather)
        }
    }

    private func findTargetScrollView() -> NSScrollView? {
        if let siblings = superview?.subviews {
            for sibling in siblings where sibling !== self {
                if let sv = sibling as? NSScrollView { return sv }
                if let found = findFirst(in: sibling) { return found }
            }
        }
        return nil
    }

    private func findFirst(in view: NSView) -> NSScrollView? {
        if let sv = view as? NSScrollView { return sv }
        for sub in view.subviews where sub !== self {
            if let found = findFirst(in: sub) { return found }
        }
        return nil
    }
}

struct DaybookScrollEdgeFeatherModifier: ViewModifier {
    var enabled: Bool
    var featherHeight: CGFloat = 7.0

    @State private var topFeather = false
    @State private var bottomFeather = false

    func body(content: Content) -> some View {
        if enabled {
            content
                .background(DaybookScrollEdgeObserver { top, bottom in
                    topFeather = top
                    bottomFeather = bottom
                })
                .mask {
                    GeometryReader { geo in
                        let total = geo.size.height
                        if total > featherHeight * 2 {
                            LinearGradient(
                                stops: [
                                    .init(color: topFeather ? .clear : .black, location: 0),
                                    .init(color: .black, location: topFeather ? (featherHeight / total) : 0),
                                    .init(color: .black, location: bottomFeather ? (1.0 - featherHeight / total) : 1.0),
                                    .init(color: bottomFeather ? .clear : .black, location: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .animation(.easeOut(duration: 0.15), value: topFeather)
                            .animation(.easeOut(duration: 0.15), value: bottomFeather)
                        } else {
                            Color.black
                        }
                    }
                }
        } else {
            content
        }
    }
}
