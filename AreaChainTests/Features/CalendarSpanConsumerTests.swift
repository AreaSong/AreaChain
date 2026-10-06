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
        #expect(host.window.firstResponder is NSWindow, "布局卸载输入后沿原生路径自然回到窗口")
        #expect(host.selectedKey == "2026-09-30")
        host.assertWeekProjection()
        try host.assertUnchanged()
        try await host.switchSpan(.month)
        try host.assertSpan(.month)
        #expect(try host.field().stringValue == "Synthetic unsubmitted draft")
        try host.assertUnchanged()
    }

    @Test(arguments: [false, true], [CGFloat(1000), CGFloat(480)])
    func bothEntrancesRestoreFirstKeyAndListDay(embedded: Bool, width: CGFloat) async throws {
        let narrow = width == 480
        let host = try CalendarSpanTestSupport(width: narrow && !embedded ? 420 : width,
            locale: narrow ? "zh-Hans" : "en", scheme: narrow ? .dark : .light,
            embedded: embedded, day: "2026-12-31")
        defer { host.close() }
        try await host.prepare()
        try await host.enterAndInspect(host.todos[0])
        for span in [CalendarSpan.week, .month] {
            let before = host.selectedKey
            host.recordRoute("before switch")
            try await host.switchSpan(span)
            try host.assertSpan(span)
            #expect(host.selectedKey == before)
            #expect(host.window.firstResponder is NSWindow)
            host.recordRoute("after switch, before first key")
            // 这必须是切换后的第一个日历按键；不能先用 Escape 或强制结束编辑恢复焦点。
            try await host.key(span == .week ? 124 : 123)
            #expect(host.selectedKey == (span == .week ? "2027-01-01" : "2026-12-31"))
            host.recordRoute("after first key")
            try await host.enterAndInspect(host.todos[span == .week ? 2 : 0])
        }
        // Return 仍从首项开始；下键沿清单顺序进入第二项，不能按网格跨七天。
        try await host.key(125)
        try await host.key(36, chars: "\r")
        #expect(WorkspaceNavigation.shared.selectedTaskID == host.todos[1].id)
        #expect(host.selectedKey == "2026-12-31")
        try await host.key(53, chars: "\u{1b}")
        try await host.key(125)
        #expect(host.selectedKey == "2027-01-07")
        try await host.key(126)
        #expect(host.selectedKey == "2026-12-31")
        try host.assertUnchanged()
    }

    @Test(arguments: [false, true])
    func reselectKeepsEachEntrancesOriginalBehavior(embedded: Bool) async throws {
        let host = try CalendarSpanTestSupport(embedded: embedded)
        defer { host.close() }
        try await host.prepare()
        for span in [CalendarSpan.month, .week] {
            try await host.switchSpan(span)
            try await host.enterAndInspect(host.todos[0])
            try await host.switchSpan(span)
            try await host.key(125)
            if embedded {
                #expect(host.selectedKey == "2026-10-07", "顶栏当前项仍显式恢复网格")
                try await host.key(126)
            } else {
                #expect(host.selectedKey == "2026-09-30", "分段同值写入不触发范围变化协调")
                try await host.key(36, chars: "\r")
                #expect(WorkspaceNavigation.shared.selectedTaskID == host.todos[1].id)
                try await host.key(53, chars: "\u{1b}")
            }
            #expect(host.selectedKey == "2026-09-30")
            try host.assertSpan(span)
        }
        try host.assertUnchanged()
    }

    @Test(arguments: [false, true])
    func emptyDateReturnKeepsGridWithoutInspection(embedded: Bool) async throws {
        let host = try CalendarSpanTestSupport(embedded: embedded)
        defer { host.close() }
        try await host.prepare()
        try await host.switchSpan(.week)
        try await host.key(124)
        try await host.key(124)
        #expect(host.selectedKey == "2026-10-02")
        for span in [CalendarSpan.month, .week] {
            try await host.switchSpan(span)
            if span == .month { #expect(WorkspaceNavigation.shared.inspectorTargetIDs.isEmpty) }
            let inspected = WorkspaceNavigation.shared.selectedTaskID
            try await host.key(36, chars: "\r")
            try await host.key(36, chars: "\r")
            #expect(WorkspaceNavigation.shared.selectedTaskID == inspected)
            try await host.key(124)
            #expect(host.selectedKey == "2026-10-03", "空日 Return 不能制造列表焦点")
            try await host.key(123)
        }
        try host.assertUnchanged()
    }

    @Test(arguments: [CGFloat(1000), CGFloat(480)])
    func headerEditorSurvivesSpanChangesAndKeepsComposition(width: CGFloat) async throws {
        let host = try CalendarSpanTestSupport(width: width, embedded: true)
        defer { host.close() }
        try await host.prepare()
        let capture = try host.field()
        host.window.makeFirstResponder(capture)
        let captureEditor = try #require(capture.currentEditor() as? NSTextView)
        captureEditor.insertText("Synthetic retained draft", replacementRange: captureEditor.selectedRange())
        let search = try #require(Native.elements(host.window.contentView).compactMap { $0 as? DaybookAppKitTextField }
            .first { $0.placeholderString == host.text("workspace.search.placeholder") && !$0.isHiddenOrHasHiddenAncestor })
        host.window.makeFirstResponder(search)
        let editor = try #require(search.currentEditor() as? NSTextView)
        editor.insertText("Synthetic native search", replacementRange: editor.selectedRange())
        try await SystemPageHost.settle(host.window)
        for span in [CalendarSpan.week, .month] {
            try await host.switchSpan(span)
            #expect(host.window.firstResponder === editor, "仍挂载的顶栏输入不能被业务 grid 抢焦点")
            let caret = editor.selectedRange().location
            try await host.key(123, chars: "\u{F702}")
            #expect(editor.selectedRange().location == caret - 1)
            editor.setMarkedText("拼音", selectedRange: NSRange(location: 2, length: 0),
                replacementRange: editor.selectedRange())
            #expect(editor.hasMarkedText())
            try await host.key(124, chars: "\u{F703}")
            try await host.key(36, chars: "\r")
            #expect(host.window.firstResponder === editor && host.selectedKey == "2026-09-30")
            #expect(WorkspaceNavigation.shared.selectedTaskID == nil)
            try host.assertUnchanged()
            host.recordRoute("active header editor")
        }
        #expect(try host.field().stringValue == "Synthetic retained draft")
    }

    @Test func otherWindowHiddenReopenedAndUnmountedDoNotConsumeKeys() async throws {
        let host = try CalendarSpanTestSupport()
        defer { host.close() }
        try await host.prepare()
        try await host.enterAndInspect(host.todos[0])
        try await host.switchSpan(.week)
        let other = host.fixture.window(Text("Synthetic other window"), size: NSSize(width: 280, height: 180))
        defer { SystemPageHost.release(other) }
        try await NativeSyntaxUI.prepareFocus(in: other)
        try await assertOtherWindowKeys(other, leave: host)
        host.window.orderOut(nil)
        try await assertOtherWindowKeys(other, leave: host)
        host.window.makeKeyAndOrderFront(nil)
        try await SystemPageHost.settle(host.window)
        try await host.key(124)
        #expect(host.selectedKey == "2026-10-01")
        try await host.enterAndInspect(host.todos[2])
        other.makeKeyAndOrderFront(nil)
        try await SystemPageHost.settle(other)
        try await assertOtherWindowKeys(other, leave: host)
        host.window.makeKeyAndOrderFront(nil)
        try await SystemPageHost.settle(host.window)
        try await host.switchSpan(.month)
        host.window.contentView = nil
        try await SystemPageHost.settle(host.window)
        let selected = host.selectedKey
        let inspected = WorkspaceNavigation.shared.selectedTaskID
        for code: UInt16 in [124, 125, 36] { try await host.key(code) }
        #expect(host.selectedKey == selected && WorkspaceNavigation.shared.selectedTaskID == inspected)
        try host.assertUnchanged()
    }

    private func assertOtherWindowKeys(_ other: NSWindow, leave host: CalendarSpanTestSupport) async throws {
        let selected = host.selectedKey
        let inspected = WorkspaceNavigation.shared.selectedTaskID
        try #require(other.isKeyWindow)
        for (code, chars) in [(UInt16(124), "\u{F703}"), (125, "\u{F701}"), (36, "\r")] {
            NSApp.postEvent(try PickerNativeTestSupport.key(code: code, chars: chars, in: other), atStart: false)
            try await SystemPageHost.settle(other)
            #expect(host.selectedKey == selected && WorkspaceNavigation.shared.selectedTaskID == inspected)
        }
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
        // 第十阶段 F 关闭旧缺陷：切换后第一次方向键必须生效，不能补 Escape。
        #expect(host.selectedKey == "2026-10-01")
        try host.assertSpan(.week)
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
        try Native.assertBounds([host.node("calendar.week.prev"), host.node("calendar.week.next")], in: host.window)
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
