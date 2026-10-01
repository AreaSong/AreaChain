import Foundation
import Testing
@testable import AreaChain

struct ContentQueryPageMappingTests {
    typealias Fixture = QuerySessionFixture

    @Test func allPageScopesAndGlobalIsolation() {
        let cases: [(ContentQueryPage, ContentQueryScopeSelection)] = [
            (.overview, .global), (.settings, .global), (.shortcuts, .global), (.privacy, .global), (.backup, .global),
            (.today(.init()), .catalog(.tasks)), (.pending(lane: .overdue, filter: .init()), .catalog(.tasks)),
            (.items(.init(todayKey: Fixture.today)), .catalog(.tasks)), (.diaries(tagID: nil), .catalog(.diaries)),
            (.images, .catalog(.images)), (.clipboard, .catalog(.clipboard)), (.tags, .catalog(.tags)), (.trash, .catalog(.trash)),
            (.calendar(Fixture.interval()), .catalog(.tasks)), (.schedule(Fixture.interval()), .catalog(.tasks)),
            (.quadrants(dayKey: Fixture.today, selection: nil), .catalog(.tasks)),
            (.tagContents(tagID: UUID(), types: [.todo, .routine, .subtask]), .global)
        ]
        for (page, scope) in cases {
            let state = ContentQuerySession(page: Fixture.page(page))
            #expect(state.scope == scope)
            #expect(!state.showsResults)
            #expect(state.isReady)
            #expect(state.composition?.types.contains(.clipboardEntry) == (scope == .catalog(.clipboard)))
            #expect(state.composition?.deletion == (scope == .catalog(.trash) ? .deletedOnly : .liveOnly))
            #expect(state.composition?.restrictsCommandDiscovery == false)
        }
    }

    @Test func onlyActualFiltersAreMapped() {
        let filter = BoardFilter(tagID: BoardFilter.noneID, bundleID: "example.source", isHighPriorityOnly: true,
                                 priorityScope: .all, reminderScope: .set, dateScope: .overdue)
        let today = ContentQuerySession(page: Fixture.page(.today(filter)))
        #expect(today.conditions.contains { $0.value == .page(.noTags) })
        #expect(today.conditions.contains { $0.value == .page(.sourceApplication("example.source")) })
        #expect(today.pageProjection.boardFilter?.priorityScope == .highPriorityOnly)
        #expect(today.pageProjection.boardFilter?.reminderScope == .set)
        for page in [ContentQueryPage.pending(lane: .upcoming, filter: filter), .items(.init(filter: filter, todayKey: Fixture.today))] {
            let state = ContentQuerySession(page: Fixture.page(page))
            #expect(!state.conditions.contains { $0.value.dimension == .content(.reminder) })
        }
        for page in [ContentQueryPage.images, .trash, .clipboard, .tags] {
            #expect(ContentQueryPageMapping.defaults(Fixture.page(page)).count == 1)
        }
    }

    @Test func dateRulesRetainEvaluationAndInjectedCalendar() throws {
        let cases: [(ContentQueryPage, DateFilterScope, ContentQueryPageDateRule.Evaluation)] = [
            (.today(.init(dateScope: .recent)), .recent, .listedDay),
            (.pending(lane: .overdue, filter: .init()), .overdue, .agenda),
            (.pending(lane: .upcoming, filter: .init()), .upcoming, .agenda),
            (.items(.init(filter: .init(dateScope: .overdue), todayKey: Fixture.today)), .overdue, .items)
        ]
        for (page, scope, evaluation) in cases {
            let context = Fixture.page(page)
            let state = ContentQuerySession(page: context)
            let condition = try Fixture.condition(.content(.date), in: state)
            #expect(condition.value == .page(.boardDate(scope, .init(
                evaluation: evaluation, todayKey: context.todayKey, calendar: context.calendar))))
            #expect(state.pageProjection.boardFilter?.dateScope == scope)
        }
    }

    @Test func itemStatusesRemainTypeSpecificAndDisabledRoutinesCanBeIncluded() {
        let page = ContentQueryPage.items(.init(kind: .recurring, todoStatus: .done, routineStatus: .disabled, todayKey: Fixture.today))
        let state = ContentQuerySession(page: Fixture.page(page))
        #expect(state.conditions.contains { $0.value == .page(.itemKind(.recurring)) })
        #expect(state.conditions.contains { $0.value == .page(.todoStatus(.done)) })
        #expect(state.conditions.contains { $0.value == .page(.routineStatus(.disabled)) })
        #expect(!state.conditions.contains { $0.value == .atom(.status(.done)) })
        #expect(state.composition?.routines == .enabledAndDisabled)
    }

    @Test func calendarScheduleAndQuadrantDatesComeFromCaller() throws {
        for interval in [Fixture.interval(), Fixture.interval("2026-09-28", "2026-10-04"), Fixture.interval("2026-10-01", "2026-10-31")] {
            for page in [ContentQueryPage.calendar(interval), .schedule(interval)] {
                let state = ContentQuerySession(page: Fixture.page(page))
                #expect(try Fixture.condition(.content(.date), in: state).value == .atom(.date(interval)))
            }
        }
        let all = ContentQuerySession(page: Fixture.page(.quadrants(dayKey: "2026-10-02", selection: nil)))
        #expect(!all.conditions.contains { $0.value.dimension == .content(.priority) })
        let chosen = ContentQuerySession(page: Fixture.page(.quadrants(dayKey: "2026-10-02", selection: .important)))
        #expect(chosen.conditions.contains { $0.value == ContentQueryPageMapping.priorityValue(.p2) })
    }

    @Test func tagContentsCannotBroadenIntoUnrelatedOrPrivateScopes() {
        let tagID = UUID()
        var state = ContentQuerySession(page: Fixture.page(.tagContents(tagID: tagID, types: [.todo, .subtask, .routine])))
        #expect(state.conditions.contains { $0.value == .page(.tagID(tagID)) })
        #expect(state.composition?.types == [.todo, .subtask, .routine])
        #expect(state.composition?.deletion == .liveOnly)
        Fixture.apply(.addCondition(.page(.contentTypes([.clipboardEntry]))), &state)
        #expect(!state.isReady)
        #expect(state.composition?.types.isEmpty == true)
    }

    @Test func diaryAndMenuContextsUseActualFilterContractsAndSeparateHosts() {
        let id = UUID()
        let workspace = ContentQuerySession(page: Fixture.page(.diaries(tagID: id)))
        let menu = ContentQuerySession(page: Fixture.page(.diaries(tagID: id), host: "menu"))
        #expect(workspace.conditions.map(\.value) == menu.conditions.map(\.value))
        #expect(workspace.hostID != menu.hostID)
        #expect(workspace.conditions.count == 2)
        #expect(!ContentQueryPageProjection.accepts(.page(.noTags), context: workspace.page))
    }

    @Test func invalidCallerDateIsDiagnosedWithoutSystemFallback() {
        let state = ContentQuerySession(page: Fixture.page(.calendar(Fixture.interval("2026-02-30"))))
        #expect(!state.isReady)
        #expect(state.conditionDiagnostics.contains { $0.issue == .invalidDate })
        #expect(!state.showsResults)
    }

    @Test func typedIntervalsCannotSmuggleRelativeStrings() {
        let state = ContentQuerySession(page: Fixture.page(.calendar(Fixture.interval("today"))))
        #expect(!state.isReady)
        #expect(state.conditionDiagnostics.contains { $0.issue == .invalidDate })
    }

    @Test func taskListTagProjectionRetainsSubtaskMatchingRule() throws {
        let id = UUID()
        let state = ContentQuerySession(page: Fixture.page(.items(.init(filter: .init(tagID: id), todayKey: Fixture.today))))
        #expect(try Fixture.condition(.content(.tag), in: state).value == .page(.tagID(id, matching: .taskOrSubtask)))
        #expect(state.pageProjection.boardFilter?.tagID == id)
        #expect(!ContentQueryPageProjection.accepts(.page(.tagID(id)), context: state.page))
    }
}
