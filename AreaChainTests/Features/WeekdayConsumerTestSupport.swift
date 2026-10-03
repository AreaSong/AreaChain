import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

/// 复用已有合成习惯、内存库、导航恢复和仓储注入；不接真实通知或日历。
@MainActor
final class WeekdayConsumerTestSupport {
    let base: HabitMonthTestSupport
    let repo: RecurringToggleRepository
    private let restoreRepository: () -> Void
    private let otherSnapshot: RoutineSnapshot
    var routine: DailyRoutine { base.routine }
    var context: ModelContext { base.context }

    init() throws {
        base = try HabitMonthTestSupport()
        base.other.deletedAt = Date(timeIntervalSince1970: 1)
        try base.context.save()
        otherSnapshot = base.other.snapshot
        repo = RecurringToggleRepository(base.context)
        let previous = DayBoardMutations.routineRepositoryProvider
        restoreRepository = { DayBoardMutations.routineRepositoryProvider = previous }
        let injected = repo
        DayBoardMutations.routineRepositoryProvider = { _ in injected }
        #expect(NotificationScheduler.isRunningTests)
    }

    func cleanup() {
        restoreRepository()
        base.cleanup()
    }

    func window(_ host: String, locale: String = "en", dark: Bool = false, narrow: Bool = true) -> NSWindow {
        base.fixture.window(Group {
            switch host {
            case "editor": RecurringItemEditor()
            case "management": ResidentsPage()
            default: HabitDrawerTestHost()
            }
        }, locale: locale, scheme: dark ? .dark : .light,
           size: NSSize(width: host == "detail" ? (narrow ? 280 : 320) : (narrow ? 440 : 560), height: 900))
    }

    func assertUnrelatedUnchanged() throws {
        let current = routine.snapshot
        let original = base.original[0]
        #expect(current.isEnabled == original.isEnabled)
        #expect(current.pausedOnDayKey == original.pausedOnDayKey)
        #expect(current.remindMinutes == original.remindMinutes)
        #expect(current.tagIDs == original.tagIDs)
        #expect(current.isImportant == original.isImportant && current.isUrgent == original.isUrgent)
        #expect(base.other.snapshot == otherSnapshot)
        #expect(base.checks.compactMap(\.snapshot) == base.originalChecks)
        #expect(repo.switches == 0 && repo.reminderWrites.isEmpty)
        #expect(BoardSelection.shared.inspectingDayKey == "2026-09-09")
        #expect(WorkspaceNavigation.shared.selectedTaskID == routine.id)
    }
}
