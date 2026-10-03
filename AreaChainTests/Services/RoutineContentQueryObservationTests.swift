import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct RoutineContentQueryObservationTests {
    @Test(arguments: ["2026-09-30", "2026-10-02"])
    func queryPastOrFutureNeverRelabelsCurrentDefinition(day: String) throws {
        let f = try RoutineContentQueryFixture()
        let parent = f.routine()
        parent.pausedOnDayKey = "2026-09-15"
        f.check(parent, day: day, done: true)
        let result = f.read("/routines on:" + day + " status:done")
        #expect(result.batch.facts.routine.scheduleEvidence == [.currentDefinition(parent.snapshot, observedOn: "2026-10-01")])
        #expect(try RoutineContentQueryFixture.definitions(result).undeterminedObjects.map(\.id) == [parent.id])
        let records = try RoutineContentQueryFixture.occurrence(f.records("date:" + day))
        #expect(records.matches.isEmpty && !records.coverage.historyIsComplete)
        #expect(!records.reviewRecords.isEmpty)
    }

    @Test func crossingMidnightRequiresFreshObservationAndLeavesFrozenQueryUntouched() throws {
        let f = try RoutineContentQueryFixture()
        let parent = f.routine()
        let first = f.read("/routines on:today status:open", observed: "2026-10-01")
        let next = f.read("/routines on:today status:open", observed: "2026-10-02")
        #expect(first.batch.session == next.batch.session)
        #expect(try RoutineContentQueryFixture.definitions(first).matches.count == 1)
        #expect(try RoutineContentQueryFixture.definitions(next).matches.isEmpty)
        #expect(next.batch.facts.routine.scheduleEvidence == [.currentDefinition(parent.snapshot, observedOn: "2026-10-02")])
        #expect(first.batch.facts.routine.scheduleEvidence.first?.interval.lowerBound == "2026-10-01")
    }

    @Test func handedOffDateContextIsNotTheObservationClock() throws {
        let f = try RoutineContentQueryFixture()
        let parent = f.routine()
        let source = TodoQueryFixture.session("/routines on:today status:open")
        let original = QuerySessionFixture.page(.overview, visit: "destination", host: "other")
        let destinationPage = ContentQueryPageContext(location: original.location, page: original.page,
                                                       todayKey: "2026-10-03", calendar: original.calendar)
        let frozen = source.handedOff(to: ContentQuerySession(page: destinationPage))
        let result = f.reader.read(session: frozen, requestID: UUID(), observation: RoutineContentQueryFixture.observation("2026-10-03"))
        #expect(result.batch.session.queryDates.todayKey == "2026-10-01")
        #expect(result.batch.facts.routine.scheduleEvidence == [.currentDefinition(parent.snapshot, observedOn: "2026-10-03")])
        #expect(try RoutineContentQueryFixture.definitions(result).matches.isEmpty)
    }

    @Test func timezoneAndInvalidClockFailClosedWithoutSubstitutingToday() throws {
        let f = try RoutineContentQueryFixture()
        f.routine()
        let session = TodoQueryFixture.session("/routines on:today status:open")
        var other = session.queryDates.calendar
        other.timeZone = TimeZone(secondsFromGMT: 0)!
        let mismatched = f.reader.read(session: session, requestID: UUID(),
            observation: .init(instant: RoutineContentQueryFixture.observation().instant, calendar: other))
        #expect(mismatched.routine.issues == [.observationCalendarMismatch])
        #expect(mismatched.batch.facts.routine.scheduleEvidence.isEmpty)
        let invalid = f.reader.read(session: session, requestID: UUID(),
            observation: .init(instant: Date(timeIntervalSince1970: .infinity), calendar: session.queryDates.calendar))
        #expect(invalid.routine.issues == [.invalidObservation])
        #expect(invalid.batch.facts.routine.scheduleEvidence.isEmpty)
    }

    @Test func civilMidnightUsesInjectedInstantAndMatchingTimezone() throws {
        let f = try RoutineContentQueryFixture()
        f.routine()
        let session = TodoQueryFixture.session("/routines on:today status:open")
        let calendar = session.queryDates.calendar
        let midnight = try #require(DayKey.date(from: "2026-10-02", calendar: calendar))
        let before = f.reader.read(session: session, requestID: UUID(),
            observation: .init(instant: midnight.addingTimeInterval(-1), calendar: calendar))
        let after = f.reader.read(session: session, requestID: UUID(),
            observation: .init(instant: midnight, calendar: calendar))
        #expect(before.batch.facts.routine.scheduleEvidence.first?.interval.lowerBound == "2026-10-01")
        #expect(after.batch.facts.routine.scheduleEvidence.first?.interval.lowerBound == "2026-10-02")
        #expect(before.batch.session == after.batch.session)
        #expect(try RoutineContentQueryFixture.definitions(before).matches.count == 1)
        #expect(try RoutineContentQueryFixture.definitions(after).undeterminedObjects.count == 1)
    }
}
