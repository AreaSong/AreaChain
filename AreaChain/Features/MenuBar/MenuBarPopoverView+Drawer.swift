import AppKit
import SwiftData
import SwiftUI

extension MenuBarPopoverView {
    // MARK: - 筛选抽屉浮层与交互协调

    var filterDrawerOverlay: some View {
        ZStack(alignment: .bottom) {
            // 1. 半透明遮罩层：覆盖上方待办列表区域，点击任意空白处收起抽屉
            Color.black.opacity(0.12)
                .frame(width: DaybookTheme.popoverWidth, height: DaybookTheme.popoverHeight)
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissFilterDrawer()
                }
                .transition(.opacity)

            // 2. 手账风内部抽屉卡片：停靠在底栏上方
            MenuBarFilterDrawer(
                tab: tab,
                filter: $boardFilter,
                diaryFilterTagID: $diaryFilterTagID,
                projects: projects.filter { $0.deletedAt == nil },
                projectCounts: taskProjectCounts,
                unclassifiedCount: unclassifiedTodosCount,
                tags: tab == .tasks ? Catalog.liveTaskTags(Array(tags)) : Catalog.liveTags(Array(tags)),
                tagCounts: currentTabTagCounts,
                onDismiss: dismissFilterDrawer,
                externalCategory: $filterCategory
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 42)
            .transition(
                reduceMotion
                    ? .opacity
                    : .move(edge: .bottom).combined(with: .opacity)
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
