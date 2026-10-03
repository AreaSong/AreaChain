import Foundation
import Observation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct ContentQueryReadSessionObservationTests {
    @Test func methodChangeWillChangeClosesGateAndResubscriptionGapStaysClosed() async throws {
        let f = try SearchReadFixture()
        try await f.unlock()
        try await f.publish()
        let revision = f.vault.revision
        // 实际方法边界改变 isChangingMethods，未直接写任何 vault 状态。
        try f.vault.beginMethodChange()
        #expect(f.vault.revision == revision && f.vault.isChangingMethods)
        #expect(!f.session.isTrackingReady && !f.session.hasPublicationPermit)
        #expect(!f.session.hasRetainedPresentation)
        #expect(throws: ContentQueryReadSessionError.trackingPending) { try f.session.prepare(read: f.batch) }
        f.vault.endMethodChange()
        try f.vault.beginMethodChange()
        f.vault.endMethodChange()
        await f.settle()
        #expect(!f.session.hasPublicationPermit)
        try await f.publish()
        // 第二轮实际属性变更证明跟踪确实重新建立。
        try f.vault.setIdleSeconds(60)
        #expect(f.vault.revision > revision && !f.session.hasRetainedPresentation)
        await f.settle()
        try await f.publish()
        f.vault.lock()
        try f.expectEmpty()
    }

    @Test func authenticationStartWithoutDidChangeRevokesOldResults() async throws {
        let f = try SearchReadFixture()
        try await f.unlock()
        try await f.publish()
        let revision = f.vault.revision
        await f.system.suspend()
        let authentication = Task { try await f.vault.unlockWithSystem(reason: "Synthetic pending read") }
        for _ in 0..<200 where await f.system.pendingRead == nil { await Task.yield() }
        #expect(await f.system.pendingRead != nil)
        #expect(f.vault.isAuthenticating && f.vault.revision == revision)
        #expect(!f.session.hasPublicationPermit && !f.session.hasRetainedPresentation)
        await f.settle()
        #expect(throws: ContentQueryReadSessionError.vaultBusy) { try f.session.prepare(read: f.batch) }
        await f.system.finishRead()
        try await authentication.value
        await f.settle()
        #expect(!f.session.hasPublicationPermit && f.owner.source == nil)
    }

    @Test func repeatedInstallAndNotificationsDoNotAccumulateObservationCallbacks() async throws {
        let f = try SearchReadFixture()
        f.session.install()
        f.session.install()
        try await f.publish()
        // didChange 即使没有字段改变也关闭并重订阅；旧 registrar 回调必须被停用。
        for _ in 0..<3 {
            NotificationCenter.default.post(name: .privacyDidChange, object: f.vault)
            await f.settle()
        }
        try await f.publish()
        let epoch = f.session.invalidationEpoch
        try f.vault.beginMethodChange()
        #expect(f.session.invalidationEpoch == epoch + 1)
        f.vault.endMethodChange()
        await f.settle()
        #expect(!f.session.hasPublicationPermit)
    }

    @Test func foreignVaultEventsAndOtherFocusObjectDoNotAffectHost() async throws {
        let f = try SearchReadFixture()
        let other = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys())
        try await f.publish()
        let epoch = f.session.invalidationEpoch
        other.lock()
        NotificationCenter.default.post(name: .privacyMask, object: other)
        f.focus.post(name: SearchReadFixture.focusLost, object: NSObject())
        #expect(f.session.invalidationEpoch == epoch && f.session.hasPublicationPermit)
        #expect(try f.session.presentation().response.definiteMatchCount == 1)
    }

    @Test func detachedAndOldTrackingCallbacksCannotAffectReinstalledHost() async throws {
        let f = try SearchReadFixture()
        try await f.publish()
        try f.vault.beginMethodChange()
        f.session.detach()
        f.vault.endMethodChange()
        f.session.install()
        try await f.publish()
        for _ in 0..<5 { await Task.yield() }
        #expect(f.session.hasPublicationPermit)
        let epoch = f.session.invalidationEpoch
        try f.vault.beginMethodChange()
        #expect(f.session.invalidationEpoch == epoch + 1)
        f.vault.endMethodChange()
        await f.settle()
        f.session.detach()
        let query = try f.query
        f.vault.lock()
        #expect(try f.query == query)
        #expect(!f.session.hasRetainedPresentation)
    }

    @Test func destructionReleasesObserversAndFrozenSource() throws {
        let h = try HandoffFixture(sourcePage: .overview)
        let vault = PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys())
        let owner = try ContentQueryReadOwner()
        var session: ContentQueryReadSession? = try .init(vault: vault, owner: owner, coordinator: h.coordinator,
            ownership: h.owned().lease.ownership, notifications: .init(privacy: .default, model: .init(),
                focus: .init(), focusLost: SearchReadFixture.focusLost, focusObject: NSObject()))
        session?.install()
        let released = { [weak session] in session == nil }
        _ = try session?.prepare { .init(requestID: UUID(), session: $0) }
        #expect(owner.source != nil)
        session = nil
        #expect(released() && owner.source == nil)
        let before = try h.state()
        vault.lock()
        #expect(try h.state() == before)
    }

    @Test func unexpectedBackgroundNotificationFailsClosedWithoutMainSync() async throws {
        let f = try SearchReadFixture()
        try await f.publish()
        let vault = f.vault
        await Task.detached { NotificationCenter.default.post(name: .privacyWillLock, object: vault) }.value
        for _ in 0..<100 where f.session.diagnostic != .unexpectedExecutor { await Task.yield() }
        #expect(f.session.diagnostic == .unexpectedExecutor)
        #expect(!f.session.hasRetainedPresentation && !f.session.hasPublicationPermit)
        #expect(throws: ContentQueryReadSessionError.unexpectedExecutor) { try f.session.prepare(read: f.batch) }
        try f.expectEmpty()
    }
}
