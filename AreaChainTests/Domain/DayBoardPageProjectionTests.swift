import Foundation
import Testing
@testable import AreaChain

struct DayBoardPageProjectionTests {
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test func checkIndexKeepsFirstMarkAndMatchesLegacyScan() {
        let routineID = UUID()
        let checks = [
            CheckSnapshot(routineId: routineID, dayKey: "2026-09-07", isDone: false),
            CheckSnapshot(routineId: routineID, dayKey: "2026-09-07", isDone: true, isSkipped: true)
        ]
        let index = DayBoardCheckIndex(checks)
        let routine = RoutineSnapshot(
            id: routineID, title: "日报", sortOrder: 0, isEnabled: true, createdDayKey: "2026-09-01"
        )
        #expect(index.isClosed(routineId: routineID, dayKey: "2026-09-07") == false)
        #expect(index.isSkipped(routineId: routineID, dayKey: "2026-09-07") == false)
        #expect(DayBoardLogic.isRoutineDone(routine, checks: checks, on: "2026-09-07") == false)
        #expect(DayBoardLogic.check(for: routine, checks: checks, on: "2026-09-07")?.isDone == false)
    }

    @Test func dayPartitionMatchesOpenAndCompletedLists() {
        let today = "2026-09-07"
        let openTodo = TodoSnapshot(id: UUID(), title: "开", isDone: false, dayKey: today)
        let doneTodo = TodoSnapshot(id: UUID(), title: "完", isDone: true, dayKey: today)
        let other = TodoSnapshot(id: UUID(), title: "别日", isDone: false, dayKey: "2026-09-08")
        let due = RoutineSnapshot(
            id: UUID(), title: "日报", sortOrder: 0, isEnabled: true, createdDayKey: "2026-09-01"
        )
        let closed = RoutineSnapshot(
            id: UUID(), title: "复盘", sortOrder: 1, isEnabled: true, createdDayKey: "2026-09-01"
        )
        let checks = [CheckSnapshot(routineId: closed.id, dayKey: today, isDone: true)]
        let source = DayBoardSource(
            routines: [due, closed],
            checks: checks,
            todos: [openTodo, doneTodo, other]
        )
        let lists = DayBoardDayProjection.partition(source: source, dayKey: today, calendar: utcCalendar)
        #expect(lists.openTodos.map(\.id) == DayBoardLogic.openTodos(todos: source.todos, dayKey: today).map(\.id))
        #expect(lists.doneTodos.map(\.id) == DayBoardLogic.completedTodos(todos: source.todos, dayKey: today).map(\.id))
        #expect(
            lists.openRoutines.map(\.id)
                == DayBoardLogic.openRoutines(
                    routines: source.routines, checks: source.checks, dayKey: today
                ).map(\.id)
        )
        #expect(
            lists.doneRoutines.map(\.id)
                == DayBoardLogic.completedRoutines(
                    routines: source.routines, checks: source.checks, dayKey: today
                ).map(\.id)
        )
    }

    @Test func pageProjectionMatchesListedTodayYesterdayAndUpcoming() throws {
        let today = "2026-09-11"
        let yesterday = "2026-09-10"
        let yesterdayTodo = TodoSnapshot(id: UUID(), title: "昨天", isDone: false, dayKey: yesterday)
        let todayTodo = TodoSnapshot(id: UUID(), title: "今天", isDone: false, dayKey: today)
        let future = TodoSnapshot(id: UUID(), title: "即将", isDone: false, dayKey: "2026-09-12")
        let yesterdayDate = try #require(DayKey.date(from: yesterday, calendar: utcCalendar))
        let weekday = utcCalendar.component(.weekday, from: yesterdayDate)
        let habit = RoutineSnapshot(
            id: UUID(),
            title: "昨天习惯",
            sortOrder: 0,
            isEnabled: true,
            createdDayKey: "2026-09-01",
            weekdayMask: 1 << (weekday - 1)
        )
        let source = DayBoardSource(
            routines: [habit],
            checks: [],
            todos: [yesterdayTodo, todayTodo, future]
        )
        let overdue = DayBoardPageProjection.project(
            source: source,
            todayKey: today,
            yesterdayKey: yesterday,
            filter: BoardFilter().withDateScope(.overdue),
            calendar: utcCalendar
        )
        #expect(overdue.yesterdayItems.map(\.id) == [habit.id, yesterdayTodo.id])
        #expect(overdue.upcomingTodos.isEmpty)
        #expect(overdue.todayVisibleIDs.isEmpty)

        let todayOnly = DayBoardPageProjection.project(
            source: source,
            todayKey: today,
            yesterdayKey: yesterday,
            filter: BoardFilter().withDateScope(.today),
            calendar: utcCalendar
        )
        #expect(todayOnly.yesterdayItems.isEmpty)
        #expect(todayOnly.upcomingTodos.isEmpty)
        #expect(todayOnly.todayVisibleIDs == [todayTodo.id])

        let upcoming = DayBoardPageProjection.project(
            source: source,
            todayKey: today,
            yesterdayKey: yesterday,
            filter: BoardFilter().withDateScope(.upcoming),
            calendar: utcCalendar
        )
        #expect(upcoming.yesterdayItems.isEmpty)
        #expect(upcoming.upcomingTodos.map(\.id) == [future.id])
        #expect(upcoming.todayVisibleIDs.isEmpty)
    }

    @Test @MainActor func attachmentIndexMatchesLinearLiveLookup() {
        let owner = UUID()
        let other = UUID()
        let live = AttachmentItem(
            ownerKind: AttachmentOwner.todo.rawValue, ownerID: owner, filename: "a.png",
            createdAt: Date(timeIntervalSince1970: 2)
        )
        let earlier = AttachmentItem(
            ownerKind: AttachmentOwner.todo.rawValue, ownerID: owner, filename: "b.png",
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let deleted = AttachmentItem(
            ownerKind: AttachmentOwner.todo.rawValue, ownerID: owner, filename: "gone.png",
            createdAt: Date(timeIntervalSince1970: 3),
            deletedAt: Date(timeIntervalSince1970: 4)
        )
        let routineShot = AttachmentItem(
            ownerKind: AttachmentOwner.routine.rawValue, ownerID: owner, filename: "r.png"
        )
        let stranger = AttachmentItem(
            ownerKind: AttachmentOwner.todo.rawValue, ownerID: other, filename: "x.png"
        )
        let items = [live, earlier, deleted, routineShot, stranger]
        let index = CatalogAttachmentIndex(items)
        let expected = Catalog.liveAttachments(for: owner, in: items, ownerKind: .todo)
        #expect(index.live(ownerID: owner, ownerKind: .todo).map(\.id) == expected.map(\.id))
        #expect(expected.map(\.filename) == ["b.png", "a.png"])
    }

    @Test func pageProjectionScaleStaysEquivalentAndFast() {
        let calendar = utcCalendar
        var routines: [RoutineSnapshot] = []
        var checks: [CheckSnapshot] = []
        var todos: [TodoSnapshot] = []
        for index in 0..<40 {
            let item = RoutineSnapshot(
                id: UUID(),
                title: "r-\(index)",
                sortOrder: index,
                isEnabled: true,
                createdDayKey: "2026-08-01",
                weekdayMask: index.isMultiple(of: 3) ? WeekdayMask.workdays : WeekdayMask.all
            )
            routines.append(item)
            checks.append(CheckSnapshot(routineId: item.id, dayKey: "2026-09-07", isDone: index.isMultiple(of: 2)))
            todos.append(
                TodoSnapshot(
                    id: UUID(),
                    title: "t-\(index)",
                    isDone: index.isMultiple(of: 5),
                    dayKey: index.isMultiple(of: 2) ? "2026-09-07" : "2026-09-08"
                )
            )
        }
        let today = "2026-09-07"
        let yesterday = "2026-09-06"
        let filter = BoardFilter()
        let source = DayBoardSource(routines: routines, checks: checks, todos: todos)
        _ = DayBoardPageProjection.project(
            source: source, todayKey: today, yesterdayKey: yesterday, filter: filter, calendar: calendar
        )
        _ = naivePageAccesses(
            routines: routines, checks: checks, todos: todos,
            today: today, yesterday: yesterday, filter: filter, calendar: calendar
        )

        var indexed: DayBoardPageSnapshot?
        var naive: NaivePageAccess?
        var indexedSamples: [TimeInterval] = []
        var naiveSamples: [TimeInterval] = []
        for _ in 1...3 {
            indexedSamples.append(elapsedSeconds {
                let built = DayBoardSource(routines: routines, checks: checks, todos: todos)
                indexed = DayBoardPageProjection.project(
                    source: built, todayKey: today, yesterdayKey: yesterday, filter: filter, calendar: calendar
                )
                _ = DayBoardDayProjection.partition(source: built, dayKey: today, calendar: calendar)
            })
            naiveSamples.append(elapsedSeconds {
                naive = naivePageAccesses(
                    routines: routines, checks: checks, todos: todos,
                    today: today, yesterday: yesterday, filter: filter, calendar: calendar
                )
            })
        }
        let indexedMedian = medianElapsed(indexedSamples)
        let naiveMedian = medianElapsed(naiveSamples)
        #expect(indexed?.todayVisibleIDs == naive?.todayVisibleIDs)
        #expect(indexed?.yesterdayItems.map(\.id) == naive?.yesterdayIDs)
        #expect(
            indexedMedian < 0.2,
            "indexed median \(indexedMedian)s vs naive median \(naiveMedian)s"
        )
        #expect(indexedMedian <= naiveMedian + 0.05)
        print("DAYBOARD_PAGE indexed=\(indexedMedian) naive=\(naiveMedian)")
    }

    private struct NaivePageAccess {
        var todayVisibleIDs: [UUID]
        var yesterdayIDs: [UUID]
    }

    private func naivePageAccesses(
        routines: [RoutineSnapshot],
        checks: [CheckSnapshot],
        todos: [TodoSnapshot],
        today: String,
        yesterday: String,
        filter: BoardFilter,
        calendar: Calendar
    ) -> NaivePageAccess {
        var todayVisibleIDs: [UUID] = []
        var yesterdayIDs: [UUID] = []
        for _ in 0..<8 {
            let snapshots = (routines, checks, todos)
            todayVisibleIDs = DayBoardLogic.openBoardItems(
                routines: snapshots.0, checks: snapshots.1, todos: snapshots.2, dayKey: today
            ).map(\.modelID)
            yesterdayIDs = DayBoardLogic.yesterdayUnfinished(
                routines: snapshots.0, checks: snapshots.1, todos: snapshots.2, yesterdayKey: yesterday
            ).map(\.id)
            _ = DayBoardLogic.openRoutines(routines: snapshots.0, checks: snapshots.1, dayKey: today)
            _ = DayBoardLogic.completedRoutines(routines: snapshots.0, checks: snapshots.1, dayKey: today)
            _ = DayBoardLogic.upcomingTodos(todos: snapshots.2, todayKey: today)
            _ = Classification.matchesListedRow(
                ClassifyBits(),
                dayKey: today,
                isDone: false,
                remindMinutes: nil,
                todayKey: today,
                filter: filter
            )
            _ = calendar
        }
        return NaivePageAccess(todayVisibleIDs: todayVisibleIDs, yesterdayIDs: yesterdayIDs)
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
