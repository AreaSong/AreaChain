import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct WorkspaceShellPreviewSettingsTests {
    private static let storageKey = "areachain.workspace.shellPreview.enabled"

    @Test
    func togglingOffResetsShowingShellPreview() {
        let settings = WorkspaceShellPreviewSettings.shared
        let navigation = WorkspaceNavigation.shared
        let previousSetting = settings.isEnabled
        let previousNavState = navigation.isShowingShellPreview
        defer {
            settings.isEnabled = previousSetting
            navigation.isShowingShellPreview = previousNavState
        }

        settings.isEnabled = true
        navigation.revealShellPreview()
        #expect(navigation.isShowingShellPreview)

        settings.isEnabled = false
        #expect(!navigation.isShowingShellPreview)
    }

    @Test(arguments: ["en", "zh-Hans"])
    func localizationKeysArePresent(locale: String) {
        let loc = Locale(identifier: locale)
        let toggleText = L10n.string("settings.workspaceShellPreview.toggle", locale: loc)
        let helpText = L10n.string("settings.workspaceShellPreview.help", locale: loc)
        let sidebarTitle = L10n.string("重构预览（今日）", locale: loc)

        #expect(!toggleText.isEmpty)
        #expect(!helpText.isEmpty)
        #expect(!sidebarTitle.isEmpty)

        if locale == "zh-Hans" {
            #expect(toggleText == "显示工作台重构预览页（左侧栏「重构预览（今日）」）")
            #expect(sidebarTitle == "重构预览（今日）")
        } else {
            #expect(toggleText == "Show workspace refactor preview (Sidebar \"Refactor Preview (Today)\")")
            #expect(sidebarTitle == "Refactor Preview (Today)")
        }
    }
}
