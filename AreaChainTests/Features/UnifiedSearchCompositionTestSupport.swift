import AppKit
import SwiftData
import Testing
@testable import AreaChain

extension UnifiedSearchTaskCreateFixture {
    @discardableResult
    func seedTag(_ name: String, deleted: Bool = false, privateTag: Bool = false) throws -> TagItem {
        let context = io.capture.context
        let tag = TagItem(name: name, sortOrder: try context.fetchCount(FetchDescriptor<TagItem>()),
                          deletedAt: deleted ? Date(timeIntervalSince1970: 100) : nil)
        tag.isPrivateDiary = privateTag
        context.insert(tag)
        try context.save()
        return tag
    }

    func readTags() throws -> [TagItem] {
        let reader = ModelContext(io.capture.context.container)
        reader.autosaveEnabled = false
        return try reader.fetch(FetchDescriptor<TagItem>(sortBy: [SortDescriptor(\.sortOrder)]))
    }

    func noCompositionWrites() throws {
        #expect(try io.capture.readTodos().isEmpty)
        #expect(count("save") == 0 && count("ui") == 0)
        #expect(io.capture.authorizations.isEmpty && io.capture.registered.isEmpty)
        #expect(io.notificationProcessed == 0 && io.calendarProcessed == 0)
    }

    func editComposition(_ argument: CommandArgument) throws {
        let item = try #require(controller.plan?.items.first)
        controller.beginPlanEditing(item.stamp, source: controller.buffer)
        try #require(controller.editParameter(argument, source: controller.buffer) != nil)
        controller.endPlanEditing(try #require(controller.editingPlanItem?.stamp), source: controller.buffer)
    }
}

extension UnifiedSearchTestHost {
    func compositionMode(_ parameter: CommandParameterID, _ mode: CommandFieldOperation,
                         fixture: UnifiedSearchTaskCreateFixture) async throws {
        for _ in 0..<6 {
            let draft = try #require(fixture.controller.editingDraft)
            if (draft.arguments.first { $0.parameter == parameter }?.operation ?? .unspecified) == mode { return }
            let node = try await compositionPicker("unified.parameter.mode." + parameter.rawValue)
            try await PickerNativeTestSupport.keyboardSelection(node, moveDown: true, in: window)
            try await settle()
        }
        try #require(fixture.controller.editingDraft?.arguments.first { $0.parameter == parameter }?.operation == mode,
                     "字段模式未通过原生菜单切换到目标值")
    }

    func prepareAndAcceptComposition(_ fixture: UnifiedSearchTaskCreateFixture) async throws -> CommandTaskCreatePreparation {
        try await clickCompositionControl("unified.task.prepare")
        let preview = try #require(fixture.controller.currentTaskComposition,
            "准备失败：visible=\(fixture.controller.operationVisible)，issue=\(fixture.controller.compositionFailure ?? "none")，active=\(fixture.controller.operations?.active != nil)，plan=\(fixture.controller.plan?.items.count ?? -1)")
        #expect(preview.canPrepareExecution)
        try fixture.noCompositionWrites()
        try await clickCompositionControl("unified.composition.accept")
        try fixture.noCompositionWrites()
        return try #require(fixture.controller.currentTaskAcceptance)
    }

    func clickCompositionControl(_ identifier: String) async throws {
        let node = try resultNode(identifier)
        try await revealCompositionControl(node)
        try await SettingsButtonTestSupport.click(node, in: window)
    }

    func revealCompositionControl(_ node: NSObject) async throws {
        let boundary = try #require(SettingsButtonTestSupport.elements(window.contentView)
            .compactMap { $0 as? UnifiedSearchOperationBoundary }.first)
        for _ in 0..<3 {
            try await SettingsButtonTestSupport.reveal(node, in: window)
            if boundary.convert(boundary.bounds, to: nil).contains(try SettingsButtonTestSupport.frame(node, in: window)) { break }
        }
        let frame = try SettingsButtonTestSupport.frame(node, in: window)
        try #require(boundary.convert(boundary.bounds, to: nil).contains(frame),
                     "目标必须完整位于操作面板内，panel=\(boundary.convert(boundary.bounds, to: nil))，control=\(frame)")
    }

    /// formRow 的辅助身份属于整行；实际鼠标必须点中其中的 NSPopUpButton，不能点空白。
    func compositionPicker(_ identifier: String) async throws -> NSPopUpButton {
        let row = try resultNode(identifier)
        try await revealCompositionControl(row)
        let rect = try SettingsButtonTestSupport.frame(row, in: window)
        return try #require(SettingsButtonTestSupport.elements(window.contentView).compactMap { $0 as? NSPopUpButton }
            .first {
                let frame = $0.convert($0.bounds, to: nil)
                return rect.contains(.init(x: frame.midX, y: frame.midY))
            })
    }

    func assertCompositionTagFocus() throws {
        let node = try resultNode("unified.tags.choose")
        let selector = NSSelectorFromString("isAccessibilityFocused")
        try #require(node.responds(to: selector))
        let focused = unsafeBitCast(node.method(for: selector), to: (@convention(c) (AnyObject, Selector) -> Bool).self)
        #expect(focused(node, selector), "返回原标签选择按钮的键盘焦点")
    }
}
