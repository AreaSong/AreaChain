import Foundation
import Testing
@testable import AreaChain

struct ContentQuerySortTimeTests {
    @Test func trueTimeSourcesDoNotBorrowBusinessOrUsageDates() {
        let batch = ContentQueryBatchReader.read(QueryBatchFixture.mixed())
        for match in batch.matches {
            let time = QuerySortFixture.time(match)
            if match.id.type == .tag {
                #expect(time.source == .unavailable && time.day == nil && time.issue == .missing)
            } else {
                #expect(time.source == .createdAt && time.instant != nil && time.issue == nil)
            }
        }
        let clipboard = ContentQueryBatchReader.read(QueryBatchFixture.mixed("/clipboard")).matches[0]
        #expect(QuerySortFixture.time(clipboard).source == .copiedAt)
        let occurrence = ContentQueryBatchReader.read(QueryBatchFixture.occurrences()).matches[0]
        let time = QuerySortFixture.time(occurrence)
        #expect(time.source == .executionDay && time.day == occurrence.id.dayKey && time.instant == nil)
        let trash = ContentQueryBatchReader.read(QueryBatchFixture.trash()).matches
        #expect(trash.allSatisfy { QuerySortFixture.time($0).source == .createdAt })
    }

    @Test func recentWithinTierAndExplicitRecentOverride() {
        var batch = QuerySortFixture.batch("alpha", titles: [("alpha", ""), ("alpha tail", ""), ("alpha", "")])
        var values = batch.snapshots.todos.values!
        values[1].createdAt += 200; values[2].createdAt += 100
        batch.snapshots.todos = .complete(values)
        #expect(QuerySortFixture.sort(batch).ordered.map(\.id.id) == [values[2].id, values[0].id, values[1].id])
        let recent = QuerySortFixture.sort(batch, mode: .recent)
        #expect(recent.ordered.map(\.id.id) == [values[1].id, values[2].id, values[0].id])
        #expect(recent.applied == .recent && recent.fallback == nil)
    }

    @Test func sameDayPrecisionHasOneTotalOrdering() {
        let dates = TodoQueryFixture.session().queryDates
        let occurrence = ContentQueryBatchReader.read(QueryBatchFixture.occurrences()).matches[0]
        let civil = QuerySortFixture.time(occurrence)
        let midnight = DayKey.date(from: civil.day!, calendar: dates.calendar)!
        let early = QuerySortFixture.time(QuerySortFixture.todo(1, stamp: midnight))
        let late = QuerySortFixture.time(QuerySortFixture.todo(2, stamp: midnight + 86_000))
        let rows = [QuerySortFixture.row(1, time: civil), QuerySortFixture.row(2, time: early), QuerySortFixture.row(3, time: late)]
        #expect(rows.sorted(by: ContentQuerySorter.precedes).map(\.id.id) == [3, 2, 1].map { TodoQueryFixture.todo($0).id })
        #expect(civil.instant == nil)
    }

    @Test func timezoneIsInjectedAndInvalidDatesStayMissing() {
        var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(secondsFromGMT: 0)!
        var shanghai = utc; shanghai.timeZone = TimeZone(secondsFromGMT: 28_800)!
        let date = DayKey.date(from: "2026-10-01", calendar: utc)! + 20 * 3_600
        let match = QuerySortFixture.todo(1, stamp: date)
        #expect(QuerySortFixture.time(match, dates: .init(todayKey: "2026-10-02", calendar: utc)).day == "2026-10-01")
        #expect(QuerySortFixture.time(match, dates: .init(todayKey: "2026-10-02", calendar: shanghai)).day == "2026-10-02")
        for stamp in [Date.distantPast, .distantFuture, Date(timeIntervalSince1970: .nan), Date(timeIntervalSince1970: .infinity)] {
            let time = QuerySortFixture.time(QuerySortFixture.todo(1, stamp: stamp))
            #expect(time.day == nil && time.instant == nil && time.issue == .invalid)
        }
        let invalid = QuerySortFixture.time(match, dates: .init(todayKey: "bad", calendar: utc))
        #expect(invalid.issue == .invalidDateEnvironment && invalid.instant == nil)
    }

    @Test func invalidExecutionDayAndMissingTimeDoNotBorrowOtherDates() {
        let original = ContentQueryBatchReader.read(QueryBatchFixture.occurrences()).matches[0]
        guard case .routineOccurrence(let value) = original else { Issue.record("缺少记录"); return }
        for day in [nil, "2026-02-30", "invalid"] as [String?] {
            let bad = ContentQueryBatchMatch.routineOccurrence(.init(
                id: .init(type: .routineOccurrence, id: value.id.id, dayKey: day), routine: value.routine,
                routineTitle: value.routineTitle, status: value.status, source: value.source,
                occurrence: value.occurrence, evidence: value.evidence))
            let time = QuerySortFixture.time(bad)
            #expect(time.day == nil && time.instant == nil)
            #expect(time.issue == (day == nil ? .missing : .invalid))
        }
        let missing = QuerySortFixture.time(QuerySortFixture.todo(1, stamp: .distantPast))
        let valid = QuerySortFixture.time(QuerySortFixture.todo(2))
        #expect(ContentQuerySorter.precedes(QuerySortFixture.row(2, time: valid), QuerySortFixture.row(1, time: missing)))
    }

    @Test func stableIdentityAndComparatorProperties() {
        let batch = ContentQueryBatchReader.read(QueryBatchFixture.mixed())
        let occurrence = ContentQueryBatchReader.read(QueryBatchFixture.occurrences()).matches[0]
        let times = batch.matches.map { QuerySortFixture.time($0) } + [QuerySortFixture.time(occurrence),
            QuerySortFixture.time(QuerySortFixture.todo(1, stamp: .distantPast))]
        let rows = times.enumerated().flatMap { index, time in
            [QuerySortFixture.row(index + 1, time: time), QuerySortFixture.row(index + 1, time: time, type: .tag)]
        }
        let expected = rows.sorted(by: ContentQuerySorter.precedes)
        for lhs in rows {
            #expect(!ContentQuerySorter.precedes(lhs, lhs))
            for rhs in rows {
                if ContentQuerySorter.precedes(lhs, rhs) {
                    #expect(!ContentQuerySorter.precedes(rhs, lhs))
                    for last in rows where ContentQuerySorter.precedes(rhs, last) {
                        #expect(ContentQuerySorter.precedes(lhs, last))
                    }
                }
            }
        }
        for _ in 0..<20 { #expect(rows.shuffled().sorted(by: ContentQuerySorter.precedes) == expected) }
        let sameTime = times[0]
        let days = ["2026-10-02", "2026-10-01"].map {
            QuerySortFixture.row(1, time: sameTime, type: .routineOccurrence, day: $0)
        }
        #expect(days.sorted(by: ContentQuerySorter.precedes).first?.id.dayKey == "2026-10-01")
    }
}
