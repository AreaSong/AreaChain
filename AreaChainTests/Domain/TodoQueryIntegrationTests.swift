import Foundation
import Testing
@testable import AreaChain

struct TodoQueryIntegrationTests {
    @Test func parserToEffectiveConditionsToTypedResultsIncludesPageAndUserPredicates() throws {
        let source = "汇报 (#工作 | #学习) -#归档 status:open"
        let page = QuerySessionFixture.page(.today(.init(bundleID: "app.source", priorityScope: .p2)))
        var session = ContentQuerySession(page: page)
        QuerySessionFixture.apply(.setInput(source), &session)
        #expect(session.input == ContentQueryParser().parse(source, context: page.dates))
        #expect(session.conditions.contains { $0.origin.isPage && $0.value.dimension == .sourceApplication })
        session = TodoQueryFixture.add(.page(.reminderPresence(.set)), to: session)
        var match = TodoQueryFixture.todo(1)
        match.isImportant = true
        match.sourceBundleID = "app.source"
        match.tagIDs = TodoQueryFixture.work.uuidString
        match.remindMinutes = 930
        var wrongDay = match
        wrongDay.id = TodoQueryFixture.todo(2).id
        wrongDay.dayKey = "2026-10-02"
        var wrongSource = match
        wrongSource.id = TodoQueryFixture.todo(3).id
        wrongSource.sourceBundleID = ""
        var noReminder = match
        noReminder.id = TodoQueryFixture.todo(4).id
        noReminder.remindMinutes = nil
        let response = TodoQueryFixture.read(session, [match, wrongDay, wrongSource, noReminder])
        #expect(response.requestID == TodoQueryFixture.requestID && response.queryIsValid)
        #expect(response.matches.map(\.id) == [.init(type: .todo, id: match.id)])
        #expect(response.coverage.requestedTypes == [.todo, .subtask, .routine])
        #expect(response.coverage.coveredTypes == [.todo] && response.coverage.isPartialTypeCoverage)
        #expect(response.isCompleteForCoveredTypes)
        let result = try #require(response.matches.first)
        #expect(Set(result.evidence.map(\.conditionID)) == Set(session.conditions.map(\.id)))
        #expect(result.title == match.title && result.dayKey == match.dayKey && result.createdAt == match.createdAt)
    }

    @Test func userTakesOverAutomaticDateBeforeProviderReadsIt() {
        var session = TodoQueryFixture.session("汇报", page: .today(.init()))
        let today = TodoQueryFixture.todo(1)
        let tomorrow = TodoQueryFixture.todo(2, day: "2026-10-02")
        #expect(TodoQueryFixture.read(session, [today, tomorrow]).matches.map(\.id.id) == [today.id])
        QuerySessionFixture.apply(.setInput("汇报 date:2026-10-02"), &session)
        #expect(!session.conditions.contains { $0.origin.isPage && $0.value.dimension == .content(.date) })
        #expect(TodoQueryFixture.read(session, [today, tomorrow]).matches.map(\.id.id) == [tomorrow.id])
        let refreshed = ContentQueryPageContext(location: session.page.location, page: .today(.init()),
                                                todayKey: "2026-10-03", calendar: session.page.calendar)
        QuerySessionFixture.apply(.refreshPage(refreshed), &session)
        #expect(TodoQueryFixture.read(session, [today, tomorrow]).matches.map(\.id.id) == [tomorrow.id])
    }

    @Test func handoffFreezesSourcePageAndDateInterpretationThroughTargetNavigation() {
        let source = TodoQueryFixture.session("汇报", page: .pending(lane: .overdue, filter: .init(tagID: TodoQueryFixture.work)))
        let target = ContentQuerySession(page: QuerySessionFixture.page(.diaries(tagID: TodoQueryFixture.archive),
                                                                        visit: "target", host: "menubar"))
        var moved = source.handedOff(to: target)
        var parent = TodoQueryFixture.todo(1, day: "2026-09-30")
        parent.subtasks = [TodoQueryFixture.subtask(1, parent: parent, tags: [TodoQueryFixture.work])]
        let today = TodoQueryFixture.todo(2)
        let first = TodoQueryFixture.read(moved, [parent, today])
        #expect(first.matches.map(\.id.id) == [parent.id])
        #expect(moved.conditions.contains { $0.origin.isHandoffPage })
        let next = ContentQueryPageContext(location: .init(hostID: target.hostID, visitID: "next", reference: "settings"),
                                           page: .settings, todayKey: "2026-10-08", calendar: target.page.calendar)
        QuerySessionFixture.apply(.enterPage(next), &moved)
        QuerySessionFixture.apply(.refreshPage(next), &moved)
        #expect(TodoQueryFixture.read(moved, [parent, today]) == first)
        #expect(moved.queryDates.todayKey == source.queryDates.todayKey)
    }

    @Test func coverageDistinguishesTodoSubsetUnsupportedScopeAndDeletedPolicy() {
        let todo = TodoQueryFixture.todo(1)
        for source in ["项目", "/tasks 项目"] {
            let response = TodoQueryFixture.read(source, [todo])
            #expect(response.state == .evaluated && response.coverage.providerTypes == [.todo])
            #expect(response.coverage.isPartialTypeCoverage && response.matches.count == 1)
        }
        for source in ["/diaries 项目", "/subtasks 项目", "/routines 项目", "/clipboard 项目", "/trash 项目"] {
            let response = TodoQueryFixture.read(source, [todo])
            #expect(response.queryIsValid && response.state == .notApplicable && response.matches.isEmpty)
            #expect(response.coverage.coveredTypes.isEmpty && !response.isCompleteForCoveredTypes)
        }
        let onlyTodo = TodoQueryFixture.add(.page(.contentTypes([.todo])), to: TodoQueryFixture.session())
        let complete = TodoQueryFixture.read(onlyTodo, [todo])
        #expect(complete.matches.count == 1 && !complete.coverage.isPartialTypeCoverage)
        let onlySubtask = TodoQueryFixture.add(.page(.contentTypes([.subtask])), to: TodoQueryFixture.session())
        #expect(TodoQueryFixture.read(onlySubtask, [todo]).state == .notApplicable)
        #expect(TodoQueryFixture.read("missing", [todo]).coverage.isPartialTypeCoverage)
    }

    @Test func duplicateTodoIDsAreAllQuarantinedIncludingLiveDeletedCollision() {
        let first = TodoQueryFixture.todo(1)
        let duplicate = TodoQueryFixture.todo(2)
        var tombstone = duplicate
        tombstone.deletedAt = TodoQueryFixture.created
        let last = TodoQueryFixture.todo(3)
        let response = TodoQueryFixture.read("项目", [last, duplicate, first, tombstone, duplicate])
        #expect(response.matches.map(\.id.id) == [last.id, first.id])
        #expect(response.diagnostics == [.init(issue: .duplicateTodoID, object: .init(type: .todo, id: duplicate.id),
                                               inputIndices: [1, 3, 4])])
        #expect(!response.isCompleteForCoveredTypes)
        #expect(CommandObjectReference(type: .todo, id: first.id) != CommandObjectReference(type: .routine, id: first.id))
    }

    @Test func readPreservesInputsAndStableInputOrderAndOmitsDeletedRecords() {
        let first = TodoQueryFixture.todo(1)
        var deleted = TodoQueryFixture.todo(2)
        deleted.deletedAt = TodoQueryFixture.created
        let last = TodoQueryFixture.todo(3, day: "2026-09-30")
        let todos = [last, deleted, first]
        let state = TodoQueryFixture.session("项目")
        let beforeTodos = todos
        let beforeSession = state
        let response = TodoQueryFixture.read(state, todos)
        #expect(response.matches.map(\.id.id) == [last.id, first.id])
        #expect(TodoQueryFixture.read(state, todos) == response && todos == beforeTodos && state == beforeSession)
        #expect(response.diagnostics.isEmpty && response.isCompleteForCoveredTypes)
    }

    @Test func invalidQueriesAndUnsupportedImagesNeverProduceWidenedResults() {
        let todos = [TodoQueryFixture.todo(1)]
        for text in ["项目 date:2026-02-30", #"项目 "未结束"#, "status:open status:done", "/tasks /diaries", "/set"] {
            let response = TodoQueryFixture.read(text, todos)
            #expect(!response.queryIsValid && response.state == .invalidQuery && response.matches.isEmpty)
            #expect(response.diagnostics.first?.issue == .invalidQuery)
        }
        for text in ["has:image", "项目 has:image", "(has:image | has:image)"] {
            let response = TodoQueryFixture.read(text, todos)
            #expect(response.queryIsValid && response.state == .blocked && response.matches.isEmpty)
            #expect(response.diagnostics.allSatisfy { $0.issue == .imageAssociationUnavailable && !$0.conditionIDs.isEmpty })
            #expect(!response.isCompleteForCoveredTypes)
        }
        var repeated = TodoQueryFixture.session("项目 汇报")
        repeated.conditions[1] = repeated.conditions[0]
        let invalid = TodoQueryFixture.read(repeated, todos)
        #expect(invalid.state == .invalidQuery && invalid.diagnostics.first?.issue == .ambiguousConditionIDs)
    }

    @Test func commonQuerySubsetAgreesWithBoardSearchTodoHitSets() {
        var first = TodoQueryFixture.todo(1, title: "项目 CAFÉ")
        first.notes = "汇报"
        first.tagIDs = TodoQueryFixture.work.uuidString
        first.isImportant = true
        first.remindMinutes = 930
        var second = TodoQueryFixture.todo(2, title: "汇报")
        second.isDone = true
        second.tagIDs = TagIDList.encode([TodoQueryFixture.work, TodoQueryFixture.study])
        let todos = [first, second, TodoQueryFixture.todo(3, title: "其他")]
        for source in ["项目 汇报", "cafe", "#工作", "#工作 #学习", "!p2", "@15:30", "汇报 #工作 !p2 @15:30", "无命中"] {
            let current = TodoQueryFixture.read(source, todos)
            let legacy = BoardSearch.hits(query: source, todos: todos, diaries: [], routines: [],
                                          todayKey: QuerySessionFixture.today, tagMap: TodoQueryFixture.names,
                                          calendar: QuerySessionFixture.page().calendar)
            #expect(current.queryIsValid && current.isCompleteForCoveredTypes)
            #expect(Set(current.matches.map(\.id.id)) == Set(legacy.filter { $0.kind == .todo }.map(\.id)))
        }
    }
}
