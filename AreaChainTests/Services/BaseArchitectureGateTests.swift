import AppKit
import Foundation
import Testing
@testable import AreaChain

/// 三大唯一基类（`BaseAction`、`BaseTextInput`、`BaseWindow`）与动作总目录的自动化架构门禁测试。
@Suite(.serialized)
@MainActor
struct BaseArchitectureGateTests {
    @Test func allStandaloneWindowsInheritFromBaseWindow() {
        #expect(PanelWindowController.self is BaseWindow.Type)
        #expect(DiaryWindowController.self is BaseWindow.Type)
        #expect(ClipboardHistoryPanel.self is BaseWindow.Type)
        #expect(QuickEntryPanelController.self is BaseWindow.Type)
        #expect(AttachmentImageViewerWindowController.self is BaseWindow.Type)
        #expect(ControlsPreviewWindowController.self is BaseWindow.Type)
    }

    @Test func allStandardActionsInheritFromBaseActionAndExposeCompleteCLIMetadata() {
        let history = ActionHistoryStore.inMemory()
        let registry = ActionRegistry(historyStore: history)
        let actions = StandardActionCatalog.all(history: history)
        registry.register(actions)

        #expect(actions.count >= 60)

        var seenIDs: Set<ActionID> = []
        for action in actions {
            #expect((action as AnyObject) is BaseAction)
            #expect(seenIDs.insert(action.id).inserted, "Duplicate ActionID: \(action.id.rawValue)")
            #expect(!action.englishTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            #expect(!action.chineseTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            #expect(!action.commandNames.isEmpty, "Action \(action.id.rawValue) must declare at least one CLI command name")
            #expect(!action.iconName.isEmpty)
            #expect(registry.action(for: action.id) != nil)
            for cmd in action.commandNames {
                #expect(registry.resolve(commandOrID: cmd) != nil, "Command alias \(cmd) must resolve in ActionRegistry")
            }
        }
    }

    @Test func daybookActionButtonBindsToRegisteredBaseActions() {
        let history = ActionHistoryStore.inMemory()
        let registry = ActionRegistry(historyStore: history)
        let dispatcher = DaybookActionDispatcher()
        StandardActionCatalog.bootstrapIfNeeded(registry: registry, dispatcher: dispatcher)

        for action in registry.allActions {
            let availability = dispatcher.availabilityResolver?(action.id.rawValue)
            #expect(availability != nil)
            let tooltip = dispatcher.tooltipResolver?(action.id.rawValue)
            #expect(tooltip != nil && !(tooltip?.isEmpty ?? true))
        }
    }
}
