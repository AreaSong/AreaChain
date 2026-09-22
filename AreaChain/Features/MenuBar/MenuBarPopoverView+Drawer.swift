import AppKit
import SwiftData
import SwiftUI

extension MenuBarPopoverView {
    // MARK: - 筛选级联浮层与交互协调

    var filterDrawerOverlay: some View {
        ZStack(alignment: .bottomLeading) {
            // 1. 透明点击感知层：无任何视觉遮罩与暗淡效果，点击外部任意处轻巧收起
            Color.black.opacity(0.001)
                .frame(width: DaybookTheme.popoverWidth, height: DaybookTheme.popoverHeight)
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissFilterDrawer()
                }

            // 2. 树状两级级联悬停浮窗：紧贴底栏「筛选」按钮上沿
            MenuBarFilterFlyout(
                tab: tab,
                filters: $filters,
                projects: projects.filter { $0.deletedAt == nil },
                projectCounts: taskProjectCounts,
                unclassifiedCount: unclassifiedTodosCount,
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
        .frame(width: DaybookTheme.popoverWidth, height: DaybookTheme.popoverHeight)
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
