import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct YesterdayCardActionTests {
    @Test(arguments: [false, true], [false, true])
    func routineInspectionAndCompletionKeepYesterday(centered: Bool, skip: Bool) async throws {
        let previousDay = BoardSelection.shared.inspectingDayKey
        defer { BoardSelection.shared.inspectingDayKey = previousDay }
        let restore = MenuButtonTestSupport.preserveListingNavigation()
        defer { restore() }
        let fixture = try YesterdayCardFixture(centered: centered, count: 0)
        defer { fixture.support.cleanup() }
        let routine = try fixture.addYesterdayRoutine()
        let before = routine.snapshot
        let window = fixture.window()
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await fixture.expand(in: window)
        let row = try fixture.row(routine.id, in: window)
        let frame = row.convert(row.bounds, to: nil)
        try await SurfaceEventTestSupport.click(NSPoint(x: frame.midX, y: frame.midY), in: window)
        #expect(fixture.inspected == [routine.id] && fixture.focused == routine.id)
        #expect(BoardSelection.shared.inspectingDayKey == fixture.yesterday)
        if skip {
            let menu = try await MenuButtonTestSupport.openAndEscape(
                MenuButtonTestSupport.menu("row.more", in: window), in: window)
            try MenuButtonTestSupport.dispatch(MenuButtonTestSupport.localized("row.skip", "en"), in: menu)
        } else {
            // PointerView 只覆盖正文，不能拿正文起点猜测左侧完成控件的位置。
            let label = L10n.string("checkbox.open", locale: Locale(identifier: "en"))
            let candidates = try SettingsButtonTestSupport.buttons(in: window).filter {
                guard MenuButtonTestSupport.title($0) == label else { return false }
                return abs(try SettingsButtonTestSupport.frame($0, in: window).midY - frame.midY) < 3
            }
            try #require(candidates.count == 1)
            try await SettingsButtonTestSupport.click(try #require(candidates.first), in: window)
        }
        try await SystemPageHost.settle(window)
        let checks = try fixture.support.container.mainContext.fetch(FetchDescriptor<RoutineCheck>())
        try #require(checks.count == 1)
        let check = try #require(checks.first)
        #expect(check.routine?.id == routine.id && check.dayKey == fixture.yesterday)
        #expect(check.isDone && check.isSkipped == skip)
        #expect(routine.snapshot == before)
        #expect(BoardSelection.shared.inspectingDayKey == fixture.yesterday)
    }

    @Test(arguments: [false, true], ["send", "accessibility"])
    func originalMoveActionOnlyMovesYesterdayTodos(centered: Bool, delivery: String) async throws {
        let fixture = try YesterdayCardFixture(centered: centered, count: 2)
        defer { fixture.support.cleanup() }
        let targets = fixture.todos.filter { $0.dayKey == fixture.yesterday }
        let routine = try fixture.addYesterdayRoutine()
        let routineBefore = routine.snapshot
        let context = fixture.support.container.mainContext
        let unrelated = TodoItem(title: "Synthetic unrelated", dayKey: "2026-10-01")
        context.insert(unrelated)
        fixture.todos.append(unrelated)
        try context.save()
        let repository = MonthGridMoveRepository(context)
        let previous = DayBoardMutations.taskRepositoryProvider
        DayBoardMutations.taskRepositoryProvider = { _ in repository }
        defer { DayBoardMutations.taskRepositoryProvider = previous }
        let window = fixture.window()
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await fixture.expand(in: window)
        let button = try SettingsButtonTestSupport.button("stamp.yesterday.moveAll", in: window)
        let frame = try SettingsButtonTestSupport.frame(button, in: window)
        // 先测按钮左侧的标题空白，不能因外壳把按钮扩到整卡。
        try await SurfaceEventTestSupport.click(NSPoint(x: frame.minX - 8, y: frame.midY), in: window)
        #expect(repository.calls.isEmpty)
        if delivery == "send" {
            try await SurfaceEventTestSupport.click(NSPoint(x: frame.midX, y: frame.midY), in: window)
        } else {
            let press = NSSelectorFromString("accessibilityPerformPress")
            try #require(button.responds(to: press))
            _ = button.perform(press)
            try await SystemPageHost.settle(window)
        }
        #expect(repository.calls.map(\.0) == targets.map(\.id))
        #expect(repository.calls.allSatisfy { $0.1 == fixture.today })
        #expect(targets.allSatisfy { $0.dayKey == fixture.today && !$0.isDone })
        #expect(unrelated.dayKey == "2026-10-01")
        #expect(routine.snapshot == routineBefore)
        #expect(try context.fetchCount(FetchDescriptor<RoutineCheck>()) == 0)
        #expect(try ModelContext(context.container).fetch(FetchDescriptor<TodoItem>()).filter {
            targets.map(\.id).contains($0.id) && $0.dayKey == fixture.today
        }.count == 2)
    }

    @Test(arguments: [false, true])
    func originalRowInspectionUsesYesterday(centered: Bool) async throws {
        let previousDay = BoardSelection.shared.inspectingDayKey
        defer { BoardSelection.shared.inspectingDayKey = previousDay }
        let restore = MenuButtonTestSupport.preserveListingNavigation()
        defer { restore() }
        let fixture = try YesterdayCardFixture(centered: centered)
        defer { fixture.support.cleanup() }
        let window = fixture.window()
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await fixture.expand(in: window)
        let todo = try #require(fixture.todos.first)
        let row = try fixture.row(todo.id, in: window)
        let frame = row.convert(row.bounds, to: nil)
        try await SurfaceEventTestSupport.click(NSPoint(x: frame.midX, y: frame.midY), in: window)
        #expect(fixture.inspected == [todo.id])
        #expect(fixture.focused == todo.id)
        #expect(BoardSelection.shared.inspectingDayKey == fixture.yesterday)
        #expect(todo.dayKey == fixture.yesterday && !todo.isDone)
    }

    @Test(arguments: [false, true])
    func failedMovesKeepModelsRowsAndOriginalFeedback(centered: Bool) async throws {
        let fixture = try YesterdayCardFixture(centered: centered, count: 2)
        defer { fixture.support.cleanup() }
        _ = try fixture.addYesterdayRoutine()
        let context = fixture.support.container.mainContext
        let before = fixture.todos.map(\.snapshot)
        let routinesBefore = fixture.routines.map(\.snapshot)
        let repository = MonthGridMoveRepository(context)
        repository.fails = true
        let previous = DayBoardMutations.taskRepositoryProvider
        DayBoardMutations.taskRepositoryProvider = { _ in repository }
        defer { DayBoardMutations.taskRepositoryProvider = previous }
        var refreshes = 0
        let observer = NotificationCenter.default.addObserver(forName: .boardDidChange, object: nil, queue: .main) { _ in
            refreshes += 1
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        let failures = MutationFeedback.shared.failureCount
        let window = fixture.window()
        defer { SystemPageHost.release(window) }
        try await NativeSyntaxUI.prepareFocus(in: window)
        try await fixture.expand(in: window)
        #expect(repository.calls.isEmpty && refreshes == 0)
        try await SettingsButtonTestSupport.click(SettingsButtonTestSupport.button("stamp.yesterday.moveAll", in: window), in: window)
        #expect(repository.calls.count == 2)
        #expect(MutationFeedback.shared.failureCount == failures + 2)
        #expect(refreshes == 0)
        #expect(fixture.todos.map(\.snapshot) == before && fixture.routines.map(\.snapshot) == routinesBefore)
        for todo in fixture.todos where todo.dayKey == fixture.yesterday { _ = try fixture.row(todo.id, in: window) }
        _ = try SettingsButtonTestSupport.button("stamp.yesterday.moveAll", in: window)
        repository.fails = false
        try await SettingsButtonTestSupport.click(SettingsButtonTestSupport.button("stamp.yesterday.moveAll", in: window), in: window)
        #expect(repository.calls.count == 4 && refreshes == 2, "成功仍逐项保存和发布，不改成批量事务")
        #expect(fixture.todos.allSatisfy { $0.dayKey == fixture.today })
        #expect(fixture.routines.map(\.snapshot) == routinesBefore)
        #expect(try context.fetchCount(FetchDescriptor<RoutineCheck>()) == 0)
    }
}
