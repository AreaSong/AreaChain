import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@MainActor
struct ClosureRegressionTests {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test func leftoverChipAccessibilityLabelsIncludeLocalizedContextAndCount() {
        let chinese = Locale(identifier: "zh-Hans")
        let english = Locale(identifier: "en")
        #expect(LeftoverChipKind.yesterday.accessibilityLabel(count: 2, locale: chinese) == "昨天 2 条")
        #expect(LeftoverChipKind.upcoming.accessibilityLabel(count: 3, locale: chinese) == "即将 3 条")
        #expect(LeftoverChipKind.yesterday.accessibilityLabel(count: 2, locale: english) == "Yesterday 2")
        #expect(LeftoverChipKind.upcoming.accessibilityLabel(count: 3, locale: english) == "Upcoming 3")
        #expect(LeftoverChipKind.yesterday.accessibilityLabel(count: 0, locale: chinese) == "昨天未完成 0 条")
        #expect(LeftoverChipKind.upcoming.accessibilityLabel(count: 0, locale: chinese) == "即将 0 条")
        #expect(LeftoverChipKind.yesterday.accessibilityLabel(count: 0, locale: english) == "Yesterday leftover 0")
        #expect(LeftoverChipKind.upcoming.accessibilityLabel(count: 0, locale: english) == "Upcoming 0")
    }

    @Test func resettingStoreIncludesCalendarLedgerAndOnlyOwnedFiles() {
        var attempted: [URL] = []
        // 只记录路径，不触碰真实数据库、同步记录或附件。
        Persistence.resetStoreOnDisk { attempted.append($0) }
        let root = URL.applicationSupportDirectory
        let expected = ["areachain.store", "areachain.store-shm", "areachain.store-wal", CalendarSyncStorage.ledgerFilename]
            .map { root.appending(path: $0) } + [AttachmentStore.directory()]
        #expect(attempted == expected)
        #expect(attempted.count == Set(attempted).count)
        #expect(!attempted.contains(root))
    }

    @Test func workspaceRoutePreservesExplicitInspectionDayAfterResettingFilters() {
        let board = BoardSelection()
        let navigation = WorkspaceNavigation(boardSelection: board)
        let id = UUID()
        navigation.selectedProjectID = UUID()
        navigation.revealTab(.today, inspecting: id, dayKey: "2026-09-10")
        #expect(navigation.selectedProjectID == nil)
        #expect(navigation.selectedTaskID == id)
        #expect(board.inspectingDayKey == "2026-09-10")
        navigation.revealTab(.residents)
        #expect(board.inspectingDayKey == DayClock.shared.todayKey)
    }

    @Test func consecutiveSpaceCompletesVisibleNeighborsWithoutUndoingHiddenTask() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let day = DayKey.today()
        let first = TodoItem(title: "第一条", dayKey: day)
        let second = TodoItem(title: "第二条", dayKey: day)
        context.insert(first)
        context.insert(second)
        try context.save()
        var focusedID: UUID? = first.id
        var returnedToInput = false
        let list = DayBoardList(
            dayKey: day, routines: [], checks: [], todos: [first, second],
            config: DayBoardListConfig(interaction: DayBoardInteraction(
                focusedTaskID: Binding(get: { focusedID }, set: { focusedID = $0 }),
                onReturnToInput: { returnedToInput = true }
            ))
        )

        list.toggleSelected(id: first.id)
        #expect(first.isDone)
        #expect(focusedID == second.id)
        list.toggleSelected(id: try #require(focusedID))
        #expect(first.isDone && second.isDone)
        #expect(focusedID == nil)
        #expect(returnedToInput)
    }

    @Test func resumingPauseBridgesCancelledCheckWithoutChangingEarlierMiss() throws {
        let container = try makeContainer()
        let repo = SwiftDataRoutineRepository(container: container)
        let routine = try repo.addRoutine(CreateRoutineParams(title: "习惯", createdDayKey: "2026-09-08"))
        for day in ["2026-09-08", "2026-09-09", "2026-09-10"] {
            try repo.toggleRoutine(id: routine.id, dayKey: day)
        }
        try repo.toggleRoutine(id: routine.id, dayKey: "2026-09-08")
        try repo.toggleRoutine(id: routine.id, dayKey: "2026-09-10")
        try repo.setRoutineEnabled(id: routine.id, enabled: false, todayKey: "2026-09-10")
        try repo.setRoutineEnabled(id: routine.id, enabled: true, todayKey: "2026-09-12")

        let checks = try repo.fetchChecks(for: routine.id)
        let pauseDay = try #require(checks.first { $0.dayKey == "2026-09-10" })
        #expect(pauseDay.isDone && pauseDay.isSkipped)
        #expect(checks.first { $0.dayKey == "2026-09-08" }?.isDone == false)
        #expect(!checks.contains { $0.dayKey == "2026-09-12" })
        let streak = try repo.calculateStreak(for: routine, todayKey: "2026-09-12")
        #expect(streak.currentStreak == 1)
    }

    @Test func remindersKeepWallClockTimeAcrossDaylightSavingTransitions() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        for key in ["2026-03-08", "2026-11-01"] {
            let fire = try #require(DayKey.date(dayKey: key, minutes: 9 * 60 + 30, calendar: calendar))
            #expect(DayKey.from(fire, calendar: calendar) == key)
            #expect(calendar.component(.hour, from: fire) == 9)
            #expect(calendar.component(.minute, from: fire) == 30)
        }
    }

    @Test func nonExistentReminderTimeMovesToFirstAvailableWallClockTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let fire = try #require(DayKey.date(dayKey: "2026-03-08", minutes: 150, calendar: calendar))
        #expect(calendar.component(.hour, from: fire) == 3)
        #expect(calendar.component(.minute, from: fire) == 0)
    }

    @Test func futureCompletedAndSkippedDaysDoNotReceiveRoutineReminders() throws {
        let routine = RoutineSnapshot(
            id: UUID(), title: "提醒", sortOrder: 0, isEnabled: true,
            createdDayKey: "2026-09-01", remindMinutes: 9 * 60
        )
        let checks = [
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-12", isDone: true),
            CheckSnapshot(routineId: routine.id, dayKey: "2026-09-13", isDone: true, isSkipped: true)
        ]
        let request = try #require(ReminderPlanning.catalog(
            routines: [routine], checks: checks, todos: [], todayKey: "2026-09-11"
        ).first)
        let now = try #require(DayKey.date(dayKey: "2026-09-11", minutes: 20 * 60))
        let fire = try #require(ReminderPlanning.nextFireDate(request, now: now))
        #expect(DayKey.from(fire) == "2026-09-14")
    }

    @Test func routineReminderCanPassMoreThanSixteenClosedDays() throws {
        let routine = RoutineSnapshot(
            id: UUID(), title: "长期安排", sortOrder: 0, isEnabled: true,
            createdDayKey: "2026-09-01", remindMinutes: 9 * 60
        )
        let checks = (0..<21).map {
            CheckSnapshot(routineId: routine.id, dayKey: DayKey.shifted("2026-09-11", by: $0), isDone: true)
        }
        let request = try #require(ReminderPlanning.catalog(
            routines: [routine], checks: checks, todos: [], todayKey: "2026-09-11"
        ).first)
        let now = try #require(DayKey.date(dayKey: "2026-09-11", minutes: 8 * 60))
        let fire = try #require(ReminderPlanning.nextFireDate(request, now: now))
        #expect(DayKey.from(fire) == "2026-10-02")
    }
}
