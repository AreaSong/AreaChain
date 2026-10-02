import Foundation
import Testing
@testable import AreaChain

struct RoutineQueryPageTests {
    @Test func pageDefaultsUserTakeoverAndHandoffAreEvaluated() {
        let page = ContentQueryPage.today(.init())
        let automatic = TodoQueryFixture.session("合成", page: page)
        #expect(RoutineProviderFixture.read(automatic).undeterminedObjects.count == 1)
        let evidence = [RoutineProviderFixture.schedule]
        #expect(RoutineProviderFixture.read(automatic, evidence: evidence).matches.count == 1)
        let takeover = ContentQueryReducer.reduce(automatic, .setInput("合成 date:2026-08-31")).state
        #expect(RoutineProviderFixture.read(takeover, evidence: evidence).matches.isEmpty)
        let destination = TodoQueryFixture.session("", page: .items(.init(todayKey: QuerySessionFixture.today)))
        let frozen = automatic.handedOff(to: destination)
        #expect(frozen.conditions.contains { $0.origin.isHandoffPage })
        #expect(RoutineProviderFixture.read(frozen).undeterminedObjects.count == 1)
        let response = RoutineProviderFixture.read(frozen, evidence: evidence)
        #expect(response.matches.first?.evidence.contains { item in
            frozen.conditions.contains { $0.id == item.conditionID && $0.origin.isHandoffPage }
        } == true)
    }

    @Test func oldAgendaRequiresBoundedCoverageAndKeepsAnyClosedRule() {
        var routine = RoutineQueryFixture.routine()
        routine.createdDayKey = "2026-09-30"
        let session = TodoQueryFixture.session("合成", page: .pending(lane: .overdue, filter: .init()))
        #expect(RoutineProviderFixture.read(session, routines: [routine]).diagnostics.contains {
            $0.issue == .missingPageCheckCoverage
        })
        let rows = [RoutineQueryFixture.check(.unprocessed, day: "2026-09-30"),
                    RoutineQueryFixture.check(.completed, day: "2026-09-30")]
        #expect(!DayBoardCheckIndex(rows).isClosed(routineId: routine.id, dayKey: "2026-09-30"))
        #expect(AgendaProjection.overdueRoutines(routines: [routine], checks: rows, todayKey: "2026-10-01",
                                               calendar: RoutineQueryFixture.dates.calendar).isEmpty)
        let response = RoutineProviderFixture.read(session, routines: [routine], checks: rows,
                                                   coverage: [RoutineProviderFixture.complete])
        #expect(response.matches.isEmpty && response.isCompleteForCoveredTypes)
    }

    @Test func legacyProjectionCannotHideExplicitStatusConflict() {
        var routine = RoutineQueryFixture.routine()
        routine.createdDayKey = "2026-09-30"
        let page = ContentQueryPage.pending(lane: .overdue, filter: .init())
        let session = TodoQueryFixture.session("合成 on:2026-09-30 status:open", page: page)
        let rows = [RoutineQueryFixture.check(.unprocessed, day: "2026-09-30"),
                    RoutineQueryFixture.check(.completed, day: "2026-09-30")]
        let response = RoutineProviderFixture.read(session, routines: [routine], evidence: [RoutineProviderFixture.schedule],
            checks: rows, coverage: [RoutineProviderFixture.complete])
        // 旧投影确定不入围可排除对象，但新记录冲突仍必须报告。
        #expect(response.matches.isEmpty && response.undeterminedObjects.isEmpty)
        #expect(response.diagnostics.contains { $0.issue == .check(.conflictingRecords) })
        let today = TodoQueryFixture.session("合成 on:today status:open", page: .today(.init(dateScope: .today)))
        let conflictingToday = [RoutineQueryFixture.check(.unprocessed), RoutineQueryFixture.check(.completed)]
        let uncertain = RoutineProviderFixture.read(today, evidence: [RoutineProviderFixture.schedule],
            checks: conflictingToday, coverage: [RoutineProviderFixture.complete])
        #expect(uncertain.undeterminedObjects.count == 1)
    }

    @Test func itemsAndListedDateRemainLegacyAndUnsupportedCombinationsAreExplicit() {
        let upcoming = TodoQueryFixture.session("合成", page: .items(.init(filter: .init(dateScope: .upcoming), todayKey: QuerySessionFixture.today)))
        let response = RoutineProviderFixture.read(upcoming)
        #expect(response.matches.count == 1)
        #expect(response.matches[0].dateExistence == nil)
        #expect(response.matches[0].evidence.contains { $0.field == .legacyPageProjection })
        let unsupported = TodoQueryFixture.session("合成", page: .today(.init(dateScope: .overdue)))
        #expect(RoutineProviderFixture.read(unsupported).diagnostics.contains { $0.issue == .unsupportedListedDay })
        #expect(RoutineProviderFixture.read(unsupported).undeterminedObjects.count == 1)
    }

    @Test func commonLegacyTextQueryAgreesWithoutComparingNewSemantics() {
        let routine = RoutineQueryFixture.routine()
        let response = RoutineProviderFixture.read("/routines 合成")
        let legacy = BoardSearch.hits(query: "合成", todos: [], diaries: [], routines: [routine],
                                      todayKey: QuerySessionFixture.today, calendar: RoutineQueryFixture.dates.calendar)
        #expect(response.matches.count == legacy.count)
        #expect(response.matches.first?.title == routine.title)
    }
}
