import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@MainActor
struct CalendarMonthNavigationTests {
    @Test func embeddedWideCalendarShowsMonthBar() async throws {
        let container = try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let selection = BoardSelection.shared
        let original = selection.inspectingDayKey
        defer { selection.inspectingDayKey = original }
        selection.inspectingDayKey = "2026-09-15"
        let window = SystemPageHost.window(
            CalendarPage(todayKey: "2026-09-26", routines: [], checks: [], todos: []),
            container: container,
            scheme: .light,
            locale: "zh-Hans",
            size: NSSize(width: 1100, height: 720),
            embedded: true
        )
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let content = try #require(window.contentView)
        let anchor = try #require(findAnchor(in: content), "宽布局没有月份切换条")
        let frame = anchor.convert(anchor.bounds, to: content)
        #expect(frame.width > 40)
        #expect(frame.minX >= -1 && frame.maxX <= content.bounds.width + 1)
        #expect(frame.minY >= -1 && frame.maxY <= content.bounds.height + 1)
    }

    private func findAnchor(in view: NSView?) -> NSView? {
        guard let view else { return nil }
        if view.identifier?.rawValue == "period.bar" { return view }
        for child in view.subviews {
            if let found = findAnchor(in: child) { return found }
        }
        return nil
    }
}
