import AppKit
import SwiftData
import Testing
@testable import AreaChain

/// 合并批 M-6 检查点 B：唯一装配点；收尾批 M-7 删除开关后，启动即装配、失败可重试。纯程序化，不开窗口、不发键鼠事件。
@Suite(.serialized, .tags(.backgroundWindow)) @MainActor struct UnifiedSearchProductionAssemblyTests {
    /// 收尾批 M-7：旧开关键留在 UserDefaults 不迁移，代码不再读取——存着“关”也照样装配。
    @Test func legacyPreferenceKeyIsIgnored() throws {
        let fixture = try UnifiedSearchProductionFixture()
        defer { fixture.cleanup() }
        fixture.defaults.set(false, forKey: "areachain.prefs.unifiedSearchEnabled")
        let production = UnifiedSearchProduction()
        defer { production.stop(center: fixture.center) }
        production.start(center: fixture.center, makeServices: { fixture.services() })
        #expect(production.assembly != nil && !production.assemblyFailed)
        #expect(fixture.defaults.object(forKey: "areachain.prefs.unifiedSearchEnabled") as? Bool == false)
        #expect(fixture.probe.total == 0 && fixture.saves == 0)
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
        let production = try UnifiedSearchProductionAssembly.attempt(services: fixture.services(productionAttachments: true)).get()
        defer { production.discard() }
        let shared = try #require(WorkspaceAttachmentStorage.resolve(production.hostContext))
        #expect(shared.store === AttachmentStore.shared && shared.root == nil && !shared.ordinaryOnly)
        let isolated = try fixture.assembly()
        defer { isolated.discard() }
        let own = try #require(WorkspaceAttachmentStorage.resolve(isolated.hostContext))
        #expect(own.store !== AttachmentStore.shared && own.ordinaryOnly && own.root != nil)
    }

    /// 修复批 M-6R 检查点 D：装配失败不再无声——记录失败供宿主搜索框提示；仍失败时保持失败，偏好变化后重试成功即清除。
    @Test func assemblyFailureIsRecordedAndClearedOnRetry() throws {
        let fixture = try UnifiedSearchProductionFixture()
        defer { fixture.cleanup() }
        let production = UnifiedSearchProduction()
        defer { production.stop(center: fixture.center) }
        var fail = true
        production.assemble = { services, coordinator in
            fail ? .failure(CommandHandoffError.stale) : UnifiedSearchProductionAssembly.attempt(services: services, coordinator: coordinator)
        }
        production.start(center: fixture.center, makeServices: { fixture.services() })
        #expect(production.assembly == nil && production.assemblyFailed)
        fixture.center.post(name: .appPreferencesDidChange, object: nil)
        #expect(production.assembly == nil && production.assemblyFailed)
        fail = false
        fixture.center.post(name: .appPreferencesDidChange, object: nil)
        #expect(production.assembly != nil && !production.assemblyFailed)
        #expect(fixture.probe.total == 0 && fixture.saves == 0)
    }

    /// 收尾批 M-7：已有装配时偏好变化不重建，控制器、查询与工作台展示状态都不动。
    @Test func preferenceChangesKeepTheExistingAssembly() throws {
        let fixture = try UnifiedSearchProductionFixture()
        defer { fixture.cleanup() }
        let production = UnifiedSearchProduction()
        defer { production.stop(center: fixture.center) }
        production.start(center: fixture.center, makeServices: { fixture.services() })
        let first = try #require(production.assembly)
        #expect(fixture.navigation.searchPresentation == false)
        try first.coordinator.send(.query(.setInput("needle")),
                                   expecting: first.coordinator.host(UnifiedSearchProductionAssembly.workspaceHost).lease)
        let generation = production.generation
        fixture.center.post(name: .appPreferencesDidChange, object: nil)
        #expect(production.assembly === first && production.generation == generation)
        #expect(first.workspace.session.diagnostic != .detached && fixture.navigation.searchPresentation == false)
        #expect(fixture.probe.total == 0 && fixture.saves == 0)
    }
}
