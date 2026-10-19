import AppKit
import Testing
@testable import AreaChain

/// 回收与转换的原生夹具共用：输入指令路径、经真实选择器选目标、读焦点与标签。只发合成原生事件。
@MainActor enum UnifiedSearchCommandDriver {
    static func command(_ path: String, controller: UnifiedSearchController, host: UnifiedSearchTestHost) async throws {
        let editor = try host.editor
        editor.insertText(path, replacementRange: .init(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        try await host.key(48, "\t")
        try await host.clickCompositionControl("unified.objects.choose.target")
        await controller.objectSelectionTask?.value
        try await host.settle()
    }

    static func select(_ objects: [CommandObjectReference], controller: UnifiedSearchController,
                       host: UnifiedSearchTestHost) async throws {
        let picker = try #require(controller.objectSelection)
        for target in objects {
            host.window.makeFirstResponder(try host.field)
            for _ in 0...picker.browse.snapshot.visible.count {
                if controller.objectSelection?.browse.active == target { break }
                let active = controller.objectSelection?.browse.active
                let sequence = picker.browse.snapshot.visible
                let forward = (active.flatMap(sequence.firstIndex) ?? -1) < (sequence.firstIndex(of: target) ?? 0)
                try await host.key(forward ? 125 : 126, forward ? "\u{F701}" : "\u{F700}")
            }
            try #require(controller.objectSelection?.browse.active == target,
                "visible=\(picker.browse.snapshot.visible.count) known=\(picker.browse.snapshot.known.count) has=\(picker.browse.snapshot.known.contains(target)) message=\(controller.objectSelectionMessage) results=\(controller.session.isMasked)")
            try await host.clickCompositionControl("unified.select." + target.searchIdentifier)
        }
        try await host.clickCompositionControl("unified.objects.accept")
        await controller.objectSelectionTask?.value
        try await host.settle()
    }

    static func focused(_ identifier: String, host: UnifiedSearchTestHost) throws -> Bool {
        let node = try host.resultNode(identifier)
        let selector = NSSelectorFromString("isAccessibilityFocused")
        try #require(node.responds(to: selector))
        let read = unsafeBitCast(node.method(for: selector), to: (@convention(c) (AnyObject, Selector) -> Bool).self)
        return read(node, selector)
    }

    static func label(_ identifier: String, host: UnifiedSearchTestHost) throws -> String? {
        SettingsButtonTestSupport.value(try host.resultNode(identifier), "accessibilityLabel") as? String
    }

    /// 静态文字的可读内容：SwiftUI 可能放在 label、value 或 title 之一。
    static func text(_ identifier: String, host: UnifiedSearchTestHost) throws -> String? {
        let node = try host.resultNode(identifier)
        return ["accessibilityLabel", "accessibilityValue", "accessibilityTitle"].lazy
            .compactMap { SettingsButtonTestSupport.value(node, $0) as? String }.first { !$0.isEmpty }
    }

    static func has(_ identifier: String, host: UnifiedSearchTestHost) -> Bool {
        SettingsButtonTestSupport.elements(host.window.contentView)
            .contains { SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String == identifier }
    }
}
