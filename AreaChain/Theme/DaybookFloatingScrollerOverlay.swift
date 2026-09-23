import AppKit

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
        let width: CGFloat = 14
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.flash()
        }
    }

    func flash() {
        updateKnobGeometry()
        guard currentKnobRect.width > 0, currentKnobRect.height > 0 else { return }
        fadeTimer?.invalidate()
        fadeTimer = nil
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.animator().alphaValue = 1.0
        }
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            guard let self, !self.isHovered, !self.isDragging else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.35
                self.animator().alphaValue = 0.0
            }
            self.fadeTimer = nil
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
        let knobWidth: CGFloat = active ? 6.0 : 4.0
        let rightMargin: CGFloat = 2.5
        let knobX = bounds.width - knobWidth - rightMargin

        currentKnobRect = NSRect(x: knobX, y: knobY, width: knobWidth, height: knobHeight)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard currentKnobRect.width > 0, currentKnobRect.height > 0 else { return }
        let active = isHovered || isDragging
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let baseAlpha: CGFloat = active ? 0.65 : 0.42
        let pillColor = isDark ? NSColor(white: 1.0, alpha: baseAlpha) : NSColor(white: 0.12, alpha: baseAlpha)

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
