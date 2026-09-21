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
                onDismiss: dismissFilterDrawer
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 48)
            .transition(
                reduceMotion
                    ? .opacity
                    : .move(edge: .bottom).combined(with: .opacity)
            )
            .onHover { hovering in
                handleDrawerHover(hovering)
            }
        }
        .frame(width: DaybookTheme.popoverWidth, height: DaybookTheme.popoverHeight)
        .zIndex(30)
    }

    func handleFilterTriggerHover(_ hovering: Bool) {
        hoverOpenWorkItem?.cancel()
        if hovering {
            hoverCloseWorkItem?.cancel()
            guard !isFilterDrawerPresented else { return }
            let work = DispatchWorkItem {
                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                    isFilterDrawerPresented = true
                }
            }
            hoverOpenWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
        } else {
            guard isFilterDrawerPresented else { return }
            scheduleDrawerClose()
        }
    }

    func handleDrawerHover(_ hovering: Bool) {
        if hovering {
            hoverCloseWorkItem?.cancel()
        } else {
            scheduleDrawerClose()
        }
    }

    func toggleFilterDrawer() {
        hoverOpenWorkItem?.cancel()
        hoverCloseWorkItem?.cancel()
        withAnimation(DaybookMotion.interactive(reduceMotion)) {
            isFilterDrawerPresented.toggle()
        }
    }

    func dismissFilterDrawer() {
        hoverOpenWorkItem?.cancel()
        hoverCloseWorkItem?.cancel()
        withAnimation(DaybookMotion.interactive(reduceMotion)) {
            isFilterDrawerPresented = false
        }
    }

    private func scheduleDrawerClose() {
        hoverCloseWorkItem?.cancel()
        let work = DispatchWorkItem {
            withAnimation(DaybookMotion.interactive(reduceMotion)) {
                isFilterDrawerPresented = false
            }
        }
        hoverCloseWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30, execute: work)
    }
}
