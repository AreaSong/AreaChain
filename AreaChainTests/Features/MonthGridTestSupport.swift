import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@MainActor @Observable
final class MonthGridProbe {
    var dates = CalendarMonthGridDates(monthKey: "2026-08-01", todayKey: "2026-08-18", selectedKey: "2026-08-19")
    var counts = ["2026-08-18": 3, "2026-08-19": 999999]
    var selections: [String] = []
    var drops: [(UUID, String)] = []
    var reject = false
    var disabled = false
    var allowsDrop = true
    var calendar = Calendar(identifier: .gregorian)

    func select(_ key: String) {
        selections.append(key)
        if !reject { dates.selectedKey = key }
    }
}

struct MonthGridProbeView: View {
    var probe: MonthGridProbe
    var compact = false
    var body: some View {
        CalendarMonthGrid(dates: probe.dates, counts: probe.counts, isCompact: compact,
                          onSelect: probe.select,
                          onDropTodo: probe.allowsDrop ? { probe.drops.append(($0, $1)) } : nil)
            .disabled(probe.disabled)
            .environment(\.calendar, probe.calendar)
            .padding(20)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(DaybookPalette.fill.page)
    }
}

@MainActor
enum MonthGridTestSupport {
    typealias Native = SettingsButtonTestSupport

    static func belongsToGrid(_ node: NSObject) -> Bool {
        var current: NSObject? = node
        var visited = Set<ObjectIdentifier>()
        while let item = current, visited.insert(ObjectIdentifier(item)).inserted {
            if Native.value(item, "accessibilityIdentifier") as? String == "calendar.month.grid" { return true }
            current = Native.value(item, "accessibilityParent") as? NSObject
        }
        return false
    }

    static func day(_ key: String, in window: NSWindow) throws -> NSObject {
        let matches = Native.buttons(in: window).filter {
            Native.value($0, "accessibilityIdentifier") as? String == "daybook.date.\(key)" && belongsToGrid($0)
        }
        try #require(matches.count == 1, "指定月网格中的日键必须唯一")
        return try #require(matches.first)
    }

    static func click(_ point: NSPoint, in window: NSWindow) async throws {
        try #require(window.isKeyWindow)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            NSApp.postEvent(try MenuButtonTestSupport.mouse(type, at: point, in: window), atStart: false)
        }
        try await SystemPageHost.settle(window)
    }
}
