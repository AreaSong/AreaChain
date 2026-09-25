import Foundation
import Testing
@testable import AreaChain

struct DashboardProjectionTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1
        return calendar
    }

    @Test func todayCountsOpenDoneDeletedFutureAndInvalid() {
        let today = "2026-09-25"
        let open = todo("open", day: today)
        let done = todo("done", day: today, isDone: true)
        let deleted = todo("deleted", day: today, deletedAt: date("2026-09-25"))
        let future = todo("future", day: "2026-09-26")
        let invalid = todo("bad", day: "not-a-day")
        let stat = day("2026-09-25", todos: [open, done, deleted, future, invalid])
        #expect(stat.scheduledCount == 2)
        #expect(stat.completedCount == 1)
        #expect(stat.openCount == 1)
        #expect(stat.skippedCount == 0)
        let summary = project(today: today, todos: [open, done, deleted, future, invalid]).summary
        #expect(summary.todayStat == stat)
        #expect(summary.upcomingCount == 1)
    }

    @Test func routineScheduleSkipsCreationPastAndKeepsTodayOpen() {
        let routine = routine(created: "2026-09-01", mask: WeekdayMask.all)
        let days = DashboardProjection.closedDays(ending: "2026-09-03", count: 5, calendar: calendar)
        #expect(days == ["2026-08-30", "2026-08-31", "2026-09-01", "2026-09-02", "2026-09-03"])
        let stats = stats(days: days, routines: [routine])
        #expect(stats[0].scheduledCount == 0)
        #expect(stats[2].scheduledCount == 1)
        #expect(stats[2].openCount == 1)
        let summary = project(today: "2026-09-03", routines: [routine]).summary
        #expect(summary.todayStat.openCount == 1)
        #expect(summary.todayStat.completedCount == 0)
        #expect(summary.strongestCurrentStreak == 0)
    }

    @Test func historicalMissSkipAndOffDayCompletion() {
        let id = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        var routine = routine(id: id, created: "2026-09-01", mask: mondayMask())
        let monday = "2026-09-07"
        let tuesday = "2026-09-08"
        #expect(WeekdayMask.contains(mondayMask(), dayKey: monday, calendar: calendar))
        #expect(!WeekdayMask.contains(mondayMask(), dayKey: tuesday, calendar: calendar))
        let missed = day(monday, routines: [routine])
        #expect(missed.openCount == 1)
        #expect(missed.completedCount == 0)
        let skipped = day(monday, routines: [routine], checks: [check(id, monday, skipped: true)])
        #expect(skipped.skippedCount == 1)
        #expect(skipped.completedCount == 0)
        #expect(skipped.scheduledCount == 1)
        let off = day(tuesday, routines: [routine], checks: [check(id, tuesday, done: true)])
        #expect(off.completedCount == 1)
        #expect(off.scheduledCount == 1)
        #expect(off.completionRate == 1)
        routine.isEnabled = false
        routine.pausedOnDayKey = monday
        let paused = day(monday, routines: [routine])
        #expect(paused.scheduledCount == 0)
        routine.pausedOnDayKey = nil
        let legacy = day("2026-09-14", routines: [routine])
        #expect(legacy.scheduledCount == 0)
    }

    @Test func duplicateChecksPreferSkipAndDoNotDoubleCount() {
        let id = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
        let routine = routine(id: id, created: "2026-09-01")
        let checks = [
            check(id, "2026-09-02", done: true),
            check(id, "2026-09-02", done: true, skipped: true)
        ]
        let stat = day("2026-09-02", routines: [routine], checks: checks)
        #expect(stat.completedCount == 0)
        #expect(stat.skippedCount == 1)
        #expect(stat.scheduledCount == 1)
        let rows = DashboardProjection.activities(
            todos: [], routines: [routine], checks: checks, diaries: [],
            todayKey: "2026-09-02", calendar: calendar
        )
        #expect(rows.filter { $0.kind == .skipped }.count == 1)
        #expect(rows.filter { $0.kind == .completed && $0.subjectKind == .routine }.isEmpty)
    }

    @Test func completionRateBoundsAndClosedRange() {
        let empty = DashboardDayStat.make(dayKey: "2026-09-01", scheduledCount: 0, completedCount: 0, skippedCount: 0)
        #expect(empty.completionRate == nil)
        let half = day("2026-09-01", todos: [todo("a", day: "2026-09-01", isDone: true), todo("b", day: "2026-09-01")])
        #expect(half.completionRate == 0.5)
        let capped = DashboardDayStat.make(dayKey: "2026-09-01", scheduledCount: 1, completedCount: 3, skippedCount: 0)
        #expect(capped.completionRate == 1)
        #expect(capped.completedCount == 1)
        let days = DashboardProjection.closedDays(ending: "2026-09-07", count: 7, calendar: calendar)
        #expect(days.first == "2026-09-01")
        #expect(days.last == "2026-09-07")
        #expect(days.count == 7)
    }

    @Test func heatmapSpanPaddingLeapYearAndWeekStart() {
        let end = "2026-09-25"
        let cells = DashboardProjection.heatmap(ending: end, dayCount: 365, stats: [:], calendar: calendar)
        let real = cells.filter { !$0.isPaddingCell }
        #expect(real.count == 365)
        #expect(real.last?.dayKey == end)
        #expect(cells.contains { $0.isPaddingCell })
        #expect(cells.count.isMultiple(of: 7))
        #expect(real.contains { $0.dayKey == "2026-02-28" || $0.dayKey == "2025-09-26" })
        let leap = DashboardProjection.closedDays(ending: "2024-03-01", count: 2, calendar: calendar)
        #expect(leap == ["2024-02-29", "2024-03-01"])
        var monday = calendar
        monday.firstWeekday = 2
        let sundayGrid = DashboardProjection.heatmap(ending: "2026-01-04", dayCount: 10, stats: [:], calendar: calendar)
        let mondayGrid = DashboardProjection.heatmap(ending: "2026-01-04", dayCount: 10, stats: [:], calendar: monday)
        #expect(sundayGrid.filter(\.isPaddingCell).count != mondayGrid.filter(\.isPaddingCell).count
                || sundayGrid.first?.isPaddingCell != mondayGrid.first?.isPaddingCell)
        let year = DashboardProjection.closedDays(ending: "2026-01-02", count: 3, calendar: calendar)
        #expect(year == ["2025-12-31", "2026-01-01", "2026-01-02"])
    }

    @Test func heatmapIntensityIgnoresSkipsSubtasksAndDeletedItems() {
        #expect(DashboardProjection.intensityLevel(completedCount: 0) == 0)
        #expect(DashboardProjection.intensityLevel(completedCount: 1) == 1)
        #expect(DashboardProjection.intensityLevel(completedCount: 4) == 4)
        #expect(DashboardProjection.intensityLevel(completedCount: 9) == 4)
        let id = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!
        let routine = routine(id: id, created: "2026-09-01")
        let skipped = day("2026-09-01", routines: [routine], checks: [check(id, "2026-09-01", skipped: true)])
        #expect(DashboardProjection.intensityLevel(completedCount: skipped.completedCount) == 0)
        var child = todo("parent", day: "2026-09-01", isDone: true)
        child.subtasks = [SubtaskSnapshot(id: UUID(), todoId: child.id, title: "child", isDone: true)]
        let withChild = day("2026-09-01", todos: [child])
        #expect(withChild.completedCount == 1)
        let removed = todo("gone", day: "2026-09-01", isDone: true, deletedAt: date("2026-09-02"))
        #expect(day("2026-09-01", todos: [removed]).completedCount == 0)
    }

    @Test func activitiesUseCreatedAtItemDateAndStableOrder() {
        let created = date("2026-09-20T08:00:00Z")
        let item = todo("写周报", day: "2026-09-18", isDone: true, createdAt: created)
        let rows = DashboardProjection.activities(
            todos: [item], routines: [], checks: [], diaries: [],
            todayKey: "2026-09-25", calendar: calendar
        )
        let createdRow = rows.first { $0.kind == .created }
        let doneRow = rows.first { $0.kind == .completed }
        #expect(createdRow?.dayKey == "2026-09-20")
        #expect(doneRow?.dayKey == "2026-09-18")
        #expect(doneRow?.title == "写周报")
        let first = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let second = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let sameDay = [
            todo("b", id: second, day: "2026-09-25", createdAt: date("2026-09-25T02:00:00Z")),
            todo("a", id: first, day: "2026-09-25", createdAt: date("2026-09-25T01:00:00Z"))
        ]
        let ordered = DashboardProjection.activities(
            todos: sameDay, routines: [], checks: [], diaries: [],
            todayKey: "2026-09-25", calendar: calendar
        ).filter { $0.kind == .created }
        #expect(ordered.map(\.subjectID) == [first, second])
        let many = (0..<20).map { todo("n\($0)", day: "2026-09-25", createdAt: date("2026-09-25T00:00:00Z")) }
        #expect(DashboardProjection.activities(
            todos: many, routines: [], checks: [], diaries: [],
            todayKey: "2026-09-25", calendar: calendar
        ).count == DashboardProjection.activityDisplayLimit)
    }

    @Test func privateDiariesAndMissingObjectsDoNotInventActivity() {
        let secret = "私密正文不应出现"
        var diary = DiarySnapshot(
            id: UUID(), text: secret, dayKey: "2026-09-25", createdAt: date("2026-09-25T03:00:00Z"),
            isPrivate: true, isContentAvailable: false
        )
        diary.tagIDs = "密码"
        let rows = DashboardProjection.activities(
            todos: [], routines: [], checks: [], diaries: [diary],
            todayKey: "2026-09-25", calendar: calendar
        )
        #expect(rows.isEmpty)
        let visible = DiarySnapshot(
            id: UUID(), text: secret, dayKey: "2026-09-25", createdAt: date("2026-09-25T03:00:00Z")
        )
        let shown = DashboardProjection.activities(
            todos: [], routines: [], checks: [], diaries: [visible],
            todayKey: "2026-09-25", calendar: calendar
        )
        #expect(shown.count == 1)
        #expect(shown[0].title.isEmpty)
        #expect(shown[0].titleKey == "dashboard.activity.diaryCreated")
        #expect(!shown[0].title.contains(secret))
        let edited = todo("改过的标题", day: "2026-09-25", createdAt: date("2026-09-25T01:00:00Z"))
        let kinds = DashboardProjection.activities(
            todos: [edited], routines: [], checks: [], diaries: [],
            todayKey: "2026-09-25", calendar: calendar
        ).map(\.kind)
        #expect(kinds == [.created])
    }
}

private extension DashboardProjectionTests {
    func project(
        today: String,
        todos: [TodoSnapshot] = [],
        routines: [RoutineSnapshot] = [],
        checks: [CheckSnapshot] = []
    ) -> DashboardSnapshot {
        DashboardProjection.project(
            todos: todos, routines: routines, checks: checks, diaries: [],
            todayKey: today, calendar: calendar
        )
    }

    func day(
        _ key: String,
        todos: [TodoSnapshot] = [],
        routines: [RoutineSnapshot] = [],
        checks: [CheckSnapshot] = []
    ) -> DashboardDayStat {
        let stats = stats(days: [key], todos: todos, routines: routines, checks: checks)
        return stats[0]
    }

    func stats(
        days: [String],
        todos: [TodoSnapshot] = [],
        routines: [RoutineSnapshot] = [],
        checks: [CheckSnapshot] = []
    ) -> [DashboardDayStat] {
        days.map { key in
            project(today: key, todos: todos, routines: routines, checks: checks).summary.todayStat
        }
    }

    func todo(
        _ title: String,
        id: UUID = UUID(),
        day: String,
        isDone: Bool = false,
        createdAt: Date = Date(timeIntervalSince1970: 0),
        deletedAt: Date? = nil
    ) -> TodoSnapshot {
        TodoSnapshot(
            id: id, title: title, isDone: isDone, dayKey: day,
            createdAt: createdAt, deletedAt: deletedAt
        )
    }

    func routine(
        id: UUID = UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!,
        created: String,
        mask: Int = WeekdayMask.all
    ) -> RoutineSnapshot {
        RoutineSnapshot(
            id: id, title: "晨间", sortOrder: 0, isEnabled: true,
            createdDayKey: created, weekdayMask: mask, createdAt: date("2026-09-01T00:00:00Z")
        )
    }

    func check(_ id: UUID, _ day: String, done: Bool = false, skipped: Bool = false) -> CheckSnapshot {
        CheckSnapshot(routineId: id, dayKey: day, isDone: done, isSkipped: skipped)
    }

    func mondayMask() -> Int {
        WeekdayMask.bitForTest(2)
    }

    func date(_ text: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: text) { return date }
        return formatter.date(from: text + "T00:00:00Z")!
    }
}

private extension WeekdayMask {
    static func bitForTest(_ weekday: Int) -> Int {
        1 << (weekday - 1)
    }
}
