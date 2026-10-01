import Foundation
import Testing
@testable import AreaChain

struct ContentQueryIntegrationTests {
    @Test func complexInputSurvivesProjectionDetachmentAndReturnsToOriginalPage() throws {
        let page = QuerySessionFixture.page()
        var host = CommandHostSession(page: page)
        #expect(!host.query.showsResults && host.query.scope == .catalog(.tasks))
        let source = "/tasks 汇报 (#工作 | #学习) -#归档 status:open"
        let parsed = ContentQueryParser().parse(source, context: page.dates)
        host.queryEvent(.setInput(source))
        #expect(host.query.input == parsed && host.query.showsResults && host.query.isReady)
        let tags = host.query.conditions.filter { $0.value.dimension == .content(.tag) }
        #expect(tags.map(\.value) == [.clause([.init(atom: .tag("工作")), .init(atom: .tag("学习"))]),
                                     .clause([.init(atom: .tag("归档"), excluded: true)])])
        for (condition, fragment) in zip(tags, ["(#工作 | #学习)", "-#归档"]) {
            #expect(condition.origin == .input(range: (source as NSString).range(of: fragment)))
        }
        let projection = host.query.pageProjection
        #expect(Set(tags.map(\.id)).isSubset(of: Set(projection.extendedConditionIDs)))
        #expect(projection.extendedDimensions.contains(.content(.tag)))
        #expect(projection.boardFilter?.tagID == nil)
        let before = host.query
        let intents = host.queryEvent(.pageFilterChanged(page.location, .content(.tag), .page(.noTags)))
        #expect(intents == [.requiresQueryEditing(tags.map(\.id))] && host.query == before)
        host.queryEvent(.projectionApplied(page.location))
        #expect(host.query == before)
        host.queryEvent(.detach)
        let independent = host.query.conditions
        let other = QuerySessionFixture.page(.diaries(tagID: UUID()), visit: "diaries")
        host.queryEvent(.enterPage(other))
        host.queryEvent(.refreshPage(other))
        host.queryEvent(.pageFilterChanged(other.location, .content(.tag), .page(.tagID(UUID()))))
        #expect(host.query.conditions == independent && host.query.binding == .independent(.explicit))
        #expect(host.queryEvent(.clearUserQuery).contains(.returnToPage(page.location)))
        #expect(host.query.page == page && !host.query.showsResults)
        // 没有提供者或记录输入；isReady 仅证明查询有效，不产生“有结果”断言。
    }

    @Test func diagnosticsStillAddressOriginalUTF16AfterARealConditionEdit() throws {
        var host = PlanFixture.host()
        let source = "/tasks 👩🏽‍💻e\u{301} 汇报 (#工作 | #学习) -#归档 status:open date:2026-02-30"
        host.queryEvent(.setInput(source))
        let invalid = try #require(host.query.textDiagnostics.first { $0.issue == .invalidDate })
        #expect(invalid.range == (source as NSString).range(of: "date:2026-02-30"))
        #expect(CommandPathText.valid(invalid.range, in: source))
        #expect(!host.query.isReady && host.query.showsResults)
        let exclusion = try #require(host.query.conditions.first {
            $0.value == .clause([.init(atom: .tag("归档"), excluded: true)])
        })
        host.queryEvent(.removeCondition(exclusion.id))
        let edited = try QuerySessionFixture.source(host.query)
        #expect(edited == source.replacingOccurrences(of: "-#归档", with: ""))
        let diagnostic = try #require(host.query.textDiagnostics.first { $0.issue == .invalidDate })
        #expect(diagnostic.range == (edited as NSString).range(of: "date:2026-02-30"))
        #expect(host.query.input == ContentQueryParser().parse(edited, context: host.query.queryDates))
    }

    @Test func defaultDateTakeoverAndRemovedScopeHaveDifferentLifetimes() throws {
        let page = QuerySessionFixture.page()
        var host = CommandHostSession(page: page)
        let automatic = try QuerySessionFixture.condition(.content(.date), in: host.query)
        #expect(automatic.value == .atom(.date(QuerySessionFixture.interval())))
        #expect(automatic.origin == .page(visitID: page.location.visitID))
        host.queryEvent(.setInput("汇报 date:today"))
        let ownedDate = try QuerySessionFixture.condition(.content(.date), in: host.query)
        #expect(ownedDate.origin.isUser && !host.query.conditions.contains { $0.id == automatic.id })
        let tomorrow = ContentQueryPageContext(location: page.location, page: page.page,
                                               todayKey: "2026-10-02", calendar: page.calendar)
        host.queryEvent(.refreshPage(tomorrow))
        #expect(try QuerySessionFixture.condition(.content(.date), in: host.query) == ownedDate)
        let scope = try QuerySessionFixture.condition(.scope, in: host.query)
        host.queryEvent(.removeCondition(scope.id))
        host.queryEvent(.refreshPage(tomorrow))
        #expect(host.query.scope == .global && host.query.suppressed.contains(.scope))
        #expect(host.query.binding == .independent(.removedPageScope))
        #expect(host.queryEvent(.clearUserQuery).contains(.returnToPage(page.location)))
        #expect(host.query.scope == .global && host.query.suppressed.contains(.scope))
        host.queryEvent(.enterPage(QuerySessionFixture.page(.settings, visit: "settings")))
        let reentered = QuerySessionFixture.page(.today(.init()), visit: "today-again")
        host.queryEvent(.enterPage(reentered))
        #expect(host.query.scope == .catalog(.tasks) && host.query.suppressed.isEmpty)
        #expect(!host.query.showsResults)
    }
}
