import Foundation
import Testing
@testable import AreaChain

/// 结果区让位的唯一判断：指令不从搜索结果取对象时让位，查询与要挑对象的指令保留结果。
@Suite(.serialized, .tags(.backgroundWindow)) @MainActor struct UnifiedSearchResultsYieldTests {
    @Test func catalogRuleKeepsResultsForQueriesAndObjectPickers() {
        for command in CommandCatalog.standard.entries {
            let picksObjects = command.parameters.contains {
                if case .object = $0.type { return true }
                if case .objects = $0.type { return true }
                return false
            }
            if [.group, .scope, .query].contains(command.category) || picksObjects {
                #expect(!UnifiedSearchController.ignoresSearchResults(command), "\(command.id.rawValue) 需要结果区")
            }
        }
        let inspect = CommandCatalog.standard.command(id: .init(rawValue: "occurrence.inspect"))
        #expect(inspect.map(UnifiedSearchController.ignoresSearchResults) == false, "occurrence.inspect 取焦点结果")
        for id in ["setting.appearance", "todo.create", "go.today", "tag.create", "privacy.lock"] {
            let command = CommandCatalog.standard.command(id: .init(rawValue: id))
            #expect(command.map(UnifiedSearchController.ignoresSearchResults) == true, "\(id) 应让位")
        }
    }

    @Test func controllerYieldsOnlyForCommandsThatIgnoreResults() throws {
        let fixture = try UnifiedSearchProductionFixture()
        defer { fixture.cleanup() }
        let assembly = try fixture.assembly()
        defer { assembly.discard() }
        let controller = try #require(assembly.workspace)
        // 导航类输入一打完就有面板；修改类要按 Return 开始草稿后才有面板，之前不让位。
        let cases: [(String, Bool)] = [
            ("/go/today", true), ("/window/workspace/reveal", true), ("/routines/checks/inspect/2026-10-05", false),
            ("/window/diary/open", false), ("/clipboard/search", false), ("/tasks", false), ("meeting", false),
            ("/setting/appearance/dark", false), ("/tasks/add", false),
        ]
        for (text, hides) in cases {
            _ = controller.edit(.init(source: controller.buffer, text: text, selection: .init(location: text.utf16.count, length: 0)))
            #expect(controller.hidesResultsForCommand == hides, "\(text)")
        }
        for text in ["/setting/appearance/dark", "/tasks/add"] {
            _ = controller.edit(.init(source: controller.buffer, text: text, selection: .init(location: text.utf16.count, length: 0)))
            controller.intent(.open, source: controller.buffer)
            try #require(controller.operations?.active != nil, "\(text) 应已开始草稿")
            #expect(controller.hidesResultsForCommand, "\(text) 开始草稿后让位")
            controller.discardActiveOperation(source: controller.buffer)
        }
        _ = controller.edit(.init(source: controller.buffer, text: "/tasks/move", selection: .init(location: 11, length: 0)))
        controller.intent(.open, source: controller.buffer)
        #expect(controller.operations?.active != nil && !controller.hidesResultsForCommand, "挑对象的指令开始草稿后仍保留结果")
    }
}
