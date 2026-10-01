import Foundation
import Testing
@testable import AreaChain

struct ContentQueryProjectionTests {
    typealias Fixture = QuerySessionFixture

    @Test func complexQueriesCannotBeCompressedOrOverwrittenByBoardFilters() throws {
        for source in ["(#甲 | #乙)", "-#甲", "#甲 #乙", "(!p1 | !p4)", "@15:30", "date:today date:2026-10-02"] {
            var state = ContentQuerySession(page: Fixture.page())
            Fixture.apply(.setInput(source), &state)
            let explicit = state.conditions.filter { !$0.origin.isPage }
            let dimension = try #require(explicit.first?.value.dimension)
            #expect(state.pageProjection.extendedDimensions.contains(dimension))
            let snapshot = state
            let output = Fixture.apply(.pageFilterChanged(state.page.location, dimension, nil), &state)
            #expect(output == [.requiresQueryEditing(explicit.map(\.id))])
            #expect(state == snapshot)
            #expect(Fixture.apply(.projectionApplied(state.page.location), &state).isEmpty)
            #expect(try Fixture.source(state) == source)
        }
    }

    @Test func pageEditsOfSimpleTextConditionsPreserveRemainingRawInputAndDiagnostics() throws {
        let prefix = "👩🏽‍💻 e\u{301} "
        var state = ContentQuerySession(page: Fixture.page())
        Fixture.apply(.setInput(prefix + "!p1 \"未闭合"), &state)
        let priorityID = try Fixture.condition(.content(.priority), in: state).id
        let p2 = try #require(ContentQueryPageMapping.priorityValue(.p2))
        Fixture.apply(.editCondition(priorityID, p2), &state)
        let source = try Fixture.source(state)
        #expect(source == prefix + " \"未闭合")
        let diagnostic = try #require(state.textDiagnostics.first)
        #expect((source as NSString).substring(with: diagnostic.range) == "\"未闭合")
        #expect(diagnostic.range.location == (prefix + " ").utf16.count)
        #expect(try Fixture.condition(.content(.priority), in: state).id == priorityID)
        #expect(try Fixture.condition(.content(.priority), in: state).origin == .user)
    }

    @Test func automaticConditionsNeverFabricateRangesOrShiftInvalidInput() throws {
        let prefix = "中文 👩🏽‍💻 e\u{301} "
        let source = prefix + "date:2026-10-"
        var state = ContentQuerySession(page: Fixture.page(.today(.init(tagID: UUID()))))
        Fixture.apply(.setInput(source), &state)
        guard case .content(let expected) = ContentQueryParser().parse(source, context: state.page.dates) else {
            Issue.record("应返回内容"); return
        }
        #expect(state.textDiagnostics == expected.diagnostics)
        #expect(try Fixture.source(state) == source)
        #expect(state.conditions.filter { $0.origin.isPage }.allSatisfy {
            if case .input = $0.origin { return false }; return true
        })
        Fixture.apply(.refreshPage(Fixture.page(.today(.init(bundleID: "new.app")))), &state)
        #expect(state.textDiagnostics == expected.diagnostics)
        #expect(!state.isReady)
    }

    @Test func unchangedInputConditionsKeepIdentityAfterEarlierUTF16Changes() throws {
        var state = ContentQuerySession(page: Fixture.page())
        Fixture.apply(.setInput("甲 #工作"), &state)
        let tag = try Fixture.condition(.content(.tag), in: state)
        Fixture.apply(.setInput("👩🏽‍💻 新的前缀 #工作"), &state)
        let edited = try Fixture.condition(.content(.tag), in: state)
        #expect(edited.id == tag.id)
        #expect(edited.origin != tag.origin)
        if case .input(let range) = edited.origin {
            #expect((try Fixture.source(state) as NSString).substring(with: range) == "#工作")
        } else { Issue.record("应保持输入来源") }
    }

    @Test func stableTagIdentitySurvivesDisplayNameChange() throws {
        let id = UUID()
        var state = ContentQuerySession(page: Fixture.page(.diaries(tagID: id)))
        let initial = try Fixture.condition(.content(.tag), in: state)
        // 显示名称由宿主查表，改名事件仍传同一 UUID，不重新按文字解析。
        Fixture.apply(.refreshPage(Fixture.page(.diaries(tagID: id))), &state)
        #expect(try Fixture.condition(.content(.tag), in: state) == initial)
        #expect(state.pageProjection.boardFilter?.tagID == id)
        Fixture.apply(.setInput("#同名标签"), &state)
        #expect(state.pageProjection.extendedDimensions.contains(.content(.tag)))
        #expect(try Fixture.condition(.content(.tag), in: state).value != initial.value)
    }

    @Test func sameDimensionUserPrecedenceDoesNotHideRealCrossDimensionConflict() {
        var state = ContentQuerySession(page: Fixture.page(.pending(lane: .overdue, filter: .init())))
        Fixture.apply(.setInput("status:done"), &state)
        #expect(state.isStructurallyValid)
        #expect(state.typeAnalysis.assessment(for: .todo)?.reasons.contains { $0.issue == .contradiction } == true)
        #expect(state.conditions.contains { $0.value == .atom(.status(.done)) })
        Fixture.apply(.setInput("date:today"), &state)
        #expect(state.isReady)
        #expect(state.conditions.filter { $0.value.dimension == .content(.date) }.count == 1)
        #expect(!state.conditions.contains { if case .page(.boardDate) = $0.value { return true }; return false })
    }

    @Test func semanticConflictsRetainAllConditionsAndHaveIdentityDiagnostics() {
        var state = ContentQuerySession(page: Fixture.page(.settings))
        Fixture.apply(.addCondition(.page(.noTags)), &state)
        Fixture.apply(.addCondition(.page(.tagID(UUID()))), &state)
        #expect(state.conditions.count == 2)
        #expect(state.typeAnalysis.assessment(for: .todo)?.reasons == [
            .init(issue: .contradiction, conditionIDs: state.conditions.map(\.id), binding: .ownTags)
        ])
        Fixture.apply(.clearUserQuery, &state)
        Fixture.apply(.addCondition(.page(.reminderPresence(.unset))), &state)
        Fixture.apply(.setInput("@15:30"), &state)
        #expect(state.isStructurallyValid)
        #expect(state.typeAnalysis.assessment(for: .todo)?.reasons.contains { $0.issue == .contradiction } == true)
    }

    @Test func invalidSemanticConditionsAreNotReadyAndDoNotProduceExecution() {
        var state = ContentQuerySession(page: Fixture.page())
        let intents = Fixture.apply(.addCondition(.clause([])), &state)
        #expect(!state.isReady)
        #expect(state.conditionDiagnostics.contains { $0.issue == .incompleteCondition })
        #expect(state.showsResults)
        for intent in intents {
            switch intent {
            case .synchronizePage, .returnToPage, .requiresQueryEditing, .rejectedEvent: break
            }
        }
        // 此穷举在引入新意图时要求重审；当前 API 不接收或输出操作草稿、目标或执行项。
    }

    @Test func refreshDoesNotReparseRelativeUserDate() throws {
        var state = ContentQuerySession(page: Fixture.page(.calendar(Fixture.interval())))
        Fixture.apply(.setInput("date:today"), &state)
        let date = try Fixture.condition(.content(.date), in: state)
        let page = ContentQueryPageContext(location: state.page.location, page: .calendar(Fixture.interval("2026-10-02")),
                                           todayKey: "2026-10-02", calendar: state.page.calendar)
        Fixture.apply(.refreshPage(page), &state)
        #expect(try Fixture.condition(.content(.date), in: state) == date)
    }

    @Test func calendarProjectionOnlyAcceptsRepresentablePeriods() {
        let month = Fixture.interval("2026-10-01", "2026-10-31")
        let context = Fixture.page(.calendar(month, view: .month))
        #expect(ContentQueryPageProjection.accepts(.atom(.date(month)), context: context))
        #expect(!ContentQueryPageProjection.accepts(.atom(.date(Fixture.interval())), context: context))
        let quadrant = Fixture.page(.quadrants(dayKey: Fixture.today, selection: nil))
        #expect(!ContentQueryPageProjection.accepts(.atom(.date(month)), context: quadrant))
    }

    @Test func explicitDetachKeepsConditionsAndDoesNotBecomeGlobal() {
        var state = ContentQuerySession(page: Fixture.page())
        let before = state.conditions.map(\.value)
        Fixture.apply(.detach, &state)
        #expect(state.conditions.map(\.value) == before)
        #expect(state.conditions.allSatisfy { $0.origin == .user })
        #expect(state.showsResults)
    }

    @Test func pageDateChoiceReplacesAutomaticDateButCannotEraseExtendedUserDates() {
        var state = ContentQuerySession(page: Fixture.page())
        let value = ContentQueryConditionValue.page(.boardDate(.upcoming, .init(
            evaluation: .listedDay, todayKey: state.page.todayKey, calendar: state.page.calendar)))
        Fixture.apply(.pageFilterChanged(state.page.location, .content(.date), value), &state)
        #expect(state.pageProjection.boardFilter?.dateScope == .upcoming)
        #expect(state.conditions.filter { $0.value.dimension == .content(.date) }.map(\.value) == [value])
    }
}
