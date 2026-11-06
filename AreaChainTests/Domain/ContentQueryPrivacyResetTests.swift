import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct ContentQueryPrivacyResetTests {
    @Test func systemClearDropsFrozenConditionsAndReturnSnapshot() throws {
        let h = try HandoffFixture(sourcePage: .diaries(tagID: UUID()))
        try h.send(.query(.setInput("/diaries synthetic-query #synthetic-tag")))
        try h.transfer()
        let target = HandoffFixture.target
        let before = try h.state(target)
        #expect(before.query.handoffContext != nil && before.query.returnPoint != nil)
        #expect(!before.query.conditions.isEmpty)
        let original = try h.owned(target).lease
        try h.send(.query(.setInput("Synthetic revised query")), host: target)
        try h.coordinator.invalidateSearch(ownedBy: original.ownership)
        let after = try h.state(target)
        #expect(try QuerySessionFixture.source(after.query) == "")
        #expect(after.query.conditions.isEmpty && after.query.returnPoint == nil && after.query.handoffContext == nil)
        #expect(after.query.page.page == .overview && after.query.page.location.reference == "")
        #expect(after.query.binding == .independent(.privacyInvalidated))
        #expect(throws: CommandHandoffError.stale) { try h.coordinator.send(.query(.setInput("stale")), expecting: original) }
    }

    @Test func handoffOfClearedQueryKeepsBothHostsWaitingForTrustedPage() throws {
        let h = try HandoffFixture()
        try h.coordinator.invalidateSearch(ownedBy: h.owned().lease.ownership)
        try h.transfer()
        for host in [HandoffFixture.source, HandoffFixture.target] {
            let query = try h.state(host).query
            #expect(query.binding == .independent(.privacyInvalidated))
            #expect(query.conditions.isEmpty && query.returnPoint == nil && query.handoffContext == nil)
        }
    }

    @Test func oldSourceCallbackCannotClearReceiverNewQuery() async throws {
        let f = try SearchReadFixture()
        try await f.publish()
        let old = try f.lease
        try f.handoff.transfer()
        try f.handoff.send(.query(.setInput("Receiver new query")), host: HandoffFixture.target)
        let target = try f.handoff.state(HandoffFixture.target)
        let otherVault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys())
        let receiver = try ContentQueryReadSession(vault: otherVault, owner: ContentQueryReadOwner(),
            coordinator: f.handoff.coordinator, ownership: f.handoff.owned(HandoffFixture.target).lease.ownership,
            notifications: .init(privacy: .default, model: .init(), focus: .init(),
                                 focusLost: SearchReadFixture.focusLost, focusObject: NSObject()))
        receiver.install()
        let read = try receiver.prepare { .init(requestID: UUID(), session: $0) }
        try receiver.evaluate(read)
        try await receiver.publish(read)
        f.vault.lock()
        #expect(f.session.diagnostic == .staleHost)
        #expect(f.owner.source == nil && !f.session.hasPublicationPermit)
        #expect(try f.handoff.state(HandoffFixture.target) == target)
        #expect(receiver.hasPublicationPermit)
        #expect(throws: CommandHandoffError.stale) { try f.handoff.coordinator.invalidateSearch(ownedBy: old.ownership) }
    }

    @Test func privacyResetDoesNotRestoreUserReturnPageOrAutomaticallyRebuildConditions() throws {
        var query = ContentQuerySession(page: QuerySessionFixture.page(.diaries(tagID: UUID())))
        QuerySessionFixture.apply(.setInput("Synthetic secret"), &query)
        QuerySessionFixture.apply(.detach, &query)
        let ordinary = ContentQueryReducer.reduce(query, .clearUserQuery)
        #expect(!ordinary.state.conditions.isEmpty)
        let cleared = ContentQueryReducer.reduce(query, .privacyInvalidated)
        #expect(cleared.intents.isEmpty && cleared.state.conditions.isEmpty)
        #expect(cleared.state.returnPoint == nil && cleared.state.page.page == .overview)
        let input = ContentQueryReducer.reduce(cleared.state, .setInput("date:today"))
        #expect(input.intents == [.rejectedEvent] && input.state == cleared.state)
        #expect(ContentQueryReducer.reduce(cleared.state, .rebind).intents == [.rejectedEvent])
        let moved = cleared.state.handedOff(to: ContentQuerySession(page: QuerySessionFixture.page(host: "other")))
        #expect(moved.binding == .independent(.privacyInvalidated) && moved.handoffContext == nil)
        let rebuilt = ContentQueryReducer.reduce(cleared.state, .enterPage(QuerySessionFixture.page(.today(.init()), visit: "trusted")))
        #expect(!rebuilt.state.conditions.isEmpty && rebuilt.state.conditions.allSatisfy { $0.origin.isPage })
        #expect(try QuerySessionFixture.source(rebuilt.state) == "")
    }
}
