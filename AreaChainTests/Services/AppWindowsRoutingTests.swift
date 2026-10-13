import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct AppWindowsRoutingTests {
    @Test func openSettingsSelectsTheWorkspaceSettingsTab() {
        let navigation = WorkspaceNavigation(boardSelection: BoardSelection())
        var presentations = 0
        let opening = AppWindows.WorkspaceOpening(navigation: navigation, dismissOverlay: {}, activate: {},
                                                   show: { presentations += 1 })

        navigation.revealTab(.today)
        AppWindows.openSettings(opening: opening)

        #expect(navigation.selectedTab == .settings)
        #expect(presentations == 1)
        let id = UUID()
        AppWindows.openWorkspace(tab: .calendar, inspecting: id, dayKey: "2026-10-07", opening: opening)
        #expect(navigation.selectedTaskID == id && navigation.inspectingDayKey == "2026-10-07")
        AppWindows.revealWorkspace(opening: opening)
        #expect(navigation.selectedTab == .calendar && navigation.selectedTaskID == id)
        #expect(presentations == 3)
    }

    @Test func centeredFramePlacesWorkspaceAtExactScreenCenter() {
        let visibleFrame = NSRect(x: 0, y: 86, width: 1800, height: 1044)
        let size = DaybookMetrics.Window.workspaceSize
        let centered = AppWindows.centeredFrame(size: size, in: visibleFrame)

        #expect(centered.size == size)
        #expect(centered.origin.x == 420)
        #expect(centered.origin.y == 288)
        #expect(centered.midX == visibleFrame.midX)
        #expect(centered.midY == visibleFrame.midY)
    }
}
