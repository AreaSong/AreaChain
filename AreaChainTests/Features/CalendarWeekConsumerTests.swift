import AppKit
import SwiftUI
import Testing
@testable import AreaChain

private struct CalendarWeekProbeView: View {
    var probe: CalendarWeekTestSupport
    var id = "week.test"
    var body: some View { probe.board(id) }
}

@Suite(.serialized) @MainActor
struct CalendarWeekConsumerTests {
    typealias Native = SettingsButtonTestSupport
    typealias Support = CalendarWeekTestSupport

    @Test func reselectRejectExternalDisabledAndInstances() async throws {
        let f = try Support(populated: true)
        let other = try Support()
        defer { other.cleanup(); f.cleanup() }
        let window = f.fixture.window(VStack {
            CalendarWeekProbeView(probe: f)
            CalendarWeekProbeView(probe: other, id: "week.other")
        }.padding(20), size: NSSize(width: 1100, height: 500))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let next = "2026-10-01"
        for _ in 0..<2 { try await Native.click(Support.header(next, in: window), in: window) }
        #expect(f.selections == [next, next] && other.selections.isEmpty)
        #expect(f.selected == next && other.selected == "2026-09-30")
        f.acceptsSelection = false
        try await Native.click(Support.header("2026-09-30", in: window), in: window)
        #expect(f.selected == next)
        #expect(try Support.header(next, in: window).value(forKey: "accessibilitySelected") as? Bool == true)
        #expect(try Support.header("2026-09-30", in: window).value(forKey: "accessibilitySelected") as? Bool == false)
        let count = f.selections.count
        f.disabled = true
        try await SystemPageHost.settle(window)
        try await Native.click(Support.header(next, in: window), in: window)
        #expect(f.selections.count == count)
        f.days = DayKey.weekKeys(containing: "2028-02-29")
        f.selected = "2028-02-29"
        try await SystemPageHost.settle(window)
        #expect(try Support.header(f.selected, in: window).value(forKey: "accessibilitySelected") as? Bool == true)
        #expect(f.selections.count == count)
        try f.assertUnchanged()
        try other.assertUnchanged()
    }

    @Test(arguments: [1, 2])
    func civilWeeksAndInputOrder(firstWeekday: Int) async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = firstWeekday
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        for day in ["2026-09-30", "2026-12-31", "2024-02-29"] {
            let f = try Support(day: day, calendar: calendar)
            defer { f.cleanup() }
            // 顺序是外部输入契约；刻意逆序证明公共呈现没有重新生成或排序一周。
            f.days.reverse()
            let window = f.fixture.window(CalendarWeekProbeView(probe: f).environment(\.calendar, calendar)
                .padding(20), size: NSSize(width: 1100, height: 300))
            defer { SystemPageHost.release(window) }
            try await SystemPageHost.settle(window)
            let frames = try Support.frames(f.days, in: window)
            #expect(frames.map(\.minX) == frames.map(\.minX).sorted())
            #expect(f.days.contains(day))
            #expect(Native.buttons(in: window).filter {
                (Native.value($0, "accessibilityIdentifier") as? String)?.hasPrefix("calendar.week.") == true
            }.count == 7)
            try f.assertUnchanged()
        }
    }

    @Test func listClickRetainsOwningDay() async throws {
        let f = try Support(populated: true)
        defer { f.cleanup() }
        let window = f.fixture.window(CalendarWeekProbeView(probe: f).padding(20),
                                      size: NSSize(width: 1400, height: 360))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let node = try #require(Native.elements(window.contentView).first {
            MenuButtonTestSupport.title($0) == "Synthetic week item"
                || Native.value($0, "accessibilityValue") as? String == "Synthetic week item"
        })
        try await Native.click(node, in: window)
        #expect(f.selections.isEmpty)
        #expect(f.inspections.count == 1)
        #expect(f.inspections.first?.0 == f.todos[0].id && f.inspections.first?.1 == "2026-09-30")
        try f.assertUnchanged()
    }

    @Test func productionPageSelectionInspectionAndDraft() async throws {
        let f = try CalendarSpanTestSupport(day: "2026-12-31")
        defer { f.close() }
        try await f.prepare()
        let field = try f.field()
        f.window.makeFirstResponder(field)
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.insertText("Synthetic week draft", replacementRange: editor.selectedRange())
        try await f.switchSpan(.week)
        for _ in 0..<2 { try await Native.click(f.node("calendar.week.2027-01-01"), in: f.window) }
        #expect(f.selectedKey == "2027-01-01")
        try await f.key(36, chars: "\r")
        try await f.key(36, chars: "\r")
        #expect(WorkspaceNavigation.shared.selectedTaskID == f.todos[2].id)
        #expect(BoardSelection.shared.inspectingDayKey == "2027-01-01")
        try await f.key(53, chars: "\u{1b}")
        try await f.key(123)
        #expect(f.selectedKey == "2026-12-31")
        try await Native.click(f.node("calendar.week.next"), in: f.window)
        #expect(f.selectedKey == "2027-01-07")
        try await Native.click(f.node("calendar.week.prev"), in: f.window)
        #expect(f.selectedKey == "2026-12-31")
        BoardSelection.shared.inspectingDayKey = "2028-02-29"
        try await SystemPageHost.settle(f.window)
        _ = try f.node("calendar.week.2028-02-29")
        try await f.switchSpan(.month)
        #expect(try f.field().stringValue == "Synthetic week draft")
        try f.assertUnchanged()
    }
}
