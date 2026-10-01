import Foundation
import Testing
@testable import AreaChain

@MainActor struct ContentQueryHandoffTests {
    @Test func sourceAutomaticScopeAndPredicatesFreezeWithoutBecomingUserInput() throws {
        let fixture = try HandoffFixture(targetPage: .diaries(tagID: UUID()))
        let before = try fixture.state().query
        #expect(!before.showsResults)
        let ticket = try fixture.prepare()
        #expect(!ticket.requirements.replacesQuery)
        try fixture.coordinator.confirm(ticket, readiness: .init())
        try fixture.coordinator.commit(ticket)
        let received = try fixture.state(HandoffFixture.target).query
        #expect(!received.showsResults)
        #expect(received.scope == .catalog(.tasks))
        #expect(received.composition == before.composition)
        #expect(received.conditions.map(\.value) == before.conditions.map(\.value))
        #expect(received.conditions.map(\.id) == before.conditions.map(\.id))
        #expect(received.conditions.allSatisfy { $0.origin == .handoffPage(before.page.location) })
        #expect(received.binding == .independent(.handoff))
        let refresh = QuerySessionFixture.page(.images, host: HandoffFixture.source)
        try fixture.send(.query(.refreshPage(refresh)))
        try fixture.send(.query(.refreshPage(refresh)), host: HandoffFixture.target)
        #expect(try fixture.state(HandoffFixture.target).query == received)
        try fixture.send(.query(.enterPage(QuerySessionFixture.page(.trash, visit: "trash", host: HandoffFixture.target))), host: HandoffFixture.target)
        #expect(try fixture.state(HandoffFixture.target).query.conditions == received.conditions)
        #expect(try fixture.state(HandoffFixture.target).query.scope == .catalog(.tasks))
    }

    @Test func rawInputDiagnosticsExplicitScopeAndDatesAreNotReparsed() throws {
        let fixture = try HandoffFixture(targetPage: .clipboard)
        try fixture.send(.query(.setInput("/diaries Synthetic 😀 date:2026-99-01")))
        let before = try fixture.state().query
        #expect(!before.textDiagnostics.isEmpty)
        try fixture.transfer()
        let received = try fixture.state(HandoffFixture.target).query
        #expect(received.input == before.input)
        #expect(received.textDiagnostics == before.textDiagnostics)
        #expect(received.conditions == before.conditions)
        #expect(received.scope == .catalog(.diaries))
        #expect(received.queryDates.todayKey == before.queryDates.todayKey)
        #expect(received.queryDates.calendar == before.queryDates.calendar)
        #expect(received.handoffContext == before.page)
        let current = try fixture.owned(HandoffFixture.target)
        let refresh = ContentQueryPageContext(location: current.session.query.page.location, page: .clipboard,
                                              todayKey: "2027-01-02", calendar: before.page.calendar)
        try fixture.send(.query(.refreshPage(refresh)), host: HandoffFixture.target)
        #expect(try fixture.state(HandoffFixture.target).query.queryDates.todayKey == before.queryDates.todayKey)
        #expect(try fixture.state(HandoffFixture.target).query.queryDates.calendar == before.queryDates.calendar)
        #expect(try fixture.state(HandoffFixture.target).query.input == before.input)
    }

    @Test func effectiveGlobalScopeIsExplicitlyFrozenAndCanRebind() throws {
        let fixture = try HandoffFixture(sourcePage: .settings, targetPage: .diaries(tagID: nil))
        try fixture.transfer()
        let received = try fixture.state(HandoffFixture.target).query
        #expect(received.scope == .global && !received.showsResults)
        #expect(received.conditions.contains { $0.value == .scope(.global) && $0.origin.isHandoffPage })
        try fixture.send(.query(.rebind), host: HandoffFixture.target)
        let rebound = try fixture.state(HandoffFixture.target).query
        #expect(rebound.scope == .catalog(.diaries))
        #expect(rebound.handoffContext == nil)
        #expect(rebound.binding == .page(visitID: rebound.page.location.visitID))
        #expect(rebound.conditions.allSatisfy { $0.origin.isPage })
    }

    @Test func rebindDoesNotOverrideExplicitUserScope() throws {
        let fixture = try HandoffFixture(targetPage: .images)
        try fixture.send(.query(.setInput("/diaries Synthetic query")))
        try fixture.transfer()
        let before = try fixture.state(HandoffFixture.target).query
        let result = try fixture.send(.query(.rebind), host: HandoffFixture.target)
        if case .query(let intents) = result {
            #expect(intents.contains { if case .requiresQueryEditing = $0 { return true }; return false })
        } else { Issue.record("Expected query editing") }
        #expect(try fixture.state(HandoffFixture.target).query == before)
    }

    @Test func clearReturnsOnlyToTargetAndRestoresTargetDefaults() throws {
        let fixture = try HandoffFixture(targetPage: .images)
        try fixture.send(.query(.setInput("Synthetic query")))
        let source = try fixture.state().query.page.location
        let scope = try QuerySessionFixture.condition(.scope, in: fixture.state().query)
        try fixture.send(.query(.removeCondition(scope.id)))
        let target = try fixture.state(HandoffFixture.target).query.page.location
        try fixture.transfer()
        try fixture.send(.query(.enterPage(QuerySessionFixture.page(.trash, visit: "later", host: HandoffFixture.target))), host: HandoffFixture.target)
        let result = try fixture.send(.query(.clearUserQuery), host: HandoffFixture.target)
        if case .query(let intents) = result {
            #expect(intents.contains(.returnToPage(target)))
            #expect(!intents.contains(.returnToPage(source)))
            #expect(!intents.contains { if case .synchronizePage(let location, _) = $0 { return location.hostID == source.hostID }; return false })
        } else { Issue.record("Expected query effect") }
        let cleared = try fixture.state(HandoffFixture.target).query
        #expect(cleared.scope == .catalog(.images))
        #expect(cleared.suppressed.isEmpty && cleared.handoffContext == nil)
        #expect(cleared.page.location == target && !cleared.showsResults)
    }

    @Test func targetSuppressionSurvivesReplacementAndClear() throws {
        let fixture = try HandoffFixture(targetPage: .images)
        let targetScope = try QuerySessionFixture.condition(.scope, in: fixture.state(HandoffFixture.target).query)
        try fixture.send(.query(.removeCondition(targetScope.id)), host: HandoffFixture.target)
        let ticket = try fixture.prepare()
        #expect(ticket.requirements.replacesQuery)
        try fixture.coordinator.confirm(ticket, readiness: .init(acceptsQueryReplacement: true))
        try fixture.coordinator.commit(ticket)
        try fixture.send(.query(.clearUserQuery), host: HandoffFixture.target)
        let query = try fixture.state(HandoffFixture.target).query
        #expect(query.scope == .global)
        #expect(query.suppressed.contains(.scope))
    }

    @Test(arguments: [" ", "/setting/language/chinese", "text", "detach", "userCondition"])
    func targetIntentRequiresReplacementEvenWithoutResults(intent: String) throws {
        let fixture = try HandoffFixture()
        switch intent {
        case "detach": try fixture.send(.query(.detach), host: HandoffFixture.target)
        case "userCondition": try fixture.send(.query(.addCondition(.scope(.global))), host: HandoffFixture.target)
        default: try fixture.send(.query(.setInput(intent)), host: HandoffFixture.target)
        }
        #expect(try fixture.prepare().requirements.replacesQuery)
    }

    @Test func editingFrozenConditionCreatesUserIntentAndClearRemovesIt() throws {
        let fixture = try HandoffFixture()
        try fixture.transfer()
        let query = try fixture.state(HandoffFixture.target).query
        let condition = try #require(query.conditions.first { $0.value.dimension == .content(.date) })
        try fixture.send(.query(.editCondition(condition.id, condition.value)), host: HandoffFixture.target)
        #expect(try fixture.state(HandoffFixture.target).query.showsResults)
        try fixture.send(.query(.setInput("")), host: HandoffFixture.target)
        #expect(try fixture.state(HandoffFixture.target).query.conditions.contains { $0.id == condition.id && $0.origin == .user })
        try fixture.send(.query(.clearUserQuery), host: HandoffFixture.target)
        #expect(try fixture.state(HandoffFixture.target).query.conditions.isEmpty)
    }

    @Test func newExplicitInputReplacesOnlyFrozenDimensions() throws {
        let fixture = try HandoffFixture()
        try fixture.transfer()
        try fixture.send(.query(.setInput("/diaries Synthetic date:2026-12-03")), host: HandoffFixture.target)
        let query = try fixture.state(HandoffFixture.target).query
        #expect(query.scope == .catalog(.diaries))
        #expect(query.conditions.filter { $0.value.dimension == .content(.date) }.count == 1)
        #expect(query.conditions.allSatisfy { $0.origin.isUser })
        #expect(query.isReady)
    }

    @Test func removingFrozenScopeDoesNotImplicitlyRebindOnNavigation() throws {
        let fixture = try HandoffFixture()
        try fixture.send(.query(.setInput("Synthetic query")))
        try fixture.transfer()
        let scope = try QuerySessionFixture.condition(.scope, in: fixture.state(HandoffFixture.target).query)
        try fixture.send(.query(.removeCondition(scope.id)), host: HandoffFixture.target)
        let before = try fixture.state(HandoffFixture.target).query
        try fixture.send(.query(.enterPage(QuerySessionFixture.page(.images, visit: "images", host: HandoffFixture.target))), host: HandoffFixture.target)
        let after = try fixture.state(HandoffFixture.target).query
        #expect(after.scope == .global)
        #expect(after.conditions == before.conditions)
        #expect(after.binding == .independent(.removedPageScope))
        #expect(after.suppressed.contains(.scope))
        #expect(after.handoffContext == before.handoffContext)
    }
}
