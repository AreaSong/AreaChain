import Foundation
import Testing
@testable import AreaChain

struct TodoQueryDateTests {
    @Test func dateUnionsIntersectAcrossGroupsWithInclusiveEndpoints() {
        let todos = (1...5).map { TodoQueryFixture.todo($0, day: String(format: "2026-10-%02d", $0)) }
        let source = "(date:2026-10-01..2026-10-03 | date:2026-10-05) date:2026-10-03..2026-10-05"
        let response = TodoQueryFixture.read(source, todos)
        #expect(response.queryIsValid && response.matches.map(\.id.id) == [todos[2].id, todos[4].id])
        let disjoint = TodoQueryFixture.read("date:2026-10-01 date:2026-10-02", todos)
        #expect(disjoint.queryIsValid && disjoint.state == .unsatisfiable && disjoint.matches.isEmpty)
    }

    @Test func createdUsesInjectedCivilDayAndDateUsesScheduledDay() throws {
        var todo = TodoQueryFixture.todo(1, day: "2026-10-03")
        todo.createdAt = try #require(ISO8601DateFormatter().date(from: "2026-09-30T16:30:00Z"))
        let text = "created:2026-10-01 date:2026-10-03"
        let shanghai = TodoQueryFixture.session(text)
        #expect(TodoQueryFixture.read(shanghai, [todo]).matches.count == 1)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let page = ContentQueryPageContext(location: shanghai.page.location, page: .overview,
                                           todayKey: "2026-10-01", calendar: calendar)
        let west = ContentQueryReducer.reduce(.init(page: page), .setInput(text)).state
        #expect(TodoQueryFixture.read(west, [todo]).matches.isEmpty)
        let previous = ContentQueryReducer.reduce(west, .setInput("created:2026-09-30")).state
        #expect(TodoQueryFixture.read(previous, [todo]).matches.count == 1)
        let createdOR = TodoQueryFixture.read("(created:2026-09-30 | created:2026-10-01) created:2026-10-01", [todo])
        #expect(createdOR.matches.count == 1 && createdOR.matches[0].evidence.allSatisfy { $0.field == .createdAt })
    }

    @Test func malformedSnapshotDatesAndTimestampsAreDiagnosedWithoutRollover() {
        let days = ["2026-02-30", "2026-2-03", "", "not-a-day", "2026-13-01"]
        let todos = days.enumerated().map { TodoQueryFixture.todo($0.offset + 1, day: $0.element) }
        let response = TodoQueryFixture.read("项目", todos)
        #expect(response.state == .evaluated && response.matches.isEmpty && !response.isCompleteForCoveredTypes)
        #expect(response.diagnostics.map(\.issue) == Array(repeating: .invalidScheduledDay, count: days.count))
        for value in [Double.nan, .infinity, -.infinity, Double.greatestFiniteMagnitude] {
            var todo = TodoQueryFixture.todo(1)
            todo.createdAt = Date(timeIntervalSince1970: value)
            let invalid = TodoQueryFixture.read("项目", [todo])
            #expect(invalid.matches.isEmpty && invalid.diagnostics.first?.issue == .invalidCreatedAt)
        }
    }

    @Test func allThreePageDateSourcesUseTheirExistingRules() {
        let old = TodoQueryFixture.todo(1, day: "2026-09-30")
        let today = TodoQueryFixture.todo(2)
        let future = TodoQueryFixture.todo(3, day: "2026-10-02")
        var closed = TodoQueryFixture.todo(4, day: "2026-09-29")
        closed.isDone = true
        var completedFuture = TodoQueryFixture.todo(5, day: "2026-10-08")
        completedFuture.isDone = true
        let beyond = TodoQueryFixture.todo(6, day: "2026-10-09")
        let todos = [old, today, future, closed, completedFuture, beyond]
        let cases: [(ContentQueryPage, [UUID])] = [
            (.today(.init(dateScope: .overdue)), [old.id]),
            (.pending(lane: .overdue, filter: .init()), [old.id]),
            (.pending(lane: .upcoming, filter: .init()), [future.id, beyond.id]),
            (.items(.init(filter: .init(dateScope: .recent), todayKey: QuerySessionFixture.today)),
             [today.id, future.id, completedFuture.id]),
            (.today(.init(dateScope: .today)), [today.id]),
            (.today(.init(dateScope: .upcoming)), [future.id, beyond.id])
        ]
        for (page, expected) in cases {
            let result = TodoQueryFixture.read(TodoQueryFixture.session("", page: page), todos)
            #expect(result.state == .evaluated && result.matches.map(\.id.id) == expected)
            #expect(result.matches.allSatisfy { $0.evidence.contains { $0.field == .scheduledDay } })
        }
    }

    @Test func recentForListedAndItemsUsesInjectedCalendarEvenAcrossSkippedCivilDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Pacific/Apia"))
        let todo = TodoQueryFixture.todo(1, day: "2011-12-31")
        #expect(DayKey.shifted("2011-12-23", by: 7, calendar: calendar) == "2011-12-31")
        for evaluation in [ContentQueryPageDateRule.Evaluation.listedDay, .items] {
            let rule = ContentQueryPageDateRule(evaluation: evaluation, todayKey: "2011-12-23", calendar: calendar)
            let state = TodoQueryFixture.add(.page(.boardDate(.recent, rule)), to: TodoQueryFixture.session())
            #expect(TodoQueryFixture.read(state, [todo]).matches.count == 1)
        }
    }

    @Test func unsupportedAgendaDateAndInvalidInjectedContextAreExplicit() {
        let dates = QuerySessionFixture.page().dates
        let unsupported = TodoQueryFixture.add(.page(.boardDate(.recent, .init(evaluation: .agenda,
            todayKey: dates.todayKey, calendar: dates.calendar))), to: TodoQueryFixture.session())
        let response = TodoQueryFixture.read(unsupported, [TodoQueryFixture.todo(1)])
        #expect(response.queryIsValid && response.state == .blocked && response.matches.isEmpty)
        #expect(response.diagnostics.first?.issue == .unsupportedAgendaDate)
        let page = ContentQueryPageContext(location: unsupported.page.location, page: .overview,
                                           todayKey: "2026-02-30", calendar: dates.calendar)
        let invalid = TodoQueryFixture.read(ContentQuerySession(page: page), [TodoQueryFixture.todo(1)])
        #expect(invalid.state == .blocked && invalid.diagnostics.first?.issue == .invalidDateContext)
    }
}
