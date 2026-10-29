import Foundation

/// 菜单栏把自己没接上、工作台能处理的指令交给工作台。判断用工作台控制器自己的 `disposition(for:)`，
/// 转交走装配里唯一的“显示工作台 → 等窗口可见 → 写入文字”入口；菜单栏不另写执行逻辑。
@MainActor struct UnifiedSearchWorkspaceHandoff {
    let disposition: @MainActor (CommandID) -> CommandHostDisposition
    /// 交出菜单栏当前的指令文字（含已填参数）；工作台在可见后按自己的 Return 路径处理。
    let open: @MainActor (String) -> Void
}

extension UnifiedSearchController {
    /// 菜单栏的 Return：当前指令标为“在工作台完成”时交出同一文字，菜单栏原文字与草稿都不动。
    func handOffToWorkspace(_ source: UnifiedSearchBuffer) -> Bool {
        guard validates(source), let handoff = workspaceHandoff, let command = browsedCommand,
              disposition(for: command.id) == .workspaceHandoff else { return false }
        handoff.open(source.text)
        navigationMessage = "unified.handoff.sent"
        return true
    }

    /// 工作台接到转交的文字（已写入输入框）后：与用户在工作台打同一文字再按 Return 等价。
    /// 导航与打开原页面按文字执行；停在从搜索导航到的目的地时先回到搜索页；需要草稿的指令按路径里的参数开始草稿，
    /// 参数沿接受参数候选的同一校验。
    func openHandedOffCommand() {
        let parsed = CommandPathParser().parse(.init(text: buffer.text))
        guard let command = parsed.command else { return }
        if isNavigationInput { intent(.open, source: buffer); return }
        if returnThenContinue({ [weak self] _ in self?.openHandedOffCommand() }) { return }
        let argument = parsed.arguments.first { acceptsTypedArgument($0, for: command.id) }
        beginOperation(command.id, source: buffer, text: buffer.text, argument: argument)
    }

    /// 工作台有未完成的指令草稿或待执行列表：转交不写入、不替换它们，只显示工作台自己的被挡说明（与关闭工作台被挡同一块）。
    func reportBlockedHandoff() {
        navigationMessage = "unified.handoff.blocked"
        if isNavigationPresented, returnSearch == nil { navigationRouter?.navigation.searchPresentation = true }
    }

    /// 用户自己改字或接受候选即收起被挡说明：之后的输入是新意图，不再与其他面板重复同一句。
    func clearBlockedHandoff() {
        if navigationMessage == "unified.handoff.blocked" { navigationMessage = "unified.navigation.hint" }
    }

    /// 被挡说明只由反馈与未完成工作派生：工作处理完或有了新反馈即收起，不另存状态。
    var showsBlockedHandoff: Bool { navigationMessage == "unified.handoff.blocked" && hasUnsavedCommandWork }
}
