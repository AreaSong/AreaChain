import AppKit
import SwiftData
import Testing
@testable import AreaChain

/// 合并批 M-6 检查点 B：开关、唯一装配点与新旧切换。纯程序化，不开窗口、不发键鼠事件。
@Suite(.serialized, .tags(.backgroundWindow)) @MainActor struct UnifiedSearchProductionAssemblyTests {
    @Test func preferenceDefaultsOnAndPersists() throws {
        let defaults = try #require(UserDefaults(suiteName: "AreaChain.M6.pref." + UUID().uuidString))
        let first = AppPreferences(defaults: defaults)
        #expect(first.unifiedSearchEnabled)
        #expect(defaults.object(forKey: AppPreferences.unifiedSearchEnabledKey) == nil)
        first.unifiedSearchEnabled = false
        #expect(defaults.object(forKey: AppPreferences.unifiedSearchEnabledKey) as? Bool == false)
        #expect(!AppPreferences(defaults: defaults).unifiedSearchEnabled)
    }

    @Test func disabledAssemblesNothing() throws {
        let fixture = try UnifiedSearchProductionFixture()
        defer { fixture.cleanup() }
        var built = false
        let assembly = UnifiedSearchProductionAssembly.make(enabled: false, services: {
            built = true
            return fixture.services()
        })
        #expect(assembly == nil && !built)
    }

    @Test func assemblesBothHostsWithoutSideEffects() throws {
        let fixture = try UnifiedSearchProductionFixture()
        defer { fixture.cleanup() }
        let assembly = try fixture.assembly()
        defer { assembly.discard() }
        let workspace = try #require(assembly.controller(for: UnifiedSearchProductionAssembly.workspaceHost))
        let menubar = try #require(assembly.controller(for: UnifiedSearchProductionAssembly.menubarHost))
        #expect(workspace !== menubar && workspace.coordinator === menubar.coordinator)
        #expect(workspace.navigationRouter === assembly.router && workspace.pageCommands != nil)
        #expect(menubar.navigationRouter == nil && menubar.pageCommands == nil)
        // 设置类沿用当前偏好权威：旧键 AppPreferences + LocalSettingCommandAdapter，没有文件后端。
        #expect(workspace.localSettings != nil && workspace.fileSettings == nil && fixture.preferences.usesLegacyLocalPreferences)
        #expect(assembly.router.navigation === fixture.navigation && assembly.hostContext.navigation === fixture.navigation)
        #expect(!assembly.hostContext.sharesProductionStorage)
        // 装配不读库写库、不申请权限、不刷新提醒／日历、不碰剪贴板与窗口。
        #expect(fixture.probe.total == 0 && fixture.saves == 0 && !fixture.context.hasChanges)
        #expect(workspace.buffer.text.isEmpty && menubar.buffer.text.isEmpty)
    }

    @Test func productionHostKeepsOriginalAttachmentSemantics() throws {
        let fixture = try UnifiedSearchProductionFixture()
        defer { fixture.cleanup() }
        let production = try #require(UnifiedSearchProductionAssembly.make(enabled: true,
            services: { fixture.services(productionAttachments: true) }))
        defer { production.discard() }
        let shared = try #require(WorkspaceAttachmentStorage.resolve(production.hostContext))
        #expect(shared.store === AttachmentStore.shared && shared.root == nil && !shared.ordinaryOnly)
        let isolated = try fixture.assembly()
        defer { isolated.discard() }
        let own = try #require(WorkspaceAttachmentStorage.resolve(isolated.hostContext))
        #expect(own.store !== AttachmentStore.shared && own.ordinaryOnly && own.root != nil)
    }

    /// 修复批 M-6R 检查点 D：装配失败不再无声——记录失败供设置提示；关开关清除，偏好变化后重试成功也清除。
    @Test func assemblyFailureIsRecordedAndClearedOnRetryOrToggleOff() throws {
        let fixture = try UnifiedSearchProductionFixture()
        defer { fixture.cleanup() }
        let production = UnifiedSearchProduction()
        defer { production.stop(center: fixture.center) }
        var fail = true
        production.assemble = { services, coordinator in
            fail ? .failure(CommandHandoffError.stale) : UnifiedSearchProductionAssembly.attempt(services: services, coordinator: coordinator)
        }
        production.start(preferences: fixture.preferences, center: fixture.center, makeServices: { fixture.services() })
        #expect(production.assembly == nil && production.assemblyFailed)
        #expect(fixture.preferences.unifiedSearchEnabled)
        fixture.preferences.unifiedSearchEnabled = false
        fixture.center.post(name: .appPreferencesDidChange, object: nil)
        #expect(!production.assemblyFailed)
        fail = false
        fixture.preferences.unifiedSearchEnabled = true
        fixture.center.post(name: .appPreferencesDidChange, object: nil)
        #expect(production.assembly != nil && !production.assemblyFailed)
        #expect(fixture.probe.total == 0 && fixture.saves == 0)
    }

    @Test func toggleOffRestoresOldSearchAndKeepsDrafts() throws {
        let fixture = try UnifiedSearchProductionFixture()
        defer { fixture.cleanup() }
        let production = UnifiedSearchProduction()
        defer { production.stop(center: fixture.center) }
        production.start(preferences: fixture.preferences, center: fixture.center, makeServices: { fixture.services() })
        let first = try #require(production.assembly)
        let workspace = try #require(first.workspace)
        #expect(fixture.navigation.searchPresentation == false)
        try first.coordinator.send(.query(.setInput("needle")),
                                   expecting: first.coordinator.host(UnifiedSearchProductionAssembly.workspaceHost).lease)
        let generation = production.generation

        fixture.preferences.unifiedSearchEnabled = false
        fixture.center.post(name: .appPreferencesDidChange, object: nil)
        #expect(production.assembly == nil && production.generation == generation + 1)
        #expect(workspace.session.diagnostic == .detached)
        #expect(fixture.navigation.searchPresentation == nil)

        fixture.preferences.unifiedSearchEnabled = true
        fixture.center.post(name: .appPreferencesDidChange, object: nil)
        let second = try #require(production.assembly)
        #expect(second !== first && second.coordinator === first.coordinator)
        #expect(second.workspace.buffer.text == "needle")
        #expect(fixture.navigation.searchPresentation == true)
        #expect(fixture.probe.total == 0 && fixture.saves == 0)
    }
}
