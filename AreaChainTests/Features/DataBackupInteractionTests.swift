import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct DataBackupInteractionTests {
    private static var retained: [ModelContainer] = []

    @Test func workspaceRoutesOpenRealPagesInsteadOfPlaceholders() async throws {
        let container = try makeContainer()
        let previous = NavigationSnapshot()
        defer { previous.restore() }
        let window = SystemPageHost.window(
            MainSplitWorkspaceView(),
            container: container, scheme: .light, locale: "zh-Hans",
            size: DaybookMetrics.Window.workspaceMinSize
        )
        defer { SystemPageHost.release(window) }
        let placeholder = "当前阶段只接通导航，功能将在后续阶段实现。"
        for tab in [WorkspaceTab.privacy, .dataBackup] {
            WorkspaceNavigation.shared.revealTab(tab)
            try await SystemPageHost.settle(window)
            let ids = SystemPageHost.identifiers(in: window)
            #expect(!SystemPageHost.labels(in: window).contains(placeholder))
            if tab == .privacy {
                #expect(ids.contains("privacy.unlock.settings"))
                #expect(!ids.contains("data.backup.page"))
            } else {
                #expect(ids.contains("data.backup.page"))
                #expect(!ids.contains("privacy.unlock.settings"))
            }
        }
        #expect(try container.mainContext.fetchCount(FetchDescriptor<TodoItem>()) == 0)
    }

    @Test func privacyPageNamesEachVaultState() async throws {
        for state in [PrivacyVault.State.unconfigured, .locked, .unlocked, .unavailable] {
            try await assertVaultState(state)
        }
    }

    private func assertVaultState(_ state: PrivacyVault.State) async throws {
        let container = try makeContainer()
        let vault = try await vault(state)
        let before = vault.revision
        let window = SystemPageHost.window(
            PrivacyUnlockSettingsView(vault: vault),
            container: container, scheme: .dark, locale: "en",
            size: DaybookMetrics.Window.workspaceMinSize
        )
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let ids = SystemPageHost.identifiers(in: window)
        #expect(ids.contains("privacy.vault.state"))
        #expect(ids.contains("privacy.boundary"))
        #expect(!ids.contains("dataBackup.export.json") && !ids.contains("dataBackup.export.encrypted"))
        switch state {
        case .unconfigured:
            #expect(ids.contains("privacy.setup") && !ids.contains("privacy.tags.manage"))
        case .locked, .unlocked:
            #expect(ids.contains("privacy.tags.manage") && ids.contains("privacy.autolock") && ids.contains("privacy.lock.toggle"))
        case .unavailable:
            #expect(!ids.contains("privacy.setup") && !ids.contains("privacy.tags.manage"))
        }
        #expect(vault.revision == before)
    }

    @Test func pendingSystemKeyCleanupStaysVisibleWithoutBackupActions() async throws {
        let container = try makeContainer()
        let store = MemoryVaultConfigurationStore()
        store.pendingSystemKeyIDs = [UUID()]
        let vault = PrivacyVault(store: store, systemKeys: FakeSystemVaultKeys())
        let window = SystemPageHost.window(
            PrivacyUnlockSettingsView(vault: vault),
            container: container, scheme: .light, locale: "zh-Hans",
            size: NSSize(width: 880, height: 640)
        )
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let ids = SystemPageHost.identifiers(in: window)
        #expect(vault.hasPendingSystemKeyCleanup)
        #expect(ids.contains("privacy.vault.cleanup") && ids.contains("privacy.system.cleanup.retry"))
        #expect(!ids.contains("dataBackup.restore.encrypted"))
    }

    private func vault(_ state: PrivacyVault.State) async throws -> PrivacyVault {
        switch state {
        case .unconfigured:
            return PrivacyVault(store: MemoryVaultConfigurationStore(), systemKeys: FakeSystemVaultKeys())
        case .locked:
            let fixture = try await PrivacyFixture.make()
            fixture.vault.lock()
            let vault = fixture.vault
            fixture.cleanup()
            return vault
        case .unlocked:
            let fixture = try await PrivacyFixture.make()
            let vault = fixture.vault
            fixture.cleanup()
            return vault
        case .unavailable:
            let store = MemoryVaultConfigurationStore()
            store.loadError = PrivacyError.storageFailure
            return PrivacyVault(store: store, systemKeys: FakeSystemVaultKeys())
        }
    }

    private func makeContainer() throws -> ModelContainer {
        let container = try ModelContainer(for: Schema(AreaChainSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        Self.retained.append(container)
        return container
    }

    @MainActor
    private struct NavigationSnapshot {
        let tab = WorkspaceNavigation.shared.selectedTab
        func restore() { WorkspaceNavigation.shared.revealTab(tab) }
    }
}
