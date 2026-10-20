import AppKit
import SwiftData
import Testing
@testable import AreaChain

/// X-1 原生夹具：合成内存库、私有事件与计数 fake 刷新；四个标签指令只在此显式装配。
@MainActor final class UnifiedSearchSimpleFixture {
    let service: SimpleCommandFixture
    let results: UnifiedSearchResultsFixture
    var controller: UnifiedSearchController { results.controller }

    /// 合并批 M-2：organize 为真时另装配标签整理规格（合并、解绑、回收、恢复）。
    init(organize: Bool = false, restore: Bool = false) throws {
        let service = try SimpleCommandFixture(organize: organize, restore: restore)
        self.service = service
        var batch = QueryBatchFixture.empty("/tags")
        _ = TagContentQueryReader(context: service.context).readSources(into: &batch)
        let environment = service.environment!
        let specs = TagCommandSpecs.all() + (organize ? TagOrganizeSpecs.all(service.organizing) : [])
            + (restore ? TrashRestoreSpec.all() : [])
        results = try .init(batch, pageSize: 20, simple: { coordinator in
            SimpleCommandAdapter(coordinator: coordinator, environment: environment, specs: specs, capability: .open)
        })
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

    func begin(_ path: String, host: UnifiedSearchTestHost) async throws {
        let editor = try host.editor
        editor.insertText(path, replacementRange: .init(location: 0, length: editor.string.utf16.count))
        try await host.settle()
        try await host.key(48, "\t")
    }

    /// 经原参数文本框输入名字：原生插入文本后 Return 确认，与其他短文本参数同一入口。
    func typeName(_ name: String, host: UnifiedSearchTestHost) async throws {
        let editor = try await host.focusParameter(.name)
        editor.insertText(name, replacementRange: editor.selectedRange())
        try await host.settle()
        try await host.key(36, "\r")
    }

    func chooseTargets(_ tags: [TagItem], host: UnifiedSearchTestHost) async throws {
        try await host.clickCompositionControl("unified.objects.choose.target")
        await controller.objectSelectionTask?.value
        try await host.settle()
        try await UnifiedSearchCommandDriver.select(tags.map(service.target), controller: controller, host: host)
    }

    func prepareAndAccept(_ host: UnifiedSearchTestHost, name: String) async throws -> CommandSimpleAcceptance {
        try await host.clickCompositionControl("unified.simple.prepare")
        let preview = try #require(controller.currentSimplePreview, "准备失败：\(controller.simpleFailure ?? "none")")
        #expect(service.count("save") == 0 && service.count("ui") == 0 && !service.context.hasChanges)
        try await host.revealSettingControlInsidePanel("unified.simple.values")
        try host.snapshot("x1-" + name + "-preview")
        try await host.clickCompositionControl("unified.simple.accept")
        let accepted = try #require(controller.currentSimpleAcceptance)
        #expect(accepted.preview == preview && service.count("save") == 0)
        return accepted
    }

    /// 按钮与 ⌘Return 同一入口；保存后再次提交不会重复写入。
    func save(_ host: UnifiedSearchTestHost, name: String, chord: Bool) async throws -> CommandSimpleFacts {
        if chord {
            host.window.makeFirstResponder(try host.field)
            try await host.settle()
            try await host.key(36, "\r", flags: .command)
        } else { try await host.clickCompositionControl("unified.simple.save") }
        let facts = try #require(controller.simpleUnit?.simple, "未执行：\(controller.simpleFailure ?? "none")")
        #expect(facts.state == .saved && service.count("save") == 1 && service.count("ui") == 1)
        controller.requestOperationSubmit(controller.buffer)
        try await host.settle()
        #expect(service.count("save") == 1)
        try await host.revealSettingControlInsidePanel("unified.simple.status")
        try host.snapshot("x1-" + name + "-saved")
        return facts
    }

    func text(_ identifier: String, host: UnifiedSearchTestHost) throws -> String? {
        try UnifiedSearchCommandDriver.text(identifier, host: host)
    }
}
