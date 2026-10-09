import AppKit
import SwiftUI

/// 两个标记由同一个 modifier 持有，只搜索它们共同父节点内的局部区间。
/// 不使用 SwiftUI 私有类型、屏幕坐标或全窗口第一个滚动容器。
@MainActor
final class DaybookScrollScope {
    weak var start: DaybookScrollBoundaryView?
    weak var host: DaybookScrollerHostNSView?
    weak var edgeObserver: DaybookScrollEdgeObserverNSView?

    func target(endingAt end: NSView) -> NSScrollView? {
        guard let start, start.window != nil, start.window === end.window else { return nil }
        let startPath = ancestry(start)
        let endPath = ancestry(end)
        guard let common = startPath.first(where: { node in endPath.contains { $0 === node } }),
              let first = startPath.first(where: { $0.superview === common }),
              let last = endPath.first(where: { $0.superview === common }),
              let lower = common.subviews.firstIndex(where: { $0 === first }),
              let upper = common.subviews.firstIndex(where: { $0 === last }), lower < upper else { return nil }
        let candidates = common.subviews[(lower + 1)..<upper].flatMap(Self.outerScrolls)
        return candidates.count == 1 ? candidates.first : nil
    }

    private func ancestry(_ view: NSView) -> [NSView] {
        var result: [NSView] = []
        var node: NSView? = view
        while let current = node {
            result.append(current)
            node = current.superview
        }
        return result
    }

    /// 旧直接入口位于 document 内时保留原归属（正文自身还可能含 AppKit 滚动编辑器）。
    /// 外部入口只接受局部唯一候选；嵌套的公共装配必须走成对 scope，不走此兼容路径。
    static func unscopedTarget(for host: DaybookScrollerHostNSView) -> NSScrollView? {
        if let enclosing = host.enclosingScrollView { return enclosing }
        var branch: NSView = host
        while let parent = branch.superview {
            if let clip = parent as? NSClipView { return clip.enclosingScrollView }
            let siblings = parent.subviews.filter { $0 !== branch }
            let candidates = siblings.flatMap(outerScrolls)
            if !candidates.isEmpty {
                guard candidates.count == 1, !siblings.contains(where: containsConfigurator) else { return nil }
                return candidates.first
            }
            if parent === host.window?.contentView { return nil }
            branch = parent
        }
        return nil
    }

    private static func outerScrolls(in view: NSView) -> [NSScrollView] {
        if let scroll = view as? NSScrollView { return [scroll] }
        return view.subviews.flatMap(outerScrolls)
    }

    private static func containsConfigurator(_ view: NSView) -> Bool {
        if view is DaybookScrollerHostNSView { return true }
        // 内层 Configurator 属于自己的 document，不与外层直接装配争用。
        if view is NSScrollView { return false }
        return view.subviews.contains(where: containsConfigurator)
    }
}

struct DaybookScrollTargetModifier: ViewModifier {
    var featherEdges = false
    var featherHeight: CGFloat = 7.0
    @State private var scope = DaybookScrollScope()
    @Environment(\.daybookScrollTopEdge) private var topEdge

    func body(content: Content) -> some View {
        // 两端位于掩膜之外，渐变状态的原生重排不能改变区间；实际浮层仍是目标 ScrollView 的子视图。
        content
            .modifier(DaybookScrollEdgeFeatherModifier(
                enabled: featherEdges || topEdge, featherHeight: featherHeight,
                scope: scope, topOnly: !featherEdges, respectsReducedTransparency: topEdge
            ))
            .background(DaybookScrollBoundary(scope: scope))
            .overlay(DaybookScrollerConfigurator(scope: scope).allowsHitTesting(false))
    }
}

private struct DaybookScrollBoundary: NSViewRepresentable {
    let scope: DaybookScrollScope

    func makeNSView(context: Context) -> DaybookScrollBoundaryView {
        let view = DaybookScrollBoundaryView()
        view.scope = scope
        scope.start = view
        return view
    }

    func updateNSView(_ nsView: DaybookScrollBoundaryView, context: Context) {
        scope.start = nsView
        scope.host?.applyScroller()
    }

    static func dismantleNSView(_ nsView: DaybookScrollBoundaryView, coordinator: ()) {
        // 重挂期间旧标记的迟到拆卸不能清掉同一 scope 的新起点。
        guard let scope = nsView.scope, scope.start === nsView else { return }
        scope.start = nil
        scope.host?.applyScroller()
    }
}

final class DaybookScrollBoundaryView: NSView {
    weak var scope: DaybookScrollScope?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        scope?.host?.applyScroller()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        scope?.host?.applyScroller()
    }

    override func layout() {
        super.layout()
        scope?.host?.applyScroller()
    }
}

/// 宿主只启用实际滚动区的顶部过渡；原调用方的底部策略与其他宿主默认值不变。
private struct DaybookScrollTopEdgeKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var daybookScrollTopEdge: Bool {
        get { self[DaybookScrollTopEdgeKey.self] }
        set { self[DaybookScrollTopEdgeKey.self] = newValue }
    }
}
