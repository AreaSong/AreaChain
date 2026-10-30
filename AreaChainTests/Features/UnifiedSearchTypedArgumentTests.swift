import Foundation
import Testing
@testable import AreaChain

/// 手打完整路径后按 Return：路径尾段的取值与接受候选一样带进草稿（与工作台接到转交同一入口）。
@Suite(.serialized, .tags(.backgroundWindow)) @MainActor struct UnifiedSearchTypedArgumentTests {
    private func type(_ text: String, into controller: UnifiedSearchController) {
        _ = controller.edit(.init(source: controller.buffer, text: text, selection: .init(location: text.utf16.count, length: 0)))
    }

    @Test func returnCarriesTypedValueAndRetypingEditsIt() throws {
        let fixture = try UnifiedSearchProductionFixture()
        defer { fixture.cleanup() }
        let assembly = try fixture.assembly()
        defer { assembly.discard() }
        let controller = try #require(assembly.workspace)
        type("/setting/appearance/dark", into: controller)
        controller.intent(.open, source: controller.buffer)
        let draft = try #require(controller.editingDraft)
        #expect(draft.commandID.rawValue == "setting.appearance")
        #expect(draft.arguments.first { $0.parameter == .value }?.value == .choice("dark"))
        // 同一指令已有草稿时再打另一个取值并 Return：改写这个参数，不另开草稿。
        type("/setting/appearance/light", into: controller)
        controller.intent(.open, source: controller.buffer)
        let edited = try #require(controller.editingDraft)
        #expect(edited.id == draft.id)
        #expect(edited.arguments.first { $0.parameter == .value }?.value == .choice("light"))
    }

    @Test func returnWithoutTailStartsAnEmptyDraft() throws {
        let fixture = try UnifiedSearchProductionFixture()
        defer { fixture.cleanup() }
        let assembly = try fixture.assembly()
        defer { assembly.discard() }
        let controller = try #require(assembly.workspace)
        type("/setting/appearance", into: controller)
        controller.intent(.open, source: controller.buffer)
        let draft = try #require(controller.editingDraft)
        #expect(draft.commandID.rawValue == "setting.appearance" && draft.arguments.isEmpty)
    }

    /// 尾段不是合法取值：开空草稿，输入框规范成指令路径，不留下看似生效的取值。
    @Test func invalidTailStartsAnEmptyDraftWithCanonicalText() throws {
        let fixture = try UnifiedSearchProductionFixture()
        defer { fixture.cleanup() }
        let assembly = try fixture.assembly()
        defer { assembly.discard() }
        let controller = try #require(assembly.workspace)
        type("/setting/appearance/purple", into: controller)
        controller.intent(.open, source: controller.buffer)
        let draft = try #require(controller.editingDraft)
        #expect(draft.commandID.rawValue == "setting.appearance" && draft.arguments.isEmpty)
        #expect(controller.buffer.text == "/setting/appearance")
    }
}
