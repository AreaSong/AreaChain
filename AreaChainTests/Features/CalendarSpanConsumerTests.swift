import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct CalendarSpanConsumerTests {
    typealias Native = SettingsButtonTestSupport

    @Test(arguments: [CGFloat(1000), CGFloat(420)])
    func roundTripPreservesDateDraftAndRecords(width: CGFloat) async throws {
        let host = try CalendarSpanTestSupport(width: width)
        defer { host.close() }
        try await host.prepare()
        try host.assertSpan(.month)
        let group = try host.node("calendar.span")
        if Native.value(try host.node("calendar.span.month"), "accessibilityRole") as? String == "AXRadioButton" {
            #expect(Native.elements(host.window.contentView).contains {
                Native.value($0, "accessibilityValue") as? String == host.text("calendar.span")
            })
        } else {
            #expect(MenuButtonTestSupport.title(group) == host.text("calendar.span"))
        }
        #expect(try Native.frame(group, in: host.window).width <= 220)
        let field = try host.field()
        host.window.makeFirstResponder(field)
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.insertText("Synthetic unsubmitted draft", replacementRange: editor.selectedRange())
        try await SystemPageHost.settle(host.window)
        try await host.switchSpan(.week)
        try host.assertSpan(.week)
        #expect(host.selectedKey == "2026-09-30")
        host.assertWeekProjection()
        try host.assertUnchanged()
        try await host.switchSpan(.month)
        try host.assertSpan(.month)
        #expect(try host.field().stringValue == "Synthetic unsubmitted draft")
        try host.assertUnchanged()
    }

    @Test func windowGridAndListKeyboardPaths() async throws {
        let host = try CalendarSpanTestSupport()
        defer { host.close() }
        try await host.prepare()
        host.window.makeFirstResponder(nil)
        try await host.key(124)
        #expect(host.selectedKey == "2026-10-01")
        try await host.key(123)
        try await host.key(126)
        #expect(host.selectedKey == "2026-09-23")
        try await host.key(125)
        #expect(host.selectedKey == "2026-09-30")
        try await host.key(36, chars: "\r")
        try await host.key(36, chars: "\r")
        #expect(WorkspaceNavigation.shared.selectedTaskID == host.todos[0].id)
        try await host.switchSpan(.week)
        #expect(host.window.firstResponder is NSWindow)
        try await host.key(124)
        withKnownIssue("F 原生与迁移同样失败：列表切周未恢复网格，见工程手册第四阶段 F") {
            #expect(host.selectedKey == "2026-10-01")
        }
        try host.assertSpan(.week)
        // 旧列表仍能按 Escape 返回网格；不通过强设业务状态掩盖上面的已知缺口。
        try await host.key(53, chars: "\u{1b}")
        try await host.key(124)
        #expect(host.selectedKey == "2026-10-01")
        try await host.key(36, chars: "\r")
        try await host.key(36, chars: "\r")
        #expect(WorkspaceNavigation.shared.selectedTaskID == host.todos[2].id)
        try await host.key(53, chars: "\u{1b}")
        try await host.key(123)
        #expect(host.selectedKey == "2026-09-30")
        try host.assertUnchanged()
    }

    @Test func focusedInputKeepsArrowsAndSubmit() async throws {
        let host = try CalendarSpanTestSupport()
        defer { host.close() }
        try await host.prepare()
        try await host.switchSpan(.week)
        try await host.switchSpan(.month)
        let field = try host.field()
        host.window.makeFirstResponder(field)
        let editor = try #require(field.currentEditor() as? NSTextView)
        editor.insertText("Synthetic explicit submit", replacementRange: editor.selectedRange())
        try await SystemPageHost.settle(host.window)
        let caret = editor.selectedRange().location
        try await host.key(123, chars: "\u{F702}")
        #expect(host.selectedKey == "2026-09-30" && editor.selectedRange().location == caret - 1)
        #expect(host.window.firstResponder === editor)
        try host.assertSpan(.month)
        try host.assertUnchanged()
        try await host.key(36, chars: "\r")
        #expect(try host.context.fetchCount(FetchDescriptor<TodoItem>()) == 5)
        #expect(try host.field().stringValue.isEmpty)
        #expect(host.selectedKey == "2026-09-30")
        try host.assertSpan(.month)
    }

    @Test func segmentClickLeavesDateKeysWithWindow() async throws {
        let host = try CalendarSpanTestSupport()
        defer { host.close() }
        try await host.prepare()
        host.window.makeFirstResponder(nil)
        try await host.switchSpan(.month)
        // 记录真实 firstResponder 后再验证窗口事件；不从 segmented 或 Button 类型推断方向键。
        #expect(host.window.firstResponder is NSWindow)
        try await host.key(124)
        #expect(host.selectedKey == "2026-10-01")
        try host.assertSpan(.month)
        try await host.key(123)
        #expect(host.selectedKey == "2026-09-30")
        try host.assertUnchanged()
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func periodNavigationAndLayout(locale: String, scheme: ColorScheme) async throws {
        for width in [CGFloat(1000), CGFloat(420)] {
            try await checkPeriodLayout(width: width, locale: locale, scheme: scheme)
        }
    }

    private func checkPeriodLayout(width: CGFloat, locale: String, scheme: ColorScheme) async throws {
        let host = try CalendarSpanTestSupport(width: width, locale: locale, scheme: scheme)
        defer { host.close() }
        try await host.prepare()
        try host.assertSpan(.month)
        try Native.snapshot(host.window, name: "calendar-month-\(locale)-\(scheme)-\(Int(width))")
        try await Native.click(host.node("calendar.next"), in: host.window)
        #expect(host.selectedKey == "2026-10-30")
        try await Native.click(host.node("calendar.prev"), in: host.window)
        #expect(host.selectedKey == "2026-09-30")
        try await host.switchSpan(.week)
        try host.assertSpan(.week)
        host.assertWeekProjection()
        try Native.snapshot(host.window, name: "calendar-week-\(locale)-\(scheme)-\(Int(width))")
        if width == 420 {
            let next = try #require(Native.buttons(in: host.window).first {
                MenuButtonTestSupport.title($0) == host.text("calendar.week.next")
            })
            let frame = try Native.frame(next, in: host.window)
            withKnownIssue("F 原生与迁移同样失败：420pt 周布局右侧越界，见工程手册第四阶段 F") {
                #expect(frame.maxX <= width)
            }
            try host.assertUnchanged()
            return
        }
        try await Native.click(host.node("calendar.week.next"), in: host.window)
        #expect(host.selectedKey == "2026-10-07")
        try await Native.click(host.node("calendar.week.prev"), in: host.window)
        #expect(host.selectedKey == "2026-09-30")
        try host.assertUnchanged()
    }

    @Test(arguments: [CGFloat(1000), CGFloat(480)])
    func embeddedHeaderKeepsMenuAndInspectorProjection(width: CGFloat) async throws {
        let host = try CalendarSpanTestSupport(width: width, embedded: true)
        defer { host.close() }
        try await host.prepare()
        #expect(WorkspaceNavigation.shared.inspectorTargetIDs == Set(host.todos.prefix(2).map(\.id)))
        #expect(host.nodes().allSatisfy { Native.value($0, "accessibilityIdentifier") as? String != "calendar.span" })
        for span in [CalendarSpan.week, .month] {
            let trigger = width < 520 ? "workspace.header.more" : "workspace.header.action.calendar.span"
            let menu = try await MenuButtonTestSupport.openAndEscape(host.node(trigger), in: host.window)
            let spanMenu = width < 520 ? try #require(menu.items.first { $0.submenu != nil }?.submenu) : menu
            #expect(spanMenu.items.filter { !$0.isHidden && !$0.isSeparatorItem }.map(\.title)
                == [host.text("calendar.span.month"), host.text("calendar.span.week")])
            try MenuButtonTestSupport.dispatch(host.text("calendar.span." + span.rawValue), in: spanMenu)
            try await SystemPageHost.settle(host.window)
            #expect(host.selectedKey == "2026-09-30")
            let expected = span == .week ? host.todos.prefix(3) : host.todos.prefix(2)
            #expect(WorkspaceNavigation.shared.inspectorTargetIDs == Set(expected.map(\.id)))
            let action = try #require(host.probe.content.actions.first)
            #expect(action.children.filter(\.isActive).map(\.id) == ["calendar." + span.rawValue])
        }
        try host.assertUnchanged()
    }

    @Test(arguments: ["2026-11-01", "2026-12-31", "2027-02-28"])
    func crossingMonthWeeksKeepSelectedDate(day: String) async throws {
        let host = try CalendarSpanTestSupport(day: day)
        defer { host.close() }
        try await host.prepare()
        try await host.switchSpan(.week)
        host.assertWeekProjection()
        #expect(host.selectedKey == day)
        try host.assertSpan(.week)
        try await host.switchSpan(.month)
        #expect(host.selectedKey == day)
        try host.assertSpan(.month)
        try host.assertUnchanged()
    }
}
