import AppKit
import SwiftData
import Testing
@testable import AreaChain

/// T-M4 原生夹具：合成内存库、私有事件与 fake 剪贴板；回收与复制只在此显式装配。
@MainActor final class UnifiedSearchTrashFixture {
    let service: TrashCommandFixture
    let results: UnifiedSearchResultsFixture
    let writer = FakeClipboardWriter()
    let privacy = NotificationCenter()
    var controller: UnifiedSearchController { results.controller }
    var base: BatchCommandFixture { service.base }

    init(count: Int = 3) throws {
        service = try TrashCommandFixture(count: count)
        service.base.routine.isEnabled = true
        service.base.todos[1].notes = "  第二项备注\n第二行 👩🏽‍💻  "
        try service.context.save()
        var batch = QueryBatchFixture.empty("/tasks")
        var issues: [TaskContentQueryReadIssue] = []
        TaskContentQueryReader(context: service.context).readSources(into: &batch, issues: &issues)
        #expect(issues.isEmpty)
        _ = RoutineContentQueryReader(reads: .init(context: service.context)).readSources(
            into: &batch, observation: RoutineContentQueryFixture.observation(batch.dates.todayKey))
        batch.facts.metadata = .init(tagNames: Dictionary(uniqueKeysWithValues: service.base.tags.map { ($0.id, $0.name) }),
                                     privateTagIDs: [])
        let base = service.base
        let copy = try TaskCopyCommandEnvironment(context: service.context, source: { target in
            let notes = base.todos.first { $0.id == target.id }.flatMap { TaskCopyContent.notes($0.notes) }
            return .init(revision: base.sourceRevision, protection: .ordinary, notes: notes == nil ? .absent : .present)
        }, writer: writer)
        results = try .init(batch, pageSize: 20, privacyCenter: privacy, trashEnvironment: service.base.environment,
                            trashCapability: .softTrash, taskCopyEnvironment: copy)
    }

    /// 0 标准英文浅色、1 紧凑英文深色、2 标准中文深色、3 紧凑中文浅色；紧凑 304pt 为最小支持宽度代表。
    func host(_ style: Int) async throws -> UnifiedSearchTestHost {
        _ = try await results.publish()
        let host = UnifiedSearchTestHost(layout: style % 2 == 0 ? .standard : .compact,
            width: style % 2 == 0 ? 444 : 304, locale: style < 2 ? "en" : "zh-Hans",
            dark: style == 1 || style == 2, results: controller, operations: true)
        try await host.start()
        return host
    }

    func command(_ path: String, host: UnifiedSearchTestHost) async throws {
        let editor = try host.editor
        editor.insertText(path, replacementRange: .init(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        try await host.key(48, "\t")
        try await host.clickCompositionControl("unified.objects.choose.target")
        await controller.objectSelectionTask?.value
        try await host.settle()
    }

    func select(_ objects: [CommandObjectReference], host: UnifiedSearchTestHost) async throws {
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

    func prepareAndAccept(_ host: UnifiedSearchTestHost, name: String) async throws -> CommandTrashAcceptance {
        try await host.clickCompositionControl("unified.trash.prepare")
        let preview = try #require(controller.currentTrashPreview, "回收准备失败：\(controller.trashFailure ?? "none")")
        #expect(service.count("save") == 0 && service.count("ui") == 0)
        try await host.revealSettingControlInsidePanel("unified.trash.values")
        try host.snapshot("tm4-" + name + "-preview")
        try await host.clickCompositionControl("unified.trash.accept")
        let accepted = try #require(controller.currentTrashAcceptance)
        #expect(accepted.preview == preview && service.count("save") == 0)
        return accepted
    }

    /// ⌘Return 与“检查后移到回收站”同一入口：只打开确认，绝不写入。
    func openConfirmation(_ host: UnifiedSearchTestHost, chord: Bool) async throws -> CommandTrashConfirmation {
        if chord {
            host.window.makeFirstResponder(try host.field)
            try await host.settle()
            try await host.key(36, "\r", flags: .command)
        } else { try await host.clickCompositionControl("unified.trash.review") }
        let confirmation = try #require(controller.trashConfirmation, "确认未打开：\(controller.trashFailure ?? "none")")
        #expect(service.count("save") == 0 && controller.settingExecution == nil)
        return confirmation
    }

    func focused(_ identifier: String, host: UnifiedSearchTestHost) throws -> Bool {
        let node = try host.resultNode(identifier)
        let selector = NSSelectorFromString("isAccessibilityFocused")
        try #require(node.responds(to: selector))
        let read = unsafeBitCast(node.method(for: selector), to: (@convention(c) (AnyObject, Selector) -> Bool).self)
        return read(node, selector)
    }

    func label(_ identifier: String, host: UnifiedSearchTestHost) throws -> String? {
        SettingsButtonTestSupport.value(try host.resultNode(identifier), "accessibilityLabel") as? String
    }

    func has(_ identifier: String, host: UnifiedSearchTestHost) -> Bool {
        SettingsButtonTestSupport.elements(host.window.contentView)
            .contains { SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String == identifier }
    }
}
