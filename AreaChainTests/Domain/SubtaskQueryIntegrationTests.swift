import Foundation
import Testing
@testable import AreaChain

struct SubtaskQueryIntegrationTests {
    @Test func rawSubtasksAndTasksQueriesReachTypedResultsThroughParserAndSession() throws {
        var parent = SubtaskQueryFixture.parent(1)
        parent.subtasks[0].tagIDs = TodoQueryFixture.work.uuidString
        let wrong = SubtaskQueryFixture.parent(2, title: "无关")
        for scope in ["/subtasks", "/tasks"] {
            let source = scope + " 汇报 (#工作 | #学习) status:open created:today date:today"
            let query = TodoQueryFixture.session(source)
            #expect(query.input == ContentQueryParser().parse(source, context: query.queryDates))
            let result = SubtaskQueryFixture.read(query, [parent, wrong])
            let match = try #require(result.matches.first)
            #expect(result.queryIsValid && result.isCompleteForCoveredTypes && result.requestID == TodoQueryFixture.requestID)
            #expect(result.matches.map(\.id) == [.init(type: .subtask, id: parent.subtasks[0].id)])
            #expect(match.parent == .init(type: .todo, id: parent.id))
            #expect(Set(match.evidence.map(\.conditionID)) == Set(query.conditions.map(\.id)))
            #expect(result.coverage.coveredTypes == [.subtask])
            #expect(result.coverage.isPartialTypeCoverage == (scope == "/tasks"))
        }
    }

    @Test func pageTagsAndDatesAreEffectiveAndUserConditionsTakeOver() {
        let page = ContentQueryPage.today(.init(tagID: TodoQueryFixture.work))
        var today = SubtaskQueryFixture.parent(1)
        today.subtasks[0].tagIDs = TodoQueryFixture.work.uuidString
        var tomorrow = SubtaskQueryFixture.parent(2, day: "2026-10-02")
        tomorrow.subtasks[0].tagIDs = TodoQueryFixture.study.uuidString
        let parents = [today, tomorrow]
        var query = TodoQueryFixture.session("汇报", page: page)
        #expect(SubtaskQueryFixture.read(query, parents).matches.map(\.id.id) == [today.subtasks[0].id])
        QuerySessionFixture.apply(.setInput("汇报 #学习 date:2026-10-02"), &query)
        #expect(!query.conditions.contains { $0.origin.isPage && [.content(.tag), .content(.date)].contains($0.value.dimension) })
        #expect(SubtaskQueryFixture.read(query, parents).matches.map(\.id.id) == [tomorrow.subtasks[0].id])
        let refreshed = ContentQueryPageContext(location: query.page.location, page: page,
                                                todayKey: "2026-10-03", calendar: query.page.calendar)
        QuerySessionFixture.apply(.refreshPage(refreshed), &query)
        #expect(SubtaskQueryFixture.read(query, parents).matches.map(\.id.id) == [tomorrow.subtasks[0].id])
    }

    @Test func handoffFreezesTagParentDateAndCalendarAcrossTargetNavigation() {
        let source = TodoQueryFixture.session("汇报", page: .pending(lane: .overdue, filter: .init(tagID: TodoQueryFixture.work)))
        let target = ContentQuerySession(page: QuerySessionFixture.page(.diaries(tagID: TodoQueryFixture.archive),
                                                                         visit: "target", host: "menubar"))
        var parent = SubtaskQueryFixture.parent(1, day: "2026-09-30")
        parent.subtasks[0].tagIDs = TodoQueryFixture.work.uuidString
        parent.subtasks.append(TodoQueryFixture.subtask(2, parent: parent, tags: [TodoQueryFixture.archive]))
        var moved = source.handedOff(to: target)
        let first = SubtaskQueryFixture.read(moved, [parent])
        #expect(first.matches.map(\.id.id) == [parent.subtasks[0].id] && first.isCompleteForCoveredTypes)
        #expect(moved.conditions.contains { $0.origin.isHandoffPage })
        let next = ContentQueryPageContext(location: .init(hostID: target.hostID, visitID: "next", reference: "settings"),
                                           page: .settings, todayKey: "2026-09-29", calendar: target.page.calendar)
        QuerySessionFixture.apply(.enterPage(next), &moved)
        QuerySessionFixture.apply(.refreshPage(next), &moved)
        #expect(SubtaskQueryFixture.read(moved, [parent]) == first && moved.queryDates.todayKey == source.queryDates.todayKey)
        let beforeConditions = moved.conditions
        QuerySessionFixture.apply(.setInput("汇报 created:today"), &moved)
        #expect(moved.input == ContentQueryParser().parse("汇报 created:today", context: source.queryDates))
        #expect(moved.conditions.filter { $0.origin.isHandoffPage } == beforeConditions.filter { $0.origin.isHandoffPage })
        #expect(SubtaskQueryFixture.read(moved, [parent]).matches.map(\.id.id) == [parent.subtasks[0].id])
    }

    @Test func queryValidityScopeAndPartialCoverageAreDifferentFromZeroHits() {
        let parent = SubtaskQueryFixture.parent(1)
        for text in ["date:2026-02-30", #""未结束"#, "/tasks /diaries", "/set"] {
            let result = SubtaskQueryFixture.read(text, [parent])
            #expect(!result.queryIsValid && result.state == .invalidQuery && result.matches.isEmpty)
            #expect(result.diagnostics.first?.issue == .invalidQuery)
        }
        let contradiction = SubtaskQueryFixture.read("status:open status:done", [parent])
        #expect(contradiction.queryIsValid && contradiction.state == .unsatisfiable && contradiction.matches.isEmpty)
        #expect(contradiction.typeAnalysis.assessment(for: .subtask)?.reasons.contains { $0.issue == .contradiction } == true)
        var repeated = TodoQueryFixture.session("汇报 子任务")
        repeated.conditions[1] = repeated.conditions[0]
        #expect(SubtaskQueryFixture.read(repeated, [parent]).diagnostics.first?.issue == .ambiguousConditionIDs)
        for text in ["/diaries", "/routines", "/tags", "/images", "/clipboard", "/trash"] {
            let result = SubtaskQueryFixture.read(text, [parent])
            #expect(result.queryIsValid && result.state == .notApplicable && result.matches.isEmpty)
            #expect(result.coverage.coveredTypes.isEmpty && !result.isCompleteForCoveredTypes)
        }
        for text in ["无命中", "/tasks 无命中", "/subtasks 无命中"] {
            let result = SubtaskQueryFixture.read(text, [parent])
            #expect(result.matches.isEmpty && result.isCompleteForCoveredTypes && result.coverage.providerTypes == [.subtask])
            #expect(result.coverage.isPartialTypeCoverage == !text.hasPrefix("/subtasks"))
        }
        let tagPage = ContentQueryPage.tagContents(tagID: TodoQueryFixture.work, types: [.todo])
        #expect(SubtaskQueryFixture.read(TodoQueryFixture.session("", page: tagPage), [parent]).state == .notApplicable)
        let onlyChild = TodoQueryFixture.add(.page(.contentTypes([.subtask])), to: TodoQueryFixture.session())
        #expect(!SubtaskQueryFixture.read(onlyChild, [parent]).coverage.isPartialTypeCoverage)
    }

    @Test func legacyComparisonUsesOnlyCommonChildTextTagAndParentPageSemantics() {
        var first = SubtaskQueryFixture.parent(1, title: "项目 CAFÉ 汇报", day: "2026-09-30")
        first.subtasks[0].tagIDs = TodoQueryFixture.work.uuidString
        first.sourceBundleID = "app.source"
        first.remindMinutes = 930
        var second = SubtaskQueryFixture.parent(2, title: "汇报", day: "2026-09-29")
        second.subtasks[0].tagIDs = TagIDList.encode([TodoQueryFixture.work, TodoQueryFixture.study])
        second.subtasks[0].isDone = true
        let parents = [first, second, SubtaskQueryFixture.parent(3, title: "其他")]
        let filters: [BoardFilter] = [.init(), .init(tagID: TodoQueryFixture.work), .init(tagID: BoardFilter.noneID),
                                     .init(bundleID: "app.source"), .init(reminderScope: .set), .init(dateScope: .overdue)]
        for filter in filters {
            for text in ["项目 汇报", "cafe", "#工作", "#工作 #学习", "汇报 #工作", "无命中"] {
                var query = TodoQueryFixture.session(text)
                for condition in ContentQueryPageMapping.board(filter, context: query.page, evaluation: .listedDay, reminders: true) {
                    query = TodoQueryFixture.add(condition, to: query)
                }
                let result = SubtaskQueryFixture.read(query, parents)
                let legacy = BoardSearch.hits(query: text, todos: parents, diaries: [], routines: [],
                    todayKey: QuerySessionFixture.today, tagMap: TodoQueryFixture.names,
                    scope: .init(filter: filter), calendar: query.page.calendar)
                // noTags 与显式正标签被新 Session 静态拒绝；旧搜索同样无命中，不把它当有效查询等价。
                if filter.isNoTag && text.contains("#") {
                    #expect(result.queryIsValid && result.state == .unsatisfiable && legacy.filter { $0.kind == .subtask }.isEmpty)
                    continue
                }
                #expect(result.isCompleteForCoveredTypes)
                #expect(Set(result.matches.map(\.id.id)) == Set(legacy.filter { $0.kind == .subtask }.map(\.id)))
            }
        }
        // status / created 是新语法，不加入旧搜索等价集。
        #expect(SubtaskQueryFixture.read("status:done created:today", parents).matches.map(\.id.id) == [second.subtasks[0].id])
    }
}
