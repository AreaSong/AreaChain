import Foundation
import Testing
@testable import AreaChain

/// 「搜索与指令」页的常用精选：固定 24 行，示例真能解析回对应指令，工作台都能处理。
@Suite(.serialized, .tags(.backgroundWindow)) @MainActor struct SearchGuideContentTests {
    @Test func featuredRowsAreTheDecidedCommandsInOrder() throws {
        let ids = SearchGuideFeatured.all.map(\.command.rawValue)
        #expect(ids == [
            "todo.create", "todo.move", "todo.completion", "todo.priority", "todo.tags", "todo.reminder", "todo.due",
            "todo.trash", "tasks.postponeYesterday", "batch.move", "routine.capture", "occurrence.complete",
            "routine.enabled", "diary.create", "diary.toTodo", "tag.create", "tag.merge", "clipboard.search",
            "clipboard.paste", "go.today", "inspector.open", "privacy.lock", "setting.appearance", "trash.restore",
        ])
        #expect(Set(SearchGuideFeatured.all.map(\.id)).count == SearchGuideFeatured.all.count)
        for row in SearchGuideFeatured.all {
            #expect(CommandCatalog.standard.command(id: row.command) != nil, "\(row.command.rawValue) 不在目录里")
        }
    }

    @Test func everyExampleParsesToItsCommand() {
        for row in SearchGuideFeatured.all {
            let parsed = CommandPathParser().parse(CommandPathRequest(text: row.example))
            #expect(parsed.command?.id == row.command, "\(row.example) 应解析到 \(row.command.rawValue)")
            #expect(parsed.state != .invalid, "\(row.example)：\(parsed.diagnostics)")
        }
    }

    @Test(arguments: ["en", "zh-Hans"]) func featuredCopyIsBilingual(language: String) {
        let locale = Locale(identifier: language)
        let keys = SearchGuideFeatured.all.flatMap { [$0.summaryKey, $0.nameKey ?? "command.\($0.command.rawValue).name"] }
            + SearchGuideFeatured.Group.allCases.map(\.titleKey)
            + SearchGuideSyntax.basics + SearchGuideSyntax.conditions.flatMap { [$0.key] + ($0.tokenKey.map { [$0] } ?? []) }
        for key in keys { #expect(L10n.format(key, locale: locale) != key, "\(key) 缺少 \(language)") }
    }

    @Test func workspaceHandlesEveryFeaturedCommand() throws {
        let fixture = try UnifiedSearchProductionFixture()
        defer { fixture.cleanup() }
        let assembly = try fixture.assembly()
        defer { assembly.discard() }
        let workspace = try #require(assembly.workspace)
        for row in SearchGuideFeatured.all {
            let kind = workspace.disposition(for: row.command).kind
            #expect(![.catalogUnavailable, .unwired].contains(kind), "\(row.command.rawValue) 在工作台是 \(kind)")
        }
    }

    /// 示例会替换搜索框文字：工作台有未完成的指令草稿时不提供，没有工作台控制器时也不提供。
    @Test func examplesAreBlockedByUnfinishedCommandWork() throws {
        let fixture = try UnifiedSearchProductionFixture()
        defer { fixture.cleanup() }
        let assembly = try fixture.assembly()
        defer { assembly.discard() }
        let workspace = try #require(assembly.workspace)
        #expect(SearchGuideHosts(workspace: nil, menubar: assembly.menubar).blocksExamples)
        #expect(!SearchGuideHosts(workspace: workspace, menubar: nil).blocksExamples)
        let path = "/tasks/add"
        _ = workspace.edit(.init(source: workspace.buffer, text: path, selection: .init(location: path.utf16.count, length: 0)))
        workspace.intent(.open, source: workspace.buffer)
        try #require(workspace.operations?.active != nil, "应已开始 todo.create 草稿")
        #expect(SearchGuideHosts(workspace: workspace, menubar: nil).blocksExamples)
    }
}
