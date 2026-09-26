import AppKit
import SwiftUI

// MARK: - 兼容 AppKit NSScrollView 的 DaybookScroller

/// 现代化细圆角胶囊滚动条：强制 overlay 风格，消除系统槽道
final class DaybookScroller: NSScroller {
    override class var isCompatibleWithOverlayScrollers: Bool { true }

    override var scrollerStyle: NSScroller.Style {
        get { .overlay }
        set {
            _ = newValue
            super.scrollerStyle = .overlay
        }
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
        var current: NSView? = self
        while let node = current {
            if let target = node as? NSScrollView {
                return target
            }
            if let found = findScrollViewInSiblings(of: node) {
                return found
            }
            current = node.superview
        }
        return nil
    }

    private func findScrollViewInSiblings(of node: NSView) -> NSScrollView? {
        guard let parent = node.superview else { return nil }
        for sibling in parent.subviews where sibling !== node {
            if let found = findFirstScrollView(in: sibling) {
                return found
            }
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                            .animation(DaybookMotion.fade(reduceMotion), value: topFeather)
                            .animation(DaybookMotion.fade(reduceMotion), value: bottomFeather)
                        } else {
                            Rectangle()
                        }
                    }
                }
        } else {
            content
        }
    }
}

extension View {
    /// 现代化细圆角胶囊滚动条与优雅视口羽化修饰器
    func daybookScroll(featherEdges: Bool = true, featherHeight: CGFloat = 7.0) -> some View {
        self
            .background(DaybookScrollerConfigurator())
            .modifier(DaybookScrollEdgeFeatherModifier(enabled: featherEdges, featherHeight: featherHeight))
    }
}
