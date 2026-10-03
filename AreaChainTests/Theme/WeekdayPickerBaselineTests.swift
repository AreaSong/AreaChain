import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct WeekdayPickerBaselineTests {
    typealias Native = SettingsButtonTestSupport
    typealias Support = WeekdayPickerTestSupport

    @Test(arguments: ["en", "zh-Hans"], [false, true])
    func productionGeometry(locale: String, showsTitle: Bool) async throws {
        let f = try Native()
        defer { f.cleanup() }
        var callbacks: [Int] = []
        let window = f.window(TaskDetailWeekdayPicker(resolvedMask: WeekdayMask.workdays,
            onUpdateMask: { callbacks.append($0) }, showsTitle: showsTitle,
            accessibilityTitle: "residents.days").padding(20).background(DaybookPalette.fill.page),
            locale: locale, size: NSSize(width: 300, height: 110))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let nodes = try Support.days(locale: locale, in: window)
        let frames = try nodes.map { try Native.frame($0, in: window) }.sorted { $0.minX < $1.minX }
        try Native.assertBounds(nodes, in: window)
        #expect(frames.count == 7)
        #expect(Set(frames.map(\.width)) == [25])
        #expect(Set(frames.map(\.height)) == [25])
        #expect(abs(frames[1].minX - frames[0].maxX - 4) < 0.01)
        try Support.expectMask(WeekdayMask.workdays, locale: locale, in: window)
        #expect(callbacks.isEmpty)
        let heading = L10n.string("drawer.weekdays.title", locale: Locale(identifier: locale))
        #expect(Support.copyContains(heading, in: window) == showsTitle)
        let group = L10n.string("residents.days", locale: Locale(identifier: locale))
        #expect(Support.copyContains(group, in: window))
        print("WeekdayD geometry locale=\(locale) title=\(showsTitle) frames=\(frames)")
        try Native.snapshot(window, name: "weekdayD-baseline-\(locale)-\(showsTitle)")
    }

    @Test func productionHitAndPressedFeedback() async throws {
        let f = try Native()
        defer { f.cleanup() }
        var callbacks = 0
        let window = f.window(TaskDetailWeekdayPicker(resolvedMask: WeekdayMask.all,
            onUpdateMask: { _ in callbacks += 1 }, showsTitle: false).padding(20)
            .background(DaybookPalette.fill.page), size: NSSize(width: 300, height: 100))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let frame = try Native.frame(Support.day(2, in: window), in: window)
        let before = try Support.bitmap(window)
        let center = NSPoint(x: frame.midX, y: frame.midY)
        try await Support.mouse(center, type: .leftMouseDown, in: window)
        #expect(callbacks == 0)
        let pressedDiffers = before != (try Support.bitmap(window))
        #expect(pressedDiffers)
        try await Support.mouse(center, type: .leftMouseUp, in: window)
        #expect(callbacks == 1)
        var hits: [Bool] = []
        for point in [NSPoint(x: frame.minX + 0.5, y: frame.midY),
                      NSPoint(x: frame.minX + 0.5, y: frame.minY + 0.5),
                      NSPoint(x: frame.maxX + 2, y: frame.midY)] {
            let count = callbacks
            try await Support.mouse(point, type: .leftMouseDown, in: window)
            try await Support.mouse(point, type: .leftMouseUp, in: window)
            hits.append(callbacks > count)
        }
        print("WeekdayD plain pressedDiffers=\(pressedDiffers) edge/corner/gap=\(hits)")
        #expect(hits == [true, false, false])
    }
}
