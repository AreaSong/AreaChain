import AppKit
import SwiftUI
import Testing
@testable import AreaChain

/// 合并批 M-2 原生页面指令的共用操作：与参数确认、对象选择发出的事件相同；面板按钮先滚进操作面板，
/// 再用 AXPress 触发同一入口（工作台窗口里合成鼠标到不了操作面板，见 §9.96 缺口）。
extension UnifiedSearchNavigationFixture {
    func begin(_ command: String) async throws {
        try #require(controller.beginOperation(.init(rawValue: command), source: controller.buffer) != nil)
        try await settle()
    }

    func edit(_ argument: CommandArgument) async throws {
        let stamp = try #require(controller.operations?.active?.stamp)
        try #require(controller.sendOperation(.edit(stamp, argument), source: controller.buffer) != nil)
        try await settle()
    }

    func target(_ objects: [CommandObjectReference]) async throws {
        let stamp = try #require(controller.operations?.active?.stamp)
        try #require(controller.sendOperation(.selectTargets(stamp, .init(objects.count == 1 ? .single : .selected, objects: objects),
                                                             baseline: nil), source: controller.buffer) != nil)
        try await settle()
    }

    func press(_ id: String) async throws {
        let window = try #require(window)
        let node = try #require(SettingsButtonTestSupport.elements(window.contentView).first {
            SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String == id
        }, "缺少 \(id)")
        let boundary = try #require(SettingsButtonTestSupport.elements(window.contentView)
            .compactMap { $0 as? UnifiedSearchOperationBoundary }.first)
        let scroll = try #require(SettingsButtonTestSupport.elements(window.contentView).compactMap { $0 as? NSScrollView }
            .first { $0.convert($0.bounds, to: nil) == boundary.convert(boundary.bounds, to: nil) })
        let document = try #require(scroll.documentView)
        let rect = try SettingsButtonTestSupport.frame(node, in: window)
        document.scrollToVisible(document.convert(rect.insetBy(dx: 0, dy: -60), from: nil))
        scroll.reflectScrolledClipView(scroll.contentView)
        try await settle()
        _ = node.perform(NSSelectorFromString("accessibilityPerformPress"))
        try await settle()
        await controller.navigationTask?.value
        try await settle()
    }

    func exists(_ id: String) throws -> Bool {
        let window = try #require(window)
        return SettingsButtonTestSupport.elements(window.contentView).contains {
            SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String == id
        }
    }

    func label(_ id: String) throws -> String {
        let window = try #require(window)
        let node = try #require(SettingsButtonTestSupport.elements(window.contentView).first {
            SettingsButtonTestSupport.value($0, "accessibilityIdentifier") as? String == id
        }, "缺少 \(id)")
        return ["accessibilityLabel", "accessibilityValue"].compactMap { SettingsButtonTestSupport.value(node, $0) as? String }
            .joined(separator: " ")
    }

    /// 装配好页面指令宿主（今天固定为夹具日期）并停在指定页面。
    func assemblePages(_ page: WorkspaceTab) -> WorkspacePageCommands {
        navigation.selectedTab = page
        navigation.boardSelection.inspectingDayKey = day
        let pages = WorkspacePageCommands(router: router, host: hostContext, context: context)
        pages.today = { [day] in day }
        controller.pageCommands = pages
        return pages
    }
}
