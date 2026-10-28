import AppKit
import SwiftUI
import Testing
@testable import AreaChain

/// 修复批 M-7G 检查点 C：各家族原生端到端。真实原生输入（编辑器输入、Return、⌘Return 键盘事件）走正式版装配，
/// 一半用例在开始草稿后先真实切走窗口再切回（遮罩后由 Return 显式恢复）。到达深度如实记录：
/// 设置在原生里写入偏好；其余家族到达提交入口（⌘Return）并得到对应适配器的回应（预览、确认或具体失败，不是“暂不可执行”）。
/// 需要对象的家族在这里不选对象，因此适配器回应的是缺少目标；写入路径由各家族自己的原生测试覆盖。前台套件。
@Suite(.serialized) @MainActor struct UnifiedSearchFamilyNativeTests {
    struct Family: CustomStringConvertible, Sendable {
        let name: String
        let command: String
        let switchesAway: Bool
        var description: String { name }
    }

    static let workspaceFamilies: [Family] = [
        .init(name: "任务", command: "todo.create", switchesAway: true),
        .init(name: "子任务", command: "subtask.create", switchesAway: false),
        .init(name: "习惯", command: "routine.create", switchesAway: true),
        .init(name: "批量", command: "batch.completion", switchesAway: false),
        .init(name: "转换", command: "routine.toTodo", switchesAway: true),
        .init(name: "回收", command: "todo.trash", switchesAway: false),
        .init(name: "复制", command: "todo.copy", switchesAway: true),
        .init(name: "标签", command: "tag.create", switchesAway: false),
        .init(name: "手记", command: "diary.create", switchesAway: true),
        .init(name: "图片", command: "image.trash", switchesAway: false),
        .init(name: "剪贴板", command: "clipboard.pinned", switchesAway: true),
        .init(name: "页面", command: "tasks.filter", switchesAway: false),
        .init(name: "设置", command: "setting.truncation", switchesAway: true),
        .init(name: "日历", command: "calendar.create", switchesAway: false),
        .init(name: "四象限", command: "quadrant.priority", switchesAway: true),
        .init(name: "安排", command: "gantt.shift", switchesAway: false),
    ]

    static let menubarFamilies: [Family] = [
        .init(name: "设置", command: "setting.truncation", switchesAway: true),
        .init(name: "任务新建", command: "todo.create", switchesAway: false),
        .init(name: "手记新建", command: "diary.create", switchesAway: true),
    ]

    @Test(arguments: workspaceFamilies) func workspaceFamilyReachesSubmission(_ family: Family) async throws {
        try await Self.run(family, kind: .workspace)
    }

    @Test(arguments: menubarFamilies) func menubarFamilyReachesSubmission(_ family: Family) async throws {
        try await Self.run(family, kind: .menubar)
    }

    static func run(_ family: Family, kind: UnifiedSearchFocusRecoveryTests.Kind) async throws {
        let host = try UnifiedSearchFocusHost(kind)
        defer { host.close() }
        try await host.start()
        let command = try #require(CommandCatalog.standard.command(id: .init(rawValue: family.command)))
        let controller = host.controller
        #expect(controller.disposition(for: command.id).kind == .executable, "\(family.name) 标签应为可执行")
        try await host.type(command.path)
        if UnifiedSearchController.routesAsNavigation(command) {
            // 不建草稿的家族（Return 直接执行）：切走再切回后按 Return，由显式恢复后执行，不能报未装配或不支持。
            if family.switchesAway { try await host.switchAwayAndBack() }
            try await host.pressReturnUntil { controller.navigationMessage != "unified.navigation.hint" }
            #expect(!["unified.navigation.unsupported", "unified.navigation.unassembled", "unified.navigation.stale"]
                .contains(controller.navigationMessage), "\(family.name)：\(controller.navigationMessage)")
            return
        }
        try await host.pressReturnUntil { controller.operations?.active?.commandID == command.id }
        try #require(controller.operations?.active?.commandID == command.id, "\(family.name) 未开始草稿")
        #expect(host.operationPanelShown)
        if family.switchesAway {
            try await host.switchAwayAndBack()
            #expect(!host.operationPanelShown)
            try await host.key(36, "\r")
            #expect(host.operationPanelShown, "\(family.name) 切回后 Return 未恢复面板")
        }
        let before = responses(controller)
        try await host.key(36, "\r", flags: .command)
        for _ in 0..<50 where responses(controller) == before { try await Task.sleep(for: .milliseconds(20)) }
        let blocked = controller.settingFailure?.issue == .unsupported || controller.operationMessage == "unified.operation.submitBlocked"
        #expect(!blocked, "\(family.name) 提交落到“暂不可执行”")
        #expect(responses(controller) != before, "\(family.name) ⌘Return 没有得到适配器回应")
    }

    /// 设置家族在原生里走到写入：/setting/appearance → 参数候选“深色” → ⌘Return；先切走再切回。
    @Test(arguments: UnifiedSearchFocusRecoveryTests.Kind.allCases) func appearanceWritesPreference(kind: UnifiedSearchFocusRecoveryTests.Kind) async throws {
        let host = try UnifiedSearchFocusHost(kind)
        defer { host.close() }
        try await host.start()
        try await host.switchAwayAndBack()
        try await host.type("/setting/appearance/da")
        try await host.pressReturnUntil { host.controller.operations?.active?.arguments.contains { $0.value == .choice("dark") } == true }
        #expect(host.operationPanelShown)
        try await host.key(36, "\r", flags: .command)
        for _ in 0..<50 where host.fixture.preferences.appearance != .dark { try await Task.sleep(for: .milliseconds(20)) }
        #expect(host.fixture.preferences.appearance == .dark)
    }

    /// 各家族适配器回应的可观察字段（只比是否出现，不读内容）。
    static func responses(_ c: UnifiedSearchController) -> [Bool] {
        [c.taskCreatePreparation != nil, c.taskCreateFailure != nil, c.taskCompositionPreview != nil, c.compositionFailure != nil,
         c.subtaskPreview != nil, c.subtaskFailure != nil, c.routineCreatePreview != nil, c.routineCreateFailure != nil,
         c.routinePreview != nil, c.routineFailure != nil, c.batchPreview != nil, c.batchFailure != nil,
         c.convertPreview != nil, c.convertConfirmation != nil, c.convertFailure != nil,
         c.trashPreview != nil, c.trashConfirmation != nil, c.trashFailure != nil, c.taskCopyPreview != nil, c.taskCopyFailure != nil,
         c.simplePreview != nil, c.simpleConfirmation != nil, c.simpleFailure != nil, c.pagePreview != nil, c.pageReceipt != nil,
         c.pageFailure != nil, c.clipboardCapture.preview != nil, c.settingFailure != nil, c.settingExecution != nil,
         c.settingConfirmation != nil, c.taskFieldPreview != nil, c.taskFieldFailure != nil, c.taskTitlePreview != nil,
         c.taskTitleFailure != nil, c.plan?.items.isEmpty == false, c.operationMessage != "unified.operation.notExecuted"]
    }
}
