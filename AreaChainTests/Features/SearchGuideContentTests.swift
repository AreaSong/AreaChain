import Foundation
import Testing
@testable import AreaChain

/// 「搜索与指令」页的常用精选：固定 24 行，示例真能解析回对应 `BaseAction`，工作台均可路由。
@Suite(.serialized, .tags(.backgroundWindow)) @MainActor struct SearchGuideContentTests {
    @Test func featuredRowsMapToRegisteredActionsInOrder() throws {
        StandardActionCatalog.bootstrapIfNeeded()
        #expect(SearchGuideFeatured.all.count == 24)
        #expect(Set(SearchGuideFeatured.all.map(\.id)).count == SearchGuideFeatured.all.count)
        for row in SearchGuideFeatured.all {
            #expect(ActionRegistry.shared.action(for: row.actionID) != nil, "\(row.actionID.rawValue) 不在 ActionRegistry 里")
        }
    }

    @Test func everyExampleParsesToItsAction() throws {
        StandardActionCatalog.bootstrapIfNeeded()
        for row in SearchGuideFeatured.all {
            let parsed = try ActionCLIParser.parse(row.example)
            guard case .command(let cmd) = parsed else {
                Issue.record("\(row.example) 未解析为 CLI 指令"); continue
            }
            let action = ActionRegistry.shared.action(forCommand: cmd.commandName)
            #expect(action?.id == row.actionID, "\(row.example) 应解析到 \(row.actionID.rawValue)")
        }
    }

    @Test(arguments: ["en", "zh-Hans"]) func featuredCopyIsBilingual(language: String) {
        let locale = Locale(identifier: language)
        let keys = SearchGuideFeatured.all.map(\.summaryKey)
            + SearchGuideFeatured.Group.allCases.map(\.titleKey)
            + SearchGuideSyntax.basics + SearchGuideSyntax.conditions.flatMap { [$0.key] + ($0.tokenKey.map { [$0] } ?? []) }
        for key in keys { #expect(L10n.format(key, locale: locale) != key, "\(key) 缺少 \(language)") }
    }

    /// 示例会替换搜索框文字：没有工作台控制器时不提供。
    @Test func examplesAreBlockedWhenWorkspaceMissing() throws {
        let fixture = try UnifiedSearchProductionFixture()
        defer { fixture.cleanup() }
        let assembly = try fixture.assembly()
        defer { assembly.discard() }
        let workspace = try #require(assembly.workspace)
        #expect(SearchGuideHosts(workspace: nil, menubar: assembly.menubar).blocksExamples)
        #expect(!SearchGuideHosts(workspace: workspace, menubar: nil).blocksExamples)
    }
}
