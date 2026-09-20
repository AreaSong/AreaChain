import AppKit
import SwiftUI

/// 现代化细圆角微胶囊滚动条：彻底移除粗灰滑槽，采用半透明水墨胶囊悬浮于内容边缘。
final class DaybookScroller: NSScroller {
    private var isHovered = false
    private var isDragging = false
    private var trackingArea: NSTrackingArea?
    private var fadeTimer: Timer?
    private var scrollObserver: NSObjectProtocol?

    override class var isCompatibleWithOverlayScrollers: Bool { true }

    // 锁定为 .overlay，绝不允许系统或外部将其降级为 .legacy（legacy 会强行开辟 15pt 灰槽挤压内容）
    override var scrollerStyle: NSScroller.Style {
        get { .overlay }
        set { super.scrollerStyle = .overlay }
    }

    override var knobStyle: NSScroller.KnobStyle {
        get { .default }
        set { super.knobStyle = .default }
    }

    override var isOpaque: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupScroller()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupScroller()
    }

    deinit {
        fadeTimer?.invalidate()
        if let scrollObserver {
            NotificationCenter.default.removeObserver(scrollObserver)
        }
    }

    private func setupScroller() {
        super.scrollerStyle = .overlay
        alphaValue = 0
        wantsLayer = true
        setupScrollObserver()
    }

    private func setupScrollObserver() {
        scrollObserver = NotificationCenter.default.addObserver(
            forName: NSScrollView.didLiveScrollNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, let target = notification.object as? NSScrollView, target.verticalScroller === self else {
                return
            }
            self.revealOnScroll()
        }
    }

    // MARK: - Layout & Dimension

    override class func scrollerWidth(for controlSize: NSControl.ControlSize, scrollerStyle: NSScroller.Style) -> CGFloat {
        12.0
    }

    // MARK: - Drawing Overrides

    override func draw(_ dirtyRect: NSRect) {
        // 关键防护：坚决不调用 super.draw(dirtyRect)！
        // super.draw 会在 legacy 模式或系统偏好开启时强行绘制系统灰色滑槽和方形滑块。
        // 我们只在有滑块时自绘优雅的圆角胶囊：
        drawKnob()
    }

    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {
        // 彻底不绘制滑槽背景，消除原生粗灰槽道
    }

    override func drawKnob() {
        let knob = rect(for: .knob)
        guard knob.width > 0, knob.height > 0 else { return }

        let active = isHovered || isDragging
        let targetWidth: CGFloat = active ? 6.0 : 3.5
        let rightMargin: CGFloat = 2.5
        let knobX = bounds.width - targetWidth - rightMargin
        let minHeight: CGFloat = 22.0
        let knobHeight = max(knob.height, minHeight)
        let pillRect = NSRect(x: knobX, y: knob.origin.y, width: targetWidth, height: knobHeight)

        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let baseAlpha: CGFloat = active ? 0.48 : 0.24
        let pillColor = isDark ? NSColor(white: 1.0, alpha: baseAlpha) : NSColor(white: 0.0, alpha: baseAlpha)

        pillColor.setFill()
        let path = NSBezierPath(roundedRect: pillRect, xRadius: targetWidth / 2.0, yRadius: targetWidth / 2.0)
        path.fill()
    }

    // MARK: - Tracking & Hover

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        setHoverState(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        setHoverState(false)
    }

    override func mouseDown(with event: NSEvent) {
        isDragging = true
        needsDisplay = true
        super.mouseDown(with: event)
        isDragging = false
        needsDisplay = true
        scheduleFadeOut()
    }

    private func setHoverState(_ hovered: Bool) {
        guard isHovered != hovered else { return }
        isHovered = hovered
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().alphaValue = hovered ? 1.0 : (fadeTimer != nil ? 1.0 : 0.0)
        }
        needsDisplay = true
        if !hovered {
            scheduleFadeOut()
        } else {
            fadeTimer?.invalidate()
            fadeTimer = nil
        }
    }

    // MARK: - Fade Animation

    private func revealOnScroll() {
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
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
            guard let self, !self.isHovered, !self.isDragging else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                self.animator().alphaValue = 0.0
            }
            self.fadeTimer = nil
        }
    }
}

// MARK: - SwiftUI Bridge Configurator

struct DaybookScrollerConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> DaybookScrollerHostNSView {
        let view = DaybookScrollerHostNSView()
        return view
    }

    func updateNSView(_ nsView: DaybookScrollerHostNSView, context: Context) {
        nsView.applyScroller()
    }
}

final class DaybookScrollerHostNSView: NSView {
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
        scrollView.scrollerStyle = .overlay
        scrollView.hasVerticalScroller = true
        if !(scrollView.verticalScroller is DaybookScroller) {
            let scroller = DaybookScroller()
            scrollView.verticalScroller = scroller
        }
    }

    private func locateTargetScrollView() -> NSScrollView? {
        if let direct = enclosingScrollView {
            return direct
        }
        // 1. 优先检查同级兄弟视图（.background(DaybookScrollerConfigurator()) 所在层级）
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
        // 2. 向上递归检查父级及祖先
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
