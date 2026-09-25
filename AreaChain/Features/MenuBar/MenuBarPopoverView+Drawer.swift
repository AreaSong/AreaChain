import AppKit
import SwiftData
import SwiftUI

extension MenuBarPopoverView {
    // MARK: - 筛选级联浮层与交互协调

    var filterDrawerOverlay: some View {
        ZStack(alignment: .bottomLeading) {
            // 底栏留给筛选按钮。SwiftUI 的 onTapGesture 接不住测试和连点发出的鼠标按下，遮罩自己收起。
            FilterDrawerScrim(passHeight: 44) { dismissFilterDrawer() }
                .frame(width: DaybookMetrics.Window.popoverWidth, height: DaybookMetrics.Window.popoverHeight)

            // 树状两级级联悬停浮窗：紧贴底栏「筛选」按钮上沿
            MenuBarFilterFlyout(
                tab: tab,
                filters: $filters,
                tags: tab == .tasks ? Catalog.liveTaskTags(Array(tags)) : Catalog.liveTags(Array(tags)),
                tagCounts: currentTabTagCounts,
                onDismiss: dismissFilterDrawer,
                externalCategory: $filterCategory
            )
            .padding(.leading, 12)
            .padding(.bottom, 44)
            .transition(
                reduceMotion
                    ? .opacity
                    : .asymmetric(
                        insertion: .scale(scale: 0.96, anchor: .bottomLeading).combined(with: .opacity).combined(with: .offset(y: 4)),
                        removal: .scale(scale: 0.98, anchor: .bottomLeading).combined(with: .opacity)
                    )
            )
        }
        .frame(width: DaybookMetrics.Window.popoverWidth, height: DaybookMetrics.Window.popoverHeight)
        .zIndex(30)
    }

    func toggleFilterDrawer() {
        withAnimation(DaybookMotion.interactive(reduceMotion)) {
            isFilterDrawerPresented.toggle()
        }
    }

    func dismissFilterDrawer() {
        withAnimation(DaybookMotion.interactive(reduceMotion)) {
            isFilterDrawerPresented = false
        }
    }
}

/// 筛选浮层外面的点击收起。底栏高度内不命中，让筛选按钮自己切换开关。
private struct FilterDrawerScrim: NSViewRepresentable {
    var passHeight: CGFloat
    var onDismiss: () -> Void

    func makeNSView(context: Context) -> FilterDrawerScrimView {
        let view = FilterDrawerScrimView()
        view.passHeight = passHeight
        view.onDismiss = onDismiss
        return view
    }

    func updateNSView(_ view: FilterDrawerScrimView, context: Context) {
        view.passHeight = passHeight
        view.onDismiss = onDismiss
    }
}

private final class FilterDrawerScrimView: NSView {
    var passHeight: CGFloat = 44
    var onDismiss: () -> Void = {}

    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        guard bounds.contains(local) else { return nil }
        let yFromBottom = isFlipped ? bounds.maxY - local.y : local.y - bounds.minY
        guard yFromBottom >= passHeight else { return nil }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        onDismiss()
    }
}
