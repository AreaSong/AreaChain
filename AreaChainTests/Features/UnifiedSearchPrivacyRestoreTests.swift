import AppKit
import SwiftData
import Testing
@testable import AreaChain

/// 合并批 M-3 C：两个直接执行的安全小动作。trash.restore 经共用独立确认面板、只能单项；
/// privacy.lock 沿“立即锁定”，锁定事件撤销结果展示、返回票据与托管借用。
@Suite(.serialized) @MainActor struct UnifiedSearchPrivacyRestoreTests {
    @Test(arguments: [0, 3]) func trashRestoreGoesThroughTheSharedConfirmationPanel(style: Int) async throws {
        let f = try UnifiedSearchSimpleFixture(restore: true)
        defer { f.results.stop() }
        let host = try await f.host(style)
        defer { host.close() }
        try await f.begin("/trash/restore", host: host)
        let stamp = try #require(f.controller.operations?.active?.stamp)
        let id = CommandID(rawValue: "trash.restore")
        try #require(f.controller.sendOperation(.selectTargets(stamp, .init(.single, objects: [f.service.target(f.service.deleted)]),
                                                               baseline: f.controller.targetBaseline(for: id)),
                                                source: f.controller.buffer) != nil)
        try await host.settle()
        _ = try await f.prepareAndAccept(host, name: "m3-trash-restore-\(style)")
        try await host.clickCompositionControl("unified.simple.save")
        #expect(f.controller.simpleConfirmation != nil && f.service.count("save") == 0)
        #expect(UnifiedSearchCommandDriver.has("unified.simple.confirmation", host: host))
        try host.snapshot("m3-trash-restore-confirm-\(style)")
        // Esc 只撤销确认：草稿与接受都还在，不写库。
        try await host.key(53, "\u{1b}")
        #expect(f.controller.simpleConfirmation == nil && f.controller.currentSimpleAcceptance != nil)
        #expect(f.service.deleted.deletedAt != nil && f.service.count("save") == 0)
        try await host.clickCompositionControl("unified.simple.save")
        try await host.clickCompositionControl("unified.simple.confirm")
        let facts = try #require(f.controller.simpleUnit?.simple, "未执行：\(f.controller.simpleFailure ?? "none")")
        #expect(facts.state == .saved && f.service.count("save") == 1 && f.service.deleted.deletedAt == nil)
        try host.snapshot("m3-trash-restore-saved-\(style)")
    }

    @Test func lockRevokesPresentationTicketAndLoans() async throws {
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        let fakes = SystemCommandFakes()
        _ = fakes.install(fixture)
        try await fixture.vault.create(password: "m3-synthetic-password", systemUnlock: false)
        try #require(fixture.vault.isUnlocked)
        // 保险箱状态变化会让结果会话异步重新订阅；就绪后再读，避免 trackingPending。
        for _ in 0..<50 where !fixture.session.isTrackingReady { try await Task.sleep(for: .milliseconds(20)) }
        var locks = 0
        let observer = fixture.privacy.addObserver(forName: .privacyWillLock, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { locks += 1 }
        }
        defer { fixture.privacy.removeObserver(observer) }
        // 长文托管与统一搜索订阅同一个隔离隐私中心（L-M1b）：锁定事件同样会撤销它的签发资格。
        let escrow = CommandLongTextEscrow(coordinator: fixture.handoff.coordinator, privacy: fixture.privacy)
        _ = escrow
        try await fixture.start()
        // 预览在搜索面板里：说明会做什么，此时还没有锁定。
        try await fixture.enter("/privacy/lock")
        #expect(SettingsButtonTestSupport.elements(fixture.window?.contentView).contains {
            SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String == "unified.system.preview"
        })
        #expect(fixture.vault.isUnlocked && locks == 0)
        try await fixture.go("/go/settings")
        try #require(fixture.controller.returnSearch != nil)
        try await fixture.enter("/privacy/lock")
        fixture.controller.intent(.open, source: fixture.controller.buffer)
        try await fixture.settle()
        #expect(!fixture.vault.isUnlocked && locks == 1)
        #expect(fixture.controller.returnSearch == nil, "锁定撤返回票据")
        #expect(!fixture.session.hasRetainedPresentation && fixture.controller.buffer.text.isEmpty)
        #expect(fixture.navigation.navigationObject == nil)
        _ = fixture.controller.navigationInput("/privacy/lock")
        fixture.controller.executeNavigation(source: fixture.controller.buffer)
        #expect(fixture.controller.navigationMessage == "unified.privacy.lock.already" && locks == 1)
        #expect(fixture.saves == 0 && !fixture.context.hasChanges)
    }

    @Test func lockWithoutPrivacyLockOnlyExplains() async throws {
        let fixture = try UnifiedSearchNavigationFixture()
        defer { fixture.stop() }
        let fakes = SystemCommandFakes()
        _ = fakes.install(fixture)
        try await fixture.start()
        try await fixture.go("/privacy/lock")
        #expect(fixture.controller.navigationMessage == "unified.privacy.lock.unconfigured")
        #expect(!fixture.vault.isConfigured && fixture.saves == 0)
    }
}
