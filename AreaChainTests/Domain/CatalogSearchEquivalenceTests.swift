import Foundation
import Testing
@testable import AreaChain

struct CatalogSearchEquivalenceTests {
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

    @Test func emptyInputsStayEmpty() {
        let tag = TagItem(name: "工作", sortOrder: 0)
        #expect(
            Catalog.matchingListedRoutines([], checks: [], tag: tag, dayKey: "2026-09-07", open: true).isEmpty
        )
        #expect(
            Catalog.openCount(todos: [], routines: [], checks: [], tag: tag, dayKey: "2026-09-07") == 0
        )
        #expect(
            Catalog.openCount(todos: [], routines: [], checks: [], tag: nil, dayKey: "2026-09-07") == 0
        )
        #expect(
            BoardSearch.hits(query: "日报", todos: [], diaries: [], routines: [], checks: [], todayKey: "2026-09-07")
                .isEmpty
        )
        expectCatalogEquivalent(tag: tag, dayKey: "2026-09-07")
        expectSearchEquivalent(query: "日报", today: "2026-09-07", calendar: utcCalendar)
    }

    @Test func singleDayAndNewYearBoundaryStayEquivalent() {
        let calendar = utcCalendar
        let tag = TagItem(name: "工作", sortOrder: 0)
        let habit = DailyRoutine(
            title: "跨年", sortOrder: 0, createdDayKey: "2026-12-30", tagIDs: tag.id.uuidString
        )
        let closed = RoutineCheck(dayKey: "2026-12-30", isDone: true, routine: habit)
        expectCatalogEquivalent(
            tag: tag,
            dayKey: "2026-12-31",
            todos: [TodoItem(title: "旧", dayKey: "2026-12-31", tagIDs: tag.id.uuidString)],
            routines: [habit],
            checks: [closed]
        )
        let snapshot = habit.snapshot
        let todo = TodoSnapshot(id: UUID(), title: "跨年待办", isDone: false, dayKey: "2026-12-31")
        expectSearchEquivalent(
            query: "跨年",
            today: "2027-01-02",
            todos: [todo],
            routines: [snapshot],
            checks: [CheckSnapshot(routineId: snapshot.id, dayKey: "2026-12-30", isDone: true)],
            calendar: calendar
        )
        let overdueHits = BoardSearch.hits(
            query: "跨年",
            todos: [],
            diaries: [],
            routines: [snapshot],
            checks: [CheckSnapshot(routineId: snapshot.id, dayKey: "2026-12-30", isDone: true)],
            todayKey: "2027-01-02",
            scope: BoardSearchScope(filter: BoardFilter(dateScope: .overdue)),
            calendar: calendar
        )
        #expect(overdueHits.first?.dayKey == "2027-01-01")
    }

    @Test func leapDayAndCivilWeekdayAreTimezoneIndependent() {
        let tag = TagItem(name: "工作", sortOrder: 0)
        let habit = DailyRoutine(
            title: "闰年", sortOrder: 0, createdDayKey: "2024-02-28", tagIDs: tag.id.uuidString
        )
        expectCatalogEquivalent(tag: tag, dayKey: "2024-02-29", routines: [habit])
        let snapshot = habit.snapshot
        for calendar in [utcCalendar, losAngelesCalendar] {
            expectSearchEquivalent(
                query: "闰年",
                today: "2024-03-01",
                routines: [snapshot],
                calendar: calendar
            )
            let hits = BoardSearch.hits(
                query: "闰年",
                todos: [],
                diaries: [],
                routines: [snapshot],
                todayKey: "2024-02-29",
                calendar: calendar
            )
            #expect(hits.first?.dayKey == "2024-02-29")
        }
    }

    @Test func pauseResumeSkipMissOffDayAndFirstWinsStayEquivalent() {
        let tag = TagItem(name: "工作", sortOrder: 0)
        let encoded = tag.id.uuidString
        let due = DailyRoutine(title: "该打", sortOrder: 0, createdDayKey: "2026-09-01", tagIDs: encoded)
        let paused = DailyRoutine(
            title: "停用", sortOrder: 1, isEnabled: false, createdDayKey: "2026-09-01", tagIDs: encoded
        )
        let weekend = DailyRoutine(
            title: "周末", sortOrder: 2, createdDayKey: "2026-09-01",
            weekdayMask: WeekdayMask.all ^ WeekdayMask.workdays, tagIDs: encoded
        )
        let skipped = DailyRoutine(title: "跳过", sortOrder: 3, createdDayKey: "2026-09-01", tagIDs: encoded)
        let duplicate = DailyRoutine(title: "先写未闭合", sortOrder: 4, createdDayKey: "2026-09-01", tagIDs: encoded)
        let otherDay = RoutineCheck(dayKey: "2026-09-08", isDone: true, routine: duplicate)
        let openFirst = RoutineCheck(dayKey: "2026-09-09", isDone: false, routine: duplicate)
        let laterDone = RoutineCheck(dayKey: "2026-09-09", isDone: true, routine: duplicate)
        let skipMark = RoutineCheck(dayKey: "2026-09-09", isDone: true, isSkipped: true, routine: skipped)
        expectCatalogEquivalent(
            tag: tag,
            dayKey: "2026-09-09",
            todos: [
                TodoItem(title: "未完成", dayKey: "2026-09-09", tagIDs: encoded),
                TodoItem(title: "已完成", isDone: true, dayKey: "2026-09-09", tagIDs: encoded)
            ],
            routines: [due, paused, weekend, skipped, duplicate],
            checks: [otherDay, openFirst, laterDone, skipMark]
        )
        let listed = Catalog.matchingListedRoutines(
            [due, paused, weekend, skipped, duplicate],
            checks: [otherDay, openFirst, laterDone, skipMark],
            tag: tag,
            dayKey: "2026-09-09",
            open: true
        )
        #expect(listed.map(\.title) == ["该打", "停用", "周末", "先写未闭合"])
        #expect(
            Catalog.matchingListedRoutines(
                [due, paused, weekend, skipped, duplicate],
                checks: [otherDay, openFirst, laterDone, skipMark],
                tag: tag,
                dayKey: "2026-09-09",
                open: false
            ).map(\.title) == ["跳过"]
        )
    }

    @Test func softDeleteFilterAndLegacyDisableStayEquivalent() {
        let tag = TagItem(name: "工作", sortOrder: 0)
        let buriedTag = TagItem(name: "归档", sortOrder: 1, deletedAt: Date(timeIntervalSince1970: 1))
        let encoded = tag.id.uuidString
        let live = TodoItem(title: "活", dayKey: "2026-09-09", tagIDs: encoded)
        let buried = TodoItem(
            title: "删", dayKey: "2026-09-09", deletedAt: Date(timeIntervalSince1970: 2), tagIDs: encoded
        )
        let child = SubtaskItem(title: "子", tagIDs: encoded, todo: live)
        live.subtasks = [child]
        let goneHabit = DailyRoutine(
            title: "已删习惯", sortOrder: 0, createdDayKey: "2026-09-01",
            deletedAt: Date(timeIntervalSince1970: 3), tagIDs: encoded
        )
        expectCatalogEquivalent(
            tag: tag,
            dayKey: "2026-09-09",
            todos: [live, buried],
            routines: [goneHabit]
        )
        #expect(
            Catalog.openCount(todos: [live, buried], routines: [goneHabit], checks: [], tag: buriedTag, dayKey: "2026-09-09")
                == 0
        )
        var removed = live.snapshot
        removed.deletedAt = Date(timeIntervalSince1970: 4)
        var disabled = RoutineSnapshot(
            id: UUID(), title: "日报", sortOrder: 0, isEnabled: false, createdDayKey: "2026-01-01"
        )
        disabled.pausedOnDayKey = "2026-09-01"
        expectSearchEquivalent(
            query: "日报",
            today: "2026-09-09",
            todos: [removed],
            routines: [disabled],
            scope: BoardSearchScope(filter: BoardFilter(dateScope: .overdue)),
            calendar: utcCalendar
        )
    }

    @Test func overdueSearchUsesPendingDayAndStaysEquivalentAtScale() {
        let calendar = utcCalendar
        var routines: [RoutineSnapshot] = []
        var checks: [CheckSnapshot] = []
        for index in 0..<20 {
            let id = UUID()
            routines.append(
                RoutineSnapshot(
                    id: id,
                    title: "日报-\(index)",
                    sortOrder: index,
                    isEnabled: index != 7,
                    createdDayKey: "2023-12-11",
                    weekdayMask: index.isMultiple(of: 3) ? WeekdayMask.workdays : WeekdayMask.all,
                    deletedAt: index == 13 ? Date(timeIntervalSince1970: 1) : nil
                )
            )
            var cursor = DayKey.date(from: "2023-12-11", calendar: calendar)!
            for day in 0..<1000 {
                let key = DayKey.from(cursor, calendar: calendar)
                if day % 37 == 0 {
                    checks.append(CheckSnapshot(routineId: id, dayKey: key, isDone: true))
                } else if day % 41 == 0 {
                    checks.append(CheckSnapshot(routineId: id, dayKey: key, isDone: true, isSkipped: true))
                }
                cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
            }
        }
        let todayKey = "2026-09-07"
        let scope = BoardSearchScope(filter: BoardFilter(dateScope: .overdue))
        expectSearchEquivalent(
            query: "日报",
            today: todayKey,
            routines: routines,
            checks: checks,
            scope: scope,
            calendar: calendar
        )
        _ = BoardSearch.hits(
            query: "日报", todos: [], diaries: [], routines: routines, checks: checks,
            todayKey: todayKey, scope: scope, calendar: calendar
        )
        _ = CatalogSearchOracle.hits(
            query: "日报", todos: [], diaries: [], routines: routines, checks: checks,
            todayKey: todayKey, scope: scope, calendar: calendar
        )
        var indexed: [BoardSearchHit] = []
        var naive: [BoardSearchHit] = []
        var indexedSamples: [TimeInterval] = []
        var naiveSamples: [TimeInterval] = []
        for _ in 1...3 {
            indexedSamples.append(elapsedSeconds {
                indexed = BoardSearch.hits(
                    query: "日报", todos: [], diaries: [], routines: routines, checks: checks,
                    todayKey: todayKey, scope: scope, calendar: calendar
                )
            })
            naiveSamples.append(elapsedSeconds {
                naive = CatalogSearchOracle.hits(
                    query: "日报", todos: [], diaries: [], routines: routines, checks: checks,
                    todayKey: todayKey, scope: scope, calendar: calendar
                )
            })
        }
        let indexedMedian = medianElapsed(indexedSamples)
        let naiveMedian = medianElapsed(naiveSamples)
        #expect(indexed == naive)
        #expect(
            indexedMedian < 0.2,
            "search indexed median \(indexedMedian)s vs naive median \(naiveMedian)s"
        )
        #expect(indexedMedian <= naiveMedian + 0.05)
    }

    @Test func listedRoutinesScaleStaysEquivalentAndFast() {
        let tag = TagItem(name: "工作", sortOrder: 0)
        var routines: [DailyRoutine] = []
        var checks: [RoutineCheck] = []
        var todos: [TodoItem] = []
        for index in 0..<40 {
            let item = DailyRoutine(
                title: "listed-\(index)",
                sortOrder: index,
                createdDayKey: "2025-09-08",
                weekdayMask: index.isMultiple(of: 3) ? WeekdayMask.workdays : WeekdayMask.all,
                tagIDs: tag.id.uuidString
            )
            routines.append(item)
            var cursor = DayKey.date(from: "2025-09-08", calendar: utcCalendar)!
            for day in 0..<365 {
                let key = DayKey.from(cursor, calendar: utcCalendar)
                if day % 11 == 0 {
                    checks.append(RoutineCheck(dayKey: key, isDone: true, routine: item))
                } else if day % 13 == 0 {
                    checks.append(RoutineCheck(dayKey: key, isDone: true, isSkipped: true, routine: item))
                }
                cursor = utcCalendar.date(byAdding: .day, value: 1, to: cursor)!
            }
            let todo = TodoItem(
                title: "todo-\(index)",
                isDone: index.isMultiple(of: 2),
                dayKey: "2026-09-07",
                tagIDs: tag.id.uuidString
            )
            if index.isMultiple(of: 5) {
                todo.subtasks = [SubtaskItem(title: "sub-\(index)", tagIDs: tag.id.uuidString, todo: todo)]
            }
            todos.append(todo)
        }
        let dayKey = "2026-09-07"
        expectCatalogEquivalent(tag: tag, dayKey: dayKey, todos: todos, routines: routines, checks: checks)
        _ = Catalog.matchingListedRoutines(routines, checks: checks, tag: tag, dayKey: dayKey, open: true)
        _ = CatalogSearchOracle.matchingListedRoutines(routines, checks: checks, tag: tag, dayKey: dayKey, open: true)
        var indexed: [DailyRoutine] = []
        var naive: [DailyRoutine] = []
        var indexedSamples: [TimeInterval] = []
        var naiveSamples: [TimeInterval] = []
        for _ in 1...3 {
            indexedSamples.append(elapsedSeconds {
                indexed = Catalog.matchingListedRoutines(
                    routines, checks: checks, tag: tag, dayKey: dayKey, open: true
                )
                _ = Catalog.openCount(todos: todos, routines: routines, checks: checks, tag: tag, dayKey: dayKey)
            })
            naiveSamples.append(elapsedSeconds {
                naive = CatalogSearchOracle.matchingListedRoutines(
                    routines, checks: checks, tag: tag, dayKey: dayKey, open: true
                )
                _ = CatalogSearchOracle.openCount(
                    todos: todos, routines: routines, checks: checks, tag: tag, dayKey: dayKey
                )
            })
        }
        let indexedMedian = medianElapsed(indexedSamples)
        let naiveMedian = medianElapsed(naiveSamples)
        #expect(indexed.map(\.id) == naive.map(\.id))
        #expect(
            indexedMedian < 0.2,
            "catalog indexed median \(indexedMedian)s vs naive median \(naiveMedian)s"
        )
        #expect(indexedMedian <= naiveMedian + 0.05)
    }

    private func expectCatalogEquivalent(
        tag: TagItem?,
        dayKey: String,
        todos: [TodoItem] = [],
        routines: [DailyRoutine] = [],
        checks: [RoutineCheck] = []
    ) {
        #expect(
            Catalog.matchingListedRoutines(routines, checks: checks, tag: tag, dayKey: dayKey, open: true).map(\.id)
                == CatalogSearchOracle.matchingListedRoutines(
                    routines, checks: checks, tag: tag, dayKey: dayKey, open: true
                ).map(\.id)
        )
        #expect(
            Catalog.matchingListedRoutines(routines, checks: checks, tag: tag, dayKey: dayKey, open: false).map(\.id)
                == CatalogSearchOracle.matchingListedRoutines(
                    routines, checks: checks, tag: tag, dayKey: dayKey, open: false
                ).map(\.id)
        )
        #expect(
            Catalog.matchingOpenRoutines(routines, checks: checks, tag: tag, dayKey: dayKey).map(\.id)
                == CatalogSearchOracle.matchingOpenRoutines(routines, checks: checks, tag: tag, dayKey: dayKey).map(\.id)
        )
        #expect(
            Catalog.openCount(todos: todos, routines: routines, checks: checks, tag: tag, dayKey: dayKey)
                == CatalogSearchOracle.openCount(
                    todos: todos, routines: routines, checks: checks, tag: tag, dayKey: dayKey
                )
        )
    }

    private func expectSearchEquivalent(
        query: String,
        today: String,
        todos: [TodoSnapshot] = [],
        diaries: [DiarySnapshot] = [],
        routines: [RoutineSnapshot] = [],
        checks: [CheckSnapshot] = [],
        tagMap: [UUID: String] = [:],
        privacy: BoardSearchPrivacy = BoardSearchPrivacy(),
        scope: BoardSearchScope = BoardSearchScope(),
        calendar: Calendar
    ) {
        let actual = BoardSearch.hits(
            query: query, todos: todos, diaries: diaries, routines: routines, checks: checks,
            todayKey: today, tagMap: tagMap, privacy: privacy, scope: scope, calendar: calendar
        )
        let naive = CatalogSearchOracle.hits(
            query: query, todos: todos, diaries: diaries, routines: routines, checks: checks,
            todayKey: today, tagMap: tagMap, privacy: privacy, scope: scope, calendar: calendar
        )
        #expect(actual == naive)
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
