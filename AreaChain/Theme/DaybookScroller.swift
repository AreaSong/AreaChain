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
    var scope: DaybookScrollScope?

    func makeNSView(context: Context) -> DaybookScrollerHostNSView {
        let view = DaybookScrollerHostNSView()
        view.scope = scope
        return view
    }

    func updateNSView(_ nsView: DaybookScrollerHostNSView, context: Context) {
        nsView.scope = scope
        nsView.applyScroller()
    }

    static func dismantleNSView(_ nsView: DaybookScrollerHostNSView, coordinator: ()) {
        nsView.dismantle()
    }
}

final class DaybookScrollerHostNSView: NSView {
    private(set) weak var currentOverlay: DaybookFloatingScrollerOverlay?
    private(set) weak var currentScrollView: NSScrollView?
    var scope: DaybookScrollScope? {
        didSet {
            if oldValue !== scope, oldValue?.host === self {
                oldValue?.edgeObserver?.bind(to: nil)
                oldValue?.host = nil
            }
            scope?.host = self
        }
    }
    private var dismantled = false
    private var generation = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        alphaValue = 0
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        alphaValue = 0
        wantsLayer = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        scheduleApply()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        scheduleApply()
    }

    override func layout() {
        super.layout()
        applyScroller()
    }

    private func scheduleApply() {
        generation += 1
        applyScroller()
        let scheduled = generation
        DispatchQueue.main.async { [weak self] in
            guard let self, self.generation == scheduled else { return }
            self.applyScroller()
        }
    }

    func dismantle() {
        dismantled = true
        generation += 1
        clearBinding()
    }

    private func clearBinding() {
        currentOverlay?.removeFromSuperview()
        currentOverlay = nil
        currentScrollView = nil
        scope?.edgeObserver?.bind(to: nil)
    }

    func applyScroller() {
        guard !dismantled, window != nil, superview != nil,
              let scrollView = locateTargetScrollView() else {
            clearBinding()
            return
        }
        if currentScrollView !== scrollView || currentOverlay?.superview !== scrollView {
            clearBinding()
            let overlay = DaybookFloatingScrollerOverlay(scrollView: scrollView)
            scrollView.addSubview(overlay, positioned: .above, relativeTo: nil)
            currentOverlay = overlay
            currentScrollView = scrollView
        } else {
            currentOverlay?.syncFrame()
        }
        scope?.edgeObserver?.bind(to: scrollView)
    }

    private func locateTargetScrollView() -> NSScrollView? {
        if let scope { return scope.target(endingAt: self) }
        return DaybookScrollScope.unscopedTarget(for: self)
    }
}

// MARK: - 智能动态视口边缘羽化 (Fading Edges)

struct DaybookScrollEdgeObserver: NSViewRepresentable {
    var scope: DaybookScrollScope?
    var enabled = true
    var onEdgeChange: (Bool, Bool) -> Void

    func makeNSView(context: Context) -> DaybookScrollEdgeContainer {
        let view = DaybookScrollEdgeContainer()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ nsView: DaybookScrollEdgeContainer, context: Context) {
        nsView.update(scope: scope, enabled: enabled, onEdgeChange: onEdgeChange)
    }

    static func dismantleNSView(_ nsView: DaybookScrollEdgeContainer, coordinator: ()) {
        nsView.removeObserver()
    }
}

/// 保留原生背景分支身份；开关只装卸观察者，不使成对边界临时离开窗口并重装浮层。
final class DaybookScrollEdgeContainer: NSView {
    private var observer: DaybookScrollEdgeObserverNSView?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func update(scope: DaybookScrollScope?, enabled: Bool, onEdgeChange: @escaping (Bool, Bool) -> Void) {
        guard enabled else { removeObserver(); return }
        if observer == nil {
            let view = DaybookScrollEdgeObserverNSView(frame: bounds)
            view.autoresizingMask = [.width, .height]
            observer = view
            addSubview(view)
        }
        observer?.onEdgeChange = onEdgeChange
        observer?.scope = scope
        observer?.refreshBinding()
    }

    func removeObserver() {
        observer?.dismantle()
        observer?.removeFromSuperview()
        observer = nil
    }
}

final class DaybookScrollEdgeObserverNSView: NSView {
    var onEdgeChange: ((Bool, Bool) -> Void)?
    weak var scope: DaybookScrollScope? {
        didSet {
            if oldValue !== scope, oldValue?.edgeObserver === self { oldValue?.edgeObserver = nil }
            scope?.edgeObserver = self
        }
    }
    private(set) weak var currentScrollView: NSScrollView?
    private weak var currentClip: NSClipView?
    private weak var currentDocument: NSView?
    private var observers: [NSObjectProtocol] = []
    private var generation = 0
    private var dismantled = false
    private var publicationPending = false
    private var published: [Bool]?
    private var lastTop = false
    private var lastBottom = false

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refreshBinding()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        refreshBinding()
    }

    override func layout() {
        super.layout()
        refreshBinding()
    }

    func refreshBinding() {
        guard !dismantled, window != nil, superview != nil, let host = scope?.host,
              host.window === window else { bind(to: nil); return }
        // 只消费 Host 的已确认绑定；通知可能发生在 SwiftUI 重排中，不能在这里提前重新定位。
        bind(to: host.currentScrollView)
    }

    func bind(to target: NSScrollView?) {
        let target = !dismantled && window != nil && target?.window === window ? target : nil
        if currentScrollView !== target || currentClip !== target?.contentView
            || currentDocument !== target?.documentView || (target == nil && !observers.isEmpty) {
            generation += 1
            publicationPending = false
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
            currentScrollView = target
            currentClip = target?.contentView
            currentDocument = target?.documentView
            if let target { observe(target) }
        }
        checkEdges()
    }

    private func observe(_ scroll: NSScrollView) {
        let scheduled = generation
        let views: [NSView] = [scroll, scroll.contentView] + (scroll.documentView.map { [$0] } ?? [])
        for view in views {
            // 通知开关是共享能力；解绑只移除本观察者，不关闭浮层或其他使用者需要的开关。
            view.postsBoundsChangedNotifications = true
            view.postsFrameChangedNotifications = true
            for name in [NSView.boundsDidChangeNotification, NSView.frameDidChangeNotification] {
                observe(name, object: view, generation: scheduled)
            }
        }
        observe(NSScrollView.didLiveScrollNotification, object: scroll, generation: scheduled)
    }

    private func observe(_ name: Notification.Name, object: NSView, generation scheduled: Int) {
        observers.append(NotificationCenter.default.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
            guard let self, !self.dismantled, self.generation == scheduled else { return }
            self.refreshBinding()
        })
    }

    func checkEdges() {
        var top = false
        var bottom = false
        if let scroll = currentScrollView, let document = currentDocument {
            let visible = scroll.documentVisibleRect
            let height = document.bounds.height
            let overflowing = height > visible.height + 4
            top = overflowing && visible.minY > 3.0
            bottom = overflowing && visible.maxY < height - 3.0
        }
        lastTop = top
        lastBottom = bottom
        schedulePublication()
    }

    private func schedulePublication() {
        guard !dismantled, window != nil, !publicationPending, published != [lastTop, lastBottom] else { return }
        publicationPending = true
        let scheduled = generation
        // AppKit 可在 SwiftUI 更新/layout 内同步通知；合并到下一主队列轮次再写 State。
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.dismantled, self.generation == scheduled else { return }
            self.publicationPending = false
            guard self.window != nil, self.scope?.edgeObserver === self else { return }
            let state = [self.lastTop, self.lastBottom]
            guard self.published != state else { return }
            self.published = state
            self.onEdgeChange?(self.lastTop, self.lastBottom)
        }
    }

    func dismantle() {
        dismantled = true
        generation += 1
        publicationPending = false
        onEdgeChange = nil
        if scope?.edgeObserver === self { scope?.edgeObserver = nil }
        bind(to: nil)
    }
}

struct DaybookScrollEdgeFeatherModifier: ViewModifier {
    var enabled: Bool
    var featherHeight: CGFloat = 7.0
    var scope: DaybookScrollScope?
    var topOnly = false
    var respectsReducedTransparency = false

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var topFeather = false
    @State private var bottomFeather = false

    func body(content: Content) -> some View {
        content
                .background(DaybookScrollEdgeObserver(scope: scope, enabled: enabled) { top, bottom in
                    topFeather = top
                    bottomFeather = bottom
                })
                .mask {
                    GeometryReader { geo in
                        let total = geo.size.height
                        let opaque = respectsReducedTransparency && reduceTransparency
                        let top = enabled && !opaque && total > featherHeight * 2 && topFeather
                        let bottom = enabled && !topOnly && !opaque && total > featherHeight * 2 && bottomFeather
                        LinearGradient(
                            stops: [
                                .init(color: top ? .clear : .black, location: 0),
                                .init(color: .black, location: top ? (featherHeight / total) : 0),
                                .init(color: .black, location: bottom ? (1.0 - featherHeight / total) : 1.0),
                                .init(color: bottom ? .clear : .black, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .animation(DaybookMotion.fade(reduceMotion), value: topFeather)
                        .animation(DaybookMotion.fade(reduceMotion), value: bottomFeather)
                    }
                }
                .onChange(of: enabled) { _, _ in
                    topFeather = false
                    bottomFeather = false
                }
    }
}

extension View {
    /// 无参及仅传开关沿用原单参数入口：隐藏系统指示器，默认不羽化。
    func daybookScroll(featherEdges: Bool = false) -> some View {
        daybookScrollAssembly(featherEdges: featherEdges, featherHeight: 7.0,
                              indicators: DaybookScrollIndicators.hidden)
    }

    /// 显式高度沿用原双参数入口：保留上游策略，仅传高度时默认羽化。
    func daybookScroll(featherEdges: Bool = true, featherHeight: CGFloat = 7.0) -> some View {
        daybookScrollAssembly(featherEdges: featherEdges, featherHeight: featherHeight,
                              indicators: DaybookScrollIndicators.preserved)
    }

    // 指示器策略仍先应用；局部标记不重新承载内容或切换内容身份。
    private func daybookScrollAssembly<IndicatorContent: View>(
        featherEdges: Bool, featherHeight: CGFloat, indicators: (Self) -> IndicatorContent
    ) -> some View {
        indicators(self)
            .modifier(DaybookScrollTargetModifier(featherEdges: featherEdges, featherHeight: featherHeight))
    }
}

private enum DaybookScrollIndicators {
    static func hidden<Content: View>(_ content: Content) -> some View {
        content.scrollIndicators(.hidden)
    }

    // 保留必须是恒等变换，设置 automatic 仍会覆盖调用方选择。
    static func preserved<Content: View>(_ content: Content) -> Content { content }
}
