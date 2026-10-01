import Foundation
import Testing
@testable import AreaChain

struct ContentQueryPagePriorityTests {
    typealias Fixture = QuerySessionFixture

    @Test func explicitParentPriorityAndOwnPriorityHaveDifferentBindingsAndEvidence() throws {
        var parent = SubtaskQueryFixture.parent(1)
        parent.title = "汇报"
        parent.isImportant = true
        parent.isUrgent = true
        let page = ContentQueryPage.today(.init(priorityScope: .p1))
        var session = TodoQueryFixture.session("汇报", page: page)
        let condition = try Fixture.condition(.content(.priority), in: session)
        #expect(condition.value == .page(.taskPriority(.init(scope: .p1))))
        let child = try #require(SubtaskQueryFixture.read(session, [parent]).matches.first)
        #expect(child.evidence.contains { $0.conditionID == condition.id && $0.field == .parentPriority && $0.relatedObject == child.parent })
        #expect(TodoQueryFixture.read(session, [parent]).matches.first?.evidence.contains { $0.field == .priority } == true)
        Fixture.apply(.setInput("汇报 !p1"), &session)
        #expect(!session.conditions.contains { if case .page(.taskPriority) = $0.value { return true }; return false })
        #expect(SubtaskQueryFixture.read(session, [parent]).state == .inapplicableConditions)
        #expect(session.pageProjection.extendedDimensions.contains(.content(.priority)))
        let before = session
        let intents = Fixture.apply(.pageFilterChanged(session.page.location, .content(.priority), nil), &session)
        #expect(intents.contains { if case .requiresQueryEditing = $0 { return true }; return false })
        #expect(session == before)
    }

    @Test func priorityPageFiltersRetainAllLegacyCombinations() {
        var parents = (1...4).map { SubtaskQueryFixture.parent($0, title: "共同文字") }
        for index in parents.indices {
            parents[index].title = "共同文字"
            parents[index].isImportant = index < 2
            parents[index].isUrgent = index % 2 == 0
        }
        for scope in PriorityFilterScope.allCases {
            for flag in [false, true] {
                let filter = BoardFilter(isHighPriorityOnly: flag, priorityScope: scope)
                var session = TodoQueryFixture.session("共同文字")
                for value in ContentQueryPageMapping.board(filter, context: session.page, evaluation: .listedDay, reminders: true) {
                    session = TodoQueryFixture.add(value, to: session)
                }
                let legacy = BoardSearch.hits(query: "共同文字", todos: parents, diaries: [], routines: [],
                    todayKey: Fixture.today, tagMap: [:], scope: .init(filter: filter), calendar: session.queryDates.calendar)
                let children = SubtaskQueryFixture.read(session, parents)
                #expect(Set(children.matches.map(\.id.id)) == Set(legacy.filter { $0.kind == .subtask }.map(\.id)))
                #expect(children.state == (flag ? .unsatisfiable : .evaluated))
                let todo = TodoQueryFixture.read(session, parents)
                let expected = parents.filter { Classification.matches($0.classifyBits, filter: filter) }
                #expect(todo.matches.map(\.id.id) == expected.map(\.id))
                let projected = ContentQuerySession(page: Fixture.page(.today(filter))).pageProjection.boardFilter
                #expect(projected?.priorityScope == scope && projected?.isHighPriorityOnly == flag)
            }
        }
    }

    @Test func typedPageEditRefreshDeleteAndNewVisitKeepOwnership() throws {
        var state = ContentQuerySession(page: Fixture.page(.today(.init(priorityScope: .p1))))
        let id = try Fixture.condition(.content(.priority), in: state).id
        let p2 = try #require(ContentQueryPageMapping.priorityValue(.p2))
        Fixture.apply(.pageFilterChanged(state.page.location, .content(.priority), p2), &state)
        #expect(try Fixture.condition(.content(.priority), in: state).id == id)
        Fixture.apply(.refreshPage(Fixture.page(.today(.init(priorityScope: .p3)))), &state)
        #expect(try Fixture.condition(.content(.priority), in: state).value == p2)
        Fixture.apply(.removeCondition(id), &state)
        Fixture.apply(.refreshPage(Fixture.page(.today(.init(priorityScope: .p4)))), &state)
        #expect(!state.conditions.contains { $0.value.dimension == .content(.priority) })
        Fixture.apply(.enterPage(Fixture.page(.today(.init(priorityScope: .p3)), visit: "new")), &state)
        #expect(try Fixture.condition(.content(.priority), in: state).value == ContentQueryPageMapping.priorityValue(.p3))
    }

    @Test func handoffFreezesParentPredicateAndExplicitTextStillTakesOver() throws {
        let source = TodoQueryFixture.session("汇报", page: .today(.init(priorityScope: .p1)))
        let target = ContentQuerySession(page: Fixture.page(.settings, host: "menu"))
        var moved = source.handedOff(to: target)
        let frozen = try Fixture.condition(.content(.priority), in: moved)
        #expect(frozen.origin == .handoffPage(source.page.location))
        #expect(frozen.id == (try Fixture.condition(.content(.priority), in: source)).id)
        Fixture.apply(.enterPage(Fixture.page(.today(.init(priorityScope: .p4)), visit: "new", host: "menu")), &moved)
        #expect(try Fixture.condition(.content(.priority), in: moved) == frozen)
        Fixture.apply(.setInput("汇报 !p2"), &moved)
        let own = try Fixture.condition(.content(.priority), in: moved)
        #expect(own.value == .atom(.priority(.init(isImportant: true, isUrgent: false))))
        Fixture.apply(.removeCondition(own.id), &moved)
        Fixture.apply(.refreshPage(moved.page), &moved)
        #expect(!moved.conditions.contains { $0.value.dimension == .content(.priority) })
    }
}
