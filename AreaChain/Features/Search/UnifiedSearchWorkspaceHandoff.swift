import Foundation

/// 菜单栏把自己没接上、工作台能处理的指令交给工作台。
@MainActor struct UnifiedSearchWorkspaceHandoff {
    let disposition: @MainActor (CommandID) -> CommandHostDisposition
    let open: @MainActor (String, CommandObjectReference?) -> Void
}

extension UnifiedSearchController {
    func handOffToWorkspace(_ source: UnifiedSearchBuffer) -> Bool {
        guard validates(source), let handoff = workspaceHandoff, let command = browsedCommand,
              disposition(for: command.id) == .workspaceHandoff else { return false }
        handoff.open(source.text, try? session.presentation().pagination.browse.active)
        navigationMessage = "unified.handoff.sent"
        return true
    }

    func openHandedOffCommand() {
        let parsed = CommandPathParser().parse(.init(text: buffer.text))
        guard parsed.command != nil else { return }
        if isNavigationInput { intent(.open, source: buffer); return }
        if returnThenContinue({ [weak self] _ in self?.openHandedOffCommand() }) { return }
        _ = handleCLIIntentIfApplicable(.open, source: buffer)
    }

    func reportBlockedHandoff() {
        navigationMessage = "unified.handoff.blocked"
        if isNavigationPresented, returnSearch == nil { navigationRouter?.navigation.searchPresentation = true }
    }

    func clearBlockedHandoff() {
        if navigationMessage == "unified.handoff.blocked" { navigationMessage = "unified.navigation.hint" }
    }

    var showsBlockedHandoff: Bool { navigationMessage == "unified.handoff.blocked" && hasUnsavedCommandWork }
}
