import SwiftData
import SwiftUI
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct ShortcutsPageTests {
    private static var retained: [ModelContainer] = []

    @Test func shortcutsPageListsEveryRebindableAction() async throws {
        let name = "areachain.shortcut.page.tests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let center = HotKeyCenter(defaults: defaults, registration: HotKeyRegistration(register: { _, _ in true }, unregister: { _ in }))
        let store = ShortcutStore(defaults: defaults, center: center)
        let container = try ModelContainer(
            for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        Self.retained.append(container)
        let window = SystemPageHost.window(
            ShortcutsSettingsView(store: store),
            container: container,
            scheme: .light,
            locale: "zh-Hans",
            size: DaybookMetrics.Window.workspaceMinSize
        )
        defer { SystemPageHost.release(window) }
        try await SystemPageHost.settle(window)
        let ids = SystemPageHost.identifiers(in: window)
        #expect(ids.contains("shortcuts.page"))
        #expect(ids.contains("shortcuts.scope"))
        #expect(ids.contains("shortcuts.resetAll"))
        for action in ShortcutAction.allCases {
            #expect(ids.contains("shortcut.\(action.rawValue)"))
        }
    }
}
