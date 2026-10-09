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
        let edges = ScrollNativeEvidence.views(sidebar).compactMap { $0 as? DaybookScrollEdgeObserverNSView }
        #expect(edges.count == 1 && edges.first?.currentScrollView === sidebarScroll)
        try await wheel(sidebarScroll, horizontal: false, window: sidebar)
        ScrollNativeEvidence.record(sidebar, label: "sidebar-wheel-\(locale)")
        let gantt = fixture.window(GanttPage(todayKey: "2026-09-14"), locale: locale,
            scheme: locale == "en" ? .light : .dark, size: NSSize(width: locale == "en" ? 880 : 640, height: 420))
        defer { SystemPageHost.release(gantt) }
        try await SystemPageHost.settle(gantt)
        let targets = scrolls(gantt)
        #expect(targets.count == 2)
        #expect(ScrollNativeEvidence.views(gantt).allSatisfy { !($0 is DaybookScrollEdgeObserverNSView) })
        ScrollNativeEvidence.record(gantt, label: "gantt-initial-\(locale)")
        let inner = try #require(targets.first { $0.enclosingScrollView != nil })
        let outer = try #require(inner.enclosingScrollView)
        let originalCounts = targets.map { overlays($0).count }
        #expect(originalCounts == [1, 1])
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
        let targets = ScrollNativeEvidence.views(window).compactMap { ($0 as? DaybookScrollerHostNSView)?.currentScrollView }
        let outer = try #require(targets.first?.enclosingScrollView)
        #expect(overlays(outer).isEmpty)
        #expect(scrolls(window).filter { $0 !== outer }.count == targets.count)
        #expect(targets.count == 7)
        #expect(targets.map { overlays($0).count } == [1, 1, 1, 1, 1, 1, 1])
        ScrollNativeEvidence.record(window, label: "week-initial-\(locale)")
        for target in targets {
            try await revealWeekColumn(target, in: window)
            let outerOrigin = outer.contentView.bounds.origin
            let others = targets.filter { $0 !== target }
            let origins = others.map { $0.contentView.bounds.origin }
            try await wheel(target, horizontal: false, window: window)
            #expect(others.map { $0.contentView.bounds.origin } == origins)
            #expect(target.contentView.bounds.origin.y > 0)
            #expect(outer.contentView.bounds.origin == outerOrigin)
        }
        ScrollNativeEvidence.record(window, label: "week-wheel-\(locale)")
        try SettingsButtonTestSupport.snapshot(window, name: "scroll-week-\(locale)")
    }

    @Test(arguments: ["en", "zh-Hans"])
    func weekKnobsFollowDatesThroughUpdatesAndResize(locale: String) async throws {
        let support = try CalendarWeekTestSupport()
        defer { support.cleanup() }
        let todos = support.days.enumerated().flatMap { index, day in
            (0..<(12 + index * 4)).map { TodoItem(title: "Synthetic \(day) / \($0)", dayKey: day) }
        }
        todos.forEach { support.fixture.container.mainContext.insert($0) }
        try support.fixture.container.mainContext.save()
        let window = ScrollOwnershipEvidence.window(WeekScrollContent(support: support, todos: todos)
            .modelContainer(support.fixture.container).environment(support.fixture.prefs),
            locale: locale, size: .init(width: 1120, height: 420))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let rows = ScrollNativeEvidence.views(window).compactMap { $0 as? BoardRowPointerView }
        let targets = try support.days.map { day in
            let todo = try #require(todos.first { $0.dayKey == day })
            return try #require(rows.first { $0.identifier?.rawValue == todo.id.uuidString }?.enclosingScrollView)
        }
        #expect(Set(targets.map(ObjectIdentifier.init)).count == 7)
        let owned = try targets.map { try #require(overlays($0).first) }
        let heights = try owned.map { try ScrollOwnershipEvidence.knob($0).height }
        #expect(Set(heights).count == 7)
        for (day, target) in zip(support.days, targets) {
            try await revealWeekColumn(target, in: window)
            try await ScrollOwnershipEvidence.drag(target, among: targets, in: window, label: "week-\(locale)-\(day)")
        }
        let offsets = targets.map { $0.contentView.bounds.origin }
        support.selected = support.days[0]
        try await SystemPageHost.settle(window)
        #expect(targets.map { $0.contentView.bounds.origin } == offsets)
        #expect(targets.map { overlays($0).first } == owned.map(Optional.some))
        window.setContentSize(.init(width: 1000, height: 360))
        try await SystemPageHost.settle(window)
        for (target, overlay) in zip(targets, owned) {
            #expect(overlays(target) == [overlay])
            #expect(overlay.frame == DaybookFloatingScrollerOverlay.calculateFrame(for: target))
        }
        ScrollNativeEvidence.record(window, label: "week-updated-resized-\(locale)")
    }

    @Test(arguments: ["en", "zh-Hans"])
    func ganttInnerKnobUsesWindowEvents(locale: String) async throws {
        let fixture = try SettingsButtonTestSupport(isolatedPreferences: true)
        let restore = CalendarSpanTestSupport.preserveState()
        defer { restore(); fixture.cleanup() }
        for index in 0..<50 {
            fixture.container.mainContext.insert(TodoItem(title: "Synthetic \(index)", dayKey: "2026-09-14"))
        }
        try fixture.container.mainContext.save()
        let window = ScrollOwnershipEvidence.window(GanttPage(todayKey: "2026-09-14")
            .modelContainer(fixture.container).environment(fixture.prefs),
            locale: locale, size: .init(width: 880, height: 420))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let targets = scrolls(window)
        let inner = try #require(targets.first { $0.enclosingScrollView != nil })
        let outer = try #require(inner.enclosingScrollView)
        let owned = targets.flatMap(overlays)
        #expect(targets.count == 2 && targets.allSatisfy { overlays($0).count == 1 })
        try await ScrollOwnershipEvidence.drag(inner, among: targets, in: window, label: "gantt-inner-\(locale)")
        let offset = inner.contentView.bounds.origin
        window.setContentSize(.init(width: 640, height: 360))
        try await SystemPageHost.settle(window)
        // resize 会按设备像素取整；横滚的独立性从 resize 完成后的原生偏移精确核对。
        let resizedOffset = inner.contentView.bounds.origin
        #expect(abs(resizedOffset.y - offset.y) <= 1)
        try await wheel(outer, horizontal: true, window: window)
        #expect(outer.contentView.bounds.minX > 0)
        #expect(inner.contentView.bounds.origin == resizedOffset)
        #expect(targets.flatMap(overlays) == owned)
        ScrollNativeEvidence.record(window, label: "gantt-resized-horizontal-\(locale)")
    }

    private func revealWeekColumn(_ target: NSScrollView, in window: NSWindow) async throws {
        let outer = try #require(target.enclosingScrollView)
        let document = try #require(outer.documentView)
        document.scrollToVisible(target.convert(target.bounds, to: document))
        outer.reflectScrolledClipView(outer.contentView)
        try await SystemPageHost.settle(window)
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

private struct WeekScrollContent: View {
    var support: CalendarWeekTestSupport
    let todos: [TodoItem]

    var body: some View {
        CalendarWeekBoard(days: support.days, selectedKey: support.selected, todayKey: support.today,
            routines: [], checks: [], todos: todos, listFocused: false, listFocusID: .constant(nil),
            onSelect: { support.selected = $0 }, onInspect: { _, _ in }, onReturnToGrid: {}, onDropTodo: { _, _ in })
    }
}
