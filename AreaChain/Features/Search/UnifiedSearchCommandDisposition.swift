import Foundation

/// “这条指令在当前宿主里怎么处理”的唯一判断入口。导航沿 executeNavigation 使用的同一个 navigationRoute，
/// 操作沿 initialBaseline／requestOperationSubmit 使用的同一组适配器路由；候选标签、状态行与目录级用例都读这里，不另写名单。
extension UnifiedSearchController {
    enum NavigationRoute: Equatable {
        case page(WorkspaceTab), day, focusedObject, board, clipboardWindow(CommandClipboardWindow), system
        /// 习惯月历点某一天：检查器改看焦点习惯的那一天（HabitCheckMonthView → inspectTask(id, dayKey:)）。
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
        if let pages = pageCommands, pages.supportsBoardNavigation(command.id) { return .board }
        if pageCommands != nil, let window = CommandClipboardWindow(rawValue: command.id.rawValue) { return .clipboardWindow(window) }
        if CommandSystemAction.commands.contains(command.id.rawValue) { return .system }
        if let route = CommandOriginalPage.route(for: command.id) { return .originalPage(route) }
        return nil
    }

    /// 草稿提交能到达的适配器（与 requestOperationSubmit 的分派同源：shows* 都由这些 routes* 判断）。
    func routesAdapter(_ id: CommandID) -> Bool {
        ["todo.create", "todo.title"].contains(id.rawValue) || routesTaskField(id)
            || routesBatch(id) || routesSubtask(id) || routesRoutine(id) || routesTrash(id) || routesTaskCopy(id) || routesConvert(id)
            || routesSimple(id) || routesClipboardCapture(id) || routesPage(id)
            || localSettings?.supports(id) == true
    }

    func disposition(for id: CommandID) -> CommandHostDisposition {
        let own = hostDisposition(for: id)
        // 本宿主没接上、工作台能处理的（判断用工作台控制器的同一入口）交给工作台完成；目录不可用的不转交。
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
        if routesAdapter(id) || supportsSetting(id) || (id.rawValue == "routine.create" && routine?.supportsCreation == true) {
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
        case .syntaxHelp, .pageHelp, .example: "unified.candidate.page.help"
        case .useInstead: "unified.candidate.page.useInstead"
        }
    }
}
