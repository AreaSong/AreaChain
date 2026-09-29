import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct AppWindowsRoutingTests {
    @Test func openSettingsSelectsTheWorkspaceSettingsTab() {
        let navigation = WorkspaceNavigation.shared
        let previousTab = navigation.selectedTab
        let previousActivate = AppWindows.activateForOpening
        let previousShow = AppWindows.showWorkspaceWindow
        var presentations = 0
        AppWindows.activateForOpening = {}
        AppWindows.showWorkspaceWindow = { presentations += 1 }
        defer {
            AppWindows.activateForOpening = previousActivate
            AppWindows.showWorkspaceWindow = previousShow
            navigation.revealTab(previousTab)
        }

        navigation.revealTab(.today)
        AppWindows.openSettings()

        #expect(navigation.selectedTab == .settings)
        #expect(presentations == 1)
    }
}
