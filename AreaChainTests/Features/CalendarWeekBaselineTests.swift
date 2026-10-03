import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct CalendarWeekBaselineTests {
    typealias Native = SettingsButtonTestSupport
    typealias Support = CalendarWeekTestSupport

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func productionBoardGeometry(locale: String, scheme: ColorScheme) async throws {
        for width in [CGFloat(1100), 420] {
            for populated in [false, true] {
                let f = try Support(populated: populated)
                defer { f.cleanup() }
                let window = f.fixture.window(f.board().padding(20).background(DaybookPalette.fill.page),
                    locale: locale, scheme: scheme, size: NSSize(width: width, height: 360))
                defer { SystemPageHost.release(window) }
                try await SystemPageHost.settle(window)
                let frames = try Support.frames(f.days, in: window)
                #expect(frames.count == 7)
                #expect(frames.map(\.minX) == frames.map(\.minX).sorted())
                #expect(Set(frames.map(\.height)).count == 1)
                #expect(frames.allSatisfy { $0.height == 41 })
                print("WeekE board \(locale) \(scheme) width=\(width) populated=\(populated) frames=\(frames)")
                try Native.snapshot(window, name: "weekE-board-\(locale)-\(scheme)-\(Int(width))-\(populated)")
                try f.assertUnchanged()
            }
        }
    }

    @Test func productionHeaderHitAndFocus() async throws {
        let f = try Support(populated: true)
        defer { f.cleanup() }
        f.acceptsSelection = false
        let window = f.fixture.window(f.board().padding(20).background(DaybookPalette.fill.page),
                                      size: NSSize(width: 1100, height: 360))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await SystemPageHost.settle(window)
        let frame = try Native.frame(Support.header(f.selected, in: window), in: window)
        let before = try WeekdayPickerTestSupport.bitmap(window)
        let responder = window.firstResponder
        let center = NSPoint(x: frame.midX, y: frame.midY)
        try await WeekdayPickerTestSupport.mouse(center, type: .leftMouseDown, in: window)
        #expect(f.selections.isEmpty)
        let pressed = try WeekdayPickerTestSupport.bitmap(window)
        #expect(pressed != before)
        try await WeekdayPickerTestSupport.mouse(center, type: .leftMouseUp, in: window)
        #expect(f.selections == [f.selected])
        #expect(window.firstResponder === responder)
        var hits: [Bool] = []
        for point in [NSPoint(x: frame.minX + 1, y: frame.midY),
                      NSPoint(x: frame.maxX - 1, y: frame.midY),
                      NSPoint(x: frame.maxX + 4, y: frame.midY),
                      NSPoint(x: frame.midX, y: frame.minY - 4),
                      NSPoint(x: frame.midX, y: 30)] {
            let count = f.selections.count
            try await WeekdayPickerTestSupport.mouse(point, type: .leftMouseDown, in: window)
            try await WeekdayPickerTestSupport.mouse(point, type: .leftMouseUp, in: window)
            hits.append(f.selections.count > count)
        }
        print("WeekE quiet height=\(frame.height) edge/gap/list/blank hits=\(hits)")
        #expect(hits == [true, true, false, false, false])
        try f.assertUnchanged()
    }
}
