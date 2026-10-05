import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

/// 直接挂载生产 TasksPage；只持有合成输入，不镜像页面的昨日展开状态。
@Observable @MainActor
final class YesterdayCardFixture {
    let support: SettingsButtonTestSupport
    let today = "2026-10-04"
    let yesterday = "2026-10-03"
    var todos: [TodoItem] = []
    var routines: [DailyRoutine] = []
    var checks: [RoutineCheck] = []
    var inspected: [UUID] = []
    var focused: UUID?

    init(centered: Bool, count: Int = 1) throws {
        support = try SettingsButtonTestSupport(isolatedPreferences: true)
        for index in 0..<count {
            let todo = TodoItem(title: "Synthetic yesterday \(index)", dayKey: yesterday)
            support.container.mainContext.insert(todo)
            todos.append(todo)
        }
        if !centered { try addToday() }
        try support.container.mainContext.save()
    }

    func addToday() throws {
        let todo = TodoItem(title: "Synthetic today", dayKey: today)
        support.container.mainContext.insert(todo)
        todos.append(todo)
        try support.container.mainContext.save()
    }

    @discardableResult
    func addYesterdayRoutine() throws -> DailyRoutine {
        let routine = DailyRoutine(title: "Synthetic routine", sortOrder: 0,
                                   createdDayKey: yesterday, weekdayMask: WeekdayMask.only(weekday: 7))
        support.container.mainContext.insert(routine)
        routines.append(routine)
        try support.container.mainContext.save()
        return routine
    }

    func window(locale: String = "en", scheme: ColorScheme = .light, width: CGFloat = 480) -> NSWindow {
        support.window(YesterdayProductionHost(fixture: self), locale: locale,
                       scheme: scheme, size: NSSize(width: width, height: 420))
    }

    func expand(in window: NSWindow, locale: String = "en") async throws {
        let count = todos.filter { $0.dayKey == yesterday }.count + routines.count
        let label = LeftoverChipKind.yesterday.accessibilityLabel(count: count, locale: Locale(identifier: locale))
        let button = try #require(SettingsButtonTestSupport.buttons(in: window).first {
            SettingsButtonTestSupport.value($0, "accessibilityLabel") as? String == label
        }, "必须通过生产昨日入口展开")
        try await SettingsButtonTestSupport.click(button, in: window)
    }

    func rows(in window: NSWindow) -> [BoardRowPointerView] {
        OverlaySurfaceTestSupport.descendants(window.contentView).compactMap { $0 as? BoardRowPointerView }
    }

    func row(_ id: UUID, in window: NSWindow) throws -> BoardRowPointerView {
        try #require(rows(in: window).first { $0.identifier?.rawValue == id.uuidString })
    }
}

private struct YesterdayProductionHost: View {
    @Bindable var fixture: YesterdayCardFixture

    var body: some View {
        TasksPage(todayKey: fixture.today, routines: fixture.routines, checks: fixture.checks, todos: fixture.todos,
                  config: TasksPageConfig(yesterdayKey: fixture.yesterday, interaction: DayBoardInteraction(
                    focusedTaskID: $fixture.focused, onInspect: { fixture.inspected.append($0) })))
    }
}

struct YesterdayCardEnvironment {
    let locale: String
    let scheme: ColorScheme
    let width: CGFloat
    static var all: [Self] {
        ["en", "zh-Hans"].flatMap { locale in
            [ColorScheme.light, .dark].flatMap { scheme in
                [CGFloat(356), 480].map { Self(locale: locale, scheme: scheme, width: $0) }
            }
        }
    }
    var name: String { "\(locale)-\(scheme)-\(Int(width))" }
}
