import Foundation
import Testing
@testable import AreaChain

struct AgendaDayBoardEquivalenceTests {
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var losAngelesCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }

    private func routine(
        _ title: String,
        id: UUID = UUID(),
        mask: Int = WeekdayMask.all,
        enabled: Bool = true,
        created: String = "2026-01-01",
        deleted: Bool = false,
        sortOrder: Int = 0,
        tags: String = "",
        pausedOnDayKey: String? = nil
    ) -> RoutineSnapshot {
        RoutineSnapshot(
            id: id,
            title: title,
            sortOrder: sortOrder,
            isEnabled: enabled,
            createdDayKey: created,
            weekdayMask: mask,
            deletedAt: deleted ? Date(timeIntervalSince1970: 1) : nil,
            tagIDs: tags,
            pausedOnDayKey: pausedOnDayKey
        )
    }

    private func todo(
        _ title: String,
        day: String,
        done: Bool = false,
        deleted: Bool = false,
        tags: String = ""
    ) -> TodoSnapshot {
        TodoSnapshot(
            id: UUID(),
            title: title,
            isDone: done,
            dayKey: day,
            deletedAt: deleted ? Date(timeIntervalSince1970: 2) : nil,
            tagIDs: tags
        )
    }

    private func expectOpenDaysMatch(
        _ snapshot: RoutineSnapshot,
        checks: [CheckSnapshot],
        from start: String,
        through end: String,
        calendar: Calendar
    ) {
        let actual = AgendaProjection.openScheduledDays(
            snapshot, checks: checks, from: start, through: end, calendar: calendar
        )
        let naive = AgendaDayBoardOracle.openScheduledDays(
            snapshot, checks: checks, from: start, through: end, calendar: calendar
        )
        #expect(actual == naive)
    }

    @Test func emptyInputsStayEmpty() {
        let calendar = utcCalendar
        let today = "2026-09-07"
        #expect(
            AgendaProjection.overdueRoutines(routines: [], checks: [], todayKey: today, calendar: calendar).isEmpty
        )
        #expect(
            AgendaProjection.pending(
                routines: [], checks: [], todos: [], todayKey: today, calendar: calendar
            ) == PendingProjection(overdue: [], upcoming: [])
        )
        let month = DayBoardLogic.monthUnfinished(
            routines: [], checks: [], todos: [], containing: today, calendar: calendar
        )
        #expect(month.values.allSatisfy { $0 == 0 })
        #expect(DayBoardLogic.todayProgress(routines: [], checks: [], todos: [], dayKey: today).total == 0)
    }

    @Test func singleDayAndNewYearBoundaryStayEquivalent() {
        let calendar = utcCalendar
        let daily = routine("每天", created: "2026-12-30")
        let checks = [
            CheckSnapshot(routineId: daily.id, dayKey: "2026-12-30", isDone: true)
        ]
        let rows = AgendaProjection.overdueRoutines(
            routines: [daily], checks: checks, todayKey: "2027-01-02", calendar: calendar
        )
        let naive = AgendaDayBoardOracle.overdueRoutines(
            routines: [daily], checks: checks, todayKey: "2027-01-02", calendar: calendar
        )
        #expect(rows == naive)
        #expect(rows.first?.displayDayKey == "2027-01-01")
        #expect(rows.first?.openCount == 2)
        let overdueTodo = todo("跨年", day: "2026-12-31")
        let upcomingTodo = todo("明年", day: "2027-01-03")
        let pending = AgendaProjection.pending(
            routines: [], checks: [], todos: [overdueTodo, upcomingTodo],
            todayKey: "2027-01-02", calendar: calendar
        )
        #expect(pending.overdue.map(\.dayKey) == ["2026-12-31"])
        #expect(pending.upcoming.map(\.dayKey) == ["2027-01-03"])
    }

    @Test func leapDayAndCivilWeekdayAreTimezoneIndependent() {
        let daily = routine("闰年", created: "2024-02-28")
        for calendar in [utcCalendar, losAngelesCalendar] {
            expectOpenDaysMatch(
                daily, checks: [], from: "2024-02-28", through: "2024-03-01", calendar: calendar
            )
            let rows = AgendaProjection.overdueRoutines(
                routines: [daily], checks: [], todayKey: "2024-03-02", calendar: calendar
            )
            #expect(rows.first?.displayDayKey == "2024-03-01")
            #expect(AgendaProjection.openScheduledDays(
                daily, checks: [], from: "2024-02-28", through: "2024-03-01", calendar: calendar
            ).contains("2024-02-29"))
            #expect(DayBoardLogic.isRoutineDue(daily, on: "2024-02-29", calendar: calendar))
        }
    }

    @Test func pauseAndResumeKeepOverdueOnEnabledHistoryOnly() {
        let calendar = utcCalendar
        var paused = routine("停用", enabled: false, created: "2026-09-01", pausedOnDayKey: "2026-09-04")
        #expect(
            AgendaProjection.overdueRoutines(
                routines: [paused], checks: [], todayKey: "2026-09-07", calendar: calendar
            ).isEmpty
        )
        paused.isEnabled = true
        let rows = AgendaProjection.overdueRoutines(
            routines: [paused], checks: [], todayKey: "2026-09-07", calendar: calendar
        )
        let naive = AgendaDayBoardOracle.overdueRoutines(
            routines: [paused], checks: [], todayKey: "2026-09-07", calendar: calendar
        )
        #expect(rows == naive)
        #expect((rows.first?.openCount ?? 0) > 0)
    }

    @Test func skipMissAndOffDayStayEquivalent() {
        let calendar = utcCalendar
        let workdays = routine("工作日", mask: WeekdayMask.workdays, created: "2026-09-01")
        let weekend = routine("周末", mask: 1 | 64, created: "2026-09-01")
        let skipped = CheckSnapshot(
            routineId: workdays.id, dayKey: "2026-09-04", isDone: true, isSkipped: true
        )
        let done = CheckSnapshot(routineId: workdays.id, dayKey: "2026-09-03", isDone: true)
        let offDayCheck = CheckSnapshot(routineId: workdays.id, dayKey: "2026-09-06", isDone: true)
        let checks = [skipped, done, offDayCheck]
        let today = "2026-09-07"
        let actual = AgendaProjection.overdueRoutines(
            routines: [workdays, weekend], checks: checks, todayKey: today, calendar: calendar
        )
        let naive = AgendaDayBoardOracle.overdueRoutines(
            routines: [workdays, weekend], checks: checks, todayKey: today, calendar: calendar
        )
        #expect(actual == naive)
        #expect(actual.contains { $0.routineID == workdays.id })
        expectOpenDaysMatch(
            workdays, checks: checks, from: "2026-09-01", through: "2026-09-06", calendar: calendar
        )
        expectOpenDaysMatch(
            weekend, checks: checks, from: "2026-09-01", through: "2026-09-06", calendar: calendar
        )
    }

    @Test func softDeleteAndFilterLookUpTheFirstMatchingRoutine() {
        let calendar = utcCalendar
        let tag = UUID()
        let gone = routine("已删", created: "2026-09-01", deleted: true, tags: tag.uuidString)
        let tagged = routine("标签", created: "2026-09-01", sortOrder: 1, tags: tag.uuidString)
        let other = routine("其他", created: "2026-09-01", sortOrder: 2)
        let deletedTodo = todo("删待办", day: "2026-09-01", deleted: true)
        let liveTodo = todo("活待办", day: "2026-09-01", tags: tag.uuidString)
        let projection = AgendaProjection.pending(
            routines: [gone, tagged, other],
            checks: [],
            todos: [deletedTodo, liveTodo],
            todayKey: "2026-09-07",
            calendar: calendar
        )
        #expect(projection.overdue.contains { $0.modelID == gone.id } == false)
        #expect(projection.overdue.contains { $0.modelID == deletedTodo.id } == false)
        let filter = BoardFilter().withTag(tag)
        let actual = AgendaProjection.filtered(
            projection.overdue, filter: filter, routines: [gone, tagged, other],
            checks: [], todayKey: "2026-09-07"
        )
        let naive = AgendaDayBoardOracle.filtered(
            projection.overdue, filter: filter, routines: [gone, tagged, other],
            checks: [], todayKey: "2026-09-07"
        )
        #expect(actual == naive)
        #expect(actual.contains { $0.modelID == tagged.id })
        #expect(actual.contains { $0.modelID == liveTodo.id })
        #expect(!actual.contains { $0.modelID == other.id })
    }

    @Test func duplicateChecksKeepFirstMatchOnBoardAndAnyClosedOnAgenda() {
        let calendar = utcCalendar
        let item = routine("重复打卡", created: "2026-09-07")
        let firstOpen = CheckSnapshot(routineId: item.id, dayKey: "2026-09-07", isDone: false, isSkipped: false)
        let laterClosed = CheckSnapshot(routineId: item.id, dayKey: "2026-09-07", isDone: true)
        let checks = [firstOpen, laterClosed]
        #expect(DayBoardLogic.isRoutineDone(item, checks: checks, on: "2026-09-07") == false)
        #expect(
            DayBoardLogic.openRoutines(routines: [item], checks: checks, dayKey: "2026-09-07").map(\.id)
                == [item.id]
        )
        let openDays = AgendaProjection.openScheduledDays(
            item, checks: checks, from: "2026-09-07", through: "2026-09-07", calendar: calendar
        )
        #expect(openDays.isEmpty)
        expectOpenDaysMatch(
            item, checks: checks, from: "2026-09-07", through: "2026-09-07", calendar: calendar
        )
    }

    @Test func legacyPausedFieldDoesNotInventAnInspectionDay() {
        let calendar = utcCalendar
        var snapshot = routine("旧停用", enabled: false, created: "not-a-day", pausedOnDayKey: "2026-09-01")
        #expect(AgendaProjection.inspectionDay(for: snapshot, todayKey: "2026-09-07", calendar: calendar) == "2026-09-01")
        snapshot.pausedOnDayKey = nil
        snapshot.createdDayKey = "2026-09-01"
        #expect(AgendaProjection.inspectionDay(for: snapshot, todayKey: "2026-09-07", calendar: calendar) == "2026-09-08")
    }

    @Test func fourThousandDayCapMatchesNaiveWalk() {
        let calendar = utcCalendar
        let daily = routine("长历史", created: "2010-01-01")
        let checks = [
            CheckSnapshot(routineId: daily.id, dayKey: "2010-01-01", isDone: true)
        ]
        expectOpenDaysMatch(
            daily, checks: checks, from: "2010-01-01", through: "2026-09-06", calendar: calendar
        )
        let actual = AgendaProjection.overdueRoutines(
            routines: [daily], checks: checks, todayKey: "2026-09-07", calendar: calendar
        )
        let naive = AgendaDayBoardOracle.overdueRoutines(
            routines: [daily], checks: checks, todayKey: "2026-09-07", calendar: calendar
        )
        #expect(actual == naive)
        #expect(actual.first?.openCount == 3999)
    }

    @Test func monthUnfinishedMatchesLinearBadgeAndFirstCheckWins() {
        let calendar = utcCalendar
        let weekday = routine("工作日", mask: WeekdayMask.workdays, created: "2026-09-01")
        let firstOpen = CheckSnapshot(routineId: weekday.id, dayKey: "2026-09-07", isDone: false)
        let laterClosed = CheckSnapshot(routineId: weekday.id, dayKey: "2026-09-07", isDone: true)
        let todos = [
            todo("预约", day: "2026-09-10"),
            todo("已做", day: "2026-09-10", done: true),
            todo("已删", day: "2026-09-07", deleted: true)
        ]
        let checks = [firstOpen, laterClosed]
        let actual = DayBoardLogic.monthUnfinished(
            routines: [weekday], checks: checks, todos: todos, containing: "2026-09-07", calendar: calendar
        )
        let naive = AgendaDayBoardOracle.monthUnfinished(
            routines: [weekday], checks: checks, todos: todos, containing: "2026-09-07", calendar: calendar
        )
        #expect(actual == naive)
        for key in DayKey.daysInMonth(containing: "2026-09-07", calendar: calendar) {
            #expect(
                actual[key] == DayBoardLogic.todayBadgeCount(
                    routines: [weekday], checks: checks, todos: todos, dayKey: key, calendar: calendar
                )
            )
        }
        #expect(actual["2026-09-07"] == 1)
        #expect(actual["2026-09-06"] == 0)
    }

    @Test func randomHistoriesStayEquivalent() {
        let calendar = utcCalendar
        var rng = EmpiricalPRNG(seed: 20260928)
        let masks = [WeekdayMask.all, WeekdayMask.workdays, 1 << 1, 1 | 64]
        for trial in 0..<40 {
            let createdOffset = rng.nextInt(in: 0..<80)
            let span = rng.nextInt(in: 8..<120)
            let startDate = calendar.date(byAdding: .day, value: createdOffset, to: Date(timeIntervalSince1970: 1_700_000_000))!
            let created = DayKey.from(startDate, calendar: calendar)
            let todayDate = calendar.date(byAdding: .day, value: span, to: startDate)!
            let today = DayKey.from(todayDate, calendar: calendar)
            let item = routine(
                "fuzz-\(trial)",
                mask: masks[rng.nextInt(in: 0..<masks.count)],
                enabled: rng.nextInt(in: 0..<10) != 0,
                created: created,
                deleted: rng.nextInt(in: 0..<15) == 0
            )
            var checks: [CheckSnapshot] = []
            var cursor = startDate
            for _ in 0..<span {
                let key = DayKey.from(cursor, calendar: calendar)
                let roll = rng.nextInt(in: 0..<7)
                if roll == 0 {
                    checks.append(CheckSnapshot(routineId: item.id, dayKey: key, isDone: true))
                } else if roll == 1 {
                    checks.append(
                        CheckSnapshot(routineId: item.id, dayKey: key, isDone: true, isSkipped: true)
                    )
                } else if roll == 2 {
                    checks.append(CheckSnapshot(routineId: item.id, dayKey: key, isDone: false))
                    checks.append(CheckSnapshot(routineId: item.id, dayKey: key, isDone: true))
                }
                cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
            }
            expectOpenDaysMatch(
                item, checks: checks, from: created, through: DayKey.shifted(today, by: -1, calendar: calendar),
                calendar: calendar
            )
            let actual = AgendaProjection.overdueRoutines(
                routines: [item], checks: checks, todayKey: today, calendar: calendar
            )
            let naive = AgendaDayBoardOracle.overdueRoutines(
                routines: [item], checks: checks, todayKey: today, calendar: calendar
            )
            #expect(actual == naive, "trial \(trial)")
        }
    }

    @Test func overdueRoutinesScaleStaysEquivalentAndFast() {
        let calendar = utcCalendar
        let created = "2023-12-12"
        var routines: [RoutineSnapshot] = []
        var checks: [CheckSnapshot] = []
        for index in 0..<20 {
            let item = routine(
                "scale-\(index)",
                mask: index.isMultiple(of: 2) ? WeekdayMask.workdays : WeekdayMask.all,
                created: created,
                sortOrder: index
            )
            routines.append(item)
            var cursor = DayKey.date(from: created, calendar: calendar)!
            for day in 0..<1000 {
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
        }
        let todayKey = "2026-09-07"
        _ = AgendaProjection.overdueRoutines(
            routines: routines, checks: checks, todayKey: todayKey, calendar: calendar
        )
        _ = AgendaDayBoardOracle.overdueRoutines(
            routines: routines, checks: checks, todayKey: todayKey, calendar: calendar
        )
        var indexed: [RoutineAgendaRow] = []
        var naive: [RoutineAgendaRow] = []
        var indexedSamples: [TimeInterval] = []
        var naiveSamples: [TimeInterval] = []
        for _ in 1...3 {
            indexedSamples.append(elapsedSeconds {
                indexed = AgendaProjection.overdueRoutines(
                    routines: routines, checks: checks, todayKey: todayKey, calendar: calendar
                )
            })
            naiveSamples.append(elapsedSeconds {
                naive = AgendaDayBoardOracle.overdueRoutines(
                    routines: routines, checks: checks, todayKey: todayKey, calendar: calendar
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

    @Test func monthUnfinishedScaleStaysEquivalentAndFast() {
        let calendar = utcCalendar
        var routines: [RoutineSnapshot] = []
        var checks: [CheckSnapshot] = []
        var todos: [TodoSnapshot] = []
        for index in 0..<30 {
            let item = routine(
                "month-\(index)",
                mask: index.isMultiple(of: 3) ? WeekdayMask.workdays : WeekdayMask.all,
                created: "2026-08-01",
                sortOrder: index
            )
            routines.append(item)
            checks.append(CheckSnapshot(routineId: item.id, dayKey: "2026-09-03", isDone: true))
            todos.append(todo("t-\(index)", day: index.isMultiple(of: 2) ? "2026-09-10" : "2026-09-07"))
        }
        let containing = "2026-09-07"
        _ = DayBoardLogic.monthUnfinished(
            routines: routines, checks: checks, todos: todos, containing: containing, calendar: calendar
        )
        var indexed: [String: Int] = [:]
        var naive: [String: Int] = [:]
        var indexedSamples: [TimeInterval] = []
        var naiveSamples: [TimeInterval] = []
        for _ in 1...3 {
            indexedSamples.append(elapsedSeconds {
                indexed = DayBoardLogic.monthUnfinished(
                    routines: routines, checks: checks, todos: todos, containing: containing, calendar: calendar
                )
            })
            naiveSamples.append(elapsedSeconds {
                naive = AgendaDayBoardOracle.monthUnfinished(
                    routines: routines, checks: checks, todos: todos, containing: containing, calendar: calendar
                )
            })
        }
        let indexedMedian = medianElapsed(indexedSamples)
        let naiveMedian = medianElapsed(naiveSamples)
        #expect(indexed == naive)
        #expect(
            indexedMedian < 0.2,
            "month indexed median \(indexedMedian)s vs naive median \(naiveMedian)s"
        )
        #expect(indexedMedian <= naiveMedian + 0.05)
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
