import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DaybookWeekdayPickerTests {
    typealias Native = SettingsButtonTestSupport
    typealias Support = WeekdayPickerTestSupport

    @Test(arguments: [false, true])
    func masksLastDayAndCallbackCounts(allowsEmpty: Bool) async throws {
        let f = try Native()
        defer { f.cleanup() }
        let probe = WeekdayProbe()
        probe.allowsEmpty = allowsEmpty
        let window = f.window(WeekdayProbeHost(probe: probe), size: NSSize(width: 300, height: 150))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        for mask in [WeekdayMask.all, WeekdayMask.workdays, WeekdayMask.only(weekday: 2), 0, 128, 129, -1] {
            probe.mask = mask
            let count = probe.writes.count
            try await SystemPageHost.settle(window)
            try Support.expectMask(mask, allowsEmpty: allowsEmpty, in: window)
            #expect(probe.writes.count == count, "呈现和外部更新不规范化写回")
            try Support.press(Support.day(2, in: window))
            try await SystemPageHost.settle(window)
            #expect(probe.writes.count == count + 1)
            #expect(probe.mask == WeekdayMask.toggling(mask, weekday: 2, allowingEmpty: allowsEmpty))
        }
        probe.writes = []
        probe.mask = WeekdayMask.only(weekday: 2)
        try await SystemPageHost.settle(window)
        try await Native.click(Support.day(2, in: window), in: window)
        let last = allowsEmpty ? 0 : WeekdayMask.only(weekday: 2)
        #expect(probe.mask == last && probe.writes == [last])
        try Support.expectMask(last, allowsEmpty: allowsEmpty, in: window)
        try await Native.click(Support.day(allowsEmpty ? 5 : 2, in: window), in: window)
        #expect(probe.writes.count == 2, "未变化的最后一天也回调")
        #expect(probe.mask == WeekdayMask.only(weekday: allowsEmpty ? 5 : 2))
        try Support.press(Support.day(7, in: window))
        try await SystemPageHost.settle(window)
        #expect(probe.writes.count == 3)
        try Support.expectMask(probe.mask, allowsEmpty: allowsEmpty, in: window)
        try Support.press(Support.day(7, in: window))
        try await SystemPageHost.settle(window)
        #expect(probe.writes.count == 4)
        #expect(probe.mask == WeekdayMask.only(weekday: allowsEmpty ? 5 : 2))
    }

    @Test func rejectedDisabledAndLifecycleUpdates() async throws {
        let f = try Native()
        defer { f.cleanup() }
        let probe = WeekdayProbe()
        probe.accepts = false
        let window = f.window(WeekdayProbeHost(probe: probe), size: NSSize(width: 300, height: 150))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        for _ in 0..<2 { try await Native.click(Support.day(2, in: window), in: window) }
        #expect(probe.writes == [125, 125] && probe.mask == WeekdayMask.all)
        try Support.expectMask(WeekdayMask.all, in: window)
        probe.enabled = false
        try await SystemPageHost.settle(window)
        let disabled = try Support.day(2, in: window)
        #expect(disabled.value(forKey: "accessibilityEnabled") as? Bool == false)
        try await Native.click(disabled, in: window)
        try Support.press(disabled)
        try await SystemPageHost.settle(window)
        #expect(probe.writes.count == 2)
        probe.mask = WeekdayMask.workdays
        probe.shown = false
        try await SystemPageHost.settle(window)
        probe.shown = true
        try await SystemPageHost.settle(window)
        try Support.expectMask(WeekdayMask.workdays, in: window)
        #expect(probe.writes.count == 2)
        SystemPageHost.release(window)
        #expect(probe.writes.count == 2)
    }

    @Test func environmentOrderAndIndependentInstances() async throws {
        let f = try Native()
        defer { f.cleanup() }
        let probe = WeekdayProbe()
        probe.multiple = true
        let window = f.window(WeekdayProbeHost(probe: probe), size: NSSize(width: 300, height: 150))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        for (locale, first) in [("en", 1), ("zh-Hans", 2), ("en", 2)] {
            probe.locale = locale
            probe.firstWeekday = first
            try await SystemPageHost.settle(window)
            let nodes = try (1...7).map { try Support.day($0, locale: locale, host: "weekday.first", in: window) }
            let ordered = try nodes.sorted { try Native.frame($0, in: window).minX < Native.frame($1, in: window).minX }
            let labels = ordered.compactMap { Native.value($0, "accessibilityLabel") as? String }
            #expect(labels == WeekdayMask.orderedWeekdays(calendar: probe.calendar).map {
                WeekdayMask.accessibilityName($0, locale: Locale(identifier: locale), calendar: probe.calendar)
            })
            #expect(probe.writes.isEmpty)
        }
        try await Native.click(Support.day(3, host: "weekday.first", in: window), in: window)
        try await Native.click(Support.day(5, host: "weekday.second", in: window), in: window)
        #expect(probe.mask == WeekdayMask.toggling(WeekdayMask.all, weekday: 3))
        #expect(probe.other == WeekdayMask.only(weekday: 5))
        #expect(probe.writes.count == 1 && probe.otherWrites.count == 1)
        #expect(Support.copyContains("Synthetic weekdays", in: window))
    }
}

@MainActor @Observable
final class WeekdayProbe {
    var mask = WeekdayMask.all
    var other = 0
    var writes: [Int] = []
    var otherWrites: [Int] = []
    var allowsEmpty = false
    var accepts = true
    var enabled = true
    var shown = true
    var multiple = false
    var locale = "en"
    var firstWeekday = 1
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = firstWeekday
        return calendar
    }
}

struct WeekdayProbeHost: View {
    @Bindable var probe: WeekdayProbe

    var body: some View {
        VStack {
            if probe.shown {
                DaybookWeekdayPicker(selection: probe.mask, onUpdateSelection: {
                    probe.writes.append($0)
                    if probe.accepts { probe.mask = $0 }
                }, allowsEmpty: probe.allowsEmpty, accessibilityTitle: Text(verbatim: "Synthetic weekdays"))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("weekday.first")
            }
            if probe.multiple {
                DaybookWeekdayPicker(selection: probe.other, onUpdateSelection: {
                    probe.otherWrites.append($0)
                    probe.other = $0
                }, allowsEmpty: true, accessibilityTitle: Text(verbatim: "Independent weekdays"))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("weekday.second")
            }
        }
        .disabled(!probe.enabled)
        .environment(\.locale, Locale(identifier: probe.locale))
        .environment(\.calendar, probe.calendar)
    }
}
