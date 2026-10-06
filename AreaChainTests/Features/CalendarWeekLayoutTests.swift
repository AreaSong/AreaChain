import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct CalendarWeekLayoutTests {
    typealias Native = SettingsButtonTestSupport

    @Test(arguments: ["en", "zh-Hans"])
    func minimumColumnRetainsTaskControls(locale: String) async throws {
        let f = try CalendarWeekTestSupport(populated: true)
        defer { f.cleanup() }
        f.days = [f.selected]
        f.todos[0].title = "Synthetic long calendar task title for measuring truncation"
        f.todos[0].isImportant = true
        f.todos[0].remindMinutes = 9 * 60 + 30
        let window = f.fixture.window(f.board().background(DaybookPalette.fill.page), locale: locale,
            size: .init(width: 280, height: 280))
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let nodes = Native.elements(window.contentView)
        let title = try #require(nodes.first { MenuButtonTestSupport.title($0) == f.todos[0].title })
        let more = try #require(nodes.first {
            MenuButtonTestSupport.title($0) == MenuButtonTestSupport.localized("row.more", locale)
        })
        let reminder = try #require(nodes.first {
            MenuButtonTestSupport.title($0).contains("9:30")
        })
        let frames = try [title, reminder, more].map { try Native.frame($0, in: window) }
        try Native.assertBounds([title, reminder, more], in: window)
        #expect(frames[0].width >= 40)
        #expect(frames[0].maxX < frames[1].minX && frames[1].maxX < frames[2].minX)
        print("Calendar10G controls \(locale) title/time/more=\(frames)")
        try Native.snapshot(window, name: "calendar10G-controls-\(locale)")
    }
}

extension CalendarWeekLayoutTests {
    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func viewportNavigationAndSelection(locale: String, scheme: ColorScheme) async throws {
        for embedded in [false, true] {
            let f = try CalendarSpanTestSupport(width: embedded ? 480 : 420, locale: locale,
                scheme: scheme, embedded: embedded, day: "2026-12-31")
            defer { f.close() }
            try await f.prepare()
            try await f.switchSpan(.week)
            try assertSelectedVisible(f)
            let outer = try horizontal(f.window)
            let nav = try navigationFrames(f.window)
            let vertical = columnScrolls(f.window)
            #expect(vertical.count == 7)
            #expect(vertical.allSatisfy { $0.enclosingScrollView === outer })
            #expect(outer.subviews.allSatisfy { !($0 is DaybookFloatingScrollerOverlay) })
            let offsets = vertical.map { $0.contentView.bounds.origin }
            for x in [CGFloat.zero, outer.documentView!.bounds.width - outer.contentSize.width] {
                let event = try #require(CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
                    wheel1: 0, wheel2: x == 0 ? 10000 : -10000, wheel3: 0))
                outer.scrollWheel(with: try #require(NSEvent(cgEvent: event)))
                try await SystemPageHost.settle(f.window)
                #expect(f.selectedKey == "2026-12-31", "手动横滚不写选择")
                #expect(vertical.map { $0.contentView.bounds.origin } == offsets)
                #expect(try navigationFrames(f.window) == nav)
                let day = x == 0 ? "2026-12-28" : "2027-01-03"
                print("Calendar10G manual target=\(day) offset=\(outer.contentView.bounds.origin)")
                try Native.assertBounds([f.node("calendar.week." + day)], in: f.window)
                try Native.snapshot(f.window, name: "calendar10G-\(locale)-\(scheme)-\(embedded)-\(day)")
            }
            try await f.key(124)
            #expect(f.selectedKey == "2027-01-01")
            try assertSelectedVisible(f)
            try await f.enterAndInspect(f.todos[2])
            #expect(BoardSelection.shared.inspectingDayKey == "2027-01-01")
            try await f.key(53, chars: "\u{1b}")
            for key in ["calendar.week.next", "calendar.week.prev", "calendar.week.next", "period.today"] {
                try await Native.click(f.node(key), in: f.window)
                try assertSelectedVisible(f)
            }
            for day in ["2024-02-29", "2027-01-01", "2026-09-30"] {
                BoardSelection.shared.inspectingDayKey = day
                try await SystemPageHost.settle(f.window)
                try assertSelectedVisible(f)
            }
            // 连续跨周只接受最后的业务日键，迟到的请求不能把视口带回旧周。
            for day in ["2026-12-28", "2028-02-29", "2027-01-03"] {
                BoardSelection.shared.inspectingDayKey = day
            }
            try await SystemPageHost.settle(f.window)
            try assertSelectedVisible(f)
            try await f.switchSpan(.month)
            try await f.switchSpan(.week)
            try assertSelectedVisible(f)
            #expect(columnScrolls(f.window).count == 7)
            try f.assertUnchanged()
        }
    }

    @Test func equalColumnsResizeAndIdentity() async throws {
        let f = try CalendarWeekTestSupport(populated: true)
        defer { f.cleanup() }
        let window = ScrollOwnershipEvidence.window(f.board().modelContainer(f.fixture.container)
            .environment(f.fixture.prefs), locale: "en", size: .init(width: 2100, height: 420))
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let outer = try horizontal(window)
        let columns = columnScrolls(window)
        let overlays = columns.map { $0.subviews.compactMap { $0 as? DaybookFloatingScrollerOverlay } }
        #expect(overlays.allSatisfy { $0.count == 1 })
        for width in [CGFloat(2100), 2009, 2007, 420, 2100] {
            window.setContentSize(.init(width: width, height: 420))
            try await SystemPageHost.settle(window)
            #expect(try horizontal(window) === outer)
            #expect(columnScrolls(window) == columns)
            #expect(columns.map { $0.subviews.compactMap { $0 as? DaybookFloatingScrollerOverlay } } == overlays)
            let frames = try CalendarWeekTestSupport.frames(f.days, in: window)
            #expect(frames.map(\.width).max()! - frames.map(\.width).min()! <= 1)
            #expect(frames.allSatisfy { $0.width >= 268 })
            let viewport = outer.convert(outer.bounds, to: window.contentView)
            #expect(viewport.minX >= 0 && viewport.maxX <= width)
            if width >= 2008 {
                #expect(abs(outer.documentView!.bounds.width - outer.contentSize.width) <= 1)
                try Native.assertBounds(f.days.map { try CalendarWeekTestSupport.header($0, in: window) }, in: window)
            }
            print("Calendar10G resize width=\(width) viewport=\(viewport) columns=\(frames)")
            try Native.snapshot(window, name: "calendar10G-resize-\(Int(width))")
        }
        try f.assertUnchanged()
    }

    private func assertSelectedVisible(_ f: CalendarSpanTestSupport) throws {
        let header = try f.node("calendar.week." + f.selectedKey)
        try Native.assertBounds([header], in: f.window)
        let outer = try horizontal(f.window)
        let frame = try Native.frame(header, in: f.window)
        let viewport = outer.convert(outer.bounds, to: nil)
        #expect(frame.minX >= viewport.minX && frame.maxX <= viewport.maxX)
        print("Calendar10G selected=\(f.selectedKey) header=\(frame) viewport=\(viewport)")
    }

    private func horizontal(_ window: NSWindow) throws -> NSScrollView {
        let scrolls = ScrollNativeEvidence.views(window).compactMap { $0 as? NSScrollView }
        let outer = scrolls.filter { $0.enclosingScrollView == nil }
        try #require(outer.count == 1)
        return outer[0]
    }

    private func columnScrolls(_ window: NSWindow) -> [NSScrollView] {
        ScrollNativeEvidence.views(window).compactMap { ($0 as? DaybookScrollerHostNSView)?.currentScrollView }
            .filter { $0.enclosingScrollView != nil }
    }

    private func navigationFrames(_ window: NSWindow) throws -> [CGRect] {
        ScrollNativeEvidence.views(window).filter { $0.identifier?.rawValue == "period.bar" }
            .map { view in
                let frame = view.convert(view.bounds, to: nil)
                #expect(frame.minX >= 0 && frame.maxX <= window.contentView!.bounds.width)
                return frame
            }
    }
}

extension CalendarWeekLayoutTests {
    @Test(arguments: ["en", "zh-Hans"])
    func realWorkspaceContentViewport(locale: String) async throws {
        let f = try SettingsButtonTestSupport(isolatedPreferences: true)
        let restore = CalendarSpanTestSupport.preserveState()
        defer { restore(); f.cleanup() }
        WorkspaceNavigation.shared.revealTab(.calendar)
        WorkspaceNavigation.shared.clearSearch()
        BoardSelection.shared.inspectingDayKey = "2026-12-31"
        let window = ScrollOwnershipEvidence.window(MainSplitWorkspaceView()
            .modelContainer(f.container).environment(f.prefs), locale: locale,
            size: .init(width: 780, height: 640))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let trigger = try #require(Native.elements(window.contentView).first {
            Native.value($0, "accessibilityIdentifier") as? String == "workspace.header.action.calendar.span"
        })
        let menu = try await MenuButtonTestSupport.openAndEscape(trigger, in: window)
        try MenuButtonTestSupport.dispatch(MenuButtonTestSupport.localized("calendar.span.week", locale), in: menu)
        try await SystemPageHost.settle(window)
        for width in [CGFloat(780), 1200, 2400, 780] {
            window.setContentSize(.init(width: width, height: 640))
            try await SystemPageHost.settle(window)
            let outer = try #require(columnScrolls(window).first?.enclosingScrollView)
            let viewport = outer.convert(outer.bounds, to: nil)
            let bars = try navigationFrames(window)
            #expect(bars.count == 1)
            #expect(abs(bars[0].width - viewport.width) <= 1)
            #expect(viewport.minX >= 190 && viewport.maxX <= width)
            let selected = try #require(Native.buttons(in: window).first {
                Native.value($0, "accessibilityIdentifier") as? String == "calendar.week.2026-12-31"
            })
            let frame = try Native.frame(selected, in: window)
            #expect(frame.minX >= viewport.minX && frame.maxX <= viewport.maxX)
            print("Calendar10G workspace window=\(width) period=\(bars) viewport=\(viewport) selected=\(frame)")
            try Native.snapshot(window, name: "calendar10G-workspace-\(locale)-\(Int(width))")
        }
        #expect(!f.container.mainContext.hasChanges)
    }
}
