import Foundation
import Testing
@testable import AreaChain

struct RoutineScheduleHistoryTests {
    @Test func currentDefinitionDoesNotReconstructPastOrFuture() {
        var routine = RoutineQueryFixture.routine()
        routine.isEnabled = false
        routine.pausedOnDayKey = "2026-09-20"
        routine.weekdayMask = WeekdayMask.only(weekday: 2)
        let unknown = RoutineQueryFixture.history([], routine: routine)
        #expect(unknown.day("2026-09-15").state == .unknown)
        #expect(unknown.day("2026-09-25").state == .unknown)
        #expect(unknown.day("2026-10-01").state == .unknown)
        let observed = RoutineScheduleEvidence.currentDefinition(routine, observedOn: "2026-10-01")
        let current = RoutineQueryFixture.history([observed], routine: routine)
        #expect(current.day("2026-10-01").state == .notScheduled)
        #expect(current.day("2026-09-30").state == .unknown)
        #expect(current.day("2026-10-02").state == .unknown)
        let past = RoutineQueryFixture.evidence("2026-09-15", "2026-09-16")
        #expect(RoutineQueryFixture.history([observed, past], routine: routine).day("2026-09-15").state == .scheduled)
    }

    @Test func creationBoundaryAndWeekdayEvidenceDetermineOnlyCoveredDays() {
        let weekdays = RoutineQueryFixture.evidence("2026-08-01", "2026-10-10", rule: .weekdays(WeekdayMask.workdays))
        let history = RoutineQueryFixture.history([weekdays])
        let before = history.day("2026-08-31")
        #expect(before.state == .notScheduled && before.reason == .beforeCreation)
        #expect(history.day("2026-09-01").state == .scheduled)
        #expect(history.day("2026-10-03").state == .notScheduled)
        #expect(history.day("2026-10-05").state == .scheduled)
        #expect(history.day("2026-10-11").state == .unknown)
        let paused = RoutineQueryFixture.evidence("2026-10-05", "2026-10-07", rule: .notScheduled)
        #expect(RoutineQueryFixture.history([paused]).day("2026-10-06").state == .notScheduled)
    }

    @Test func contradictoryEvidenceRemainsUnknownLocally() {
        let scheduled = RoutineQueryFixture.evidence("2026-10-01", "2026-10-03")
        let notScheduled = RoutineQueryFixture.evidence("2026-10-01", "2026-10-01", rule: .notScheduled)
        let history = RoutineQueryFixture.history([scheduled, notScheduled])
        #expect(history.day("2026-10-01").state == .unknown)
        #expect(history.day("2026-10-01").reason == .conflictingEvidence)
        #expect(history.day("2026-10-01").evidenceIndices == [0, 1])
        #expect(history.day("2026-10-02").state == .scheduled)
        #expect(RoutineQueryFixture.history([scheduled, scheduled]).day("2026-10-01").state == .scheduled)
        let unrelated = RoutineQueryFixture.evidence("2026-10-01", "2026-10-03", rule: .notScheduled, id: UUID())
        #expect(RoutineQueryFixture.history([scheduled, unrelated]).day("2026-10-01").state == .scheduled)
    }

    @Test func oneKnownScheduledDayProvesExistenceDespiteUnknownRemainder() throws {
        let history = RoutineQueryFixture.history([RoutineQueryFixture.evidence("2026-10-02", "2026-10-02")])
        let window = try #require(ContentQueryDateWindow(intervals: [.init(lowerBound: "2026-10-01", upperBound: "2026-10-07")],
                                                        calendar: history.dates.calendar))
        let result = history.existence(in: window)
        #expect(result.truth == .matches && result.witnessDay == "2026-10-02")
        #expect(result.intervalsContainingUnknownDays == [
            .init(lowerBound: "2026-10-01", upperBound: "2026-10-01"),
            .init(lowerBound: "2026-10-03", upperBound: "2026-10-07")
        ])
    }

    @Test func absenceRequiresEntireWindowKnownAndNonScheduled() throws {
        let interval = QuerySessionFixture.interval("2026-10-01", "2026-10-07")
        let window = try #require(ContentQueryDateWindow(intervals: [interval], calendar: RoutineQueryFixture.dates.calendar))
        let full = RoutineQueryFixture.history([RoutineQueryFixture.evidence("2026-10-01", "2026-10-07", rule: .notScheduled)])
        #expect(full.existence(in: window).truth == .doesNotMatch)
        let partial = RoutineQueryFixture.history([RoutineQueryFixture.evidence("2026-10-01", "2026-10-06", rule: .notScheduled)])
        let unresolved = partial.existence(in: window)
        #expect(unresolved.truth == .unknown && unresolved.witnessDay == nil)
        #expect(unresolved.intervalsContainingUnknownDays == [QuerySessionFixture.interval("2026-10-07", "2026-10-07")])
        let prior = try #require(ContentQueryDateWindow(intervals: [.init(lowerBound: "2026-08-01", upperBound: "2026-08-31")],
                                                       calendar: RoutineQueryFixture.dates.calendar))
        #expect(RoutineQueryFixture.history([]).existence(in: prior).truth == .doesNotMatch)
    }

    @Test func dateGroupsFormOneFinalWindowBeforeExistence() throws {
        let session = TodoQueryFixture.session("/routines (date:2026-10-01..2026-10-03 | date:2026-10-07) date:2026-10-02..2026-10-07")
        guard case .window(let window) = ContentQueryDateWindow.resolve(session.conditions, dates: session.queryDates) else {
            Issue.record("expected bounded window"); return
        }
        #expect(window.intervals == [.init(lowerBound: "2026-10-02", upperBound: "2026-10-03"), QuerySessionFixture.interval("2026-10-07", "2026-10-07")])
        let outside = RoutineQueryFixture.history([RoutineQueryFixture.evidence("2026-10-01", "2026-10-01")])
        #expect(outside.existence(in: window).truth == .unknown)
        let disjoint = TodoQueryFixture.session("date:2026-10-01 date:2026-10-02")
        guard case .window(let empty) = ContentQueryDateWindow.resolve(disjoint.conditions, dates: disjoint.queryDates) else {
            Issue.record("expected empty bounded window"); return
        }
        #expect(empty.intervals.isEmpty && outside.existence(in: empty).truth == .doesNotMatch)
        let noDate = TodoQueryFixture.session("/routines on:today created:today")
        #expect(ContentQueryDateWindow.resolve(noDate.conditions, dates: noDate.queryDates) == .unconstrained)
    }

    @Test func evidenceRequiresBoundedSourceAndCanonicalInputs() {
        let invalid: [RoutineScheduleEvidence] = [
            .init(routineID: RoutineQueryFixture.id, interval: .init(lowerBound: "2026-10-01", upperBound: "2026-10-02"),
                  rule: .weekdays(WeekdayMask.all), source: .currentDefinition(observedOn: "2026-10-01")),
            .init(routineID: RoutineQueryFixture.id, interval: QuerySessionFixture.interval(),
                  rule: .notScheduled, source: .recordedSchedule(reference: "")),
            RoutineQueryFixture.evidence("2026-02-30", "2026-10-01"),
            RoutineQueryFixture.evidence("2026-10-02", "2026-10-01"),
            RoutineQueryFixture.evidence("2026-10-01", "2026-10-01", rule: .weekdays(0))
        ]
        for item in invalid {
            #expect(RoutineQueryFixture.history([item]).day("2026-10-01").state == .invalidInput)
        }
        var routine = RoutineQueryFixture.routine()
        routine.createdDayKey = "invalid"
        #expect(RoutineQueryFixture.history([], routine: routine).day("2026-10-01").state == .invalidInput)
        #expect(RoutineQueryFixture.history([]).day("2026-02-30").state == .invalidInput)
    }

    @Test func calendarBoundariesAndLongWindowsUseCivilDays() throws {
        var dates = RoutineQueryFixture.dates
        var calendar = dates.calendar
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        dates = .init(todayKey: "2024-03-10", calendar: calendar)
        var routine = RoutineQueryFixture.routine()
        routine.createdDayKey = "0001-01-01"
        let leap = RoutineQueryFixture.evidence("2024-02-29", "2024-03-11", rule: .weekdays(WeekdayMask.only(weekday: 1)))
        let history = RoutineScheduleHistory(routine: routine, evidence: [leap], dates: dates)
        #expect(history.day("2024-02-29").state == .notScheduled)
        #expect(history.day("2024-03-10").state == .scheduled)
        let window = try #require(ContentQueryDateWindow(intervals: [.init(lowerBound: "0001-01-01", upperBound: "9999-12-31")], calendar: calendar))
        let result = history.existence(in: window)
        #expect(result.truth == .matches && result.witnessDay == "2024-03-03")
        let end = try #require(ContentQueryDateWindow(intervals: [.init(lowerBound: "9999-12-31", upperBound: "9999-12-31")], calendar: calendar))
        #expect(history.existence(in: end).truth == .unknown)
    }
}
