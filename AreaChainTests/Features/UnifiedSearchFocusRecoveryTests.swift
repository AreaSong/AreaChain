import AppKit
import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

/// 真实窗口 key 切换（另开一个窗口抢走 key 再交回），不直接调用 loseFocus。
/// 工作台与菜单栏各走一遍：什么都不做时仍遮罩；在搜索框里打字、Return 等显式动作才恢复并重读。
@Suite(.serialized) @MainActor struct UnifiedSearchFocusRecoveryTests {
    enum Kind: CaseIterable { case workspace, menubar }

    @Test(arguments: Kind.allCases) func refocusAloneKeepsMaskAndTypingRestoresResults(kind: Kind) async throws {
        let host = try UnifiedSearchFocusHost(kind)
        defer { host.close() }
        try host.fixture.insert(TodoItem(title: "needle 合成失焦任务", dayKey: UnifiedSearchProductionFixture.today))
        try await host.start()
        try await host.type("needle")
        try await host.waitPublished()
        try await host.switchAwayAndBack()
        #expect(host.controller.session.isMasked)
        #expect((try? host.controller.session.presentation()) == nil)
        #expect(host.controller.messageKey == "unified.results.masked")
        try await host.settle()
        #expect(host.controller.session.isMasked)
        try await host.type("needle 合成")
        try await host.waitPublished()
        #expect(!host.controller.session.isMasked)
        let visible = try host.controller.session.presentation().pagination.snapshot.visible
        #expect(!visible.isEmpty)
    }

    @Test(arguments: Kind.allCases) func lockedQueryRebuildsFromTrustedPageOnNewInput(kind: Kind) async throws {
        let host = try UnifiedSearchFocusHost(kind)
        defer { host.close() }
        let secret = "M7G_SECRET_BODY"
        let privateTag = try host.fixture.insert(TagItem(name: "m7g-private", sortOrder: 0, isPrivateDiary: true))
        try host.fixture.insert(DiaryEntry(text: "needle \(secret)", dayKey: UnifiedSearchProductionFixture.today,
                                           tagIDs: privateTag.id.uuidString))
        let old = try host.fixture.insert(TodoItem(title: "needle 合成旧查询任务", dayKey: UnifiedSearchProductionFixture.today))
        let fresh = try host.fixture.insert(TodoItem(title: "fresh 合成新查询任务", dayKey: UnifiedSearchProductionFixture.today))
        try await host.fixture.vault.create(password: UnifiedSearchFocusHost.password, systemUnlock: false)
        host.forwardPrivacyEvents()
        try await host.start()
        try await host.type("needle")
        try await host.waitPublished()
        try await host.switchAway()
        host.fixture.vault.lock()
        try await host.settle()
        try await host.switchBack()
        #expect(host.controller.buffer.text.isEmpty && host.controller.queryInputText.isEmpty)
        #expect(host.controller.queryAwaitsTrustedPage, "切回窗口不应重建查询")
        try await host.type("fresh")
        try await host.waitPublished()
        #expect(!host.controller.queryAwaitsTrustedPage)
        #expect(host.controller.queryInputText == "fresh")
        let query = try host.controller.coordinator.host(host.controller.buffer.lease.ownership.hostID).session.query
        #expect(query.page.location.hostID == host.controller.buffer.lease.ownership.hostID)
        #expect(query.page.todayKey != "1970-01-01", "重建用宿主给出的可信页面，不用占位日期")
        let visible = try host.controller.session.presentation().pagination.snapshot.visible
        #expect(visible.contains(.init(type: .todo, id: fresh.id)))
        #expect(!visible.contains(.init(type: .todo, id: old.id)), "旧查询文字不回来")
        try await host.type("needle")
        try await host.waitPublished()
        #expect(try host.controller.session.presentation().pagination.snapshot.visible.contains(.init(type: .todo, id: old.id)))
        #expect(!host.allStrings.contains { $0.contains(secret) })
        try await host.fixture.vault.unlockWithPassword(UnifiedSearchFocusHost.password)
        try await host.settle()
        try await host.type("fresh 合成")
        try await host.waitPublished()
        #expect(host.controller.queryInputText == "fresh 合成")
        #expect(try host.controller.session.presentation().pagination.snapshot.visible.contains(.init(type: .todo, id: fresh.id)))
    }

    @Test(arguments: Kind.allCases) func returnAfterLockRebuildsEmptyQuery(kind: Kind) async throws {
        let host = try UnifiedSearchFocusHost(kind)
        defer { host.close() }
        try host.fixture.insert(TodoItem(title: "needle 合成公开任务", dayKey: UnifiedSearchProductionFixture.today))
        try await host.start()
        try await host.type("needle")
        try await host.waitPublished()
        try await host.switchAway()
        host.fixture.center.post(name: .privacyWillLock, object: host.fixture.vault)
        try await host.settle()
        try await host.switchBack()
        #expect(host.controller.queryAwaitsTrustedPage)
        try await host.key(36, "\r")
        #expect(!host.controller.queryAwaitsTrustedPage)
        #expect(host.controller.buffer.text.isEmpty && host.controller.queryInputText.isEmpty)
    }

    @Test(arguments: Kind.allCases) func rebuildStillHonorsVaultGates(kind: Kind) async throws {
        let host = try UnifiedSearchFocusHost(kind)
        defer { host.close() }
        try host.fixture.insert(TodoItem(title: "needle 合成公开任务", dayKey: UnifiedSearchProductionFixture.today))
        try await host.start()
        try await host.type("needle")
        try await host.waitPublished()
        host.fixture.center.post(name: .privacyWillLock, object: host.fixture.vault)
        try await host.settle()
        try host.fixture.vault.beginMethodChange()
        try await host.settle()
        try await host.type("needle")
        #expect(host.controller.queryAwaitsTrustedPage, "门禁拒绝时不重建")
        #expect(host.controller.queryInputText.isEmpty)
        #expect((try? host.controller.session.presentation()) == nil)
        #expect(host.controller.navigationMessage == "unified.gate.vaultBusy")
        host.fixture.vault.endMethodChange()
        try await host.settle()
        try await host.type("needle 合成")
        try await host.waitPublished()
        #expect(!host.controller.queryAwaitsTrustedPage && host.controller.queryInputText == "needle 合成")
    }

    @Test(arguments: Kind.allCases) func typingCommandAfterRefocusRereadsRetainedQuery(kind: Kind) async throws {
        let host = try UnifiedSearchFocusHost(kind)
        defer { host.close() }
        try host.fixture.insert(TodoItem(title: "needle 合成失焦任务", dayKey: UnifiedSearchProductionFixture.today))
        try await host.start()
        try await host.type("needle")
        try await host.waitPublished()
        try await host.switchAwayAndBack()
        #expect((try? host.controller.session.presentation()) == nil)
        try await host.type("/inspector/open")
        try await host.waitPublished()
        #expect(!host.controller.session.isMasked)
        let visible = try host.controller.session.presentation().pagination.snapshot.visible
        #expect(visible.contains { $0.type == .todo })
        if kind == .workspace {
            try await host.key(36, "\r")
            #expect(host.controller.navigationMessage != "unified.navigation.stale")
        }
    }
}
