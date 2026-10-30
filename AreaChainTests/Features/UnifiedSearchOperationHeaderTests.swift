import Foundation
import Testing
@testable import AreaChain

/// 操作面板标题区的一句预览：单值设置读到当前值时写成“当前 → 新值”，其余沿用参数摘要。
@Suite(.serialized, .tags(.backgroundWindow)) @MainActor struct UnifiedSearchOperationHeaderTests {
    @Test(arguments: ["en", "zh-Hans"]) func settingPreviewShowsCurrentAndNewValue(language: String) throws {
        let locale = Locale(identifier: language)
        let fixture = try UnifiedSearchProductionFixture()
        defer { fixture.cleanup() }
        let assembly = try fixture.assembly()
        defer { assembly.discard() }
        let controller = try #require(assembly.workspace)
        // 与原生输入相同：打出完整路径后接受“深色”候选，候选把路径尾部的值带进草稿。
        let text = "/setting/appearance/dark"
        _ = controller.edit(.init(source: controller.buffer, text: text, selection: .init(location: text.utf16.count, length: 0)))
        let parsed = CommandPathParser().parse(.init(text: text, cursorLocation: text.utf16.count))
        let candidate = try #require(parsed.candidates.first { $0.command.id.rawValue == "setting.appearance" })
        let acceptance = try #require(parsed.accepting(candidate, in: text, hasMarkedText: false))
        _ = controller.accept(.init(source: controller.buffer, text: acceptance.text,
                                    selection: .init(location: acceptance.cursorLocation, length: 0), acceptance: acceptance))
        let draft = try #require(controller.editingDraft)
        try #require(!draft.arguments.isEmpty, "接受候选后草稿应带上取值")
        let command = try #require(CommandCatalog.standard.command(id: draft.commandID))
        let current = try #require(draft.baseline.preference?.memory, "设置草稿应读到当前值")
        let preview = UnifiedSearchOperationCopy.preview(command, draft: draft, locale: locale, calendar: .current)
        let dark = L10n.format(CommandChoice(value: "dark").nameKey, locale: locale)
        #expect(preview == UnifiedSearchOperationCopy.value(current, locale: locale, calendar: .current) + " → " + dark)
    }

    @Test func otherCommandsKeepParameterSummary() throws {
        let fixture = try UnifiedSearchProductionFixture()
        defer { fixture.cleanup() }
        let assembly = try fixture.assembly()
        defer { assembly.discard() }
        let controller = try #require(assembly.workspace)
        let text = "/tasks/add"
        _ = controller.edit(.init(source: controller.buffer, text: text, selection: .init(location: text.utf16.count, length: 0)))
        controller.intent(.open, source: controller.buffer)
        let draft = try #require(controller.editingDraft)
        let command = try #require(CommandCatalog.standard.command(id: draft.commandID))
        #expect(draft.baseline.preference == nil)
        #expect(UnifiedSearchOperationCopy.preview(command, draft: draft, locale: Locale(identifier: "en"), calendar: .current)
            == UnifiedSearchOperationCopy.summary(command, draft: draft, locale: Locale(identifier: "en"), calendar: .current))
    }
}
