import Foundation

/// “这条指令在当前宿主里怎么处理”的唯一判断入口。
extension UnifiedSearchController {
    enum NavigationRoute: Equatable {
        case page(WorkspaceTab), day, focusedObject
        /// 习惯月历点某一天：检查器改看焦点习惯的那一天。
        case routineDay
        /// 检查器的关闭按钮；先让检查器按原失焦规则保存（或在隔离宿主留草稿），再关闭。
        case closeInspector
        case originalPage(CommandOriginalPage)
    }

    /// executeNavigation 分派与可用性判断共用；nil 表示当前宿主没有接上这条导航（例如菜单栏没有工作台路由）。
    func navigationRoute(for command: CommandDescriptor) -> NavigationRoute? {
        guard navigationRouter != nil else { return nil }
        if let page = WorkspaceNavigationDestination.page(command: command.id) { return .page(page) }
        if command.id.rawValue == "inspector.day" { return .day }
        if command.id.rawValue == "occurrence.inspect" { return .routineDay }
        if command.id.rawValue == "inspector.close" { return .closeInspector }
        if command.id.rawValue == "inspector.open" || command.id.rawValue == "go.tagList" { return .focusedObject }
        if let route = CommandOriginalPage.route(for: command.id) { return .originalPage(route) }
        return nil
    }

    /// 动作注册表中已注册或声明的指令可执行性判断。
    func routesAdapter(_ id: CommandID) -> Bool {
        StandardActionCatalog.bootstrapIfNeeded()
        if cliSession.resolveCLIAction(id.rawValue) != nil {
            return true
        }
        if let command = CommandCatalog.standard.command(id: id), case .declared = command.availability {
            return true
        }
        return false
    }

    func disposition(for id: CommandID) -> CommandHostDisposition {
        let own = hostDisposition(for: id)
        if own == .navigates, id.rawValue == "workspace.close", hasUnsavedCommandWork { return .blockedByUnsavedWork }
        guard own == .unwired, let handoff = workspaceHandoff,
              [.executable, .originalPage].contains(handoff.disposition(id).kind) else { return own }
        return .workspaceHandoff
    }

    private func hostDisposition(for id: CommandID) -> CommandHostDisposition {
        guard let command = CommandCatalog.standard.command(id: id) else { return .unwired }
        if Self.routesAsNavigation(command) {
            switch navigationRoute(for: command) {
            case .originalPage(let route)?:
                return .originalPage(pageKey: Self.pageKey(route.destination), finishesOnPage: route.finishesOnPage)
            case .some: return .navigates
            case nil: return catalogReason(command).map { .catalogUnavailable(reasonKey: $0) } ?? .unwired
            }
        }
        if routesAdapter(id) {
            return .executable
        }
        return catalogReason(command).map { .catalogUnavailable(reasonKey: $0) } ?? .unwired
    }

    private func catalogReason(_ command: CommandDescriptor) -> String? {
        switch command.availability {
        case .declared: nil
        case .unavailable(let reason), .unresolved(let reason): reason
        }
    }

    static func pageKey(_ destination: CommandOriginalPage.Destination) -> String {
        switch destination {
        case .page(let raw, _): WorkspaceTab(rawValue: raw)?.titleKeyName ?? "unified.candidate.page.original"
        case .object: "unified.candidate.page.object"
        case .pageHelp, .example: "unified.candidate.page.help"
        case .useInstead: "unified.candidate.page.useInstead"
        }
    }
}
