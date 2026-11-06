import Foundation
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized)
@MainActor
struct UnifiedSearchCLIBridgeTests {
    @Test func standardActionCatalogBootstrapsAllFamilies() {
        let history = ActionHistoryStore.inMemory()
        let registry = ActionRegistry(historyStore: history)
        let dispatcher = DaybookActionDispatcher()
        StandardActionCatalog.bootstrapIfNeeded(registry: registry, dispatcher: dispatcher)

        #expect(registry.allActions.count >= 60)
        #expect(registry.action(for: "win.open") != nil)
        #expect(registry.action(for: "todo.create") != nil)
        #expect(registry.action(for: "routine.check") != nil)
        #expect(registry.action(for: "cal.layout") != nil)
        #expect(registry.action(for: "diary.create") != nil)
        #expect(registry.action(for: "clip.togglePanel") != nil)
        #expect(registry.action(for: "pref.theme") != nil)
        #expect(registry.action(for: "pref.externalAccess") != nil)
        #expect(registry.action(for: "action.undo") != nil)
        #expect(registry.action(for: "action.redo") != nil)
        #expect(registry.action(for: "action.history") != nil)

        let helpText = registry.generateHelpGuide()
        #expect(helpText.contains("/todo"))
        #expect(helpText.contains("/undo"))
        #expect(helpText.contains("/redo"))
    }

    @Test func cliSessionHandlesSlashAndPipelineCommandsAndInlineConfirmation() {
        StandardActionCatalog.bootstrapIfNeeded()
        let session = UnifiedSearchCLISession()

        #expect(session.handlesCLIInput("/"))
        #expect(session.handlesCLIInput("/todo 买牛奶 !p1 @15:30"))
        #expect(session.handlesCLIInput("/todo/create 买牛奶"))
        #expect(session.handlesCLIInput("/theme dark"))
        #expect(session.handlesCLIInput("买牛奶 > move tomorrow"))
        #expect(session.handlesCLIInput("/history"))
        #expect(!session.handlesCLIInput("/trash"))
        #expect(!session.handlesCLIInput("/clipboard"))
        #expect(!session.handlesCLIInput("普通搜索关键词"))

        session.updateForInput("/history 牛奶")
        #expect(session.showingHistory)
        #expect(session.historyKeyword == "牛奶")

        session.updateForInput("/todo 新任务")
        #expect(!session.showingHistory)
    }
}
