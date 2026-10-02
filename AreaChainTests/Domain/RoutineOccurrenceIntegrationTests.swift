import Foundation
import Testing
@testable import AreaChain

struct RoutineOccurrenceIntegrationTests {
    @Test func originalQuerySessionAnalysisAndReadStateFormOnePureChain() throws {
        let session = TodoQueryFixture.session("/routines on:today status:skipped date:2026-10-01..2026-10-07")
        let before = session
        #expect(session.isStructurallyValid && session.typeAnalysis.assessment(for: .routine)?.reasons.isEmpty == true)
        let day = try #require(session.occurrenceDay.dayKey)
        let routine = RoutineQueryFixture.routine()
        let history = RoutineQueryFixture.history([.currentDefinition(routine, observedOn: day)])
        let checks = RoutineQueryFixture.read([RoutineQueryFixture.check(.skipped)])
        let evaluation = RoutineOccurrenceEvaluation(schedule: history.day(day), records: checks)
        let statusCondition = try QuerySessionFixture.condition(.content(.status), in: session)
        guard case .clause(let terms) = statusCondition.value, case .status(let status) = terms.first?.atom else {
            Issue.record("expected parsed status"); return
        }
        #expect(evaluation.matching(status) == .matches && evaluation.state == .skipped)
        #expect(evaluation.records.object == .init(type: .routineOccurrence, id: routine.id, dayKey: day))
        guard case .window(let window) = ContentQueryDateWindow.resolve(session.conditions, dates: session.queryDates) else {
            Issue.record("expected date window"); return
        }
        #expect(history.existence(in: window).truth == .matches)
        #expect(session == before)
    }

    @Test func statusMatrixRequiresScheduleAndCompleteRecords() {
        let scheduled = RoutineQueryFixture.history([RoutineQueryFixture.evidence("2026-10-01", "2026-10-01")]).day("2026-10-01")
        let nonScheduled = RoutineQueryFixture.history([RoutineQueryFixture.evidence("2026-10-01", "2026-10-01", rule: .notScheduled)]).day("2026-10-01")
        let unknown = RoutineQueryFixture.history([]).day("2026-10-01")
        let cases: [([CheckSnapshot], RoutineOccurrenceState, ContentQueryStatus)] = [
            ([], .open, .open), ([RoutineQueryFixture.check(.unprocessed)], .open, .open),
            ([RoutineQueryFixture.check(.completed)], .done, .done), ([RoutineQueryFixture.check(.skipped)], .skipped, .skipped)
        ]
        for (rows, state, matching) in cases {
            let records = RoutineQueryFixture.read(rows)
            let due = RoutineOccurrenceEvaluation(schedule: scheduled, records: records)
            #expect(due.state == state)
            for status in [ContentQueryStatus.open, .done, .skipped] {
                #expect(due.matching(status) == (status == matching ? .matches : .doesNotMatch))
                #expect(RoutineOccurrenceEvaluation(schedule: nonScheduled, records: records).matching(status) == .doesNotMatch)
                #expect(RoutineOccurrenceEvaluation(schedule: unknown, records: records).matching(status) == .unknown)
                let partial = RoutineQueryFixture.read(rows, complete: [])
                #expect(RoutineOccurrenceEvaluation(schedule: scheduled, records: partial).matching(status) == .unknown)
            }
        }
    }

    @Test func conflictsDoNotBecomeAnyDefiniteStatusAndIdentityMustAgree() {
        let schedule = RoutineQueryFixture.history([RoutineQueryFixture.evidence("2026-10-01", "2026-10-01")]).day("2026-10-01")
        let conflict = RoutineQueryFixture.read([RoutineQueryFixture.check(.completed), RoutineQueryFixture.check(.skipped)])
        let evaluation = RoutineOccurrenceEvaluation(schedule: schedule, records: conflict)
        #expect(evaluation.state == .conflict)
        for status in [ContentQueryStatus.open, .done, .skipped] { #expect(evaluation.matching(status) == .unknown) }
        let differentDay = RoutineQueryFixture.read([], day: "2026-10-02")
        #expect(RoutineOccurrenceEvaluation(schedule: schedule, records: differentDay).state == .invalidInput)
        let invalid = RoutineQueryFixture.read([], day: "2026-02-30")
        #expect(RoutineOccurrenceEvaluation(schedule: schedule, records: invalid).matching(.open) == .invalidInput)
    }

    @Test func doneAndSkippedDoNotRemoveScheduledDaysFromWindow() throws {
        let history = RoutineQueryFixture.history([RoutineQueryFixture.evidence("2026-10-01", "2026-10-01")])
        let window = try #require(ContentQueryDateWindow(intervals: [QuerySessionFixture.interval()], calendar: history.dates.calendar))
        for state in [RoutineCheckState.completed, .skipped] {
            let evaluation = RoutineOccurrenceEvaluation(schedule: history.day("2026-10-01"),
                                                         records: RoutineQueryFixture.read([RoutineQueryFixture.check(state)]))
            #expect(evaluation.matching(.open) == .doesNotMatch)
            #expect(history.existence(in: window).truth == .matches)
        }
    }

    @Test func noDateQueryKeepsDefinitionScopeAndDoesNotImplicitlySelectToday() {
        let routineQuery = TodoQueryFixture.session("/routines")
        #expect(routineQuery.occurrenceDay == .unspecified && routineQuery.conditions.count == 1)
        #expect(routineQuery.composition?.routines == .enabledAndDisabled)
        #expect(ContentQueryDateWindow.resolve(routineQuery.conditions, dates: routineQuery.queryDates) == .unconstrained)
        #expect(TodoQueryFixture.session("/tasks").composition?.routines == .enabledOnly)
        let disabled = TodoQueryFixture.add(.page(.routineStatus(.disabled)), to: TodoQueryFixture.session("/tasks"))
        #expect(disabled.composition?.routines == .enabledAndDisabled)
    }

    @Test func oldBoardAndOverdueRulesKeepTheirDistinctDuplicateAndSkipPolicies() {
        var routine = RoutineQueryFixture.routine()
        routine.createdDayKey = "2026-10-01"
        let open = RoutineQueryFixture.check(.unprocessed)
        let done = RoutineQueryFixture.check(.completed)
        var legacySkip = done
        legacySkip.isSkipped = true
        for closed in [done, RoutineQueryFixture.check(.skipped), legacySkip] {
            let rows = [open, closed]
            #expect(!DayBoardLogic.isRoutineDone(routine, checks: rows, on: "2026-10-01"))
            #expect(DayBoardLogic.isRoutineDone(routine, checks: [closed, open], on: "2026-10-01"))
            #expect(AgendaProjection.overdueRoutines(routines: [routine], checks: rows,
                todayKey: "2026-10-02", calendar: RoutineQueryFixture.dates.calendar).isEmpty)
            #expect(RoutineQueryFixture.read(rows).state == .conflict)
        }
        #expect(DayBoardLogic.isRoutineSkipped(routine, checks: [legacySkip], on: "2026-10-01"))
        #expect(DayBoardLogic.isRoutineDone(routine, checks: [legacySkip], on: "2026-10-01"))
        #expect(RoutineQueryFixture.read([legacySkip]).state == .conflict)
    }
}
