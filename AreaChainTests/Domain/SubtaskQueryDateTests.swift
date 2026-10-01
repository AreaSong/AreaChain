import Foundation
import Testing
@testable import AreaChain

struct SubtaskQueryDateTests {
    @Test func dateIsParentScheduleButCreatedIsChildCivilDay() throws {
        var parent = SubtaskQueryFixture.parent(1, day: "2026-10-03")
        parent.createdAt = try #require(ISO8601DateFormatter().date(from: "2025-01-01T00:00:00Z"))
        parent.subtasks[0].createdAt = try #require(ISO8601DateFormatter().date(from: "2026-09-30T16:30:00Z"))
        let query = TodoQueryFixture.session("created:today date:2026-10-03")
        let match = try #require(SubtaskQueryFixture.read(query, [parent]).matches.first)
        #expect(match.evidence.map(\.field) == [.createdAt, .parentScheduledDay])
        #expect(match.evidence[1].relatedObject == match.parent && match.evidence[0].relatedObject == nil)
        #expect(match.createdAt == parent.subtasks[0].createdAt && match.parentScheduledDay == parent.dayKey)
        #expect(SubtaskQueryFixture.read("date:2026-10-01", [parent]).matches.isEmpty)
        #expect(SubtaskQueryFixture.read("created:2025-01-01", [parent]).matches.isEmpty)
        var calendar = query.page.calendar
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let page = ContentQueryPageContext(location: query.page.location, page: .overview,
                                           todayKey: "2026-10-01", calendar: calendar)
        let west = ContentQueryReducer.reduce(.init(page: page), .setInput("created:2026-09-30")).state
        #expect(SubtaskQueryFixture.read(west, [parent]).matches.count == 1)
        let wrong = ContentQueryReducer.reduce(.init(page: page), .setInput("created:today")).state
        #expect(SubtaskQueryFixture.read(wrong, [parent]).matches.isEmpty)
    }

    @Test func dateAndCreatedORIntersectWithInclusiveEndpoints() {
        let parents = (1...5).map { SubtaskQueryFixture.parent($0, day: String(format: "2026-10-%02d", $0)) }
        let text = "(date:2026-10-01..2026-10-03 | date:2026-10-05) date:2026-10-03..2026-10-05"
        let result = SubtaskQueryFixture.read(text, parents)
        #expect(result.matches.map(\.id.id) == [parents[2].subtasks[0].id, parents[4].subtasks[0].id])
        let created = "(created:2026-09-30 | created:2026-10-01) created:2026-10-01"
        #expect(SubtaskQueryFixture.read(created, parents).matches.count == 5)
    }

    @Test func listedAgendaAndItemsDatesUseParentStatusAndInjectedToday() {
        var parents = [SubtaskQueryFixture.parent(1, day: "2026-09-30"), SubtaskQueryFixture.parent(2),
                       SubtaskQueryFixture.parent(3, day: "2026-10-02"), SubtaskQueryFixture.parent(4, day: "2026-09-29"),
                       SubtaskQueryFixture.parent(5, day: "2026-10-08"), SubtaskQueryFixture.parent(6, day: "2026-10-09")]
        parents[0].subtasks[0].isDone = true
        parents[3].isDone = true
        parents[4].isDone = true
        let cases: [(ContentQueryPage, [Int])] = [
            (.today(.init(dateScope: .overdue)), [0]),
            (.pending(lane: .overdue, filter: .init()), [0]),
            (.pending(lane: .upcoming, filter: .init()), [2, 5]),
            (.today(.init(dateScope: .today)), [1]),
            (.today(.init(dateScope: .upcoming)), [2, 5]),
            (.items(.init(filter: .init(dateScope: .recent), todayKey: QuerySessionFixture.today)), [1, 2, 4])
        ]
        for (page, indices) in cases {
            let result = SubtaskQueryFixture.read(TodoQueryFixture.session("", page: page), parents)
            #expect(result.isCompleteForCoveredTypes)
            #expect(result.matches.map(\.id.id) == indices.map { parents[$0].subtasks[0].id })
            #expect(result.matches.allSatisfy { match in
                match.evidence.contains { $0.field == .parentScheduledDay && $0.relatedObject == match.parent }
            })
        }
        let recentDone = TodoQueryFixture.session("status:done", page: .today(.init(dateScope: .recent)))
        parents[1].subtasks[0].isDone = true
        #expect(SubtaskQueryFixture.read(recentDone, parents).matches.map(\.id.id) == [parents[1].subtasks[0].id])
    }

    @Test func pageRecentKeepsOwnCalendarAcrossSkippedCivilDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Pacific/Apia"))
        let parent = SubtaskQueryFixture.parent(1, day: "2011-12-31")
        for evaluation in [ContentQueryPageDateRule.Evaluation.listedDay, .items] {
            let rule = ContentQueryPageDateRule(evaluation: evaluation, todayKey: "2011-12-23", calendar: calendar)
            let state = TodoQueryFixture.add(.page(.boardDate(.recent, rule)), to: TodoQueryFixture.session())
            #expect(SubtaskQueryFixture.read(state, [parent]).matches.count == 1)
        }
    }

    @Test func unsupportedAgendaAndTypeSpecificConflictRemainExplicit() {
        let parent = SubtaskQueryFixture.parent(1, day: "2026-09-30")
        let dates = QuerySessionFixture.page().dates
        let query = TodoQueryFixture.add(.page(.boardDate(.recent, .init(evaluation: .agenda,
            todayKey: dates.todayKey, calendar: dates.calendar))), to: TodoQueryFixture.session())
        let result = SubtaskQueryFixture.read(query, [parent])
        #expect(result.queryIsValid && result.state == .blocked && result.matches.isEmpty)
        #expect(result.diagnostics.first?.issue == .unsupportedAgendaDate)
        // 父级逾期不与子项自身完成态冲突；此夹具的子项未完成，因此完整求值后零命中。
        let conflict = TodoQueryFixture.session("status:done", page: .pending(lane: .overdue, filter: .init()))
        let refused = SubtaskQueryFixture.read(conflict, [parent])
        #expect(refused.queryIsValid && refused.state == .evaluated && refused.matches.isEmpty)
        #expect(refused.typeAnalysis.assessment(for: .todo)?.reasons.contains { $0.issue == .contradiction } == true)
        #expect(refused.typeAnalysis.assessment(for: .subtask)?.reasons.isEmpty == true)
        let page = ContentQueryPageContext(location: query.page.location, page: .overview,
                                           todayKey: "2026-02-30", calendar: dates.calendar)
        let invalid = SubtaskQueryFixture.read(.init(page: page), [parent])
        #expect(invalid.state == .blocked && invalid.diagnostics.first?.issue == .invalidDateContext)
    }
}
