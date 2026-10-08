import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DaybookWeekdayPickerLayoutTests {
    typealias Native = SettingsButtonTestSupport
    typealias Support = WeekdayPickerTestSupport

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func frozenPixelsGeometryAndTitle(locale: String, scheme: ColorScheme) async throws {
        let f = try Native()
        defer { f.cleanup() }
        for (mask, allowsEmpty) in [(0, true), (2, false), (WeekdayMask.workdays, false), (WeekdayMask.all, false)] {
            for showsTitle in [false, true] {
                let old = f.window(WeekdayPickerBaseline(resolvedMask: mask, onUpdateMask: { _ in },
                    showsTitle: showsTitle, allowsEmpty: allowsEmpty).padding(20).background(DaybookPalette.fill.page),
                    locale: locale, scheme: scheme, size: NSSize(width: 300, height: 110))
                defer { SystemPageHost.release(old) }
                try await SystemPageHost.settle(old)
                let pixels = try Support.bitmap(old)
                let frames = try Support.days(locale: locale, in: old).map { try Native.frame($0, in: old) }
                let window = f.window(TaskDetailWeekdayPicker(resolvedMask: mask, onUpdateMask: { _ in },
                    showsTitle: showsTitle, allowsEmpty: allowsEmpty).padding(20).background(DaybookPalette.fill.page),
                    locale: locale, scheme: scheme, size: NSSize(width: 300, height: 110))
                defer { SystemPageHost.release(window) }
                try await SystemPageHost.settle(window)
                #expect(pixels == (try Support.bitmap(window)), "字重、选中/未选中颜色和标题需逐像素等价")
                #expect(frames == (try Support.days(locale: locale, in: window).map { try Native.frame($0, in: window) }))
                try Support.expectMask(mask, allowsEmpty: allowsEmpty, locale: locale, in: window)
                if showsTitle {
                    let title = L10n.string("drawer.weekdays.title", locale: Locale(identifier: locale))
                    let node = try #require(Native.elements(window.contentView).first {
                        Native.value($0, "accessibilityRole") as? String == "AXStaticText"
                            && Native.value($0, "accessibilityValue") as? String == title
                    })
                    #expect(abs((try Native.frame(node, in: window).minY) - frames[0].maxY - 6) < 0.01)
                }
            }
        }
    }

    @Test func originalKeyboardPath() async throws {
        let f = try Native()
        defer { f.cleanup() }
        var traces: [[Int]] = []
        for baseline in [true, false] {
            var callbacks: [Int] = []
            let window = f.window(Group {
                if baseline {
                    WeekdayPickerBaseline(resolvedMask: WeekdayMask.all, onUpdateMask: { callbacks.append($0) })
                } else {
                    TaskDetailWeekdayPicker(resolvedMask: WeekdayMask.all, onUpdateMask: { callbacks.append($0) })
                }
            }, size: NSSize(width: 300, height: 110))
            defer { SystemPageHost.release(window) }
            try await NativeSyntaxUI.prepareFocus(in: window)
            try await SystemPageHost.settle(window)
            window.makeFirstResponder(nil)
            try await TimePickerNativeTestSupport.key(48, "\t", in: window)
            try await TimePickerNativeTestSupport.key(49, " ", in: window)
            traces.append(callbacks)
        }
        #expect(traces[0] == traces[1])
        print("WeekdayD keyboard old/new callbacks=\(traces); system keyboard preference unchanged")
    }

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func isolatedSamples(locale: String, scheme: ColorScheme) async throws {
        let f = try Native()
        defer { f.cleanup() }
        let window = f.window(DaybookWeekdaySamples().padding(16).background(DaybookPalette.fill.page), locale: locale, scheme: scheme,
                              size: NSSize(width: 320, height: 300))
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        #expect(Native.buttons(in: window).count == 28)
        try Native.assertBounds(Native.buttons(in: window), in: window)
        try Native.snapshot(window, name: "weekdayD-samples-\(locale)-\(scheme)")
    }
}
