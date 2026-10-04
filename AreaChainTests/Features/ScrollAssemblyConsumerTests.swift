import AppKit
import SwiftUI
import Testing
@testable import AreaChain

/// 生产消费者的装配刻画；滚动事件、程序化定位与几何证据分别记录。
@Suite(.serialized)
@MainActor
struct ScrollAssemblyConsumerTests {
    @Test(arguments: ["en", "zh-Hans"])
    func sidebarAndNestedTimeline(locale: String) async throws {
        let fixture = try SettingsButtonTestSupport()
        let restore = CalendarSpanTestSupport.preserveState()
        defer { restore(); fixture.cleanup() }
        let todos = (0..<50).map { TodoItem(title: "Synthetic \($0)", dayKey: "2026-09-14") }
        todos.forEach { fixture.container.mainContext.insert($0) }
        try fixture.container.mainContext.save()
        let sidebar = fixture.window(WorkspaceSidebarView(navigation: .shared, tags: [], todos: todos),
            locale: locale, scheme: locale == "en" ? .light : .dark, size: NSSize(width: 230, height: 360))
        defer { SystemPageHost.release(sidebar) }
        try await SystemPageHost.settle(sidebar)
        ScrollNativeEvidence.record(sidebar, label: "sidebar-\(locale)")
        let sidebarScroll = try #require(scrolls(sidebar).first)
        #expect(overlays(sidebarScroll).count == 1)
        #expect(!sidebarScroll.hasVerticalScroller)
        try await wheel(sidebarScroll, horizontal: false, window: sidebar)
        ScrollNativeEvidence.record(sidebar, label: "sidebar-wheel-\(locale)")
        let gantt = fixture.window(GanttPage(todayKey: "2026-09-14"), locale: locale,
            scheme: locale == "en" ? .light : .dark, size: NSSize(width: locale == "en" ? 880 : 640, height: 420))
        defer { SystemPageHost.release(gantt) }
        try await SystemPageHost.settle(gantt)
        let targets = scrolls(gantt)
        #expect(targets.count == 2)
        ScrollNativeEvidence.record(gantt, label: "gantt-initial-\(locale)")
        let inner = try #require(targets.first { $0.enclosingScrollView != nil })
        let outer = try #require(inner.enclosingScrollView)
        let originalCounts = targets.map { overlays($0).count }
        #expect(originalCounts == [2, 0])
        withKnownIssue("阶段 B 原实现：内层 Configurator 也定位到外层；只登记，不修目标搜索") {
            #expect(originalCounts == [1, 1])
        }
        let outerOrigin = outer.contentView.bounds.origin
        try await wheel(inner, horizontal: false, window: gantt)
        #expect(outer.contentView.bounds.origin == outerOrigin)
        let innerOrigin = inner.contentView.bounds.origin
        try await wheel(outer, horizontal: true, window: gantt)
        #expect(inner.contentView.bounds.origin == innerOrigin)
        #expect(targets.map { overlays($0).count } == originalCounts)
        ScrollNativeEvidence.record(gantt, label: "gantt-wheel-\(locale)")
        try SettingsButtonTestSupport.snapshot(gantt, name: "scroll-gantt-\(locale)")
    }

    @Test(arguments: ["en", "zh-Hans"])
    func weekColumnsKeepSeparateTargets(locale: String) async throws {
        let support = try CalendarWeekTestSupport()
        defer { support.cleanup() }
        let todos = support.days.flatMap { day in
            (0..<24).map { TodoItem(title: "Synthetic \($0)", dayKey: day) }
        }
        todos.forEach { support.fixture.container.mainContext.insert($0) }
        try support.fixture.container.mainContext.save()
        let board = CalendarWeekBoard(days: support.days, selectedKey: support.selected, todayKey: support.today,
            routines: [], checks: [], todos: todos, listFocused: false, listFocusID: .constant(nil),
            onSelect: { _ in }, onInspect: { _, _ in }, onReturnToGrid: {}, onDropTodo: { _, _ in })
        let window = support.fixture.window(board, locale: locale, scheme: locale == "en" ? .light : .dark,
            size: NSSize(width: locale == "en" ? 1120 : 840, height: 420))
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let targets = scrolls(window)
        #expect(targets.count == 7)
        #expect(targets.map { overlays($0).count } == [7, 0, 0, 0, 0, 0, 0])
        withKnownIssue("阶段 B 原实现：七个浮层均定位首列；独立原生滚动不代表浮层归属正确") {
            #expect(targets.allSatisfy { overlays($0).count == 1 })
        }
        ScrollNativeEvidence.record(window, label: "week-initial-\(locale)")
        for target in targets {
            let others = targets.filter { $0 !== target }
            let origins = others.map { $0.contentView.bounds.origin }
            try await wheel(target, horizontal: false, window: window)
            #expect(others.map { $0.contentView.bounds.origin } == origins)
            #expect(target.contentView.bounds.origin.y > 0)
        }
        ScrollNativeEvidence.record(window, label: "week-wheel-\(locale)")
        try SettingsButtonTestSupport.snapshot(window, name: "scroll-week-\(locale)")
    }

    private func scrolls(_ window: NSWindow) -> [NSScrollView] {
        ScrollNativeEvidence.views(window).compactMap { $0 as? NSScrollView }
    }

    private func overlays(_ scroll: NSScrollView) -> [DaybookFloatingScrollerOverlay] {
        scroll.subviews.compactMap { $0 as? DaybookFloatingScrollerOverlay }
    }

    private func wheel(_ scroll: NSScrollView, horizontal: Bool, window: NSWindow) async throws {
        let cg = try #require(CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
            wheel1: horizontal ? 0 : -80, wheel2: horizontal ? -80 : 0, wheel3: 0))
        let event = try #require(NSEvent(cgEvent: cg))
        // 直接投给原生目标以核对轴与响应；不冒充鼠标位置经窗口命中的滚轮/触控板证据。
        scroll.scrollWheel(with: event)
        try await SystemPageHost.settle(window)
    }
}
