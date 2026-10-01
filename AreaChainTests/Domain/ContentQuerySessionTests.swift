import Foundation
import Testing
@testable import AreaChain

struct ContentQuerySessionTests {
    typealias Fixture = QuerySessionFixture

    @Test func defaultsDoNotActivateButTextAndExplicitChipsDo() throws {
        var state = ContentQuerySession(page: Fixture.page())
        #expect(!state.showsResults)
        #expect(state.scope == .catalog(.tasks))
        #expect(try Fixture.condition(.content(.date), in: state).value == .atom(.date(Fixture.interval())))
        #expect(state.conditions.allSatisfy { $0.origin.isPage })
        Fixture.apply(.setInput("汇报"), &state)
        #expect(state.showsResults)
        #expect(state.returnPoint?.context.location == state.page.location)
        Fixture.apply(.clearUserQuery, &state)
        Fixture.apply(.addCondition(.scope(.catalog(.tasks))), &state)
        #expect(try Fixture.source(state) == "")
        #expect(state.showsResults)
    }

    @Test func removedScopeSurvivesRefreshAndHostPresentationEvents() throws {
        var state = ContentQuerySession(page: Fixture.page())
        let scope = try Fixture.condition(.scope, in: state)
        Fixture.apply(.removeCondition(scope.id), &state)
        let removed = state
        for _ in 0..<4 {
            // 重聚焦、刷新、详情/原生面板关闭只能刷新同一次访问。
            Fixture.apply(.refreshPage(Fixture.page()), &state)
            Fixture.apply(.projectionApplied(state.page.location), &state)
        }
        #expect(state == removed)
        #expect(state.scope == .global)
        #expect(state.suppressed.contains(.scope))
        #expect(state.binding == .independent(.removedPageScope))
    }

    @Test func newVisitRestoresDefaultsEvenForSamePageType() throws {
        var state = ContentQuerySession(page: Fixture.page())
        Fixture.apply(.removeCondition(try Fixture.condition(.scope, in: state).id), &state)
        Fixture.apply(.enterPage(Fixture.page(.settings, visit: "settings")), &state)
        Fixture.apply(.enterPage(Fixture.page(visit: "visit-2")), &state)
        #expect(state.scope == .catalog(.tasks))
        #expect(state.suppressed.isEmpty)
        #expect(!state.showsResults)
    }

    @Test func explicitRangeRemainsIndependentAcrossPagesAndMatchingPaths() throws {
        var state = ContentQuerySession(page: Fixture.page())
        Fixture.apply(.setInput("/diaries 汇报"), &state)
        #expect(state.binding == .independent(.userScope))
        Fixture.apply(.enterPage(Fixture.page(.calendar(Fixture.interval()), visit: "calendar")), &state)
        #expect(state.scope == .catalog(.diaries))
        #expect(!state.conditions.contains { $0.origin.isPage })
        Fixture.apply(.enterPage(Fixture.page(.diaries(tagID: UUID()), visit: "diaries")), &state)
        #expect(state.binding == .independent(.userScope))
        #expect(state.conditions.count == 2)
        Fixture.apply(.rebind, &state)
        #expect(state.binding == .page(visitID: "diaries"))
        #expect(state.conditions.contains { $0.value.dimension == .content(.tag) })
    }

    @Test func clearReturnsToCapturedVisitAndPreservesDeletionAfterActivation() throws {
        var state = ContentQuerySession(page: Fixture.page())
        let original = state.page.location
        Fixture.apply(.setInput("汇报"), &state)
        Fixture.apply(.removeCondition(try Fixture.condition(.scope, in: state).id), &state)
        Fixture.apply(.enterPage(Fixture.page(.settings, visit: "settings")), &state)
        Fixture.apply(.setInput("第二次输入"), &state)
        let intents = Fixture.apply(.clearUserQuery, &state)
        #expect(intents.contains(.returnToPage(original)))
        #expect(state.page.location == original)
        #expect(state.scope == .global)
        #expect(state.suppressed.contains(.scope))
        #expect(!state.showsResults)
    }

    @Test func returnLocationIsNotRebuiltByRefreshOrTyping() {
        var state = ContentQuerySession(page: Fixture.page())
        Fixture.apply(.setInput("甲"), &state)
        let point = state.returnPoint
        Fixture.apply(.refreshPage(Fixture.page(.today(.init(bundleID: "example.app")))), &state)
        Fixture.apply(.setInput("甲乙"), &state)
        #expect(state.returnPoint == point)
        let intents = Fixture.apply(.setInput(""), &state)
        #expect(intents.contains(.returnToPage(Fixture.page().location)))
        #expect(!state.showsResults)
    }

    @Test func boundFilterAndQueryRoundTripWithoutEchoLoop() throws {
        var state = ContentQuerySession(page: Fixture.page())
        let p2 = try #require(ContentQueryPageMapping.priorityValue(.p2))
        let output = Fixture.apply(.pageFilterChanged(state.page.location, .content(.priority), p2), &state)
        #expect(state.pageProjection.boardFilter?.priorityScope == .p2)
        #expect(try Fixture.condition(.content(.priority), in: state).origin == .user)
        #expect(!output.isEmpty)
        let snapshot = state
        #expect(Fixture.apply(.projectionApplied(state.page.location), &state).isEmpty)
        #expect(state == snapshot)
        let id = try Fixture.condition(.content(.priority), in: state).id
        Fixture.apply(.editCondition(id, .atom(.priority(PriorityToken.flags(in: "!p1")!))), &state)
        #expect(state.pageProjection.boardFilter?.priorityScope == .p1)
        #expect(try Fixture.condition(.content(.priority), in: state).id == id)
    }

    @Test func detachedPageEventsCannotChangeQueryOrWriteOldFilters() throws {
        var state = ContentQuerySession(page: Fixture.page())
        let location = state.page.location
        Fixture.apply(.detach, &state)
        let snapshot = state
        #expect(Fixture.apply(.pageFilterChanged(location, .sourceApplication, .page(.sourceApplication("app"))), &state).isEmpty)
        #expect(state == snapshot)
        let intents = Fixture.apply(.setInput("/tasks 文本"), &state)
        #expect(state.binding == .independent(.explicit))
        #expect(intents.isEmpty)
        Fixture.apply(.rebind, &state)
        #expect(state.binding == .page(visitID: location.visitID))
        #expect(state.scope == .catalog(.tasks))
    }

    @Test func rebindDoesNotSilentlyDiscardIncompatibleExplicitScope() {
        var state = ContentQuerySession(page: Fixture.page())
        Fixture.apply(.setInput("/diaries"), &state)
        let snapshot = state
        let intents = Fixture.apply(.rebind, &state)
        #expect(intents.contains { if case .requiresQueryEditing = $0 { return true }; return false })
        #expect(state == snapshot)
    }

    @Test func calendarRefreshOnlyUpdatesOwnedDateAndPreservesIdentity() throws {
        var state = ContentQuerySession(page: Fixture.page(.calendar(Fixture.interval())))
        let initial = try Fixture.condition(.content(.date), in: state)
        Fixture.apply(.refreshPage(Fixture.page(.calendar(Fixture.interval("2026-11-01", "2026-11-30")))), &state)
        #expect(try Fixture.condition(.content(.date), in: state).id == initial.id)
        Fixture.apply(.setInput("date:2026-12-01"), &state)
        let explicit = try Fixture.condition(.content(.date), in: state)
        Fixture.apply(.refreshPage(Fixture.page(.calendar(Fixture.interval("2027-01-01", "2027-01-31")))), &state)
        #expect(try Fixture.condition(.content(.date), in: state) == explicit)
        #expect(state.isReady)
    }

    @Test func switchingPagesPreservesUserDimensionsWithExplicitPrecedence() throws {
        var state = ContentQuerySession(page: Fixture.page())
        Fixture.apply(.setInput("项目 date:2026-12-01 !p2"), &state)
        let date = try Fixture.condition(.content(.date), in: state)
        Fixture.apply(.enterPage(Fixture.page(.quadrants(dayKey: "2026-10-02", selection: .urgent), visit: "quad")), &state)
        #expect(try Fixture.condition(.content(.date), in: state) == date)
        #expect(state.conditions.filter { $0.value.dimension == .content(.priority) }.count == 1)
        #expect(state.isReady)
        #expect(try Fixture.source(state) == "项目 date:2026-12-01 !p2")
    }

    @Test func editingAutomaticConditionTransfersOwnershipEvenForIdenticalValue() throws {
        var state = ContentQuerySession(page: Fixture.page(.calendar(Fixture.interval())))
        let automatic = try Fixture.condition(.content(.date), in: state)
        Fixture.apply(.editCondition(automatic.id, automatic.value), &state)
        #expect(state.showsResults)
        #expect(try Fixture.condition(.content(.date), in: state).origin == .user)
        Fixture.apply(.refreshPage(Fixture.page(.calendar(Fixture.interval("2026-12-01")))), &state)
        #expect(try Fixture.condition(.content(.date), in: state).value == automatic.value)
    }

    @Test func twoHostsRemainIndependentAndRejectCrossHostNavigation() {
        var workspace = ContentQuerySession(page: Fixture.page())
        let menu = ContentQuerySession(page: Fixture.page(host: "menu"))
        Fixture.apply(.setInput("/diaries"), &workspace)
        let snapshot = workspace
        #expect(Fixture.apply(.enterPage(menu.page), &workspace) == [.rejectedEvent])
        #expect(workspace == snapshot)
        #expect(!menu.showsResults)
        #expect(menu.scope == .catalog(.tasks))
    }

    @Test func commandParsingAndResultsHaveIndependentMeaning() throws {
        var state = ContentQuerySession(page: Fixture.page())
        Fixture.apply(.setInput("/setting/language/chinese"), &state)
        guard case .command(let path) = state.input else { Issue.record("应保留指令结果"); return }
        #expect(path.command?.id.rawValue == "setting.language")
        #expect(!state.showsResults)
        #expect(state.returnPoint == nil)
        Fixture.apply(.setInput("date:"), &state)
        #expect(state.showsResults)
        #expect(!state.isReady)
        #expect(state.textDiagnostics.first?.issue == .incompleteCondition)
    }

    @Test func clearingCommandInputAlsoReturnsToExistingResultContext() {
        var state = ContentQuerySession(page: Fixture.page())
        let original = state.page.location
        Fixture.apply(.setInput("文本"), &state)
        Fixture.apply(.setInput("/setting/language/chinese"), &state)
        #expect(!state.showsResults)
        Fixture.apply(.enterPage(Fixture.page(.settings, visit: "settings")), &state)
        let intents = Fixture.apply(.setInput(""), &state)
        #expect(intents.contains(.returnToPage(original)))
        #expect(state.page.location == original)
        #expect(state.returnPoint == nil)
    }
}
