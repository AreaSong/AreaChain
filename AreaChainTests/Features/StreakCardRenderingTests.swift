import AppKit
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct StreakCardRenderingTests {
    typealias Native = SettingsButtonTestSupport
    typealias Card = StreakCardTestSupport

    @Test(arguments: ["en", "zh-Hans"], [ColorScheme.light, .dark])
    func productionCardMatrix(locale: String, scheme: ColorScheme) async throws {
        let fixture = try Native(isolatedPreferences: true)
        let now = DayClock.shared.now
        let pointer = NSEvent.mouseLocation
        defer { fixture.cleanup(); DayClock.shared.now = now; RowBubbleTestSupport.warp(pointer) }
        DayClock.shared.now = try #require(DayKey.date(from: "2026-09-09"))
        for width in [CGFloat(280), 320] {
            let probe = StreakCardProbe()
            let window = fixture.window(StreakCardSample(probe: probe), locale: locale, scheme: scheme,
                                        size: NSSize(width: width, height: 240))
            defer { SystemPageHost.release(window) }
            try await RowBubbleTestSupport.move(NSPoint(x: 4, y: 4), in: window)
            for (current, best) in [(0, 1), (1, 99), (99, 100), (100, 7), (123456789, 9876543210)] {
                probe.config.streakResult = StreakResult(currentStreak: current, bestStreak: best)
                try await SystemPageHost.settle(window)
                try Card.assertMetrics(probe.config.streakResult, locale: locale, in: window)
                let frame = try NativeSyntaxUI.frame("syntax.streak.card", in: window)
                #expect(frame.minX == 28 && frame.width == width - 56)
                try Card.record(window, name: "metrics-\(current)-\(best)-\(Int(width))-\(locale)-\(scheme)")
            }
            probe.config.streakResult = StreakResult(currentStreak: 7, bestStreak: 21)
            try await assertStates(probe, window: window, name: "\(Int(width))-\(locale)-\(scheme)", locale: locale)
        }
    }

    private func assertStates(_ probe: StreakCardProbe, window: NSWindow, name: String, locale: String) async throws {
        let states: [(String, Bool, StreakInspectionFlags)] = [
            ("paused", false, .init(isCompleted: true, isSkipped: true, isDue: false)),
            ("skipped", true, .init(isCompleted: true, isSkipped: true, isDue: false)),
            ("completed", true, .init(isCompleted: true, isDue: false)),
            ("offday", true, .init(isDue: false)),
            ("pending", true, .init())
        ]
        for (status, enabled, flags) in states {
            probe.config.isEnabled = enabled
            probe.config.flags = flags
            probe.config.inspectDayKey = "2026-09-08"
            try await SystemPageHost.settle(window)
            try Card.assertMetrics(probe.config.streakResult, locale: locale, in: window)
            _ = try Card.node(Card.localized("drawer.streak.status.\(status)", locale: locale), in: window)
            _ = try Card.node(DayKey.displayName("2026-09-08", locale: Locale(identifier: locale)), in: window)
            try Card.record(window, name: "\(status)-\(name)")
        }
        probe.config.inspectDayKey = "2026-09-09"
        try await SystemPageHost.settle(window)
        #expect(!Card.texts(window).map(Card.text).contains(DayKey.displayName("2026-09-09", locale: Locale(identifier: locale))))
        try Card.record(window, name: "today-\(name)")
    }

    @Test func externalUpdatesAndHoverPreserveCard() async throws {
        let fixture = try Native(isolatedPreferences: true)
        let pointer = NSEvent.mouseLocation
        defer { fixture.cleanup(); RowBubbleTestSupport.warp(pointer) }
        let probe = StreakCardProbe()
        let window = fixture.window(StreakCardSample(probe: probe), size: NSSize(width: 320, height: 240))
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await RowBubbleTestSupport.move(NSPoint(x: 4, y: 4), in: window)
        try await SystemPageHost.settle(window)
        try Card.assertMetrics(probe.config.streakResult, locale: "en", in: window)
        probe.config.streakResult = StreakResult(currentStreak: 100, bestStreak: 21)
        try await SystemPageHost.settle(window)
        try Card.assertMetrics(probe.config.streakResult, locale: "en", in: window)
        probe.config.streakResult = StreakResult(currentStreak: 100, bestStreak: 999)
        try await SystemPageHost.settle(window)
        try Card.assertMetrics(probe.config.streakResult, locale: "en", in: window)
        let frame = try NativeSyntaxUI.frame("syntax.streak.card", in: window)
        let before = RowBubbleTestSupport.bytes(try OverlaySurfaceTestSupport.bitmap(window))
        try Card.record(window, name: "updated-idle")
        try await RowBubbleTestSupport.move(NSPoint(x: frame.midX, y: frame.midY), in: window)
        try await SystemPageHost.settle(window)
        let hovered = RowBubbleTestSupport.bytes(try OverlaySurfaceTestSupport.bitmap(window))
        #expect(before != hovered, "原 .card 悬停应改变表面")
        #expect(try NativeSyntaxUI.frame("syntax.streak.card", in: window) == frame)
        try Card.record(window, name: "updated-hover")
        try await RowBubbleTestSupport.move(NSPoint(x: 4, y: 4), in: window)
        try await SystemPageHost.settle(window)
        #expect(before == RowBubbleTestSupport.bytes(try OverlaySurfaceTestSupport.bitmap(window)))
    }

    @Test(arguments: ["en", "zh-Hans"])
    func productionHabitSectionConsumesResultWithoutActions(locale: String) async throws {
        let support = try HabitMonthTestSupport()
        defer { support.cleanup() }
        let navigation = WorkspaceNavigation.shared
        let selectedID = navigation.selectedTaskID
        let day = BoardSelection.shared.inspectingDayKey
        let presented = navigation.isInspectorPresented
        let probe = MenuBarHelpMutationProbe(context: support.context) {
            _ = support.routine.title; _ = support.routine.notes; _ = support.routine.isEnabled
            _ = navigation.selectedTaskID; _ = navigation.isInspectorPresented
            _ = BoardSelection.shared.inspectingDayKey
        }
        // 合成历史实际不可能给出这两个值；验证宿主仍消费传入结果，不另行计算。
        let result = StreakResult(currentStreak: 17, bestStreak: 203)
        let window = support.fixture.window(RoutineHabitSectionView(routine: support.routine,
            streakResult: result, boardDayKey: "2026-09-08", isDoneOnBoard: true, isSkipped: true)
            .padding(16), locale: locale, size: NSSize(width: 320, height: 720))
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        try Card.assertMetrics(result, locale: locale, in: window)
        _ = try Card.node(Card.localized("drawer.streak.status.skipped", locale: locale), in: window)
        _ = try Card.node(DayKey.displayName("2026-09-08", locale: Locale(identifier: locale)), in: window)
        #expect(navigation.selectedTaskID == selectedID && navigation.isInspectorPresented == presented)
        #expect(BoardSelection.shared.inspectingDayKey == day && probe.writes == 0 && probe.saves == 0)
        try support.assertUnchanged()
        try Card.record(window, name: "habit-section-\(locale)")
    }
}
