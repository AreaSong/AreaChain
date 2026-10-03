import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@MainActor @Observable
final class HabitMonthProbe {
    var day = "2026-09-09"
    var disabled = false
}

private struct HabitMonthsHost: View {
    let f: HabitMonthTestSupport
    let probe: HabitMonthProbe
    var body: some View {
        HStack {
            HabitCheckMonthView(routine: f.routine, inspectDayKey: probe.day)
                .disabled(probe.disabled)
            HabitCheckMonthView(routine: f.other, inspectDayKey: "2026-09-08")
        }
        .padding(28)
    }
}

@Suite(.serialized) @MainActor
struct HabitMonthInteractionTests {
    typealias Native = SettingsButtonTestSupport

    @Test func navigationReselectExternalUpdatesAndIsolation() async throws {
        let f = try HabitMonthTestSupport()
        defer { f.cleanup() }
        let probe = HabitMonthProbe()
        let window = f.fixture.window(HabitMonthsHost(f: f, probe: probe), size: NSSize(width: 600, height: 260))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let host = "habit.month.\(f.routine.id)"
        for key in ["2026-09-07", "2026-09-08", "2026-09-04", "2026-09-09", "2026-09-01", "2026-09-12"] {
            try await Native.click(HabitMonthTestSupport.day(key, host: host, in: window), in: window)
            #expect(BoardSelection.shared.inspectingDayKey == key)
            #expect(WorkspaceNavigation.shared.selectedTaskID == f.routine.id)
            // 外部值未回写，控件不得形成乐观镜像。
            #expect(try selected("2026-09-09", host: host, window: window))
            try f.assertUnchanged()
        }
        WorkspaceNavigation.shared.closeInspector()
        try await Native.click(HabitMonthTestSupport.day(probe.day, host: host, in: window), in: window)
        #expect(WorkspaceNavigation.shared.isInspectorPresented)
        #expect(BoardSelection.shared.inspectingDayKey == probe.day)
        probe.day = "2026-09-07"
        try await SystemPageHost.settle(window)
        #expect(try selected(probe.day, host: host, window: window))
        probe.day = "2028-02-29"
        try await SystemPageHost.settle(window)
        #expect(try selected(probe.day, host: host, window: window))
        probe.disabled = true
        try await SystemPageHost.settle(window)
        try await Native.click(HabitMonthTestSupport.day(probe.day, host: host, in: window), in: window)
        #expect(BoardSelection.shared.inspectingDayKey == "2026-09-09")
        let otherHost = "habit.month.\(f.other.id)"
        #expect(try selected("2026-09-08", host: otherHost, window: window))
        try await Native.click(HabitMonthTestSupport.day("2026-09-07", host: otherHost, in: window), in: window)
        #expect(WorkspaceNavigation.shared.selectedTaskID == f.other.id)
        #expect(try selected(probe.day, host: host, window: window))
        try f.assertUnchanged()
    }

    @Test func paddingGapAndTransparentHitAreaMatchOriginal() async throws {
        let f = try HabitMonthTestSupport()
        defer { f.cleanup() }
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        let window = f.fixture.window(HabitCheckMonthView(routine: f.routine, inspectDayKey: "2026-09-09", calendar: calendar)
            .padding(28).frame(maxHeight: .infinity, alignment: .top), size: NSSize(width: 320, height: 260))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let host = "habit.month.\(f.routine.id)"
        let third = try Native.frame(HabitMonthTestSupport.day("2026-09-03", host: host, in: window), in: window)
        let fourth = try Native.frame(HabitMonthTestSupport.day("2026-09-04", host: host, in: window), in: window)
        let points = [NSPoint(x: 28 + third.width / 2, y: third.midY),
                      NSPoint(x: (third.maxX + fourth.minX) / 2, y: third.midY)]
        for point in points {
            try await MonthGridTestSupport.click(point, in: window)
            #expect(BoardSelection.shared.inspectingDayKey == "2026-09-09")
        }
        // 有底色日期的边缘可点；没有额外扩张透明日期或 padding 的命中范围。
        try await MonthGridTestSupport.click(NSPoint(x: third.minX + 1, y: third.midY), in: window)
        #expect(BoardSelection.shared.inspectingDayKey == "2026-09-03")
        try f.assertUnchanged()
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func realDrawerCheckDayAndClose(locale: String, scheme: ColorScheme) async throws {
        let f = try HabitMonthTestSupport()
        defer { f.cleanup() }
        for width in [CGFloat(280), 320] {
            let window = f.fixture.window(HabitDrawerTestHost(), locale: locale, scheme: scheme,
                                          size: NSSize(width: width, height: 900))
            defer { SystemPageHost.release(window) }
            try await NativeSyntaxUI.prepareFocus(in: window)
            try await SystemPageHost.settle(window)
            let host = "habit.month.\(f.routine.id)"
            let states = ["2026-09-08": "skipped", "2026-09-04": "pending",
                          "2026-09-01": "offday", "2026-09-09": "pending"]
            for key in states.keys.sorted() {
                try await Native.click(HabitMonthTestSupport.day(key, host: host, in: window), in: window)
                #expect(BoardSelection.shared.inspectingDayKey == key)
                #expect(try selected(key, host: host, window: window))
                let state = try #require(states[key])
                let statusKey = "drawer.streak.status.\(state)"
                let expected = L10n.string(String.LocalizationValue(statusKey),
                                           locale: Locale(identifier: locale))
                #expect(Native.elements(window.contentView).contains {
                    MenuButtonTestSupport.title($0) == expected
                        || Native.value($0, "accessibilityValue") as? String == expected
                })
                try f.assertUnchanged()
            }
            WorkspaceNavigation.shared.inspectTask(f.routine.id, dayKey: "2028-02-29")
            try await SystemPageHost.settle(window)
            #expect(try selected("2028-02-29", host: host, window: window))
            try Native.snapshot(window, name: "habitC-drawer-\(Int(width))-\(locale)-\(scheme)")
            WorkspaceNavigation.shared.inspectTask(f.routine.id, dayKey: "2026-09-09")
            try await SystemPageHost.settle(window)
            let close = try #require(Native.buttons(in: window).first {
                Native.value($0, "accessibilityHelp") as? String == L10n.string("drawer.close.help", locale: Locale(identifier: locale))
            })
            try await Native.click(close, in: window)
            #expect(!WorkspaceNavigation.shared.isInspectorPresented)
            try f.assertUnchanged()
        }
    }

    private func selected(_ day: String, host: String, window: NSWindow) throws -> Bool {
        let node = try HabitMonthTestSupport.day(day, host: host, in: window)
        return node.value(forKey: "accessibilitySelected") as? Bool == true
    }
}
