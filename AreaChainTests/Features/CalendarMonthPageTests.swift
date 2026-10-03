import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct CalendarMonthPageTests {
    typealias Native = SettingsButtonTestSupport

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func productionMonthNavigationAndCounts(locale: String, scheme: ColorScheme) async throws {
        for (width, height) in [(CGFloat(1100), CGFloat(760)), (480, 760), (480, 520)] {
            let f = try CalendarSpanTestSupport(width: width, locale: locale, scheme: scheme, embedded: true,
                                               day: "2026-12-31", height: height)
            defer { f.close() }
            try await f.prepare()
            let selected = try f.node("daybook.date.2026-12-31")
            #expect(MonthGridTestSupport.belongsToGrid(selected))
            let rect = try Native.frame(selected, in: f.window)
            #expect(rect.height == (height == 520 ? 35 : 58))
            let hint = Native.value(selected, "accessibilityHelp") as? String
            #expect(hint == L10n.string("a11y.calendar.remaining \(2)", locale: Locale(identifier: locale)))
            try await Native.click(f.node("daybook.date.2026-12-30"), in: f.window)
            #expect(f.selectedKey == "2026-12-30")
            try f.assertUnchanged()
            try await Native.click(f.node("calendar.today"), in: f.window)
            #expect(f.selectedKey == "2026-12-31")
            try await Native.click(f.node("calendar.next"), in: f.window)
            #expect(f.selectedKey == "2027-01-31")
            try await Native.click(f.node("calendar.prev"), in: f.window)
            #expect(f.selectedKey == "2026-12-31")
            BoardSelection.shared.inspectingDayKey = "2028-02-29"
            try await SystemPageHost.settle(f.window)
            #expect(MonthGridTestSupport.belongsToGrid(try f.node("daybook.date.2028-02-29")))
            try f.assertUnchanged()
            try Native.snapshot(f.window, name: "monthB-page-\(Int(width))-\(Int(height))-\(locale)-\(scheme)")
        }
    }
}
