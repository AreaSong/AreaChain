import Foundation
import Testing
@testable import AreaChain

struct DashboardProjectionEquivalenceTests {
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1
        return calendar
    }

    private var losAngelesCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        calendar.firstWeekday = 1
        return calendar
    }

    @Test func emptyInputsStayEmpty() {
        let calendar = utcCalendar
        let today = "2026-09-07"
        expectEquivalent(today: today, calendar: calendar)
        let snapshot = DashboardProjection.project(
            todos: [], routines: [], checks: [], diaries: [], todayKey: today, calendar: calendar
        )
        #expect(snapshot.summary.todayStat.scheduledCount == 0)
        #expect(snapshot.summary.strongestCurrentStreak == 0)
        #expect(snapshot.summary.overdueCount == 0)
        #expect(snapshot.activities.isEmpty)
        #expect(snapshot.heatmap.filter { !$0.isPaddingCell }.count == 365)
    }

    @Test func singleDayAndNewYearBoundaryStayEquivalent() {
        let calendar = utcCalendar
        let daily = routine("跨年", created: "2026-12-30")
        let checks = [CheckSnapshot(routineId: daily.id, dayKey: "2026-12-30", isDone: true)]
        let overdue = todo("旧", day: "2026-12-31")
        let upcoming = todo("新", day: "2027-01-03")
        expectEquivalent(
            today: "2027-01-02",
            todos: [overdue, upcoming],
            routines: [daily],
            checks: checks,
            calendar: calendar
        )
        let snapshot = DashboardProjection.project(
            todos: [overdue, upcoming], routines: [daily], checks: checks, diaries: [],
            todayKey: "2027-01-02", calendar: calendar
        )
        #expect(snapshot.summary.todayStat.scheduledCount == 1)
        #expect(snapshot.summary.todayStat.openCount == 1)
        #expect(snapshot.heatmap.contains { $0.dayKey == "2026-12-31" && !$0.isPaddingCell })
        #expect(snapshot.heatmap.contains { $0.dayKey == "2027-01-01" && !$0.isPaddingCell })
    }

    @Test func leapDayAndCivilWeekdayAreTimezoneIndependent() {
        let daily = routine("闰年", created: "2024-02-28")
        for calendar in [utcCalendar, losAngelesCalendar] {
            expectEquivalent(today: "2024-03-01", routines: [daily], calendar: calendar)
            let snapshot = DashboardProjection.project(
                todos: [], routines: [daily], checks: [], diaries: [],
                todayKey: "2024-03-01", calendar: calendar
            )
            #expect(snapshot.heatmap.contains { $0.dayKey == "2024-02-29" && !$0.isPaddingCell })
            let leap = snapshot.heatmap.first { $0.dayKey == "2024-02-29" }
            #expect(leap?.scheduledCount == 1)
            #expect(leap?.completedCount == 0)
        }
    }

    @Test func pauseResumeSkipMissOffDayAndLegacyDisableStayEquivalent() {
        let calendar = utcCalendar
        let monday = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        var item = routine("周一", id: monday, mask: mondayMask(), created: "2026-09-01")
        let checks = [
            CheckSnapshot(routineId: monday, dayKey: "2026-09-07", isDone: true, isSkipped: true),
            CheckSnapshot(routineId: monday, dayKey: "2026-09-08", isDone: true),
            CheckSnapshot(routineId: monday, dayKey: "2026-09-14", isDone: true)
        ]
        expectEquivalent(today: "2026-09-14", routines: [item], checks: checks, calendar: calendar)
        item.isEnabled = false
        item.pausedOnDayKey = "2026-09-14"
        expectEquivalent(today: "2026-09-21", routines: [item], checks: checks, calendar: calendar)
        item.isEnabled = true
        expectEquivalent(today: "2026-09-21", routines: [item], checks: checks, calendar: calendar)
        item.isEnabled = false
        item.pausedOnDayKey = nil
        expectEquivalent(today: "2026-09-21", routines: [item], checks: checks, calendar: calendar)
        let skipped = DashboardProjection.project(
            todos: [], routines: [routine("周一", id: monday, mask: mondayMask(), created: "2026-09-01")],
            checks: checks, diaries: [], todayKey: "2026-09-08", calendar: calendar
        )
        #expect(skipped.heatmap.first { $0.dayKey == "2026-09-07" }?.completedCount == 0)
        #expect(skipped.heatmap.first { $0.dayKey == "2026-09-08" }?.completedCount == 0)
        #expect(skipped.heatmap.first { $0.dayKey == "2026-09-08" }?.scheduledCount == 0)
    }

    @Test func softDeleteForeignChecksAndInvalidKeysStayEquivalent() {
        let calendar = utcCalendar
        let liveID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        let goneID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
        let live = routine("活", id: liveID, created: "2026-09-01")
        var gone = routine("删", id: goneID, created: "2026-09-01")
        gone.deletedAt = Date(timeIntervalSince1970: 8)
        let open = todo("开", day: "2026-09-08")
        let deletedTodo = todo("废", day: "2026-09-08", deleted: true)
        let badTodo = todo("坏日", day: "not-a-day")
        let checks = [
            CheckSnapshot(routineId: liveID, dayKey: "2026-09-07", isDone: true),
            CheckSnapshot(routineId: liveID, dayKey: "2026-09-08", isDone: true),
            CheckSnapshot(routineId: goneID, dayKey: "2026-09-08", isDone: true),
            CheckSnapshot(routineId: liveID, dayKey: "2026-09-08", isDone: true, isSkipped: true)
        ]
        var invalidCreated = routine("坏创建", created: "2026-9-1")
        invalidCreated.createdDayKey = "bad-key"
        expectEquivalent(
            today: "2026-09-08",
            todos: [open, deletedTodo, badTodo],
            routines: [live, gone, invalidCreated],
            checks: checks,
            calendar: calendar
        )
        let snapshot = DashboardProjection.project(
            todos: [open, deletedTodo, badTodo],
            routines: [live, gone, invalidCreated],
            checks: checks,
            diaries: [],
            todayKey: "2026-09-08",
            calendar: calendar
        )
        #expect(snapshot.summary.strongestCurrentStreak == 1)
        #expect(snapshot.summary.todayStat.completedCount == 0)
        #expect(snapshot.summary.todayStat.skippedCount == 1)
        #expect(snapshot.summary.todayStat.scheduledCount == 2)
    }

    @Test func heatmapScaleStaysEquivalentAndFast() {
        let calendar = utcCalendar
        var routines: [RoutineSnapshot] = []
        var checks: [CheckSnapshot] = []
        var todos: [TodoSnapshot] = []
        for index in 0..<40 {
            let mask: Int
            if index.isMultiple(of: 5) {
                mask = mondayMask()
            } else if index.isMultiple(of: 2) {
                mask = WeekdayMask.workdays
            } else {
                mask = WeekdayMask.all
            }
            let item = routine(
                "dash-\(index)",
                mask: mask,
                created: "2025-09-08",
                sortOrder: index
            )
            routines.append(item)
            var cursor = DayKey.date(from: "2025-09-08", calendar: calendar)!
            for day in 0..<365 {
                let key = DayKey.from(cursor, calendar: calendar)
                if day % 37 == 0 {
                    checks.append(CheckSnapshot(routineId: item.id, dayKey: key, isDone: true))
                } else if day % 41 == 0 {
                    checks.append(
                        CheckSnapshot(routineId: item.id, dayKey: key, isDone: true, isSkipped: true)
                    )
                }
                cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
            }
            todos.append(
                todo("t-\(index)", day: index.isMultiple(of: 2) ? "2026-09-07" : "2026-08-31")
            )
        }
        let todayKey = "2026-09-07"
        _ = DashboardProjection.project(
            todos: todos, routines: routines, checks: checks, diaries: [],
            todayKey: todayKey, calendar: calendar
        )
        _ = DashboardProjectionOracle.project(
            todos: todos, routines: routines, checks: checks, diaries: [],
            todayKey: todayKey, calendar: calendar
        )
        var indexed = DashboardProjection.project(
            todos: [], routines: [], checks: [], diaries: [], todayKey: todayKey, calendar: calendar
        )
        var naive = indexed
        var indexedSamples: [TimeInterval] = []
        var naiveSamples: [TimeInterval] = []
        for _ in 1...3 {
            indexedSamples.append(elapsedSeconds {
                indexed = DashboardProjection.project(
                    todos: todos, routines: routines, checks: checks, diaries: [],
                    todayKey: todayKey, calendar: calendar
                )
            })
            naiveSamples.append(elapsedSeconds {
                naive = DashboardProjectionOracle.project(
                    todos: todos, routines: routines, checks: checks, diaries: [],
                    todayKey: todayKey, calendar: calendar
                )
            })
        }
        let indexedMedian = medianElapsed(indexedSamples)
        let naiveMedian = medianElapsed(naiveSamples)
        #expect(indexed == naive)
        #expect(
            indexedMedian < 0.2,
            "indexed median \(indexedMedian)s vs naive median \(naiveMedian)s"
        )
        #expect(indexedMedian <= naiveMedian + 0.05)
    }

    private func expectEquivalent(
        today: String,
        todos: [TodoSnapshot] = [],
        routines: [RoutineSnapshot] = [],
        checks: [CheckSnapshot] = [],
        diaries: [DiarySnapshot] = [],
        calendar: Calendar
    ) {
        let actual = DashboardProjection.project(
            todos: todos, routines: routines, checks: checks, diaries: diaries,
            todayKey: today, calendar: calendar
        )
        let naive = DashboardProjectionOracle.project(
            todos: todos, routines: routines, checks: checks, diaries: diaries,
            todayKey: today, calendar: calendar
        )
        #expect(actual.summary == naive.summary)
        #expect(actual.trend == naive.trend)
        #expect(actual.heatmap == naive.heatmap)
        #expect(actual.activities == naive.activities)
    }

    private func routine(
        _ title: String,
        id: UUID = UUID(),
        mask: Int = WeekdayMask.all,
        created: String,
        deleted: Bool = false,
        sortOrder: Int = 0,
        pausedOnDayKey: String? = nil
    ) -> RoutineSnapshot {
        RoutineSnapshot(
            id: id,
            title: title,
            sortOrder: sortOrder,
            isEnabled: true,
            createdDayKey: created,
            weekdayMask: mask,
            deletedAt: deleted ? Date(timeIntervalSince1970: 1) : nil,
            pausedOnDayKey: pausedOnDayKey
        )
    }

    private func todo(
        _ title: String,
        day: String,
        done: Bool = false,
        deleted: Bool = false
    ) -> TodoSnapshot {
        TodoSnapshot(
            id: UUID(),
            title: title,
            isDone: done,
            dayKey: day,
            deletedAt: deleted ? Date(timeIntervalSince1970: 2) : nil
        )
    }

    private func mondayMask() -> Int {
        1 << 1
    }

    private func elapsedSeconds(_ work: () -> Void) -> TimeInterval {
        let started = Date()
        work()
        return Date().timeIntervalSince(started)
    }

    private func medianElapsed(_ samples: [TimeInterval]) -> TimeInterval {
        samples.sorted()[samples.count / 2]
    }
}
