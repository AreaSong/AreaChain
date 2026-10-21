import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized, .tags(.backgroundWindow)) @MainActor
struct CalendarMonthNavigationTests {
    /// 同 RecurringItemEditorTests：视图图异步拆除晚于函数返回，容器保活到进程结束，避免后续 SwiftData 测试碰到悬空上下文。
    private static var retainedContainers: [ModelContainer] = []

    @Test(arguments: [
        NSSize(width: 1100, height: 720),
        NSSize(width: 480, height: 640)
    ])
    func embeddedCalendarShowsMonthBar(size: NSSize) async throws {
        let container = try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        Self.retainedContainers.append(container)
        let restore = CalendarSpanTestSupport.preserveState()
        defer { restore() }
        BoardSelection.shared.inspectingDayKey = "2026-09-15"
        let window = SystemPageHost.window(
            CalendarPage(todayKey: "2026-09-26", routines: [], checks: [], todos: []),
            container: container,
            scheme: .light,
            locale: "zh-Hans",
            size: size,
            embedded: true
        )
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let content = try #require(window.contentView)
        let anchor = try #require(findAnchor(in: content), "日历没有月份切换条")
        let frame = anchor.convert(anchor.bounds, to: content)
        #expect(frame.width > 40)
        #expect(frame.minX >= -1 && frame.maxX <= content.bounds.width + 1)
        #expect(frame.minY >= -1 && frame.maxY <= content.bounds.height + 1)
    }

    private func findAnchor(in view: NSView?) -> NSView? {
        guard let view else { return nil }
        if view.identifier?.rawValue == "period.bar",
           !view.isHiddenOrHasHiddenAncestor, !view.visibleRect.isEmpty { return view }
        for child in view.subviews {
            if let found = findAnchor(in: child) { return found }
        }
        return nil
    }
}
