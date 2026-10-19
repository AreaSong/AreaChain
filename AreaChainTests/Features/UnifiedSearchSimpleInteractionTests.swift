import AppKit
import SwiftData
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor struct UnifiedSearchSimpleInteractionTests {
    private static func localized(_ key: String, style: Int) -> String {
        L10n.format(key, locale: Locale(identifier: style < 2 ? "en" : "zh-Hans"))
    }

    @Test(arguments: [0, 1, 2, 3]) func createTagThroughNativePanel(style: Int) async throws {
        let f = try UnifiedSearchSimpleFixture()
        defer { f.results.stop() }
        let host = try await f.host(style)
        defer { host.close() }
        try await f.begin("/tags/add", host: host)
        try await f.typeName("原生新建 · Native", host: host)
        let accepted = try await f.prepareAndAccept(host, name: "create-\(style)")
        #expect(accepted.preview.after.rows.map(\.title) == ["原生新建 · Native"])
        let change = try #require(try f.text("unified.simple.change.name", host: host))
        #expect(change.contains("原生新建 · Native"))
        _ = try await f.save(host, name: "create-\(style)", chord: style % 2 == 0)
        #expect(try f.service.live().contains { $0.name == "原生新建 · Native" })
        #expect(try f.text("unified.simple.status", host: host) == Self.localized("unified.simple.tag.create.saved", style: style))
    }

    @Test(arguments: [1, 2]) func renameColorAndOrderTagTargets(style: Int) async throws {
        let rename = try UnifiedSearchSimpleFixture()
        defer { rename.results.stop() }
        var host = try await rename.host(style)
        try await rename.begin("/tags/rename", host: host)
        try await rename.chooseTargets([rename.service.tags[0]], host: host)
        try await rename.typeName("原生改名 · Renamed", host: host)
        _ = try await rename.prepareAndAccept(host, name: "rename-\(style)")
        _ = try await rename.save(host, name: "rename-\(style)", chord: false)
        #expect(rename.service.tags[0].name == "原生改名 · Renamed" && rename.service.tags[1].name == "家庭 · Home")
        host.close()

        let color = try UnifiedSearchSimpleFixture()
        defer { color.results.stop() }
        host = try await color.host(style)
        try await color.begin("/tags/color", host: host)
        try await color.chooseTargets([color.service.tags[0], color.service.tags[2]], host: host)
        let picker = try await host.compositionPicker("unified.parameter.choice.color")
        for _ in 0..<8 where color.controller.editingDraft?.arguments.first(where: { $0.parameter == .color })?.value != .choice("ink") {
            try await PickerNativeTestSupport.keyboardSelection(picker, moveDown: true, in: host.window)
            try await host.settle()
        }
        #expect(color.controller.editingDraft?.arguments.first { $0.parameter == .color }?.value == .choice("ink"))
        _ = try await color.prepareAndAccept(host, name: "color-\(style)")
        _ = try await color.save(host, name: "color-\(style)", chord: true)
        #expect(color.service.tags[0].colorToken == "ink" && color.service.tags[2].colorToken == "ink")
        host.close()

        let order = try UnifiedSearchSimpleFixture()
        defer { order.results.stop() }
        // 先倒排现有位置，使结果列表顺序大概率与当前位置不同，覆盖真正写入的路径。
        for (index, tag) in order.service.tags.reversed().enumerated() { tag.sortOrder = index }
        try order.service.context.save()
        host = try await order.host(style)
        defer { host.close() }
        let wanted = [order.service.tags[1], order.service.tags[2], order.service.tags[0]]
        try await order.begin("/tags/order", host: host)
        try await order.chooseTargets(wanted, host: host)
        let accepted = try await order.prepareAndAccept(host, name: "order-\(style)")
        // 原选择器按结果列表顺序登记多选（不是点击顺序，且随语言排序）；新顺序以冻结目标为准并在预览里逐项列出。
        let frozen = accepted.preview.input.targets.objects
        #expect(Set(frozen.map(\.id)) == Set(wanted.map(\.id)))
        if accepted.preview.noChange {
            try await host.clickCompositionControl("unified.simple.save")
            #expect(order.controller.simpleUnit?.simple?.state == .noChange && order.service.count("save") == 0)
        } else {
            _ = try await order.save(host, name: "order-\(style)", chord: false)
        }
        #expect(try order.service.live().map(\.id) == frozen.map(\.id))
    }

    /// 只选部分标签排序：准备即拒绝，显示原因，不写入。
    @Test func partialOrderShowsReasonAndWritesNothing() async throws {
        let f = try UnifiedSearchSimpleFixture()
        defer { f.results.stop() }
        let host = try await f.host(0)
        defer { host.close() }
        try await f.begin("/tags/order", host: host)
        try await f.chooseTargets([f.service.tags[1], f.service.tags[0]], host: host)
        try await host.clickCompositionControl("unified.simple.prepare")
        #expect(f.controller.currentSimplePreview == nil && f.controller.simpleFailure == "unified.simple.problem.incompleteOrder")
        #expect(try f.text("unified.simple.issue", host: host) == Self.localized("unified.simple.problem.incompleteOrder", style: 0))
        #expect(f.service.count("save") == 0 && f.controller.settingExecution == nil)
    }
}
